"""Инициализация Sentry.

`send_default_pii=False` — принципиально: с ним Sentry сам приложит к событию
тело запроса, заголовки и учётные данные пользователя, то есть телефоны и
ИИН окажутся у стороннего сервиса. Всё, что нужно для разбора (request_id,
user_id), добавляется явно.

Вдобавок события проходят через тот же фильтр маскирования, что и логи:
телефон может оказаться в тексте исключения, а не только в теле запроса.
"""

import logging
from typing import Any

logger = logging.getLogger(__name__)


def scrub_event(event: dict[str, Any], hint: dict[str, Any]) -> dict[str, Any] | None:
    """before_send: маскирует ПДн в тексте события.

    Возвращает None, чтобы событие не отправлять; здесь такого случая нет,
    но точка расширения оставлена намеренно.
    """
    from apps.common.logging import mask_value

    for key in ("message", "logentry", "extra", "tags", "request", "breadcrumbs"):
        if key in event:
            event[key] = mask_value(key, event[key])

    for entry in event.get("exception", {}).get("values", []):
        if isinstance(entry.get("value"), str):
            from apps.common.logging import mask_text

            entry["value"] = mask_text(entry["value"])

    return event


def init_sentry() -> bool:
    """Поднимает Sentry, если задан DSN. Возвращает, включился ли он."""
    from django.conf import settings

    dsn = getattr(settings, "SENTRY_DSN", "")
    if not dsn:
        logger.info("SENTRY_DSN не задан — Sentry выключен")
        return False

    import sentry_sdk
    from sentry_sdk.integrations.celery import CeleryIntegration
    from sentry_sdk.integrations.django import DjangoIntegration
    from sentry_sdk.integrations.logging import LoggingIntegration
    from sentry_sdk.integrations.redis import RedisIntegration

    sentry_sdk.init(
        dsn=dsn,
        environment=settings.SENTRY_ENVIRONMENT,
        integrations=[
            DjangoIntegration(),
            CeleryIntegration(),
            RedisIntegration(),
            # Логи уровня ERROR становятся событиями; INFO — хлебными крошками.
            LoggingIntegration(level=logging.INFO, event_level=logging.ERROR),
        ],
        traces_sample_rate=settings.SENTRY_TRACES_SAMPLE_RATE,
        profiles_sample_rate=settings.SENTRY_PROFILES_SAMPLE_RATE,
        # Никаких ПДн: ни тела запроса, ни заголовков, ни учётной записи.
        send_default_pii=False,
        before_send=scrub_event,
        # Второй рубеж: даже если PII где-то просочится, эти ключи не уедут.
        max_request_body_size="never",
    )
    logger.info("Sentry включён (окружение %s)", settings.SENTRY_ENVIRONMENT)
    return True
