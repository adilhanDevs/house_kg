"""Контракт API отправки, polling и прочтения сообщений."""

import uuid
from datetime import timedelta

import pytest
from django.urls import reverse
from django.utils import timezone

from apps.messaging.models import Message
from tests.factories import ConversationFactory, MessageFactory, UserFactory

pytestmark = pytest.mark.django_db


def messages_url(conversation):  # noqa: ANN001, ANN201
    return reverse("messaging:message-list", args=[conversation.id])


def read_url(conversation):  # noqa: ANN001, ANN201
    return reverse("messaging:conversation-read", args=[conversation.id])


@pytest.mark.parametrize(
    ("method", "url_name", "payload"),
    [
        ("get", "message-list", None),
        ("post", "message-list", {"text": "Здравствуйте", "client_message_id": uuid.uuid4()}),
        ("post", "conversation-read", {"last_message_id": uuid.uuid4()}),
    ],
)
def test_message_endpoints_require_authentication(api_client, method, url_name, payload):
    conversation = ConversationFactory()
    response = getattr(api_client, method)(
        reverse(f"messaging:{url_name}", args=[conversation.id]),
        payload,
    )

    assert response.status_code == 401


@pytest.mark.parametrize("text", ["   ", "x" * 2001])
def test_message_text_must_be_non_blank_and_at_most_2000_characters(client_for, text):
    conversation = ConversationFactory()

    response = client_for(conversation.buyer).post(
        messages_url(conversation),
        {"text": text, "client_message_id": str(uuid.uuid4())},
    )

    assert response.status_code == 400
    assert "text" in response.data["error"]["details"]
    assert not Message.objects.exists()


@pytest.mark.parametrize("participant", ["buyer", "seller"])
def test_both_participants_can_send_messages(client_for, participant):
    conversation = ConversationFactory()
    user = getattr(conversation, participant)

    response = client_for(user).post(
        messages_url(conversation),
        {"text": "  Объявление актуально?  ", "client_message_id": str(uuid.uuid4())},
    )

    assert response.status_code == 201
    assert response.data["sender_id"] == user.id
    assert response.data["text"] == "Объявление актуально?"
    assert Message.objects.get().sender == user


def test_sender_is_always_the_authenticated_user(client_for):
    conversation = ConversationFactory()

    response = client_for(conversation.buyer).post(
        messages_url(conversation),
        {
            "text": "Это написал покупатель",
            "client_message_id": str(uuid.uuid4()),
            "sender_id": conversation.seller_id,
        },
    )

    assert response.status_code == 201
    assert response.data["sender_id"] == conversation.buyer_id
    assert Message.objects.get().sender_id == conversation.buyer_id


def test_stranger_cannot_insert_message(client_for):
    conversation = ConversationFactory()

    response = client_for(UserFactory()).post(
        messages_url(conversation),
        {"text": "Чужое сообщение", "client_message_id": str(uuid.uuid4())},
    )

    assert response.status_code == 404
    assert not Message.objects.exists()


@pytest.mark.parametrize("endpoint", [messages_url, read_url])
def test_stranger_cannot_access_message_state(client_for, endpoint):
    conversation = ConversationFactory()
    payload = None
    method = "get"
    if endpoint is read_url:
        payload = {"last_message_id": str(MessageFactory(conversation=conversation).id)}
        method = "post"

    response = getattr(client_for(UserFactory()), method)(endpoint(conversation), payload)

    assert response.status_code == 404


def test_retry_does_not_duplicate_message_or_side_effects(client_for):
    conversation = ConversationFactory(last_message_at=timezone.now() - timedelta(days=1))
    client = client_for(conversation.buyer)
    payload = {"text": "Когда можно посмотреть?", "client_message_id": str(uuid.uuid4())}

    first = client.post(messages_url(conversation), payload)
    conversation.refresh_from_db()
    first_last_message_at = conversation.last_message_at
    second = client.post(messages_url(conversation), payload)
    conversation.refresh_from_db()

    assert first.status_code == 201
    assert second.status_code == 200
    assert first.data["id"] == second.data["id"]
    assert conversation.messages.count() == 1
    assert conversation.last_message_at == first_last_message_at


def test_client_message_id_reuse_in_another_conversation_is_conflict(client_for):
    buyer = UserFactory()
    original_conversation = ConversationFactory(buyer=buyer)
    target_conversation = ConversationFactory(
        buyer=buyer,
        last_message_at=timezone.now() - timedelta(days=1),
    )
    client_message_id = uuid.uuid4()
    original = MessageFactory(
        conversation=original_conversation,
        sender=buyer,
        client_message_id=client_message_id,
        text="Секрет первого диалога",
    )
    target_last_message_at = target_conversation.last_message_at

    response = client_for(buyer).post(
        messages_url(target_conversation),
        {"text": "Сообщение второго диалога", "client_message_id": str(client_message_id)},
    )
    target_conversation.refresh_from_db()

    assert response.status_code == 409
    assert str(original.id) not in str(response.data)
    assert Message.objects.count() == 1
    assert not target_conversation.messages.exists()
    assert target_conversation.last_message_at == target_last_message_at


