"""Фоновые задачи общего приложения."""

import logging

from celery import shared_task

logger = logging.getLogger(__name__)


@shared_task(name="common.notify_support_ticket", ignore_result=True)
def notify_support_ticket(ticket_id: int) -> None:
    """Уведомляет staff о новом обращении в поддержку."""
    from apps.common.models import SupportTicket
    from apps.common.services import notify_staff_about_ticket

    ticket = SupportTicket.objects.filter(pk=ticket_id).select_related("user").first()
    if ticket is None:
        logger.warning("Обращение %s не найдено — письмо не отправлено", ticket_id)
        return
    notify_staff_about_ticket(ticket)
