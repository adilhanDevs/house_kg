"""Маршрутизация и выключенный режим push-доставки.

Проверяем контракт транспорта, а не сам Firebase: очередь, отсутствие чтения
кредов при PUSH_ENABLED=0 и учёт пользовательских настроек по причине события.
"""

from unittest.mock import patch

import pytest
from django.test import override_settings

from apps.notifications.models import (
    DeviceToken,
    Notification,
    NotificationSettings,
    NotificationType,
)
from apps.notifications.tasks import deliver_notification_push
from tests.factories import UserFactory


def test_delivery_task_is_routed_to_push_queue() -> None:
    """`.delay()` из любого места обязан попасть в очередь push, а не в default."""
    from config.celery import app

    route = app.conf.task_routes["notifications.deliver_notification_push"]
    assert route["queue"] == "push"
    assert "push" in {queue.name for queue in app.conf.task_queues}
    assert app.conf.worker_prefetch_multiplier == 1


def test_delivery_task_ignores_result() -> None:
    """Результат не хранится: бэкенда результатов у push-очереди нет."""
    assert deliver_notification_push.ignore_result is True


@pytest.mark.django_db
@override_settings(PUSH_ENABLED=False)
def test_disabled_mode_never_loads_credentials() -> None:
    """С выключенным push задача отрабатывает и не трогает креды Firebase."""
    user = UserFactory()
    DeviceToken.objects.create(user=user, token="token-1", platform="android")
    notification = Notification.objects.create(
        user=user, type=NotificationType.SYSTEM, title="Тест"
    )

    with patch("apps.notifications.push._load_credentials") as load:
        assert deliver_notification_push(notification.pk) == 0

    load.assert_not_called()


@pytest.mark.django_db
@override_settings(PUSH_ENABLED=False)
def test_disabled_mode_keeps_notification_row() -> None:
    """Выключенный транспорт не отменяет само уведомление в базе."""
    user = UserFactory()
    notification = Notification.objects.create(
        user=user, type=NotificationType.SYSTEM, title="Тест"
    )

    assert deliver_notification_push(notification.pk) == 0
    assert Notification.objects.filter(pk=notification.pk).exists()


@pytest.mark.django_db
def test_missing_notification_is_not_an_error() -> None:
    """Уведомление удалили, пока задача ждала очереди — это не падение."""
    assert deliver_notification_push(10**9) == 0


@pytest.mark.django_db
@override_settings(PUSH_ENABLED=True)
def test_viewed_price_drop_respects_its_own_preference() -> None:
    """Отключённое «по просмотрам» гасит только push с reason=viewed."""
    user = UserFactory()
    DeviceToken.objects.create(user=user, token="token-1", platform="android")
    NotificationSettings.objects.update_or_create(
        user=user,
        defaults={"price_drop_enabled": True, "price_drop_viewed_enabled": False},
    )
    notification = Notification.objects.create(
        user=user,
        type=NotificationType.PRICE_DROP,
        title="Цена снизилась",
        payload={"reason": "viewed"},
    )

    with patch("apps.notifications.push.get_fcm_app") as fcm_app:
        assert deliver_notification_push(notification.pk) == 0

    fcm_app.assert_not_called()


@pytest.mark.django_db
@override_settings(PUSH_ENABLED=True)
def test_favourite_price_drop_ignores_viewed_preference() -> None:
    """Избранное продолжает приходить, даже если «по просмотрам» выключено."""
    user = UserFactory()
    DeviceToken.objects.create(user=user, token="token-1", platform="android")
    NotificationSettings.objects.update_or_create(
        user=user,
        defaults={"price_drop_enabled": True, "price_drop_viewed_enabled": False},
    )
    notification = Notification.objects.create(
        user=user,
        type=NotificationType.PRICE_DROP,
        title="Цена снизилась",
        payload={"reason": "favorite"},
    )

    with patch("apps.notifications.push.get_fcm_app", return_value=None) as fcm_app:
        deliver_notification_push(notification.pk)

    fcm_app.assert_called_once()
