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


@shared_task(name="common.refresh_metrics", ignore_result=True)
def refresh_metrics() -> dict[str, int]:
    """Обновляет метрики-состояния (длину очереди модерации).

    Gauge нельзя посчитать в момент скрейпа: /metrics/ обслуживает любой
    воркер, и запрос к БД оттуда сделал бы скрейп источником нагрузки.
    """
    from apps.common.metrics import refresh_moderation_queue_size

    sizes = refresh_moderation_queue_size()
    logger.info("Очередь модерации: %s", sizes)
    return sizes
