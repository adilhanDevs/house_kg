"""Бизнес-операции диалогов."""

from typing import Any

from django.db import IntegrityError, transaction
from django.db.models import Prefetch, Q
from django.shortcuts import get_object_or_404

from apps.catalog.covers import COVER_ATTR, cover_candidates, listing_cover_file
from apps.catalog.enums import ListingStatus
from apps.catalog.models import Listing
from apps.common.exceptions import ConflictError
from apps.messaging.models import Conversation, Message
from apps.notifications.models import NotificationType
from apps.notifications.services import notify


def _cover_url(listing: Listing) -> str:
    cover = listing_cover_file(listing)
    return cover.url if cover else ""


def open_conversation(*, user: Any, listing_slug: str) -> tuple[Conversation, bool]:
    """Открывает один диалог покупателя с продавцом по активному объявлению."""
    listing = get_object_or_404(
        Listing.objects.filter(status=ListingStatus.ACTIVE)
        .select_related("owner")
        .prefetch_related(Prefetch("media", queryset=cover_candidates(), to_attr=COVER_ATTR)),
        slug=listing_slug,
    )
    if listing.owner_id == user.id:
        raise ConflictError("Нельзя написать самому себе.")

    lookup = {"listing": listing, "buyer": user, "seller": listing.owner}
    defaults = {
        "listing_slug": listing.slug,
        "listing_title": listing.address.strip() or listing.get_kind_display(),
        "listing_price": listing.price,
        "listing_currency": listing.currency,
        "listing_cover_url": _cover_url(listing),
    }
    with transaction.atomic():
        try:
            with transaction.atomic():
                return Conversation.objects.get_or_create(**lookup, defaults=defaults)
        except IntegrityError:
            conversation = Conversation.objects.select_related("buyer", "seller", "listing").get(
                **lookup
            )
            return conversation, False


@transaction.atomic
def send_message(
    *,
    user: Any,
    conversation: Conversation,
    text: str,
    client_message_id: Any,
) -> tuple[Message, bool]:
    """Отправляет сообщение от участника с идемпотентностью по UUID клиента."""
    locked = get_object_or_404(
        Conversation.objects.select_for_update().filter(Q(buyer=user) | Q(seller=user)),
        pk=conversation.pk,
    )
    message, created = Message.objects.get_or_create(
        sender=user,
        client_message_id=client_message_id,
        defaults={"conversation": locked, "text": text.strip()},
    )
    if message.conversation_id != locked.id:
        raise ConflictError("client_message_id уже использован в другом диалоге.")
    if created:
        locked.last_message_at = message.created_at
        locked.save(update_fields=["last_message_at", "updated_at"])
        peer = locked.seller if locked.buyer_id == user.pk else locked.buyer
        notify(
            peer,
            notification_type=NotificationType.NEW_MESSAGE,
            title=user.name.strip() or "Новое сообщение",
            body=message.text[:140],
            payload={
                "conversation_id": str(locked.id),
                "listing_slug": locked.listing_slug,
                "sender_id": user.pk,
            },
        )
    return message, created


@transaction.atomic
def mark_conversation_read(
    *,
    user: Any,
    conversation: Conversation,
    last_message_id: Any,
) -> int:
    """Монотонно отмечает сообщения участника прочитанными до указанного."""
    locked = get_object_or_404(
        Conversation.objects.select_for_update().filter(Q(buyer=user) | Q(seller=user)),
        pk=conversation.pk,
    )
    message = get_object_or_404(Message, conversation=locked, pk=last_message_id)
    field = "buyer_last_read_at" if locked.buyer_id == user.pk else "seller_last_read_at"
    current = getattr(locked, field)
    if current is not None and current >= message.created_at:
        return 0

    setattr(locked, field, message.created_at)
    locked.save(update_fields=[field, "updated_at"])
    return 1
