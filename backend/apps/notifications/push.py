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


#: Что из payload уезжает в push, по типу события.
#:
#: Раньше payload переносился целиком, а он растёт: у снижения цены там уже
#: адрес, район, площадь, этажи и обложка. FCM отбрасывает data больше 4 КБ
#: целиком, поэтому список полей задан явно — новое поле карточки не утечёт
#: в push само собой и не утащит с собой всю доставку.
PUSH_DATA_FIELDS: dict[str, tuple[str, ...]] = {
    "new_message": ("conversation_id", "listing_slug", "sender_id", "sender_name", "preview"),
    "price_drop": (
        "listing_slug",
        "old_price",
        "new_price",
        "currency",
        "drop_amount",
        "drop_percent",
        "reason",
        "cover_url",
    ),
    "saved_filter_match": ("listing_slug", "filter_id"),
    "listing_moderated": ("listing_slug", "status"),
    "promotion_expiring": ("listing_slug", "ends_at"),
    "wallet_topup": ("amount", "bricks"),
    "system": ("kind",),
}


def _localized_payload_text(notification: Any, field: str, locale: str) -> str:
    source = notification.payload or {}
    i18n = source.get(f"{field}_i18n")
    if isinstance(i18n, dict):
        text = str(i18n.get(locale) or i18n.get("ru") or "").strip()
        if text:
            return text
    if source.get("kind") == "test_push":
        defaults = {
            "title": {
                "ru": "House KG — проверка прочтения",
                "ky": "House KG — окулганын текшерүү",
            },
            "body": {
                "ru": (
                    "Контрольное уведомление. Нажмите, чтобы открыть чат "
                    "и обновить счётчик."
                ),
                "ky": (
                    "Көзөмөл билдирмеси. Чатты ачып, эсептегичти "
                    "жаңыртуу үчүн басыңыз."
                ),
            },
        }
        text = defaults.get(field, {}).get(locale) or defaults.get(field, {}).get("ru")
        if text:
            return text
    return str(getattr(notification, field, "") or "")


def _data_payload(notification: Any) -> dict[str, str]:
    """Данные для перехода по нажатию. Только строки: FCM других не принимает."""
    payload: dict[str, str] = {
        "notification_id": str(notification.pk),
        "recipient_id": str(notification.user_id),
        "type": str(notification.type),
    }
    if notification.listing_id:
        payload["listing_id"] = str(notification.listing_id)

    allowed = PUSH_DATA_FIELDS.get(str(notification.type), ())
    source = notification.payload or {}
    for key in allowed:
        if key not in source:
            continue
        value = source[key]
        payload[key] = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False)

    return payload


def send_to_user(user: Any, notification: Any) -> int:
    """Шлёт уведомление на все активные устройства пользователя.

    Возвращает количество доставленных сообщений.
    """
    from apps.notifications.models import DeviceToken, NotificationSettings

    preferences = getattr(user, "notification_settings", None)
    if preferences is None:
        preferences = NotificationSettings.objects.filter(user=user).first()

    reason = (notification.payload or {}).get("reason")
    if preferences is not None and not preferences.allows_reason(notification.type, reason):
        logger.info(
            "Push типа %s (повод %s) отключён пользователем %s",
            notification.type,
            reason or "-",
            user.pk,
        )
        return 0

    # Порядок фиксируем внутри каждой языковой группы: по нему сопоставляются
    # ответы FCM с токенами.
    devices = list(
        DeviceToken.objects.filter(user=user, is_active=True)
        .order_by("pk")
        .values_list("token", "locale")
    )
    if not devices:
        return 0

    app = get_fcm_app()
    if app is None:
        return 0

    from firebase_admin import messaging

    sent = 0
    by_locale: dict[str, list[str]] = {}
    for token, locale in devices:
        by_locale.setdefault(locale or "ru", []).append(token)

    for locale, tokens in by_locale.items():
        title = _localized_payload_text(notification, "title", locale)
        body = _localized_payload_text(notification, "body", locale)
        for chunk in batched(tokens, FCM_BATCH_SIZE):
            batch = list(chunk)
            # tokens=, а не fids=: клиент присылает регистрационные токены FCM.
            message = messaging.MulticastMessage(
                tokens=batch,
                notification=messaging.Notification(title=title, body=body),
                data=_data_payload(notification),
            )
            response = messaging.send_each_for_multicast(message, app=app)
            sent += getattr(response, "success_count", 0)
            _deactivate_tokens(batch, response)

    logger.info("Push %s доставлен на %s устройств", notification.pk, sent)
    return sent