def test_messages_are_chronological_and_after_is_incremental(client_for):
    conversation = ConversationFactory()
    messages = [MessageFactory(conversation=conversation) for _ in range(4)]
    base = timezone.now() - timedelta(hours=1)
    for index, message in enumerate(messages):
        Message.objects.filter(pk=message.pk).update(created_at=base + timedelta(minutes=index))

    client = client_for(conversation.buyer)
    full = client.get(messages_url(conversation))
    incremental = client.get(messages_url(conversation), {"after": str(messages[1].id)})

    assert full.status_code == 200
    assert [item["id"] for item in full.data["results"]] == [
        str(message.id) for message in messages
    ]
    assert incremental.status_code == 200
    assert [item["id"] for item in incremental.data["results"]] == [
        str(messages[2].id),
        str(messages[3].id),
    ]


def test_after_never_omits_a_same_microsecond_sibling(client_for):
    conversation = ConversationFactory()
    reference = MessageFactory(conversation=conversation)
    sibling = MessageFactory(conversation=conversation)
    shared_timestamp = timezone.now()
    Message.objects.filter(pk__in=[reference.pk, sibling.pk]).update(created_at=shared_timestamp)

    response = client_for(conversation.buyer).get(
        messages_url(conversation),
        {"after": str(reference.id)},
    )

    assert response.status_code == 200
    assert str(reference.id) not in [item["id"] for item in response.data["results"]]
    assert str(sibling.id) in [item["id"] for item in response.data["results"]]


def test_after_reference_must_belong_to_the_conversation(client_for):
    conversation = ConversationFactory()
    other_message = MessageFactory()

    response = client_for(conversation.buyer).get(
        messages_url(conversation),
        {"after": str(other_message.id)},
    )

    assert response.status_code == 404


def test_history_pages_are_latest_first_but_each_page_is_chronological(client_for):
    conversation = ConversationFactory()
    messages = [MessageFactory(conversation=conversation) for _ in range(5)]
    base = timezone.now() - timedelta(hours=1)
    for index, message in enumerate(messages):
        Message.objects.filter(pk=message.pk).update(created_at=base + timedelta(minutes=index))

    client = client_for(conversation.buyer)
    url = messages_url(conversation) + "?page_size=2"
    pages = []
    while url:
        response = client.get(url)
        assert response.status_code == 200
        pages.append([item["id"] for item in response.data["results"]])
        url = response.data["next"]

    assert pages == [
        [str(messages[3].id), str(messages[4].id)],
        [str(messages[1].id), str(messages[2].id)],
        [str(messages[0].id)],
    ]


def test_initial_history_selects_the_newest_default_page(client_for):
    conversation = ConversationFactory()
    messages = [MessageFactory(conversation=conversation) for _ in range(25)]
    base = timezone.now() - timedelta(hours=1)
    for index, message in enumerate(messages):
        Message.objects.filter(pk=message.pk).update(created_at=base + timedelta(minutes=index))

    response = client_for(conversation.buyer).get(messages_url(conversation))

    assert response.status_code == 200
    assert response.data["count"] == 25
    assert [item["id"] for item in response.data["results"]] == [
        str(message.id) for message in messages[5:]
    ]
    assert response.data["next"] is not None
    assert response.data["previous"] is None


def test_composite_cursor_is_stable_for_equal_times_and_midstream_insert(client_for):
    conversation = ConversationFactory()
    shared_timestamp = timezone.now() - timedelta(minutes=1)
    messages = [
        MessageFactory(conversation=conversation, id=uuid.UUID(int=value)) for value in range(1, 8)
    ]
    Message.objects.filter(conversation=conversation).update(created_at=shared_timestamp)
    client = client_for(conversation.buyer)

    first = client.get(messages_url(conversation) + "?page_size=3")
    assert [item["id"] for item in first.data["results"]] == [
        str(messages[index].id) for index in [4, 5, 6]
    ]

    inserted = MessageFactory(conversation=conversation, id=uuid.UUID(int=8))
    Message.objects.filter(pk=inserted.pk).update(created_at=shared_timestamp)

    second = client.get(first.data["next"])
    third = client.get(second.data["next"])
    seen = [item["id"] for item in first.data["results"]]
    seen += [item["id"] for item in second.data["results"]]
    seen += [item["id"] for item in third.data["results"]]

    assert seen == [str(messages[index].id) for index in [4, 5, 6, 1, 2, 3, 0]]
    assert str(inserted.id) not in seen
    assert third.data["next"] is None
    back_to_first = client.get(second.data["previous"])
    assert [item["id"] for item in back_to_first.data["results"]] == [
        str(messages[index].id) for index in [4, 5, 6]
    ]


