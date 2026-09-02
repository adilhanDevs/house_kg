"""Команда тестирования отправки OTP через Telegram Gateway API."""

import secrets
from typing import Any

from django.core.management.base import BaseCommand, CommandError

from apps.users.phone import mask_public_phone, normalize_phone
from apps.users.sms import TelegramGatewayProvider, mask_phone


class Command(BaseCommand):
    help = "Отправка тестового verification message через Telegram Gateway API"

    def add_arguments(self, parser) -> None:
        parser.add_argument(
            "phone",
            type=str,
            help="Номер телефона получателя (E.164, например +996700123456 или 0700123456)",
        )
        parser.add_argument(
            "--code",
            type=str,
            default=None,
            help="Кастомный код (4-8 цифр). Если не указан, генерируется случайный код.",
        )
        parser.add_argument(
            "--ttl",
            type=int,
            default=300,
            help="Срок жизни кода в секундах (30..3600, по умолчанию 300).",
        )

    def handle(self, *args: Any, **options: Any) -> None:
        raw_phone = options["phone"]
        try:
            phone = normalize_phone(raw_phone)
        except Exception as exc:
            raise CommandError(f"Некорректный номер телефона {raw_phone!r}: {exc}") from exc

        code = options.get("code")
        if not code:
            code = f"{secrets.randbelow(1_000_000):06d}"
        else:
            code = str(code).strip()
            if not (code.isdigit() and 4 <= len(code) <= 8):
                raise CommandError(f"Код должен содержать от 4 до 8 цифр. Получено: {code!r}")

        ttl = options["ttl"]

        self.stdout.write(self.style.NOTICE("=== Тестирование Telegram Gateway ==="))
        self.stdout.write(
            f"Получатель (маскированный): {mask_phone(phone)} ({mask_public_phone(phone)})"
        )
        self.stdout.write(f"TTL: {ttl} сек")

        try:
            provider = TelegramGatewayProvider()
        except Exception as exc:
            self.stdout.write(self.style.ERROR(f"ОШИБКА КОНФИГУРАЦИИ: {exc}"))
            raise CommandError(str(exc)) from exc

        try:
            result = provider.send_verification_message(phone=phone, code=code, ttl=ttl)
        except Exception as exc:
            self.stdout.write(self.style.ERROR(f"ОШИБКА ОТПРАВКИ: {exc}"))
            raise CommandError(
                f"Не удалось отправить сообщение через Telegram Gateway: {exc}"
            ) from exc

        self.stdout.write(self.style.SUCCESS("✓ Сообщение успешно отправлено!"))
        self.stdout.write(f"  Request ID:        {result.request_id or '—'}")
        self.stdout.write(f"  Delivery Status:   {result.delivery_status}")
        if result.request_cost is not None:
            self.stdout.write(f"  Request Cost:      {result.request_cost}")
        if result.remaining_balance is not None:
            self.stdout.write(f"  Remaining Balance: {result.remaining_balance}")
