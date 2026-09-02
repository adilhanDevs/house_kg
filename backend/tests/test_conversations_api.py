"""Контракт API открытия и чтения диалогов."""

from datetime import timedelta
from uuid import UUID

import pytest
from django.urls import reverse
from django.utils import timezone

from apps.catalog.enums import ListingStatus, PropertyKind
from apps.messaging.models import Conversation, Message
from tests.factories import (
    ConversationFactory,
    ListingFactory,
    ListingMediaFactory,
    MessageFactory,
    UserFactory,
)

pytestmark = pytest.mark.django_db


@pytest.mark.parametrize("method", ["get", "post"])
def test_conversation_collection_requires_authentication(api_client, method):
    response = getattr(api_client, method)(
        reverse("messaging:conversation-list"),
        {"listing_slug": "any-listing"},
    )

    assert response.status_code == 401


def test_open_active_listing_snapshots_listing_and_ignores_participant_input(client_for):
    seller = UserFactory(name="Продавец")
    buyer = UserFactory(name="Покупатель")
    attacker = UserFactory()
    listing = ListingFactory(
        owner=seller,
        status=ListingStatus.ACTIVE,
        address="  ул. Исанова, 10  ",
        price="125000.00",
        currency="USD",
    )
    cover = ListingMediaFactory(listing=listing, is_cover=True, order=0)

    response = client_for(buyer).post(
        reverse("messaging:conversation-list"),
        {
            "listing_slug": listing.slug,
            "buyer_id": attacker.id,
            "seller_id": attacker.id,
        },
    )

    assert response.status_code == 201
    assert response.data["listing_slug"] == listing.slug
    assert response.data["listing_title"] == "ул. Исанова, 10"
    assert response.data["listing_price"] == "125000.00"
    assert response.data["listing_currency"] == "USD"
    assert response.data["listing_cover_url"] == cover.file.url
    assert response.data["peer"] == {
        "id": seller.id,
        "name": "Продавец",
        "avatar_url": None,
    }
    assert response.data["latest_message"] is None
    assert response.data["unread_count"] == 0
    conversation = Conversation.objects.get()
    assert conversation.buyer == buyer
    assert conversation.seller == seller


def test_open_listing_without_address_snapshots_kind_label(client_for):
    listing = ListingFactory(
        status=ListingStatus.ACTIVE,
        address="   ",
        kind=PropertyKind.HOUSE,
    )

    response = client_for(UserFactory()).post(
        reverse("messaging:conversation-list"),
        {"listing_slug": listing.slug},
    )

    assert response.status_code == 201
    assert response.data["listing_title"] == listing.get_kind_display()


def test_opening_same_listing_returns_existing_conversation(client_for):
    listing = ListingFactory(status=ListingStatus.ACTIVE)
    buyer = UserFactory()
    client = client_for(buyer)

    first = client.post(reverse("messaging:conversation-list"), {"listing_slug": listing.slug})
    second = client.post(reverse("messaging:conversation-list"), {"listing_slug": listing.slug})

    assert first.status_code == 201
    assert second.status_code == 200
    assert first.data["id"] == second.data["id"]
    assert Conversation.objects.count() == 1


def test_opening_existing_conversation_returns_annotated_message_state(client_for):
    buyer = UserFactory()
    conversation = ConversationFactory(
        buyer=buyer,
        buyer_last_read_at=timezone.now() - timedelta(minutes=5),
    )
    message = MessageFactory(conversation=conversation, sender=conversation.seller, text="new")

    response = client_for(buyer).post(
        reverse("messaging:conversation-list"),
        {"listing_slug": conversation.listing_slug},
    )

    assert response.status_code == 200
    assert response.data["latest_message"]["id"] == str(message.id)
    assert response.data["unread_count"] == 1


def test_seller_cannot_open_conversation_with_self(client_for):
    listing = ListingFactory(status=ListingStatus.ACTIVE)

    response = client_for(listing.owner).post(
        reverse("messaging:conversation-list"),
        {"listing_slug": listing.slug},
    )

    assert response.status_code == 409
    assert response.data["error"]["message"] == "Нельзя написать самому себе."
    assert not Conversation.objects.exists()


@pytest.mark.parametrize(
    "status",
    [ListingStatus.DRAFT, ListingStatus.PENDING, ListingStatus.ARCHIVED, ListingStatus.SOLD],
)
def test_inactive_listing_cannot_be_opened(client_for, status):
    listing = ListingFactory(status=status)

    response = client_for(UserFactory()).post(
        reverse("messaging:conversation-list"),
        {"listing_slug": listing.slug},
    )

    assert response.status_code == 404
    assert not Conversation.objects.exists()


