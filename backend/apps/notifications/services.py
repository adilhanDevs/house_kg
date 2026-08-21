"""Единая точка создания уведомлений.

Никто, кроме этого модуля, не создаёт Notification напрямую: иначе часть
уведомлений уходила бы без push, а часть — мимо пользовательских настроек.
"""

import logging
from typing import Any

from django.db import transaction
from django.utils import timezone

from apps.notifications.models import DeviceToken, Notification, NotificationType

logger = logging.getLogger(__name__)


def _enqueue_push(notification_ids: list[int]) -> None:
    from apps.notifications.tasks import send_push

    for notification_id in notification_ids:
        send_push.delay(notification_id)


def notify(
    user: Any,
    notification_type: str = NotificationType.SYSTEM,
    title: str = "",
    body: str = "",
    payload: dict[str, Any] | None = None,
    listing: Any = None,
) -> Notification:
    """Создаёт уведомление и ставит задачу на push."""
    notification = Notification.objects.create(
        user=user,
        type=notification_type,
        title=title,
        body=body,
        payload=payload or {},
        listing=listing,
    )

    # После коммита: до него задача не увидит запись.
    transaction.on_commit(lambda: _enqueue_push([notification.pk]))
    return notification


def notify_many(notifications: list[Notification]) -> list[Notification]:
    """Пакетное создание — для рассылок вроде сохранённых фильтров.

    Тот же контракт, что у notify(), но одним INSERT: почасовая рассылка не
    должна делать по запросу на пользователя.
    """
    if not notifications:
        return []

    created = Notification.objects.bulk_create(notifications)
    ids = [item.pk for item in created]
    transaction.on_commit(lambda: _enqueue_push(ids))
    return created


def unread_count(user: Any) -> int:
    return Notification.objects.filter(user=user, is_read=False).count()


def mark_read(user: Any, ids: list[int] | None = None, mark_all: bool = False) -> int:
    """Отмечает уведомления прочитанными. Возвращает число изменённых."""
    queryset = Notification.objects.filter(user=user, is_read=False)
    if not mark_all:
        queryset = queryset.filter(pk__in=ids or [])

    return queryset.update(is_read=True)


def register_device(
    user: Any,
    token: str,
    platform: str,
    app_version: str = "",
) -> DeviceToken:
    """Регистрирует или обновляет устройство.

    Токен принадлежит устройству: если на телефоне сменился пользователь,
    токен переезжает к новому, иначе push уходил бы прежнему владельцу.
    """
    device, created = DeviceToken.objects.update_or_create(
        token=token,
        defaults={
            "user": user,
            "platform": platform,
            "app_version": app_version,
            "is_active": True,
            "last_seen_at": timezone.now(),
        },
    )
    logger.info(
        "Устройство %s %s для пользователя %s",
        device.pk,
        "создано" if created else "обновлено",
        user.pk,
    )
    return device


def deactivate_device(user: Any, token: str) -> bool:
    """Гасит устройство при выходе из аккаунта."""
    updated = DeviceToken.objects.filter(user=user, token=token).update(is_active=False)
    return bool(updated)
