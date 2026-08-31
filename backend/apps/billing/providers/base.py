"""Абстракция платёжного провайдера.

Подключение нового банка — это новая реализация `PaymentProvider`, а не правки
во вьюхах: наверх уходят только `PaymentIntent` и `WebhookResult`.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from decimal import Decimal
from typing import Any


@dataclass(slots=True)
class PaymentIntent:
    """Что провайдер вернул на создание счёта."""

    payment_url: str
    qr_code_url: str = ""
    # Строка, которую клиент рисует как QR. Обычно это та же ссылка на оплату.
    qr_data: str = ""
    provider_ref: str = ""
    extra: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class WebhookResult:
    """Разобранный вебхук провайдера."""

    provider_ref: str
    status: str
    amount: Decimal | None = None
    raw: dict[str, Any] = field(default_factory=dict)


class WebhookSignatureError(Exception):
    """Подпись вебхука не сошлась — запрос обрабатывать нельзя."""


class PaymentProvider(ABC):
    """Контракт платёжного провайдера."""

    code: str = ""

    @abstractmethod
    def create_payment(self, *, payment: Any, return_url: str) -> PaymentIntent:
        """Создаёт счёт на стороне провайдера."""

    @abstractmethod
    def verify_webhook(self, request: Any) -> WebhookResult:
        """Проверяет подпись и разбирает тело вебхука.

        При несовпадении подписи поднимает WebhookSignatureError.
        """
