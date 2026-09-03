"""Отправка push через Firebase Cloud Messaging.

Креды берутся из окружения: либо путь к service-account JSON, либо его
содержимое в base64 (удобно для CI и секретов Kubernetes). Если ни того, ни
другого нет — push молча выключен, уведомления в базе всё равно создаются.
"""

import base64
import json
import logging
from pathlib import Path
from typing import Any

try:
    from itertools import batched
except ImportError:
    from itertools import islice

    def batched(iterable: Any, n: int) -> Any:
        if n < 1:
            raise ValueError("n must be at least one")
        it = iter(iterable)
        while batch := tuple(islice(it, n)):
            yield batch


from django.conf import settings

logger = logging.getLogger(__name__)

FCM_BATCH_SIZE = 500

# Ошибки, после которых токен больше не оживёт: приложение удалили или токен
# протух. Такие устройства выключаем, чтобы не долбиться в них каждый раз.
DEAD_TOKEN_CODES = frozenset(
    {"UNREGISTERED", "INVALID_ARGUMENT", "REGISTRATION_TOKEN_NOT_REGISTERED"}
)
DEAD_TOKEN_EXCEPTIONS = frozenset(
    {"UnregisteredError", "InvalidArgumentError", "SenderIdMismatchError"}
)

_fcm_app: Any = None
_fcm_checked = False


def _load_credentials() -> dict[str, Any] | None:
    """Service-account из base64 или из файла."""
    encoded = settings.FCM_CREDENTIALS_BASE64
    if encoded:
        try:
            return json.loads(base64.b64decode(encoded))
        except (ValueError, TypeError):
            logger.exception("FCM_CREDENTIALS_BASE64 не разбирается как JSON")
            return None

    path = settings.FCM_CREDENTIALS_FILE
    if path and Path(path).exists():
        return json.loads(Path(path).read_text(encoding="utf-8"))

    return None


def get_fcm_app() -> Any:
    """Инициализирует firebase-admin один раз на процесс.

    Проверка выключателя стоит до чтения кредов: с PUSH_ENABLED=0 файл
    service-account не открывается и firebase_admin не импортируется, поэтому
    прод поднимается без единого секрета на диске.
    """
    global _fcm_app, _fcm_checked

    if not settings.PUSH_ENABLED:
        return None

    if _fcm_checked:
        return _fcm_app

    _fcm_checked = True
    credentials_data = _load_credentials()
    if credentials_data is None:
        logger.warning("FCM не настроен — push-уведомления отключены")
        return None

    import firebase_admin
    from firebase_admin import credentials as fcm_credentials

    _fcm_app = firebase_admin.initialize_app(
        fcm_credentials.Certificate(credentials_data),
        name="house_kgz",
    )
    return _fcm_app


def reset_fcm_app() -> None:
    """Сбрасывает кэш инициализации (нужно тестам и после смены кредов)."""
    global _fcm_app, _fcm_checked
    _fcm_app, _fcm_checked = None, False


def _is_dead_token(exception: Any) -> bool:
    if exception is None:
        return False
    if type(exception).__name__ in DEAD_TOKEN_EXCEPTIONS:
        return True

    code = str(getattr(exception, "code", "") or "").upper().replace("-", "_")
    return code in DEAD_TOKEN_CODES


def _deactivate_tokens(tokens: list[str], response: Any) -> int:
    """Гасит устройства, на которые FCM ответил «токена больше нет»."""
    from apps.notifications.models import DeviceToken

    dead = [
        token
        for token, result in zip(tokens, response.responses, strict=False)
        if not result.success and _is_dead_token(getattr(result, "exception", None))
    ]
    if not dead:
        return 0

    DeviceToken.objects.filter(token__in=dead).update(is_active=False)
    logger.info("Отключено недействительных устройств: %s", len(dead))
    return len(dead)


def _data_payload(notification: Any) -> dict[str, str]:
    """FCM принимает только строковые значения в data."""
    payload = {
        "notification_id": str(notification.pk),
        "type": str(notification.type),
    }
    if notification.listing_id:
        payload["listing_id"] = str(notification.listing_id)

    for key, value in (notification.payload or {}).items():
        payload[str(key)] = (
            value if isinstance(value, str) else json.dumps(value, ensure_ascii=False)
        )

    return payload


def send_to_user(user: Any, notification: Any) -> int:
    """Шлёт уведомление на все активные устройства пользователя.

    Возвращает количество доставленных сообщений.
    """
    from apps.notifications.models import DeviceToken, NotificationSettings, NotificationType

    preferences = getattr(user, "notification_settings", None)
    if preferences is None:
        preferences = NotificationSettings.objects.filter(user=user).first()

    if preferences is not None and not preferences.allows(notification.type):
        logger.info("Push типа %s отключён пользователем %s", notification.type, user.pk)
        return 0

    # Снижение цены приходит по двум разным поводам, и отключают их отдельно:
    # «по избранному» человек обычно оставляет, а «по просмотренному» — нет.
    if (
        preferences is not None
        and notification.type == NotificationType.PRICE_DROP
        and (notification.payload or {}).get("reason") == "viewed"
        and not preferences.price_drop_viewed_enabled
    ):
        logger.info("Push о снижении цены по просмотрам отключён пользователем %s", user.pk)
        return 0

    # Порядок фиксируем: по нему сопоставляются ответы FCM с токенами.
    tokens = list(
        DeviceToken.objects.filter(user=user, is_active=True)
        .order_by("pk")
        .values_list("token", flat=True)
    )
    if not tokens:
        return 0

    app = get_fcm_app()
    if app is None:
        return 0

    from firebase_admin import messaging

    sent = 0
    for chunk in batched(tokens, FCM_BATCH_SIZE):
        batch = list(chunk)
        # tokens=, а не fids=: клиент присылает регистрационные токены FCM.
        message = messaging.MulticastMessage(
            tokens=batch,
            notification=messaging.Notification(title=notification.title, body=notification.body),
            data=_data_payload(notification),
        )
        response = messaging.send_each_for_multicast(message, app=app)
        sent += getattr(response, "success_count", 0)
        _deactivate_tokens(batch, response)

    logger.info("Push %s доставлен на %s устройств", notification.pk, sent)
    return sent
