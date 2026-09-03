"""Проверочный push одному пользователю.

Нужен один раз — в момент, когда на прод приезжают креды Firebase: убедиться,
что связка «Notification → очередь → воркер → FCM → телефон» жива, не трогая
живые события. Уведомление создаётся обычным сервисом, поэтому проходит те же
настройки и ту же доставку, что и настоящие.
"""

from typing import Any

from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = "Отправляет проверочное уведомление указанному пользователю."

    def add_arguments(self, parser: Any) -> None:
        # Идентификатор обязателен и не имеет значения по умолчанию: команда
        # шлёт push живому человеку, и «кому-нибудь» здесь неприемлемо.
        parser.add_argument("--user-id", type=int, required=True)
        parser.add_argument(
            "--title",
            default="Проверка уведомлений",
            help="Заголовок проверочного уведомления.",
        )
        parser.add_argument(
            "--body",
            default="Если вы это видите, push-уведомления работают.",
            help="Текст проверочного уведомления.",
        )

    def handle(self, *args: Any, **options: Any) -> None:
        from django.conf import settings
        from django.contrib.auth import get_user_model

        from apps.notifications.models import DeviceToken, NotificationType
        from apps.notifications.services import notify

        user = get_user_model().objects.filter(pk=options["user_id"]).first()
        if user is None:
            raise CommandError(f"Пользователь {options['user_id']} не найден.")

        if not settings.PUSH_ENABLED:
            # Выходим до создания записи: иначе в истории пользователя осталось
            # бы уведомление о проверке, которой на самом деле не было.
            self.stdout.write(
                self.style.WARNING(
                    "PUSH_ENABLED=0 — транспорт выключен, уведомление не создано. "
                    "Включите push и повторите."
                )
            )
            return

        devices = DeviceToken.objects.filter(user=user, is_active=True).count()
        if not devices:
            raise CommandError(
                f"У пользователя {user.pk} нет активных устройств — отправлять некуда."
            )

        notification = notify(
            user=user,
            notification_type=NotificationType.SYSTEM,
            title=options["title"],
            body=options["body"],
            payload={"kind": "test_push"},
        )
        self.stdout.write(
            self.style.SUCCESS(
                f"Уведомление {notification.pk} создано, "
                f"push поставлен в очередь на {devices} устр."
            )
        )
