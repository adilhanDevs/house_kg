"""Работа с очередью модерации.

Вся логика решений живёт здесь: вьюхи только проверяют права и отдают
сериализованный результат. Уведомления владельцу отправляются через
`apps.notifications.services.notify` — единственную точку их создания.
"""

import logging
from typing import Any

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.catalog.enums import ListingStatus, ModerationStatus
from apps.catalog.models import ListingReport, ModerationTask, RejectReason
from apps.common.audit import audit
from apps.common.exceptions import ApiValidationError, ConflictError
from apps.common.models import AuditLog

logger = logging.getLogger(__name__)

# Пометка в checks, когда задачу завела не подача объявления, а жалобы.
REPORTS_CHECK = "user_reports"
REPORTS_PRIORITY = 10


def open_task(listing: Any) -> ModerationTask | None:
    """Открытая задача объявления, если она есть."""
    return listing.moderation_tasks.filter(status=ModerationStatus.OPEN).first()


def enqueue_moderation(listing: Any, checks: dict[str, Any] | None = None) -> ModerationTask:
    """Ставит объявление в очередь.

    Повторная подача после исправления заводит НОВУЮ задачу: прошлые остаются
    историей, по ней видно, сколько раз автор уже приходил с тем же
    нарушением. Открытая задача при этом всегда одна — на неё есть
    ограничение в БД.
    """
    from apps.catalog.tasks import run_moderation_checks

    existing = open_task(listing)
    if existing is not None:
        return existing

    task = ModerationTask.objects.create(listing=listing, checks=checks or {})

    # Автопроверки ходят в БД и считают хеши — в очередь, а не в запрос.
    transaction.on_commit(lambda: run_moderation_checks.delay(listing.pk))
    logger.info("Объявление %s поставлено в очередь модерации (задача %s)", listing.slug, task.pk)
    return task


def enqueue_review_moderation(review: Any) -> ModerationTask:
    """Ставит отзыв в общую очередь модерации.

    Очередь одна: модератор не должен переключаться между списком объявлений
    и списком отзывов. Автопроверок у отзывов нет, поэтому приоритет нулевой —
    они разбираются после подозрительных объявлений.
    """
    existing = ModerationTask.objects.filter(review=review, status=ModerationStatus.OPEN).first()
    if existing is not None:
        return existing

    task = ModerationTask.objects.create(review=review, checks={})
    logger.info("Отзыв %s поставлен в очередь модерации (задача %s)", review.pk, task.pk)
    return task


@transaction.atomic
def approve_review_task(task: ModerationTask, moderator: Any) -> ModerationTask:
    """Одобряет отзыв: он появляется на странице продавца и входит в рейтинг."""
    from apps.users.sellers import publish_review

    review = task.review
    publish_review(review, moderator)
    audit(
        actor=moderator,
        action=AuditLog.Action.MODERATION_APPROVED,
        target=review,
        changes={"status": {"before": "pending", "after": "published"}},
        target_user=review.seller,
        extra={"task_id": task.pk, "rating": review.rating},
    )
    return _close_task(task, moderator, ModerationStatus.APPROVED)


@transaction.atomic
def reject_review_task(task: ModerationTask, moderator: Any, comment: str = "") -> ModerationTask:
    """Отклоняет отзыв. Автор увидит статус у себя, публика — ничего."""
    from apps.users.sellers import reject_review

    review = task.review
    reject_review(review, moderator, comment)
    audit(
        actor=moderator,
        action=AuditLog.Action.MODERATION_REJECTED,
        target=review,
        changes={"status": {"before": "pending", "after": "rejected"}},
        target_user=review.seller,
        extra={"task_id": task.pk, "comment": comment},
    )
    task.comment = comment
    return _close_task(task, moderator, ModerationStatus.REJECTED)


def _close_task(task: ModerationTask, moderator: Any, status: str) -> ModerationTask:
    task.status = status
    task.resolved_by = moderator
    task.resolved_at = timezone.now()
    task.save(update_fields=["status", "comment", "resolved_by", "resolved_at", "updated_at"])
    return task


