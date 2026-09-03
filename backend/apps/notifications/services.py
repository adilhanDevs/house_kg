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
    *,
    event_key: str = "",
    old_currency: Any = None,
    event_at: Any = None,
) -> list[Notification]:
    """Уведомляет о снижении цены избранное и тех, кто недавно смотрел объект.

    Адресаты — объединение двух множеств минус владелец: он и так знает, что
    сам поменял цену. Пересечение схлопывается в одно уведомление, поэтому
    добавивший в избранное и заодно смотревший получит его один раз, а не два.

    `event_key` — идентификатор самого события снижения, его передаёт
    `update_listing`, выводя из записи журнала. Без него ключ пришлось бы
    собирать из пары цен, и тогда «упало → выросло → упало до той же отметки»
    выглядело бы повтором первого события и до подписчика уже не дошло бы.
    Для прямых вызовов без ключа остаётся вывод из перехода: он стабилен и
    гасит буквальный повтор одного и того же вызова.
    """
    from decimal import Decimal

    from django.conf import settings
    from django.contrib.auth import get_user_model

    from apps.catalog.covers import listing_cover_file
    from apps.catalog.enums import ListingStatus
    from apps.engagement.models import Favourite, ViewHistory

    if listing.status != ListingStatus.ACTIVE or old_price is None or new_price is None:
        return []

    old_amount = Decimal(str(old_price))
    new_amount = Decimal(str(new_price))
    if new_amount >= old_amount or old_amount <= 0:
        return []

    # Смена валюты — не снижение цены: 100 000 USD и 95 000 KGS несравнимы, и
    # «подешевело на 5 %» здесь было бы прямым обманом.
    if old_currency is not None and old_currency != listing.currency:
        return []

    owner_id = listing.owner_id
    favourite_ids = set(
        Favourite.objects.filter(listing=listing)
        .exclude(user_id=owner_id)
        .values_list("user_id", flat=True)
    )

    window_start = timezone.now() - timedelta(days=settings.PRICE_DROP_VIEW_WINDOW_DAYS)
    viewer_ids = set(
        ViewHistory.objects.filter(listing=listing, viewed_at__gte=window_start)
        .exclude(user_id=owner_id)
        .values_list("user_id", flat=True)
    )

    recipient_ids = favourite_ids | viewer_ids
    if not recipient_ids:
        return []

    cover = listing_cover_file(listing)
    cover_url = cover.url if cover else ""
    if cover_url and cover_url.startswith("/media/"):
        cover_url = "/api/v1" + cover_url

    district_name = listing.district.name if listing.district else ""
    rooms_text = f"{listing.rooms}-комн." if listing.rooms and not listing.is_plot else ""
    specs = [s for s in [district_name, rooms_text] if s]
    body_text = f"Цена снизилась: {', '.join(specs)} — {listing.price_display}"

    drop_amount = old_amount - new_amount
    drop_percent = (drop_amount / old_amount * 100).quantize(Decimal("0.01"))
    moment = event_at or timezone.now()
    key = event_key or f"price-drop:{listing.pk}:{old_amount}:{new_amount}"

    base_payload = {
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
        "drop_amount": f"{drop_amount:.2f}",
        "drop_percent": f"{drop_percent:.2f}",
        "event_at": moment.isoformat(),
    }

    favourites_by_user = {
        favourite.user_id: favourite
        for favourite in Favourite.objects.filter(listing=listing, user_id__in=recipient_ids)
    }
    users_by_id = {user.pk: user for user in get_user_model().objects.filter(pk__in=recipient_ids)}

    created_notifications: list[Notification] = []
    for user_id in sorted(recipient_ids):
        user = users_by_id.get(user_id)
        if user is None:
            continue

        in_favourites = user_id in favourite_ids
        viewed_recently = user_id in viewer_ids
        if in_favourites and viewed_recently:
            reason = "favorite_and_viewed"
        elif in_favourites:
            reason = "favorite"
        else:
            reason = "viewed"

        existed = Notification.objects.filter(user=user, event_key=key).exists()
        notification = notify(
            user=user,
            notification_type=NotificationType.PRICE_DROP,
            title="Цена снизилась",
            body=body_text,
            payload={**base_payload, "reason": reason},
            listing=listing,
            event_key=key,
        )
        # Ключ события уникален на пользователя: повторный прогон того же
        # снижения вернёт существующую строку, а не создаст вторую.
        if not existed:
            created_notifications.append(notification)

        favourite = favourites_by_user.get(user_id)
        if favourite is not None and favourite.price_at_add != listing.price_usd:
            favourite.price_at_add = listing.price_usd
            favourite.save(update_fields=["price_at_add", "updated_at"])

    return created_notifications
