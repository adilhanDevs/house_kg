"""Запись в журнал аудита."""

from typing import Any

from django.db.models import Model
from rest_framework.request import Request

from apps.common.models import AuditLog

USER_AGENT_MAX_LENGTH = 256


def client_ip(request: Request | None) -> str | None:
    """IP клиента с учётом обратного прокси."""
    if request is None:
        return None
    forwarded = request.headers.get("X-Forwarded-For", "")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.META.get("REMOTE_ADDR")


def record_audit(
    *,
    action: str,
    request: Request | None = None,
    actor: Any = None,
    target_user: Any = None,
    obj: Model | None = None,
    extra: dict[str, Any] | None = None,
) -> AuditLog:
    """Фиксирует обращение к чувствительным данным.

    В `extra` кладём только безопасное: имя поля, действие модератора. Имена
    файлов и подписанные ссылки сюда не попадают.
    """
    if actor is None and request is not None:
        actor = request.user if request.user.is_authenticated else None

    user_agent = ""
    if request is not None:
        user_agent = request.headers.get("User-Agent", "")[:USER_AGENT_MAX_LENGTH]

    return AuditLog.objects.create(
        actor=actor,
        target_user=target_user,
        action=action,
        object_type=obj._meta.label if obj is not None else "",
        object_id=str(obj.pk) if obj is not None else "",
        ip_address=client_ip(request),
        user_agent=user_agent,
        extra=extra or {},
    )