def apply_check_results(listing_id: int, results: dict[str, Any]) -> ModerationTask | None:
    """Записывает результаты автопроверок в открытую задачу.

    Приоритет — количество сработавших проверок. Пометки, проставленные до
    прогона (например, жалобами), сохраняются и продолжают влиять на порядок.
    """
    from apps.catalog.moderation.checks import count_triggered

    task = ModerationTask.objects.filter(
        listing_id=listing_id, status=ModerationStatus.OPEN
    ).first()
    if task is None:
        logger.info("Открытой задачи модерации для объявления %s нет", listing_id)
        return None

    checks = {**(task.checks or {}), **results}
    task.checks = checks
    # Жалобы уже подняли приоритет до 10 — автопроверки его не понижают.
    task.priority = max(count_triggered(checks), task.priority)
    task.save(update_fields=["checks", "priority", "updated_at"])
    return task


def assign_task(task: ModerationTask, moderator: Any) -> ModerationTask:
    """Модератор берёт задачу себе."""
    if not task.is_open:
        raise ConflictError("Задача уже закрыта.")

    task.assigned_to = moderator
    task.save(update_fields=["assigned_to", "updated_at"])
    return task


@transaction.atomic
def approve_task(task: ModerationTask, moderator: Any) -> ModerationTask:
    """Одобряет объявление: публикация на LISTING_ACTIVE_DAYS дней."""
    from apps.catalog.services import approve_listing

    if not task.is_open:
        raise ConflictError("Задача уже закрыта.")

    if task.review_id:
        return approve_review_task(task, moderator)

    listing = task.listing
    approve_listing(listing)

    # Жалобы, из-за которых объявление сняли, считаются разобранными.
    ListingReport.objects.filter(listing=listing, is_resolved=False).update(is_resolved=True)

    task.status = ModerationStatus.APPROVED
    task.resolved_by = moderator
    task.resolved_at = timezone.now()
    task.save(update_fields=["status", "resolved_by", "resolved_at", "updated_at"])

    _notify_owner(
        listing,
        title="Объявление опубликовано",
        body=f"«{listing}» прошло проверку и появилось в каталоге.",
        payload={"result": "approved"},
    )
    audit(
        actor=moderator,
        action=AuditLog.Action.MODERATION_APPROVED,
        target=listing,
        changes={"status": {"before": ListingStatus.PENDING, "after": listing.status}},
        target_user=listing.owner,
        extra={"task_id": task.pk, "triggered_checks": task.triggered_checks},
    )
    logger.info("Задача %s одобрена модератором %s", task.pk, moderator.pk)
    return task


@transaction.atomic
def reject_task(
    task: ModerationTask,
    moderator: Any,
    reason_code: str,
    comment: str = "",
) -> ModerationTask:
    """Отклоняет объявление с причиной из справочника."""
    if not task.is_open:
        raise ConflictError("Задача уже закрыта.")

    if task.review_id:
        return reject_review_task(task, moderator, comment)

    reason = RejectReason.objects.filter(code=reason_code, is_active=True).first()
    if reason is None:
        raise ApiValidationError(
            "Неизвестная причина отклонения.",
            {"reason_code": reason_code},
        )

    listing = task.listing
    previous_status = listing.status
    # В объявление кладём готовый текст: владелец видит его без обращения
    # к справочнику, а правка формулировки задним числом не переписывает
    # уже отправленное решение.
    listing.rejection_reason = "\n".join(filter(None, [reason.title, reason.description, comment]))
    listing.status = ListingStatus.REJECTED
    listing.save(update_fields=["status", "rejection_reason", "updated_at"])

    ListingReport.objects.filter(listing=listing, is_resolved=False).update(is_resolved=True)

    task.status = ModerationStatus.REJECTED
    task.reject_reason = reason
    task.comment = comment
    task.resolved_by = moderator
    task.resolved_at = timezone.now()
    task.save(
        update_fields=[
            "status",
            "reject_reason",
            "comment",
            "resolved_by",
            "resolved_at",
            "updated_at",
        ]
    )

    _notify_owner(
        listing,
        title="Объявление отклонено",
        body="\n".join(filter(None, [reason.title, comment])),
        payload={"result": "rejected", "reason_code": reason.code, "comment": comment},
    )
    audit(
        actor=moderator,
        action=AuditLog.Action.MODERATION_REJECTED,
        target=listing,
        changes={"status": {"before": previous_status, "after": ListingStatus.REJECTED}},
        target_user=listing.owner,
        extra={"task_id": task.pk, "reason_code": reason.code, "comment": comment},
    )
    logger.info("Задача %s отклонена (%s) модератором %s", task.pk, reason.code, moderator.pk)
    return task