def test_new_message_updates_last_message_at_and_recipient_unread_only(client_for):
    conversation = ConversationFactory(last_message_at=timezone.now() - timedelta(days=1))

    sent = client_for(conversation.seller).post(
        messages_url(conversation),
        {"text": "Можно сегодня", "client_message_id": str(uuid.uuid4())},
    )
    conversation.refresh_from_db()
    buyer_list = client_for(conversation.buyer).get(reverse("messaging:conversation-list"))
    seller_list = client_for(conversation.seller).get(reverse("messaging:conversation-list"))

    assert sent.status_code == 201
    assert conversation.last_message_at == Message.objects.get().created_at
    assert buyer_list.data["results"][0]["unread_count"] == 1
    assert seller_list.data["results"][0]["unread_count"] == 0


def test_read_up_to_is_incremental_and_monotonic(client_for):
    conversation = ConversationFactory(buyer_last_read_at=None)
    old_message = MessageFactory(conversation=conversation, sender=conversation.seller)
    new_message = MessageFactory(conversation=conversation, sender=conversation.seller)
    old_at = timezone.now() - timedelta(minutes=2)
    new_at = timezone.now() - timedelta(minutes=1)
    Message.objects.filter(pk=old_message.pk).update(created_at=old_at)
    Message.objects.filter(pk=new_message.pk).update(created_at=new_at)
    client = client_for(conversation.buyer)

    first = client.post(read_url(conversation), {"last_message_id": str(old_message.id)})
    conversation.refresh_from_db()
    first_read_at = conversation.buyer_last_read_at
    one_unread = client.get(reverse("messaging:conversation-list"))
    repeated = client.post(read_url(conversation), {"last_message_id": str(old_message.id)})
    conversation.refresh_from_db()
    final = client.post(read_url(conversation), {"last_message_id": str(new_message.id)})
    zero_unread = client.get(reverse("messaging:conversation-list"))

    assert first.status_code == 200
    assert first.data == {"updated": 1, "unread_count": 1}
    assert first_read_at == old_at
    assert one_unread.data["results"][0]["unread_count"] == 1
    assert repeated.data == {"updated": 0, "unread_count": 1}
    assert conversation.buyer_last_read_at == first_read_at
    assert final.data == {"updated": 1, "unread_count": 0}
    assert zero_unread.data["results"][0]["unread_count"] == 0


def test_read_response_counts_newer_peer_messages_but_excludes_own(client_for):
    conversation = ConversationFactory(buyer_last_read_at=None)
    old_peer = MessageFactory(conversation=conversation, sender=conversation.seller)
    own = MessageFactory(conversation=conversation, sender=conversation.buyer)
    new_peer = MessageFactory(conversation=conversation, sender=conversation.seller)
    base = timezone.now() - timedelta(minutes=3)
    Message.objects.filter(pk=old_peer.pk).update(created_at=base)
    Message.objects.filter(pk=own.pk).update(created_at=base + timedelta(minutes=1))
    Message.objects.filter(pk=new_peer.pk).update(created_at=base + timedelta(minutes=2))

    response = client_for(conversation.buyer).post(
        read_url(conversation),
        {"last_message_id": str(old_peer.id)},
    )

    assert response.status_code == 200
    assert response.data == {"updated": 1, "unread_count": 1}


def test_seller_read_updates_only_seller_timestamp(client_for):
    conversation = ConversationFactory()
    message = MessageFactory(conversation=conversation, sender=conversation.buyer)

    response = client_for(conversation.seller).post(
        read_url(conversation),
        {"last_message_id": str(message.id)},
    )
    conversation.refresh_from_db()

    assert response.status_code == 200
    assert conversation.seller_last_read_at == message.created_at
    assert conversation.buyer_last_read_at is None


def test_read_message_must_belong_to_the_conversation(client_for):
    conversation = ConversationFactory(buyer_last_read_at=None)
    other_message = MessageFactory()

    response = client_for(conversation.buyer).post(
        read_url(conversation),
        {"last_message_id": str(other_message.id)},
    )
    conversation.refresh_from_db()

    assert response.status_code == 404
    assert conversation.buyer_last_read_at is None


def test_read_up_to_endpoint_rejects_get(client_for):
    conversation = ConversationFactory()

    response = client_for(conversation.buyer).get(read_url(conversation))

    assert response.status_code == 405


def test_message_send_throttle_applies_only_to_post(client_for, throttle_rates):
    conversation = ConversationFactory()
    client = client_for(conversation.buyer)
    throttle_rates(message_send="1/min")

    first = client.post(
        messages_url(conversation),
        {"text": "Первое", "client_message_id": str(uuid.uuid4())},
    )
    blocked = client.post(
        messages_url(conversation),
        {"text": "Второе", "client_message_id": str(uuid.uuid4())},
    )
    polling = client.get(messages_url(conversation))

    assert first.status_code == 201
    assert blocked.status_code == 429
    assert polling.status_code == 200