def test_stranger_cannot_see_conversation_detail(client_for):
    conversation = ConversationFactory()

    response = client_for(UserFactory()).get(
        reverse("messaging:conversation-detail", args=[conversation.id])
    )

    assert response.status_code == 404


@pytest.mark.parametrize("participant", ["buyer", "seller"])
def test_both_participants_can_see_detail(client_for, participant):
    conversation = ConversationFactory()
    user = getattr(conversation, participant)

    response = client_for(user).get(
        reverse("messaging:conversation-detail", args=[conversation.id])
    )

    assert response.status_code == 200
    assert response.data["id"] == str(conversation.id)
    assert response.data["peer"]["id"] == conversation.peer_for(user).id


def test_conversation_list_is_newest_first(client_for):
    buyer = UserFactory()
    older = ConversationFactory(buyer=buyer, last_message_at=timezone.now() - timedelta(hours=1))
    newest = ConversationFactory(buyer=buyer, last_message_at=timezone.now())

    response = client_for(buyer).get(reverse("messaging:conversation-list"))

    assert response.status_code == 200
    assert [item["id"] for item in response.data["results"]] == [
        str(newest.id),
        str(older.id),
    ]


def test_conversation_cursor_uses_uuid_tiebreaker_for_equal_timestamps(client_for):
    buyer = UserFactory()
    shared_timestamp = timezone.now()
    conversation_ids = [UUID(int=value) for value in range(1, 6)]
    for conversation_id in conversation_ids:
        ConversationFactory(
            id=conversation_id,
            buyer=buyer,
            last_message_at=shared_timestamp,
        )
    client = client_for(buyer)
    url = reverse("messaging:conversation-list") + "?page_size=2"
    seen_ids = []

    while url:
        response = client.get(url)
        assert response.status_code == 200
        seen_ids.extend(item["id"] for item in response.data["results"])
        url = response.data["next"]

    assert seen_ids == [str(value) for value in reversed(conversation_ids)]


def test_list_returns_peer_latest_message_and_participant_unread_count(client_for):
    buyer = UserFactory()
    conversation = ConversationFactory(
        buyer=buyer,
        buyer_last_read_at=timezone.now() - timedelta(minutes=30),
    )
    old_message = MessageFactory(conversation=conversation, sender=conversation.seller, text="old")
    new_message = MessageFactory(conversation=conversation, sender=conversation.seller, text="new")
    own_message = MessageFactory(conversation=conversation, sender=buyer, text="mine")
    old_at = timezone.now() - timedelta(hours=1)
    new_at = timezone.now() - timedelta(minutes=10)
    own_at = timezone.now() - timedelta(minutes=5)
    Message.objects.filter(pk=old_message.pk).update(created_at=old_at)
    Message.objects.filter(pk=new_message.pk).update(created_at=new_at)
    Message.objects.filter(pk=own_message.pk).update(created_at=own_at)
    Conversation.objects.filter(pk=conversation.pk).update(last_message_at=own_at)

    response = client_for(buyer).get(reverse("messaging:conversation-list"))

    assert response.status_code == 200
    item = response.data["results"][0]
    assert item["peer"]["id"] == conversation.seller_id
    assert item["latest_message"]["id"] == str(own_message.id)
    assert item["latest_message"]["sender_id"] == buyer.id
    assert item["latest_message"]["text"] == "mine"
    assert item["unread_count"] == 1


def test_unread_count_excludes_messages_sent_by_current_user(client_for):
    buyer = UserFactory()
    conversation = ConversationFactory(
        buyer=buyer,
        buyer_last_read_at=timezone.now() - timedelta(minutes=5),
    )
    MessageFactory(conversation=conversation, sender=buyer, text="mine")

    response = client_for(buyer).get(reverse("messaging:conversation-list"))

    assert response.status_code == 200
    assert response.data["results"][0]["unread_count"] == 0


def test_list_query_count_does_not_grow_with_conversations(client_for, django_assert_num_queries):
    buyer = UserFactory()
    first = ConversationFactory(buyer=buyer)
    MessageFactory(conversation=first, sender=first.seller)
    client = client_for(buyer)

    with django_assert_num_queries(3):
        baseline = client.get(reverse("messaging:conversation-list"))
    assert baseline.status_code == 200

    for _ in range(10):
        conversation = ConversationFactory(buyer=buyer)
        MessageFactory(conversation=conversation, sender=conversation.seller)

    with django_assert_num_queries(3):
        expanded = client.get(reverse("messaging:conversation-list"))
    assert expanded.status_code == 200
    assert expanded.data["count"] == 11