def _notify_owner(listing: Any, title: str, body: str, payload: dict[str, Any]) -> None:
    from apps.notifications.models import NotificationType
    from apps.notifications.services import notify

    notify(
        user=listing.owner,
        notification_type=NotificationType.LISTING_MODERATED,
        title=title,
        body=body,
        payload={"listing_slug": listing.slug, **payload},
        listing=listing,
    )


# -- жалобы ------------------------------------------------------------------


def rejection_history(user: Any) -> list[dict[str, Any]]:
    """Прошлые отклонения автора — контекст для модератора.

    Третье объявление с контактами в описании от одного человека — уже не
    случайность, и модератору это видно до того, как он откроет карточку.
    """
    tasks = (
        ModerationTask.objects.filter(
            listing__isnull=False,
            listing__owner_id=getattr(user, "pk", user),
            status=ModerationStatus.REJECTED,
        )
        .select_related("reject_reason", "listing")
        .order_by("-resolved_at")[: settings.MODERATION_HISTORY_LIMIT]
    )

    return [
        {
            "listing_slug": task.listing.slug,
            "reason_code": task.reject_reason.code if task.reject_reason else "",
            "reason_title": task.reject_reason.title if task.reject_reason else "",
            "comment": task.comment,
            "resolved_at": task.resolved_at,
        }
        for task in tasks
    ]


@transaction.atomic
def report_listing(listing: Any, reporter: Any, reason: str, comment: str = "") -> ListingReport:
    """Принимает жалобу и, если их накопилось достаточно, снимает объявление.

    Порог сознательно низкий: активное мошенническое объявление не должно
    висеть, пока до него дойдёт очередь модерации. Одобрение вернёт его назад.
    """
    if listing.owner_id == getattr(reporter, "pk", None):
        raise ApiValidationError("Нельзя пожаловаться на собственное объявление.")

    report, created = ListingReport.objects.get_or_create(
        listing=listing,
        reporter=reporter,
        defaults={"reason": reason, "comment": comment},
    )
    if not created:
        raise ConflictError("Вы уже жаловались на это объявление.")

    unresolved = ListingReport.objects.filter(listing=listing, is_resolved=False).count()
    if unresolved >= settings.MODERATION_REPORTS_THRESHOLD and listing.status == (
        ListingStatus.ACTIVE
    ):
        _suspend_reported(listing, unresolved)

    return report


def _suspend_reported(listing: Any, unresolved: int) -> None:
    """Снимает объявление с публикации и заводит задачу с высоким приоритетом."""
    listing.status = ListingStatus.PENDING
    listing.save(update_fields=["status", "updated_at"])

    # order_by() снимает сортировку модели: иначе created_at попадает в SELECT
    # и DISTINCT перестаёт схлопывать одинаковые причины.
    reasons = sorted(
        set(
            ListingReport.objects.filter(listing=listing, is_resolved=False)
            .order_by()
            .values_list("reason", flat=True)
        )
    )
    task = enqueue_moderation(
        listing,
        checks={
            REPORTS_CHECK: {
                "triggered": True,
                "details": {"count": unresolved, "reasons": reasons},
            }
        },
    )
    # Жалобы важнее автопроверок: такая задача идёт в начало очереди.
    ModerationTask.objects.filter(pk=task.pk).update(priority=REPORTS_PRIORITY)

    logger.warning("Объявление %s снято с публикации по %s жалобам", listing.slug, unresolved)
