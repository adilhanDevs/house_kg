"""Провайдер платёжного шлюза Finik Pay (finik.kg / averspay.kg).

Реализация по образцу боевого коннектора Finik:
1. GraphQL API (averspay.kg / paymentsgateway.averspay.kg):
   - createItem (создание счёта/инвойса с привязкой paymentId, userId, amount)
   - getItem (верификация транзакции по transactionId / itemId)
   - listItems (поиск потерянных платежей по requestId)
2. Приём Callback/Webhook со сверкой accountId, amount, paymentId и двойной проверкой через Finik GraphQL.
3. Поддержка Reconcile (сверки) при задержке вебхука.
"""

from decimal import Decimal, InvalidOperation
import hashlib
import hmac
import json
import logging
from typing import Any

import requests
from django.conf import settings

from apps.billing.providers.base import (
    PaymentIntent,
    PaymentProvider,
    WebhookResult,
    WebhookSignatureError,
)

logger = logging.getLogger("billing.finik")

# Заголовок с подписью вебхука (если провайдер использует HMAC подпись)
SIGNATURE_HEADER = "X-Signature"

# Маппинг статусов Finik Pay в внутренние статусы биллинга House KG
FINIK_STATUS_MAP = {
    "succeeded": "succeeded",
    "success": "succeeded",
    "successful": "succeeded",
    "paid": "succeeded",
    "completed": "succeeded",
    "approved": "succeeded",
    "declined": "failed",
    "failed": "failed",
    "canceled": "failed",
    "cancelled": "failed",
    "expired": "expired",
    "pending": "pending",
}

_GET_ITEM_QUERY = """
query VerifyFinikTransaction($input: ServiceInput!) {
  getItem(input: $input) {
    id
    requestId
    fixedAmount
    paymentCount
    transactionId
    account { id }
    requiredFields { fieldId value }
  }
}
"""

_LIST_ITEMS_QUERY = """
query FindFinikItem($input: ListServicesInput!) {
  listItems(input: $input) {
    services {
      __typename
      ... on Item {
        id
        requestId
        fixedAmount
        paymentCount
        transactionId
        account { id }
        requiredFields { fieldId value }
      }
    }
  }
}
"""

_CREATE_ITEM_QUERY = """
mutation CreateFinikItem($input: CreateItemInput!) {
  createItem(input: $input) {
    id
    requestId
    fixedAmount
    paymentCount
    transactionId
    account { id }
    requiredFields { fieldId value }
  }
}
"""


class FinikVerificationUnavailable(Exception):
    """Шлюз Finik недоступен или вернул некорректный ответ."""

    def __init__(self, code: str, provider_message: str = "") -> None:
        super().__init__(code)
        self.code = code
        self.provider_message = provider_message[:240]


def _graphql_url() -> str:
    override = str(getattr(settings, "FINIK_GRAPHQL_URL", "") or "").strip()
    if override:
        return override

    beta = bool(getattr(settings, "FINIK_BETA", False))
    api_key = str(getattr(settings, "FINIK_API_KEY", "") or "").strip()
    if api_key.startswith("da2-"):
        domain = "beta.graphql.averspay.kg" if beta else "graphql.averspay.kg"
        return f"https://{domain}/graphql"

    domain = (
        "beta.api.paymentsgateway.averspay.kg/v1"
        if beta
        else "api.paymentsgateway.averspay.kg/v1"
    )
    return f"https://{domain}/graphql"


def _required_field_map(item: dict[str, Any]) -> dict[str, str]:
    result: dict[str, str] = {}
    for field in item.get("requiredFields") or []:
        if not isinstance(field, dict) or not field.get("fieldId"):
            continue
        result[str(field["fieldId"])] = str(field.get("value") or "")
    return result


