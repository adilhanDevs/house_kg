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
from django.core.exceptions import ImproperlyConfigured

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
        self.provider_message = provider_message[:600]


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


# Ключи, под которыми Finik может отдать готовую ссылку на оплату. Схема шлюза
# в документации зафиксирована не полностью, поэтому берём первое, что похоже на
# ссылку, и только если ничего нет — собираем адрес по шаблону из настроек.
_URL_KEYS = ("paymentUrl", "payment_url", "checkoutUrl", "url", "link", "shortLink", "qrUrl")


def _first_url(item: dict[str, Any]) -> str:
    """Первая ссылка на оплату, которую вернул сам Finik. Пусто — если её нет."""
    for key in _URL_KEYS:
        value = str(item.get(key) or "").strip()
        if value.startswith("http://") or value.startswith("https://"):
            return value
    return ""


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
        body = ""
        if exc.response is not None:
            body = " ".join(str(exc.response.text or "").split())
        raise FinikVerificationUnavailable(f"finik_http_{status_code}", body) from exc
    except requests.Timeout as exc:
        raise FinikVerificationUnavailable("finik_timeout", str(exc)) from exc
    except (requests.RequestException, ValueError) as exc:
        # Текст исключения обязателен: без него «сеть не работает» неотличимо
        # от «нет DNS», «блокирует прокси» и «шлюз вернул не JSON».
        raise FinikVerificationUnavailable(
            "finik_network_error", f"{type(exc).__name__}: {exc}"
        ) from exc

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
        # Только собственный секрет Finik. Общий PAYMENT_WEBHOOK_SECRET сюда не
        # подставляем: чужой секрет отверг бы все настоящие подписи.
        self.secret = str(getattr(settings, "FINIK_SECRET_KEY", "") or "")
        self.callback_url = str(getattr(settings, "FINIK_CALLBACK_URL", "") or "").strip()
        self.timeout = float(getattr(settings, "FINIK_TIMEOUT_SECONDS", 15))
        self.checkout_template = str(
            getattr(settings, "FINIK_CHECKOUT_URL_TEMPLATE", "")
            or "https://pay.finik.kg/checkout/{item_id}"
        )
        # Колбэк без HMAC-подписи принимается только после сверки с Finik.
        self.require_verification = bool(
            getattr(settings, "FINIK_REQUIRE_VERIFICATION", True)
        )

    @property
    def is_configured(self) -> bool:
        return bool(self.api_key and self.account_id)

    def checkout_url(self, item_id: str) -> str:
        """Ссылка на оплату по идентификатору счёта Finik."""
        try:
            return self.checkout_template.format(item_id=item_id)
        except (KeyError, IndexError, ValueError):
            logger.error("Некорректный FINIK_CHECKOUT_URL_TEMPLATE: %r", self.checkout_template)
            return f"https://pay.finik.kg/checkout/{item_id}"

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
        if not self.is_configured:
            # Раньше здесь выдавался фиктивный счёт — клиент видел «оплату»,
            # которой не было. Теперь это громкая ошибка конфигурации.
            raise ImproperlyConfigured(
                "Finik не настроен: задайте FINIK_API_KEY и FINIK_ACCOUNT_ID. "
                "Для разработки используйте PAYMENT_PROVIDER=mock."
            )

        callback_url = self.callback_url or return_url
        item_name = f"House KG: Пополнение кошелька ({payment.amount_kgs} сом)"
        description = (
            f"Пополнение счёта House KG на {payment.amount_kgs} сом "
            f"(+ бонус {payment.bonus_bricks} кирпичей)"
        )

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
            if not item.get("id"):
                raise FinikVerificationUnavailable("finik_create_item_no_id")

            item_id = str(item["id"])
            # Ответ Finik пишем в лог целиком (ключи, не значения полей клиента):
            # по первому боевому счёту видно, отдаёт ли шлюз готовую ссылку.
            logger.info("Finik createItem ok: item=%s, поля ответа=%s", item_id, sorted(item))

            payment_url = _first_url(item) or self.checkout_url(item_id)

            return PaymentIntent(
                payment_url=payment_url,
                # Картинку QR Finik не отдаёт — клиент рисует код сам из qr_data.
                qr_code_url=str(item.get("qrCodeUrl") or item.get("qrUrl") or ""),
                qr_data=payment_url,
                provider_ref=item_id,
                extra=item,
            )
        except Exception as e:
            logger.error("Finik createItem error: %s", e)
            raise

    # -- Приём и верификация вебхука -----------------------------------------

    def verify_webhook(self, request: Any) -> WebhookResult:
        """Проверяет колбэк Finik и разбирает его тело.

        Колбэк начисляет деньги, поэтому доверяем ему только при одном из двух
        доказательств подлинности:

        1. HMAC-SHA256 подпись в заголовке X-Signature, сходящаяся с FINIK_SECRET_KEY;
        2. обратный запрос в Finik (getItem по transactionId), подтверждающий,
           что такая оплата действительно прошла.

        Нет ни того, ни другого — WebhookSignatureError, вьюха ответит 403,
        Finik повторит колбэк позже. Молча принять неподтверждённый колбэк
        нельзя: это подарок любому, кто узнает адрес вебхука.
        """
        payload = self._payload(request)
        signature = request.headers.get(SIGNATURE_HEADER, "")

        # 1. Подпись, если она пришла.
        signature_ok = False
        if signature and not self.secret:
            # Подпись пришла, а сверять не с чем. Не отказываем: ниже колбэк
            # всё равно подтверждается обратным запросом в Finik.
            logger.warning("Колбэк Finik подписан, но FINIK_SECRET_KEY не задан")
        elif signature:
            expected = self.sign(payload)
            if not hmac.compare_digest(
                signature.encode("utf-8", "ignore"), expected.encode("utf-8")
            ):
                raise WebhookSignatureError("Подпись вебхука Finik не совпала")
            signature_ok = True

        # 2. Разбор полей колбэка Finik.
        fields = payload.get("fields") or {}
        payment_id = (
            fields.get("paymentId")
            or fields.get("payment_id")
            or payload.get("payment_id")
            or payload.get("order_id")
            or ""
        )
        transaction_id = str(payload.get("transactionId") or payload.get("transaction_id") or "")
        item_id = str(
            (payload.get("item") or {}).get("id")
            or payload.get("itemId")
            or payload.get("item_id")
            or ""
        )
        amount = self._amount(payload.get("amount"))
        status_raw = str(payload.get("status") or "succeeded").lower()

        # 3. Счёт должен принадлежать нашему аккаунту в Finik.
        callback_account_id = str(
            payload.get("accountId") or payload.get("account_id") or ""
        ).strip()
        if self.account_id and callback_account_id and callback_account_id != self.account_id:
            logger.warning(
                "Finik callback accountId mismatch: %s != %s",
                callback_account_id,
                self.account_id,
            )
            raise WebhookSignatureError("Неверный accountId в колбэке Finik")

        # 4. Сверка с Finik. Без подписи она обязательна и не прощает сбоев.
        verified_item = self._verify_or_fail(
            transaction_id=transaction_id,
            signature_ok=signature_ok,
        )

        if verified_item is not None:
            # Сумму и ссылку берём из ответа Finik, а не из тела колбэка:
            # тело мог подделать кто угодно, ответ шлюза — нет.
            verified_amount = self._amount(verified_item.get("fixedAmount"))
            if verified_amount is not None:
                amount = verified_amount
            verified_id = str(verified_item.get("id") or "")
            if verified_id:
                item_id = verified_id
            verified_fields = _required_field_map(verified_item)
            verified_payment_id = verified_fields.get("paymentId") or ""
            if verified_payment_id:
                if payment_id and str(payment_id) != verified_payment_id:
                    logger.error(
                        "Finik: paymentId в колбэке (%s) не совпал с paymentId в счёте (%s)",
                        payment_id,
                        verified_payment_id,
                    )
                    raise WebhookSignatureError("paymentId колбэка не совпал с данными Finik")
                payment_id = verified_payment_id

        provider_ref = item_id or transaction_id or str(payment_id)
        if not provider_ref:
            raise WebhookSignatureError("В колбэке Finik нет ни item.id, ни transactionId")

        raw = dict(payload)
        if payment_id:
            raw.setdefault("fields", {})
            raw["fields"] = {**(raw.get("fields") or {}), "paymentId": str(payment_id)}

        return WebhookResult(
            provider_ref=provider_ref,
            status=FINIK_STATUS_MAP.get(status_raw, "failed"),
            amount=amount,
            raw=raw,
        )

    def _verify_or_fail(
        self, *, transaction_id: str, signature_ok: bool
    ) -> dict[str, Any] | None:
        """Сверяет транзакцию с Finik. Возвращает счёт или None, если сверка не нужна."""
        if not self.require_verification:
            # Только для тестов: FINIK_REQUIRE_VERIFICATION=0.
            return None

        if signature_ok:
            # Подпись уже доказала подлинность; сверка полезна, но не обязательна.
            if not (self.api_key and transaction_id):
                return None
            try:
                return self.verify_finik_transaction(transaction_id)
            except FinikVerificationUnavailable as exc:
                logger.warning("Finik GraphQL verification unavailable: %s", exc.code)
                return None

        # Подписи нет — сверка единственное доказательство, сбой означает отказ.
        if not self.api_key:
            raise WebhookSignatureError(
                "Колбэк без подписи, а FINIK_API_KEY не задан — подтвердить оплату нечем"
            )
        if not transaction_id:
            raise WebhookSignatureError("Колбэк без подписи и без transactionId")

        try:
            item = self.verify_finik_transaction(transaction_id)
        except FinikVerificationUnavailable as exc:
            logger.error("Finik не подтвердил транзакцию %s: %s", transaction_id, exc.code)
            raise WebhookSignatureError(f"Finik недоступен для сверки: {exc.code}") from exc

        if item is None:
            raise WebhookSignatureError(
                f"Finik не подтвердил оплату по транзакции {transaction_id}"
            )
        return item

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
