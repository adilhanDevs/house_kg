"""Единая точка создания уведомлений.

Никто, кроме этого модуля, не создаёт Notification напрямую: иначе часть
уведомлений уходила бы без push, а часть — мимо пользовательских настроек.
"""

import logging
from datetime import timedelta
from typing import Any

from django.db import transaction
from django.utils import timezone

from apps.notifications.models import DeviceToken, Notification, NotificationType

logger = logging.getLogger(__name__)

#: Насколько назад ищем такой же переход цены, чтобы не продублировать уведомление.
#:
#: Защита нужна от повторного вызова на одном и том же событии. Искать «когда
#: угодно в прошлом» нельзя: цена может подняться и снова упасть до той же
#: отметки — это новое снижение, и подписчик обязан о нём узнать, иначе
#: объявление замолкает для него навсегда.
#:
#: Точно отличить повтор вызова от повторившегося снижения по одной лишь
#: истории уведомлений невозможно — в модели нет журнала изменений цены.
#: Поэтому берём окно: внутри него одинаковый переход считается тем же
#: событием, за его пределами — новым. Заодно это гасит скачки цены туда-сюда.
PRICE_DROP_DUPLICATE_WINDOW = timedelta(hours=1)


def _enqueue_push(notification_ids: list[int]) -> None:
    from apps.notifications.tasks import deliver_notification_push

    for notification_id in notification_ids:
        try:
            deliver_notification_push.delay(notification_id)
        except Exception as exc:  # noqa: BLE001 - ошибка брокера уже после commit
            logger.error(
                "Не удалось поставить push в очередь: notification_id=%s, error=%s",
                notification_id,
                type(exc).__name__,
            )


def notify(
    user: Any,
    notification_type: str = NotificationType.SYSTEM,
    title: str = "",
    body: str = "",
    payload: dict[str, Any] | None = None,
    listing: Any = None,
    event_key: str = "",
) -> Notification:
    """Создаёт уведомление и ставит задачу на push."""
    values = {
        "type": notification_type,
        "title": title,
        "body": body,
        "payload": payload or {},
        "listing": listing,
    }
    if event_key:
        notification, created = Notification.objects.get_or_create(
            user=user,
            event_key=event_key,
            defaults=values,
        )
    else:
        notification = Notification.objects.create(user=user, **values)
        created = True

    # После коммита: до него задача не увидит запись.
    if created:
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
    device_id: str | None = None,
    locale: str = "ru",
    timezone_name: str = "Asia/Bishkek",
) -> DeviceToken:
    """Регистрирует или обновляет устройство.

    Токен принадлежит устройству: если на телефоне сменился пользователь,
    токен переезжает к новому, иначе push уходил бы прежнему владельцу.
    """
    device_id = (device_id or "").strip() or None
    values = {
        "user": user,
        "token": token,
        "platform": platform,
        "device_id": device_id,
        "app_version": app_version,
        "locale": locale,
        "timezone": timezone_name,
        "is_active": True,
        "last_seen_at": timezone.now(),
    }
    with transaction.atomic():
        device = None
        if device_id:
            device = DeviceToken.objects.select_for_update().filter(device_id=device_id).first()
        if device is None:
            device = DeviceToken.objects.select_for_update().filter(token=token).first()

        created = device is None
        if device is None:
            device = DeviceToken.objects.create(**values)
        else:
            conflict = (
                DeviceToken.objects.select_for_update()
                .filter(token=token)
                .exclude(pk=device.pk)
                .first()
            )
            if conflict is not None:
                conflict.delete()
            for field, value in values.items():
                setattr(device, field, value)
            device.save(
                update_fields=[
                    *values.keys(),
                    "updated_at",
                ]
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


def deactivate_current_device(
    user: Any,
    *,
    device_id: str = "",
    token: str = "",
) -> bool:
    """Гасит только установку, принадлежащую текущему пользователю."""
    queryset = DeviceToken.objects.filter(user=user, is_active=True)
    if device_id:
        queryset = queryset.filter(device_id=device_id)
    elif token:
        queryset = queryset.filter(token=token)
    else:
        return False
    return bool(queryset.update(is_active=False, last_seen_at=timezone.now()))


def notify_listing_price_drop(
    listing: Any,
    old_price: Any,
    new_price: Any,
    force_notify: bool = False,
) -> list[Notification]:
    """Отправляет уведомления о снижении цены всем подписчикам (избранное) объявления."""
    from decimal import Decimal

    from apps.catalog.covers import listing_cover_file
    from apps.catalog.enums import ListingStatus
    from apps.engagement.models import Favourite

    if listing.status != ListingStatus.ACTIVE or old_price is None or new_price is None:
        return []
    if Decimal(str(new_price)) >= Decimal(str(old_price)):
        return []

    favourites = (
        Favourite.objects.filter(listing=listing).exclude(user=listing.owner).select_related("user")
    )
    if not favourites.exists():
        return []

    cover = listing_cover_file(listing)
    cover_url = cover.url if cover else ""
    if cover_url and cover_url.startswith("/media/"):
        cover_url = "/api/v1" + cover_url

    district_name = listing.district.name if listing.district else ""
    rooms_text = f"{listing.rooms}-комн." if listing.rooms and not listing.is_plot else ""
    specs = [s for s in [district_name, rooms_text] if s]
    body_text = f"Цена снизилась: {', '.join(specs)} — {listing.price_display}"

    payload = {
        "listing_id": listing.pk,
        "listing_slug": listing.slug,
        "old_price": str(old_price),
        "new_price": str(new_price),
        "currency": listing.currency,
        "district": district_name,
        "address": listing.address,
        "rooms": listing.rooms,
        "area": str(listing.area) if listing.area is not None else "",
        "floor": listing.floor,
        "floors": listing.floors,
        "cover_url": cover_url,
    }

    created_notifications: list[Notification] = []
    for favourite in favourites:
        user = favourite.user
        if not force_notify:
            # Ключ — сам переход «было → стало», а не одна конечная цена:
            # иначе повторное падение до той же отметки замолчало бы навсегда.
            already_notified = Notification.objects.filter(
                user=user,
                type=NotificationType.PRICE_DROP,
                listing=listing,
                payload__old_price=str(old_price),
                payload__new_price=str(new_price),
                created_at__gte=timezone.now() - PRICE_DROP_DUPLICATE_WINDOW,
            ).exists()
            if already_notified:
                continue

        notification = notify(
            user=user,
            notification_type=NotificationType.PRICE_DROP,
            title="Цена снизилась",
            body=body_text,
            payload=payload,
            listing=listing,
        )
        created_notifications.append(notification)
        if favourite.price_at_add != listing.price_usd:
            favourite.price_at_add = listing.price_usd
            favourite.save(update_fields=["price_at_add", "updated_at"])

    return created_notifications