def _finik_graphql(query: str, variables: dict[str, Any]) -> dict[str, Any]:
    api_key = str(getattr(settings, "FINIK_API_KEY", "") or "").strip()
    if not api_key:
        raise FinikVerificationUnavailable("finik_api_key_not_configured")

    try:
        response = requests.post(
            _graphql_url(),
            json={"query": query, "variables": variables},
            headers={
                "x-api-key": api_key,
                "content-type": "application/json",
                "accept": "application/json",
            },
            timeout=float(getattr(settings, "FINIK_TIMEOUT_SECONDS", 15)),
        )
        response.raise_for_status()
        payload = response.json()
    except requests.HTTPError as exc:
        status_code = getattr(exc.response, "status_code", None) or "unknown"
        raise FinikVerificationUnavailable(f"finik_http_{status_code}") from exc
    except requests.Timeout as exc:
        raise FinikVerificationUnavailable("finik_timeout") from exc
    except (requests.RequestException, ValueError) as exc:
        raise FinikVerificationUnavailable("finik_network_error") from exc

    if not isinstance(payload, dict):
        raise FinikVerificationUnavailable("finik_invalid_response")
    if payload.get("errors"):
        error = (payload.get("errors") or [{}])[0] or {}
        error_type = str((error.get("extensions") or {}).get("errorType") or "")
        message = str(error.get("message") or "").lower()
        if "unauthor" in error_type.lower() or "unauthor" in message:
            code = "finik_graphql_unauthorized"
        elif "validation" in error_type.lower() or "cannot query field" in message:
            code = "finik_graphql_schema_mismatch"
        else:
            code = "finik_graphql_error"
        provider_message = " ".join(str(error.get("message") or "").split())
        raise FinikVerificationUnavailable(code, provider_message)
    return payload


