"""Фоновые задачи уведомлений: отправка push и слежение за ценами."""

import logging
from decimal import Decimal

from celery import shared_task

logger = logging.getLogger(__name__)

# Минимальное падение цены, о котором стоит писать пользователю.
PRICE_DROP_THRESHOLD = Decimal("0.03")
PRICE_DROP_BATCH = 500


@shared_task(name="notifications.send_push", ignore_result=True, max_retries=2)
def send_push(notification_id: int) -> int:
    """Отправляет push по уже созданному уведомлению."""
    from apps.notifications.models import Notification
    from apps.notifications.push import send_to_user

    notification = Notification.objects.filter(pk=notification_id).select_related("user").first()
    if notification is None:
        logger.warning("Уведомление %s не найдено — push не отправлен", notification_id)
        return 0

    return send_to_user(notification.user, notification)


def _price_drop_body(listing: object, percent: int) -> str:
    """«Цена снизилась на 5%: Технопарк, 3-комн. — 97 000$»."""
    parts = [listing.district.name]
    if not listing.is_plot and listing.rooms:
        parts.append(f"{listing.rooms}-комн.")

    return f"Цена снизилась на {percent}%: {', '.join(parts)} — {listing.price_display}"


@shared_task(name="notifications.notify_price_drop", ignore_result=True)
def notify_price_drop() -> int:
    """Раз в сутки сообщает о подешевевших объектах из избранного.

    Сравнивается цена на момент добавления в избранное; после уведомления
    отметка обновляется, поэтому о том же снижении второй раз не напишем.
    """
    from apps.catalog.enums import ListingStatus
    from apps.engagement.models import Favourite
    from apps.notifications.models import Notification, NotificationType
    from apps.notifications.services import notify_many

    favourites = (
        Favourite.objects.filter(
            listing__status=ListingStatus.ACTIVE,
            price_at_add__isnull=False,
            listing__price_usd__isnull=False,
        )
        .select_related("listing__district", "user")
        .order_by("pk")
    )

    notifications: list[Notification] = []
    updated: list[Favourite] = []

    for favourite in favourites.iterator(chunk_size=PRICE_DROP_BATCH):
        listing = favourite.listing
        was, now = favourite.price_at_add, listing.price_usd
        if was <= 0 or now >= was:
            continue

        drop = (was - now) / was
        if drop < PRICE_DROP_THRESHOLD:
            continue

        percent = int(round(drop * 100))
        notifications.append(
            Notification(
                user=favourite.user,
                type=NotificationType.PRICE_DROP,
                title="Цена снизилась",
                body=_price_drop_body(listing, percent),
                payload={
                    "listing_slug": listing.slug,
                    "old_price_usd": str(was),
                    "new_price_usd": str(now),
                    "percent": percent,
                },
                listing=listing,
            )
        )
        # Запоминаем новую цену — иначе завтра уведомим о том же снижении.
        favourite.price_at_add = now
        updated.append(favourite)

    notify_many(notifications)
    if updated:
        Favourite.objects.bulk_update(updated, ["price_at_add", "updated_at"], batch_size=500)

    logger.info("Уведомлений о снижении цены: %s", len(notifications))
    return len(notifications)
