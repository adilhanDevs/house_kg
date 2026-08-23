"""Провайдер для разработки: настоящих денег не трогает.

Нужен, чтобы Flutter-разработчик проходил весь сценарий пополнения, пока
договор с банком не подписан.
"""

import hmac
import json
import logging
import uuid
from decimal import Decimal, InvalidOperation
from io import BytesIO
from typing import Any

import qrcode
from django.conf import settings
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage

from apps.billing.providers.base import (
    PaymentIntent,
    PaymentProvider,
    WebhookResult,
    WebhookSignatureError,
)

logger = logging.getLogger(__name__)

SIGNATURE_HEADER = "X-Signature"
QR_DIRECTORY = "payments/qr"


class MockPaymentProvider(PaymentProvider):
    """Отдаёт фиктивную ссылку и настоящий QR-код на неё."""

    code = "mock"

    def create_payment(self, *, payment: Any, return_url: str) -> PaymentIntent:
        provider_ref = f"mock-{uuid.uuid4().hex[:16]}"
        payment_url = f"{settings.PAYMENT_RETURN_URL}?payment_id={payment.pk}&ref={provider_ref}"

        return PaymentIntent(
            payment_url=payment_url,
            qr_code_url=self._build_qr(payment_url, provider_ref),
            provider_ref=provider_ref,
            extra={"return_url": return_url, "mock": True},
        )

    def _build_qr(self, payment_url: str, provider_ref: str) -> str:
        """Рисует QR на ссылку оплаты и кладёт в медиа-хранилище."""
        image = qrcode.make(payment_url)
        buffer = BytesIO()
        image.save(buffer, format="PNG")

        name = f"{QR_DIRECTORY}/{provider_ref}.png"
        saved = default_storage.save(name, ContentFile(buffer.getvalue()))
        return default_storage.url(saved)

    def verify_webhook(self, request: Any) -> WebhookResult:
        """Сверяет общий секрет из окружения."""
        secret = settings.PAYMENT_WEBHOOK_SECRET
        signature = request.headers.get(SIGNATURE_HEADER, "")

        # Байты, а не строки: compare_digest падает TypeError на не-ASCII,
        # а заголовок присылает кто угодно.
        if not secret or not hmac.compare_digest(
            signature.encode("utf-8", "ignore"), secret.encode("utf-8")
        ):
            raise WebhookSignatureError("Подпись вебхука не совпала")

        payload = self._payload(request)
        amount = payload.get("amount")

        try:
            parsed_amount = Decimal(str(amount)) if amount is not None else None
        except (InvalidOperation, TypeError):
            parsed_amount = None

        return WebhookResult(
            provider_ref=str(payload.get("provider_ref") or ""),
            status=str(payload.get("status") or ""),
            amount=parsed_amount,
            raw=payload,
        )

    @staticmethod
    def _payload(request: Any) -> dict[str, Any]:
        data = getattr(request, "data", None)
        if isinstance(data, dict):
            return data
        try:
            return json.loads(request.body or b"{}")
        except (ValueError, AttributeError):
            return {}
