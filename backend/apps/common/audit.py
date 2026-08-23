"""Журнал аудита.

Запись делается **явным вызовом** `audit(...)`, а не сигналом. Сигнал видит
факт изменения, но не видит, кто его инициировал, из какого запроса и с
какого адреса — а запись аудита без актора и IP не отвечает на вопрос,
ради которого журнал и заводят.

Значения в `changes` и `extra` проходят через то же маскирование ПДн, что
и логи: журнал доступен персоналу, а телефон и ИИН — это ПДн даже там.
"""

from typing import Any

from django.db.models import Model
from rest_framework.request import Request

from apps.common.logging import mask_value, request_id_var
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


def diff(before: dict[str, Any], after: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Изменения в виде {"поле": {"before": ..., "after": ...}}.

    В журнал попадают только реально изменившиеся поля: запись, где «до» и
    «после» совпадают, только мешает читать историю.
    """
    changed: dict[str, dict[str, Any]] = {}
    for field, new_value in after.items():
        old_value = before.get(field)
        if old_value != new_value:
            changed[field] = {"before": old_value, "after": new_value}
    return changed


def audit(
    actor: Any = None,
    action: str = "",
    target: Model | None = None,
    changes: dict[str, Any] | None = None,
    request: Request | None = None,
    *,
    target_user: Any = None,
    extra: dict[str, Any] | None = None,
) -> AuditLog:
    """Записывает действие в журнал.

    Порядок аргументов повторяет сигнатуру из ТЗ:
    `audit(actor, action, target, changes, request)`.
    """
    if actor is None and request is not None and request.user.is_authenticated:
        actor = request.user

    user_agent = ""
    if request is not None:
        user_agent = request.headers.get("User-Agent", "")[:USER_AGENT_MAX_LENGTH]

    return AuditLog.objects.create(
        actor=actor if getattr(actor, "pk", None) else None,
        target_user=target_user,
        action=action,
        target_type=target._meta.label if target is not None else "",
        target_id=str(target.pk) if target is not None else "",
        changes=mask_value("changes", changes or {}),
        ip_address=client_ip(request),
        user_agent=user_agent,
        extra=mask_value("extra", extra or {}),
        request_id=request_id_var.get(),
    )


def record_audit(
    *,
    action: str,
    request: Request | None = None,
    actor: Any = None,
    target_user: Any = None,
    obj: Model | None = None,
    extra: dict[str, Any] | None = None,
) -> AuditLog:
    """Прежняя сигнатура — её использует код верификации личности."""
    return audit(
        actor=actor,
        action=action,
        target=obj,
        request=request,
        target_user=target_user,
        extra=extra,
    )
