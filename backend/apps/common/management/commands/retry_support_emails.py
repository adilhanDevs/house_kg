import logging
from django.core.management.base import BaseCommand
from apps.common.models import SupportTicket
from apps.common.services import notify_staff_about_ticket

logger = logging.getLogger(__name__)

class Command(BaseCommand):
    help = "Повторно отправляет email-уведомления для обращений в поддержку (pending/failed)"

    def handle(self, *args, **options):
        # Берем только pending / failed
        tickets = SupportTicket.objects.filter(
            email_delivery_status__in=[SupportTicket.EmailStatus.PENDING, SupportTicket.EmailStatus.FAILED]
        ).order_by("created_at")[:50]  # разумный batch limit

        if not tickets.exists():
            self.stdout.write(self.style.SUCCESS("Нет обращений для повторной отправки."))
            return

        success_count = 0
        failed_count = 0

        for ticket in tickets:
            self.stdout.write(f"Отправка письма для обращения #{ticket.pk}...")
            notify_staff_about_ticket(ticket)
            
            # Проверяем, обновился ли статус (обновляется внутри notify_staff_about_ticket)
            if ticket.email_delivery_status == SupportTicket.EmailStatus.SENT:
                success_count += 1
                self.stdout.write(self.style.SUCCESS(f"Успешно: #{ticket.pk}"))
            else:
                failed_count += 1
                self.stdout.write(self.style.ERROR(f"Ошибка: #{ticket.pk}"))

        self.stdout.write(
            self.style.SUCCESS(
                f"\nГотово. Успешно отправлено: {success_count}, ошибок: {failed_count}."
            )
        )
