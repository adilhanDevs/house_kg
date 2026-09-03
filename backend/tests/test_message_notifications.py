"""Уведомления о новых сообщениях."""

import logging
import uuid
from unittest.mock import patch

import pytest
from django.db import DatabaseError
from django.urls import reverse

from apps.messaging.models import Message
from apps.notifications.models import DeviceToken, Notification, NotificationType
from apps.notifications.tasks import send_push
from tests.factories import ConversationFactory

pytestmark = pytest.mark.django_db


def messages_url(conversation):  # noqa: ANN001, ANN201
    return reverse("messaging:message-list", args=[conversation.id])


def test_new_message_notifies_peer_once(client_for, django_capture_on_commit_callbacks):
    conversation = ConversationFactory()
    conversation.buyer.name = "  Айдар  "
    conversation.buyer.save(update_fields=["name"])
    text = "З" * 141
    payload = {"text": text, "client_message_id": str(uuid.uuid4())}

    with django_capture_on_commit_callbacks(execute=False):
        first = client_for(conversation.buyer).post(messages_url(conversation), payload)
        second = client_for(conversation.buyer).post(messages_url(conversation), payload)

    assert first.status_code == 201
    assert second.status_code == 200
    notification = Notification.objects.get(user=conversation.seller)
    assert notification.type == NotificationType.NEW_MESSAGE
    assert notification.title == "Айдар"
    assert notification.body == "З" * 140
    assert notification.payload == {
        "conversation_id": str(conversation.id),
        "listing_slug": conversation.listing_slug,
        "sender_id": conversation.buyer_id,
        "sender_name": "Айдар",
        "preview": "З" * 140,
    }
    assert Notification.objects.count() == 1


def test_new_message_uses_fallback_title_for_unnamed_sender(
    client_for, django_capture_on_commit_callbacks
):
    conversation = ConversationFactory()
    conversation.seller.name = "   "
    conversation.seller.save(update_fields=["name"])

    with django_capture_on_commit_callbacks(execute=False):
        response = client_for(conversation.seller).post(
            messages_url(conversation),
            {"text": "Добрый день", "client_message_id": str(uuid.uuid4())},
        )

    assert response.status_code == 201
    notification = Notification.objects.get(user=conversation.buyer)
    assert notification.title == "Новое сообщение"


def test_push_enqueue_failure_after_commit_keeps_message_and_notification(
    client_for,
    django_capture_on_commit_callbacks,
    caplog,
):
    conversation = ConversationFactory()
    secret_body = "Секретный текст сообщения"
    payload = {"text": secret_body, "client_message_id": str(uuid.uuid4())}

    with (
        patch("apps.notifications.tasks.send_push.delay", side_effect=RuntimeError("broker down")),
        caplog.at_level(logging.ERROR, logger="apps.notifications.services"),
        django_capture_on_commit_callbacks(execute=True),
    ):
        response = client_for(conversation.buyer).post(messages_url(conversation), payload)

    assert response.status_code == 201
    assert Message.objects.filter(conversation=conversation, text=secret_body).count() == 1
    assert Notification.objects.filter(user=conversation.seller).count() == 1
    assert "push" in caplog.text.lower()
    assert secret_body not in caplog.text
    assert conversation.buyer.phone not in caplog.text


def test_new_message_setting_prevents_push(client_for, django_capture_on_commit_callbacks):
    conversation = ConversationFactory()
    conversation.seller.notification_settings.new_message_enabled = False
    conversation.seller.notification_settings.save(update_fields=["new_message_enabled"])
    DeviceToken.objects.create(user=conversation.seller, token="seller-device", platform="android")

    with django_capture_on_commit_callbacks(execute=False):
        response = client_for(conversation.buyer).post(
            messages_url(conversation),
            {"text": "Есть вопрос", "client_message_id": str(uuid.uuid4())},
        )

    notification = Notification.objects.get(user=conversation.seller)
    with patch(
        "apps.notifications.push.get_fcm_app",
        side_effect=AssertionError("FCM не должен вызываться при отключённых уведомлениях"),
    ):
        assert send_push(notification.pk) == 0

    assert response.status_code == 201


def test_notification_database_error_rolls_back_message(
    client_for, django_capture_on_commit_callbacks
):
    conversation = ConversationFactory()
    payload = {"text": "Есть вопрос", "client_message_id": str(uuid.uuid4())}

    with (
        patch(
            "apps.notifications.services.Notification.objects.create",
            side_effect=DatabaseError("notification insert failed"),
        ),
        django_capture_on_commit_callbacks(execute=False),
    ):
        response = client_for(conversation.buyer).post(messages_url(conversation), payload)

    assert response.status_code == 500
    assert not Message.objects.filter(conversation=conversation).exists()
    assert not Notification.objects.exists()
