"""Тесты моделей диалогов и сообщений."""

import pytest
from django.contrib import admin
from django.db import IntegrityError
from django.test import RequestFactory
from django.utils import timezone

from apps.messaging.models import Conversation, Message
from tests.factories import ConversationFactory, MessageFactory, UserFactory


def test_one_conversation_per_buyer_and_listing(db):
    conversation = ConversationFactory()
    assert isinstance(conversation, Conversation)

    with pytest.raises(IntegrityError):
        ConversationFactory(
            listing=conversation.listing,
            buyer=conversation.buyer,
            seller=conversation.seller,
        )


def test_buyer_and_seller_must_differ(db):
    participant = UserFactory()

    with pytest.raises(IntegrityError):
        ConversationFactory(buyer=participant, seller=participant)


def test_client_message_id_is_unique_per_sender(db):
    message = MessageFactory()
    assert isinstance(message, Message)

    with pytest.raises(IntegrityError):
        MessageFactory(
            conversation=message.conversation,
            sender=message.sender,
            client_message_id=message.client_message_id,
        )


def test_same_client_message_id_is_allowed_for_different_senders(db):
    message = MessageFactory()

    second = MessageFactory(
        conversation=message.conversation,
        sender=message.conversation.seller,
        client_message_id=message.client_message_id,
    )

    assert second.pk


def test_participant_helpers_return_peer_and_own_read_timestamp(db):
    buyer_read_at = timezone.now()
    seller_read_at = timezone.now()
    conversation = ConversationFactory(
        buyer_last_read_at=buyer_read_at,
        seller_last_read_at=seller_read_at,
    )

    assert conversation.peer_for(conversation.buyer) == conversation.seller
    assert conversation.peer_for(conversation.seller) == conversation.buyer
    assert conversation.read_at_for(conversation.buyer) == buyer_read_at
    assert conversation.read_at_for(conversation.seller) == seller_read_at


def test_participant_helpers_reject_non_participant(db):
    conversation = ConversationFactory()
    stranger = UserFactory()

    with pytest.raises(ValueError):
        conversation.peer_for(stranger)
    with pytest.raises(ValueError):
        conversation.read_at_for(stranger)


@pytest.mark.parametrize("model", [Conversation, Message])
def test_messaging_admin_pages_are_read_only(model):
    model_admin = admin.site._registry[model]
    request = RequestFactory().get("/admin/")

    assert model_admin.has_add_permission(request) is False
    assert model_admin.has_change_permission(request) is False
    assert model_admin.has_delete_permission(request) is False


def test_message_admin_does_not_list_or_search_message_text():
    message_admin = admin.site._registry[Message]

    assert "text" not in message_admin.list_display
    assert "text" not in message_admin.search_fields
