"""Бизнес-логика конфигурации приложения и статического контента.

Вьюхи только собирают ответ, вся работа с данными и кэшом — здесь.
Всё, что читает мобильный клиент, кэшируется в Redis на 15 минут и
инвалидируется сигналами post_save/post_delete (apps/common/signals.py).
"""

import logging
from typing import Any

from django.conf import settings
from django.core.cache import cache
from django.core.mail import send_mail
from django.urls import reverse

from apps.common.cache import safe_cache_call
from apps.common.models import AppConfig, OnboardingSlide, StaticPage, SupportTicket

logger = logging.getLogger(__name__)

CACHE_TTL = 15 * 60  # 15 минут

CONFIG_CACHE_KEY = "app:config:{platform}"
ONBOARDING_CACHE_KEY = "app:onboarding"
PAGE_CACHE_KEY = "app:page:{slug}"

KNOWN_PLATFORMS = ("android", "ios")

# Документы, ссылки на которые отдаются в конфиге.
CONFIG_DOCUMENTS = (StaticPage.Slug.TERMS, StaticPage.Slug.PRIVACY)


def normalize_platform(platform: str | None) -> str:
    """android / ios, всё остальное — пустая строка (ссылка на стор не нужна)."""
    value = (platform or "").strip().lower()
    return value if value in KNOWN_PLATFORMS else ""


# -- конфигурация ------------------------------------------------------------


def build_config_payload(platform: str) -> dict[str, Any]:
    """Тело /app/config/ без зависящих от запроса полей (force_update, хост).

    Ссылки на документы кладём относительными: абсолютными их делает вьюха,
    иначе в кэш попал бы конкретный хост.
    """
    config = AppConfig.get_solo()
    pages = {
        page.slug: page
        for page in StaticPage.objects.filter(slug__in=CONFIG_DOCUMENTS, is_active=True)
    }

    documents: dict[str, dict[str, str]] = {}
    for slug in CONFIG_DOCUMENTS:
        page = pages.get(slug)
        if page is None:
            continue
        documents[str(slug)] = {
            "url": reverse("common:static-page", kwargs={"slug": page.slug}),
            "version": page.version,
        }

    return {
        "min_supported_version": config.min_supported_version,
        "recommended_version": config.recommended_version,
        "store_url": config.store_url(platform),
        "maintenance": {
            "enabled": config.maintenance_mode,
            "message": config.maintenance_message,
        },
        "feature_flags": config.feature_flags or {},
        "constants": config.constants or {},
        "documents": documents,
    }


def get_config_payload(platform: str) -> dict[str, Any]:
    """Кэшированное тело конфига для платформы."""
    key = CONFIG_CACHE_KEY.format(platform=platform or "any")
    payload = cache.get(key)
    if payload is None:
        payload = build_config_payload(platform)
        cache.set(key, payload, CACHE_TTL)
    return payload


# -- онбординг ---------------------------------------------------------------


def build_onboarding_payload() -> list[dict[str, Any]]:
    slides = OnboardingSlide.objects.filter(is_active=True).order_by("order", "id")
    return [
        {
            "id": slide.id,
            "title": slide.title,
            "text": slide.text,
            "image": slide.image.url if slide.image else None,
            "order": slide.order,
        }
        for slide in slides
    ]


def get_onboarding_payload() -> list[dict[str, Any]]:
    payload = cache.get(ONBOARDING_CACHE_KEY)
    if payload is None:
        payload = build_onboarding_payload()
        cache.set(ONBOARDING_CACHE_KEY, payload, CACHE_TTL)
    return payload


# -- статические страницы ----------------------------------------------------


def build_page_payload(slug: str) -> dict[str, Any] | None:
    page = StaticPage.objects.filter(slug=slug, is_active=True).first()
    if page is None:
        return None
    return {
        "slug": page.slug,
        "title": page.title,
        "content": page.content,
        "version": page.version,
        "updated_at": page.updated_at.isoformat(),
    }


def get_page_payload(slug: str) -> dict[str, Any] | None:
    key = PAGE_CACHE_KEY.format(slug=slug)
    payload = cache.get(key)
    if payload is None:
        payload = build_page_payload(slug)
        if payload is None:
            return None
        cache.set(key, payload, CACHE_TTL)
    return payload


# -- инвалидация кэша --------------------------------------------------------


def invalidate_config_cache() -> None:
    keys = [CONFIG_CACHE_KEY.format(platform=platform) for platform in (*KNOWN_PLATFORMS, "any")]
    safe_cache_call(cache.delete_many, keys, warning="Не удалось сбросить кэш конфига")


def invalidate_onboarding_cache() -> None:
    safe_cache_call(
        cache.delete, ONBOARDING_CACHE_KEY, warning="Не удалось сбросить кэш онбординга"
    )


def invalidate_page_cache(slug: str | None = None) -> None:
    slugs = [slug] if slug else [str(value) for value in StaticPage.Slug.values]
    keys = [PAGE_CACHE_KEY.format(slug=item) for item in slugs]
    safe_cache_call(cache.delete_many, keys, warning="Не удалось сбросить кэш страниц")
    # Ссылки и версии документов входят в конфиг — его тоже пересобираем.
    invalidate_config_cache()


# -- поддержка ---------------------------------------------------------------


def notify_staff_about_ticket(ticket: SupportTicket) -> None:
    """Письмо в поддержку. Адреса — из SUPPORT_NOTIFY_EMAILS или ADMINS."""
    recipients = list(settings.SUPPORT_NOTIFY_EMAILS) or [
        email for _, email in getattr(settings, "ADMINS", [])
    ]
    if not recipients:
        logger.warning("Обращение #%s создано, но некому отправить письмо", ticket.pk)
        return

    body = "\n".join(
        [
            f"Обращение #{ticket.pk}",
            f"Тема: {ticket.subject}",
            f"Пользователь: {ticket.user or 'аноним'}",
            f"Телефон: {ticket.contact_phone or '—'}",
            f"Платформа: {ticket.platform or '—'}, версия: {ticket.app_version or '—'}",
            "",
            ticket.message,
        ]
    )
    send_mail(
        subject=f"[house_kgz] Обращение #{ticket.pk}: {ticket.subject}",
        message=body,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=recipients,
    )


def enqueue_ticket_notification(ticket_id: int) -> None:
    """Ставит задачу на отправку письма; если брокер недоступен — шлём сразу."""
    from apps.common.tasks import notify_support_ticket

    try:
        notify_support_ticket.delay(ticket_id)
    except Exception:
        logger.warning("Celery недоступен, отправляю письмо синхронно", exc_info=True)
        notify_support_ticket(ticket_id)