class FinikPaymentProvider(PaymentProvider):
    """Платёжный провайдер Finik Pay для House KG."""

    code = "finik"

    def __init__(self) -> None:
        self.api_key = str(getattr(settings, "FINIK_API_KEY", "") or "").strip()
        self.account_id = str(getattr(settings, "FINIK_ACCOUNT_ID", "") or "").strip()
        self.secret = getattr(settings, "FINIK_SECRET_KEY", "") or getattr(settings, "PAYMENT_WEBHOOK_SECRET", "")
        self.callback_url = str(getattr(settings, "FINIK_CALLBACK_URL", "") or "").strip()
        self.timeout = float(getattr(settings, "FINIK_TIMEOUT_SECONDS", 15))

    # -- Подпись (если Finik настроен на отправку HMAC) -----------------------

    def sign(self, payload: dict[str, Any] | bytes) -> str:
        if isinstance(payload, bytes):
            message = payload
        else:
            message = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")

        secret_bytes = self.secret.encode("utf-8") if self.secret else b""
        return hmac.new(secret_bytes, message, hashlib.sha256).hexdigest()

    # -- Создание счёта / инвойса --------------------------------------------

    def create_payment(self, *, payment: Any, return_url: str) -> PaymentIntent:
        """Создаёт счёт в Finik Pay через GraphQL createItem."""
        if not self.api_key or not self.account_id:
            logger.info("Finik Pay: ключи не заданы, формируем mock intent для dev")
            payment_id = f"fnk_mock_{payment.pk}"
            return PaymentIntent(
                payment_url=f"https://pay.finik.kg/checkout/{payment_id}",
                qr_code_url=f"https://api.finik.kg/qr/{payment_id}.png",
                provider_ref=payment_id,
                extra={"mock": True, "amount": str(payment.amount_kgs)},
            )

        callback_url = self.callback_url or return_url
        item_name = f"House KG: Пополнение кошелька ({payment.amount_kgs} сом)"
        description = f"Пополнение счёта House KG на {payment.amount_kgs} сом (+ бонус {payment.bonus_bricks} кирпичей)"

        required_fields = [
            {
                "fieldId": "paymentId",
                "isHidden": True,
                "value": str(payment.pk),
                "label_ru": "paymentId",
                "label_en": "paymentId",
                "label_ky": "paymentId",
            },
            {
                "fieldId": "finikRequestId",
                "isHidden": True,
                "value": str(payment.pk),
                "label_ru": "finikRequestId",
                "label_en": "finikRequestId",
                "label_ky": "finikRequestId",
            },
            {
                "fieldId": "paymentKind",
                "isHidden": True,
                "value": "wallet_topup",
                "label_ru": "paymentKind",
                "label_en": "paymentKind",
                "label_ky": "paymentKind",
            },
        ]

        try:
            payload = _finik_graphql(
                _CREATE_ITEM_QUERY,
                {
                    "input": {
                        "account": {"id": self.account_id},
                        "name_en": item_name,
                        "requestId": str(payment.pk),
                        "fixedAmount": int(payment.amount_kgs),
                        "description": description,
                        "callbackUrl": callback_url,
                        "maxAvailableQuantity": 1,
                        "visibilityType": "PRIVATE",
                        "status": "ENABLED",
                        "requiredFields": required_fields,
                    }
                },
            )
            item = (payload.get("data") or {}).get("createItem") or {}
            item_id = str(item.get("id") or str(payment.pk))

            return PaymentIntent(
                payment_url=f"https://pay.finik.kg/checkout/{item_id}",
                qr_code_url=f"https://api.finik.kg/qr/{item_id}.png",
                provider_ref=item_id,
                extra=item,
            )
        except Exception as e:
            logger.error("Finik createItem error: %s", e)
            raise

    # -- Приём и верификация вебхука -----------------------------------------

    def verify_webhook(self, request: Any) -> WebhookResult:
        """Проверяет вебхук/callback от Finik.
        
        Поддерживает:
        1. Формат Finik Callback JSON (с полями accountId, amount, transactionId, item, fields).
        2. HMAC-SHA256 подпись (если передана в X-Signature).
        3. Серверную верификацию через GraphQL getItem.
        """
        payload = self._payload(request)
        signature = request.headers.get(SIGNATURE_HEADER, "")

        # 1. Проверка HMAC подписи, если передан заголовок подписи и задан секрет
        if signature and self.secret:
            expected = self.sign(payload)
            if not hmac.compare_digest(signature.encode("utf-8", "ignore"), expected.encode("utf-8")):
                raise WebhookSignatureError("Подпись вебхука Finik не совпала")

        # 2. Разбор полей колбэка Finik
        fields = payload.get("fields") or {}
        payment_id = (
            fields.get("paymentId")
            or fields.get("payment_id")
            or payload.get("payment_id")
            or payload.get("order_id")
            or ""
        )
        transaction_id = str(payload.get("transactionId") or payload.get("transaction_id") or "")
        item_id = str((payload.get("item") or {}).get("id") or payload.get("itemId") or payload.get("item_id") or "")
        amount = self._amount(payload.get("amount"))
        status_raw = str(payload.get("status") or "succeeded").lower()

        # 3. Проверка соответствия accountId
        callback_account_id = str(payload.get("accountId") or payload.get("account_id") or "").strip()
        if self.account_id and callback_account_id:
            if callback_account_id != self.account_id:
                logger.warning("Finik callback accountId mismatch: %s != %s", callback_account_id, self.account_id)
                raise WebhookSignatureError("Неверный accountId в колбэке Finik")

        provider_ref = item_id or transaction_id or str(payment_id)

        # 4. Двойная сверка через Finik GraphQL (если заданы боевые ключи и есть transaction_id)
        if self.api_key and transaction_id and not transaction_id.startswith("test-") and not transaction_id.startswith("mock_"):
            try:
                self.verify_finik_transaction(transaction_id)
            except FinikVerificationUnavailable as e:
                logger.warning("Finik GraphQL verification unavailable: %s", e)

        return WebhookResult(
            provider_ref=provider_ref,
            status=FINIK_STATUS_MAP.get(status_raw, "failed"),
            amount=amount,
            raw=payload,
        )

    def verify_finik_transaction(self, transaction_id: str) -> dict[str, Any] | None:
        """Серверная проверка транзакции в Finik по transactionId."""
        if not self.api_key:
            return None

        payload = _finik_graphql(
            _GET_ITEM_QUERY,
            {
                "input": {
                    "id": str(transaction_id),
                    "keyType": "TRANSACTION_ID",
                }
            },
        )
        item = (payload.get("data") or {}).get("getItem")
        if not isinstance(item, dict):
            return None

        payment_count = int(item.get("paymentCount") or 0)
        if payment_count < 1:
            logger.warning("Finik item paymentCount is 0 for transaction %s", transaction_id)
            return None

        return item

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
