"""Очередь доставки push в базе.

Транспорт на проде — таблица, а не брокер: проверяем, что строка появляется
вместе с уведомлением, обрабатывается ровно один раз, переживает падение
процесса и не копит отложенный backlog при выключенном push.
"""

from datetime import timedelta
from unittest.mock import patch

import pytest
from django.test import override_settings
from django.utils import timezone

from apps.notifications import push_outbox
from apps.notifications.models import (
    DeviceToken,
    Notification,
    NotificationType,
    PushOutbox,
    PushOutboxStatus,
)
from apps.notifications.services import notify
from tests.factories import UserFactory


@pytest.mark.django_db
def test_notification_creates_one_outbox_row() -> None:
    user = UserFactory()
    notification = notify(user, NotificationType.SYSTEM, title="Тест")

    assert PushOutbox.objects.count() == 1
    assert PushOutbox.objects.get().notification_id == notification.pk
    assert PushOutbox.objects.get().status == PushOutboxStatus.PENDING


@pytest.mark.django_db
def test_same_event_does_not_duplicate_outbox() -> None:
    """Повторное событие с тем же ключом — одно уведомление и одна строка."""
    user = UserFactory()
    notify(user, NotificationType.SYSTEM, title="Тест", event_key="e-1")
    notify(user, NotificationType.SYSTEM, title="Тест", event_key="e-1")

    assert Notification.objects.count() == 1
    assert PushOutbox.objects.count() == 1


@pytest.mark.django_db
@override_settings(PUSH_ENABLED=False)
def test_disabled_push_is_skipped_and_not_retried() -> None:
    """Выключенный транспорт не копит backlog, который однажды разом улетит."""
    user = UserFactory()
    notify(user, NotificationType.SYSTEM, title="Тест")

    with patch("apps.notifications.push._load_credentials") as load:
        assert push_outbox.process_once() == 1

    load.assert_not_called()
    row = PushOutbox.objects.get()
    assert row.status == PushOutboxStatus.SKIPPED_DISABLED
    # Второй проход её уже не подберёт.
    assert push_outbox.process_once() == 0


@pytest.mark.django_db
@override_settings(PUSH_ENABLED=True)
def test_successful_delivery_marks_sent() -> None:
    user = UserFactory()
    DeviceToken.objects.create(user=user, token="token-1", platform="android")
    notify(user, NotificationType.SYSTEM, title="Тест")

    with patch("apps.notifications.push.get_fcm_app", return_value=None):
        assert push_outbox.process_once() == 1

    row = PushOutbox.objects.get()
    assert row.status == PushOutboxStatus.SENT
    assert row.sent_at is not None
    assert push_outbox.process_once() == 0


@pytest.mark.django_db
@override_settings(PUSH_ENABLED=True)
def test_transient_failure_is_retried_with_backoff() -> None:
    user = UserFactory()
    notify(user, NotificationType.SYSTEM, title="Тест")

    with patch(
        "apps.notifications.tasks.deliver_notification_push",
        side_effect=RuntimeError("FCM недоступен"),
    ):
        push_outbox.process_once()

    row = PushOutbox.objects.get()
    assert row.status == PushOutboxStatus.RETRY
    assert row.attempts == 1
    assert row.next_attempt_at > timezone.now()
    assert "RuntimeError" in row.last_error
    # Пока не подошёл срок, строка не берётся заново.
    assert push_outbox.process_once() == 0


@pytest.mark.django_db
@override_settings(PUSH_ENABLED=True)
def test_retries_are_bounded() -> None:
    """После предела попыток строка уходит в failed, а не крутится вечно."""
    user = UserFactory()
    notify(user, NotificationType.SYSTEM, title="Тест")

    with patch(
        "apps.notifications.tasks.deliver_notification_push",
        side_effect=RuntimeError("FCM недоступен"),
    ):
        for _ in range(push_outbox.MAX_ATTEMPTS):
            PushOutbox.objects.update(next_attempt_at=timezone.now() - timedelta(seconds=1))
            push_outbox.process_once()

    row = PushOutbox.objects.get()
    assert row.status == PushOutboxStatus.FAILED
    assert row.attempts == push_outbox.MAX_ATTEMPTS


@pytest.mark.django_db
@override_settings(PUSH_ENABLED=True)
def test_stuck_processing_row_is_reclaimed() -> None:
    """Процесс умер посреди отправки — строка не должна застрять навсегда."""
    user = UserFactory()
    notify(user, NotificationType.SYSTEM, title="Тест")
    PushOutbox.objects.update(
        status=PushOutboxStatus.PROCESSING,
        locked_at=timezone.now() - push_outbox.STUCK_AFTER - timedelta(minutes=1),
    )

    with patch("apps.notifications.push.get_fcm_app", return_value=None):
        assert push_outbox.process_once() == 1

    assert PushOutbox.objects.get().status == PushOutboxStatus.SENT


@pytest.mark.django_db
@override_settings(PUSH_ENABLED=True)
def test_recently_locked_row_is_left_alone() -> None:
    """Свежезахваченную строку второй проход не отбирает."""
    user = UserFactory()
    notify(user, NotificationType.SYSTEM, title="Тест")
    PushOutbox.objects.update(status=PushOutboxStatus.PROCESSING, locked_at=timezone.now())

    assert push_outbox.process_once() == 0


@pytest.mark.django_db
def test_outbox_failure_does_not_break_the_business_event() -> None:
    """Очередь недоступна — уведомление всё равно создаётся."""
    user = UserFactory()

    with patch(
        "apps.notifications.models.PushOutbox.objects.bulk_create",
        side_effect=RuntimeError("база очереди недоступна"),
    ):
        notification = notify(user, NotificationType.SYSTEM, title="Тест")

    assert Notification.objects.filter(pk=notification.pk).exists()
