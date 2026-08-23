"""Заготовка провайдера банковского шлюза.

Структура готова, конкретные поля — за банком: у каждого свои имена в теле
запроса и свой порядок склейки строки для подписи. Места, которые нужно
заполнить по документации, помечены TODO.

Общая схема одинакова у всех:
1. POST на эндпоинт создания счёта с подписью HMAC-SHA256;
2. в ответе — ссылка на оплату и идентификатор счёта у банка;
3. вебхук о статусе с той же подписью в заголовке.
"""

import hashlib
import hmac
import json
import logging
from decimal import Decimal, InvalidOperation
from typing import Any

import requests
from django.conf import settings

from apps.billing.providers.base import (
    PaymentIntent,
    PaymentProvider,
    WebhookResult,
    WebhookSignatureError,
)

logger = logging.getLogger(__name__)

SIGNATURE_HEADER = "X-Signature"

# TODO(bank): сверить со спецификацией банка — у каждого свой словарь статусов.
STATUS_MAP = {
    "paid": "succeeded",
    "success": "succeeded",
    "declined": "failed",
    "canceled": "failed",
    "expired": "expired",
}


class BankPaymentProvider(PaymentProvider):
    """HTTP-шлюз банка с подписью HMAC-SHA256."""

    code = "bank"

    def __init__(self) -> None:
        self.api_url = settings.BANK_PAYMENT_API_URL
        self.merchant_id = settings.BANK_PAYMENT_MERCHANT_ID
        self.secret = settings.BANK_PAYMENT_SECRET
        self.timeout = settings.BANK_PAYMENT_TIMEOUT

    # -- подпись -------------------------------------------------------------

    def sign(self, payload: dict[str, Any]) -> str:
        """HMAC-SHA256 от канонического представления тела.

        TODO(bank): банк может требовать не JSON, а конкатенацию значений в
        фиксированном порядке (например f"{merchant}{order}{amount}") —
        заменить формирование `message` на схему из документации.
        """
        message = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
        return hmac.new(self.secret.encode("utf-8"), message, hashlib.sha256).hexdigest()

    # -- создание счёта ------------------------------------------------------

    def create_payment(self, *, payment: Any, return_url: str) -> PaymentIntent:
        if not self.api_url or not self.secret:
            raise RuntimeError(
                "Шлюз банка не настроен: заполните BANK_PAYMENT_API_URL и BANK_PAYMENT_SECRET."
            )

        # TODO(bank): имена полей — из документации банка.
        payload = {
            "merchant_id": self.merchant_id,
            "order_id": str(payment.pk),
            "amount": str(payment.amount_kgs),
            "currency": "KGS",
            "description": f"Пополнение кошелька house_kgz на {payment.amount_kgs} сом",
            "return_url": return_url,
        }

        response = requests.post(
            self.api_url,
            json=payload,
            headers={SIGNATURE_HEADER: self.sign(payload)},
            timeout=self.timeout,
        )
        response.raise_for_status()
        data = response.json()

        # TODO(bank): ключи ответа — из документации банка.
        return PaymentIntent(
            payment_url=data.get("payment_url", ""),
            qr_code_url=data.get("qr_url", ""),
            provider_ref=str(data.get("payment_id") or ""),
            extra=data,
        )

    # -- вебхук --------------------------------------------------------------

    def verify_webhook(self, request: Any) -> WebhookResult:
        signature = request.headers.get(SIGNATURE_HEADER, "")
        payload = self._payload(request)

        # TODO(bank): часть банков подписывает сырое тело, а не разобранный
        # словарь — тогда сверять нужно request.body.
        expected = self.sign(payload)
        # Сравниваем байты: compare_digest падает TypeError на строке с
        # не-ASCII символами, а подпись в заголовке присылает кто угодно —
        # это должно быть отказом подписи, а не 500.
        if not signature or not hmac.compare_digest(
            signature.encode("utf-8", "ignore"), expected.encode("utf-8")
        ):
            raise WebhookSignatureError("Подпись вебхука не совпала")

        return WebhookResult(
            provider_ref=str(payload.get("payment_id") or ""),
            status=STATUS_MAP.get(str(payload.get("status")), "failed"),
            amount=self._amount(payload.get("amount")),
            raw=payload,
        )

    @staticmethod
    def _amount(value: Any) -> Decimal | None:
        try:
            return Decimal(str(value)) if value is not None else None
        except (InvalidOperation, TypeError):
            return None

    @staticmethod
    def _payload(request: Any) -> dict[str, Any]:
        data = getattr(request, "data", None)
        if isinstance(data, dict):
            return data
        try:
            return json.loads(request.body or b"{}")
        except (ValueError, AttributeError):
            return {}
