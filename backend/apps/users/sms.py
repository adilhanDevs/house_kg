"""Отправка SMS / OTP: абстракция провайдера и его реализации.

Поддерживаемые провайдеры (SMS_PROVIDER):
- `console`: вывод в лог (для локальной разработки)
- `http`: отправка через классический HTTP-шлюз SMS
- `telegram`: отправка через официальный Telegram Gateway API (https://gatewayapi.telegram.org)
- `chatflow`: WhatsApp через Chatflow (Flow ID или legacy instance ID)

Открытый код нигде не логируется в production — исключение только одно:
ConsoleSmsProvider в режиме DEBUG.
"""

import logging
import re
import time
from dataclasses import dataclass
from typing import Any, Protocol

import requests
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured, ValidationError

from apps.users.phone import mask_public_phone, normalize_phone

logger = logging.getLogger(__name__)


class SmsSendError(Exception):
    """Провайдер не смог отправить сообщение."""


class OtpDeliveryError(SmsSendError):
    """Специфическая ошибка доставки OTP (шлюз недоступен, отклонён и т.д.)."""


def mask_phone(phone: str) -> str:
    """+996700123456 -> +9967****3456. Для логов."""
    if len(phone) < 8:
        return "***"
    return f"{phone[:5]}****{phone[-4:]}"


@dataclass
class TelegramSendResult:
    """Результат отправки verification message через Telegram Gateway."""

    request_id: str
    phone_number: str
    request_cost: float | None = None
    delivery_status: str = "sent"
    remaining_balance: float | None = None
    raw_response: dict[str, Any] | None = None


class SmsProvider(Protocol):
    """Контракт провайдера SMS/OTP."""

    def send(self, phone: str, text: str, **kwargs: Any) -> Any: ...

    def send_code(self, phone: str, code: str, ttl: int | None = None) -> Any: ...


class ConsoleSmsProvider:
    """Пишет сообщение в лог вместо отправки — для разработки."""

    def send(self, phone: str, text: str, **kwargs: Any) -> None:
        if settings.DEBUG:
            logger.info("SMS to %s: %s", mask_public_phone(phone), text)
        else:
            # Вне отладки текст (а в нём код) в лог не пишем.
            logger.info("SMS to %s: %s символов текста", mask_phone(phone), len(text))

    def send_code(self, phone: str, code: str, ttl: int | None = None) -> None:
        template = getattr(settings, "OTP_SMS_TEMPLATE", "house_kgz: код {code}")
        text = template.format(code=code)
        self.send(phone, text)


class HttpSmsProvider:
    """POST на HTTP-шлюз оператора с ретраями и экспоненциальной задержкой."""

    def __init__(
        self,
        url: str | None = None,
        token: str | None = None,
        timeout: int | None = None,
        retries: int | None = None,
        backoff: float | None = None,
    ) -> None:
        self.url = url or getattr(settings, "SMS_API_URL", "")
        self.token = token or getattr(settings, "SMS_API_TOKEN", "")
        self.timeout = timeout if timeout is not None else getattr(settings, "SMS_TIMEOUT", 10)
        self.retries = retries if retries is not None else getattr(settings, "SMS_RETRIES", 2)
        self.backoff = (
            backoff if backoff is not None else getattr(settings, "SMS_RETRY_BACKOFF", 1.0)
        )
        if not self.url:
            raise ImproperlyConfigured("SMS_API_URL не задан, а SMS_PROVIDER=http.")

    def send(self, phone: str, text: str, **kwargs: Any) -> None:
        headers = {"Authorization": f"Bearer {self.token}"} if self.token else {}
        last_error: Exception | None = None

        for attempt in range(self.retries + 1):
            try:
                response = requests.post(
                    self.url,
                    json={"phone": phone, "text": text},
                    headers=headers,
                    timeout=self.timeout,
                )
                response.raise_for_status()
            except requests.RequestException as exc:
                last_error = exc
                logger.warning(
                    "SMS-шлюз не ответил (%s), попытка %s из %s",
                    exc.__class__.__name__,
                    attempt + 1,
                    self.retries + 1,
                )
                if attempt < self.retries:
                    time.sleep(self.backoff * (2**attempt))
                continue
            else:
                return

        raise SmsSendError("SMS-шлюз недоступен") from last_error

    def send_code(self, phone: str, code: str, ttl: int | None = None) -> None:
        template = getattr(settings, "OTP_SMS_TEMPLATE", "house_kgz: код {code}")
        text = template.format(code=code)
        self.send(phone, text)


class TelegramGatewayProvider:
    """Провайдер отправки OTP-кодов через официальный Telegram Gateway API.

    Документация: https://gateway.telegram.org
    Base URL: https://gatewayapi.telegram.org
    """

    DEFAULT_BASE_URL = "https://gatewayapi.telegram.org"
    DEFAULT_TTL = 300
    DEFAULT_TIMEOUT = 10

    def __init__(
        self,
        token: str | None = None,
        base_url: str | None = None,
        ttl: int | None = None,
        timeout: int | None = None,
    ) -> None:
        self.token = token if token is not None else getattr(settings, "TELEGRAM_GATEWAY_TOKEN", "")
        self.base_url = (
            base_url
            if base_url is not None
            else getattr(settings, "TELEGRAM_GATEWAY_BASE_URL", self.DEFAULT_BASE_URL)
        )
        self.ttl = (
            ttl if ttl is not None else getattr(settings, "TELEGRAM_GATEWAY_TTL", self.DEFAULT_TTL)
        )
        self.timeout = (
            timeout
            if timeout is not None
            else getattr(settings, "TELEGRAM_GATEWAY_TIMEOUT", self.DEFAULT_TIMEOUT)
        )

        if not self.token:
            raise ImproperlyConfigured("TELEGRAM_GATEWAY_TOKEN не задан, а SMS_PROVIDER=telegram.")

    @property
    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        }

    def _normalize_phone(self, phone: str) -> str:
        try:
            return normalize_phone(phone)
        except ValidationError as exc:
            raise OtpDeliveryError("Некорректный номер телефона для Telegram Gateway.") from exc

    def send_verification_message(
        self,
        phone: str,
        code: str,
        ttl: int | None = None,
    ) -> TelegramSendResult:
        """Отправляет verification message в Telegram Gateway.

        POST https://gatewayapi.telegram.org/sendVerificationMessage
        Payload: {"phone_number": "+996...", "code": "1234", "ttl": 300}
        """
        normalized_phone = self._normalize_phone(phone)
        code_str = str(code).strip()
        if not (code_str.isdigit() and 4 <= len(code_str) <= 8):
            raise OtpDeliveryError(
                f"Некорректный код для Telegram Gateway (4-8 цифр, получено {len(code_str)})."
            )

        effective_ttl = ttl if ttl is not None else self.ttl
        if not (30 <= effective_ttl <= 3600):
            raise OtpDeliveryError(
                f"Недопустимый TTL для Telegram Gateway: {effective_ttl} (допустимо 30..3600 сек)."
            )

        url = f"{self.base_url.rstrip('/')}/sendVerificationMessage"
        payload = {
            "phone_number": normalized_phone,
            "code": code_str,
            "ttl": effective_ttl,
        }

        try:
            response = requests.post(
                url,
                json=payload,
                headers=self._headers,
                timeout=self.timeout,
            )
        except requests.Timeout as exc:
            logger.warning(
                "Таймаут запроса к Telegram Gateway для %s",
                mask_phone(normalized_phone),
            )
            raise OtpDeliveryError("Telegram Gateway не ответил вовремя (таймаут).") from exc
        except requests.ConnectionError as exc:
            logger.warning(
                "Ошибка соединения с Telegram Gateway для %s",
                mask_phone(normalized_phone),
            )
            raise OtpDeliveryError("Ошибка соединения с Telegram Gateway.") from exc
        except requests.RequestException as exc:
            logger.warning(
                "Сетевой сбой при обращении к Telegram Gateway (%s) для %s",
                exc.__class__.__name__,
                mask_phone(normalized_phone),
            )
            raise OtpDeliveryError("Сетевая ошибка при обращении к Telegram Gateway.") from exc

        if response.status_code == 401:
            logger.error(
                "Ошибка авторизации в Telegram Gateway для %s: проверьте TELEGRAM_GATEWAY_TOKEN",
                mask_phone(normalized_phone),
            )
            raise OtpDeliveryError("Ошибка авторизации в Telegram Gateway.")

        if response.status_code == 429:
            logger.warning(
                "Превышен лимит запросов к Telegram Gateway для %s",
                mask_phone(normalized_phone),
            )
            raise OtpDeliveryError("Превышен лимит запросов к Telegram Gateway.")

        if response.status_code >= 500:
            logger.warning("Telegram Gateway вернул серверную ошибку: %s", response.status_code)
            raise OtpDeliveryError(
                f"Telegram Gateway временно недоступен (код {response.status_code})."
            )

        try:
            data = response.json()
        except ValueError as exc:
            logger.warning(
                "Telegram Gateway вернул невалидный JSON: status=%s", response.status_code
            )
            raise OtpDeliveryError("Некорректный ответ от Telegram Gateway.") from exc

        if not data.get("ok", False):
            error_text = data.get("error", f"HTTP {response.status_code}")
            logger.warning(
                "Telegram Gateway отклонил запрос для %s: %s",
                mask_phone(normalized_phone),
                error_text,
            )
            raise OtpDeliveryError(f"Telegram Gateway отклонил запрос: {error_text}")

        if response.status_code != 200:
            raise OtpDeliveryError(f"Telegram Gateway вернул статус {response.status_code}.")

        result = data.get("result", {})
        request_id = result.get("request_id", "")
        cost = result.get("request_cost")
        status_info = result.get("delivery_status", {})
        delivery_status = (
            status_info.get("status", "sent")
            if isinstance(status_info, dict)
            else str(status_info or "sent")
        )
        remaining_balance = result.get("remaining_balance")

        logger.info(
            "OTP успешно отправлен через Telegram Gateway на %s (request_id=%s)",
            mask_phone(normalized_phone),
            request_id,
        )

        return TelegramSendResult(
            request_id=request_id,
            phone_number=normalized_phone,
            request_cost=cost,
            delivery_status=delivery_status,
            remaining_balance=remaining_balance,
            raw_response=data,
        )

    def check_verification_status(self, request_id: str, code: str) -> dict[str, Any]:
        """Проверяет статус верификации и сообщает Telegram Gateway о введённом коде.

        POST https://gatewayapi.telegram.org/checkVerificationStatus
        Payload: {"request_id": "...", "code": "..."}
        """
        if not request_id or not code:
            return {"ok": False, "error": "request_id and code are required"}

        url = f"{self.base_url.rstrip('/')}/checkVerificationStatus"
        payload = {"request_id": request_id, "code": str(code).strip()}

        try:
            response = requests.post(
                url,
                json=payload,
                headers=self._headers,
                timeout=self.timeout,
            )
            return response.json()
        except Exception as exc:
            logger.warning(
                "Не удалось проверить статус верификации в Telegram Gateway (request_id=%s): %s",
                request_id,
                exc.__class__.__name__,
            )
            return {"ok": False, "error": str(exc)}

    def check_send_ability(self, phone: str) -> dict[str, Any]:
        """Проверяет возможность доставки в Telegram на указанный номер.

        POST https://gatewayapi.telegram.org/checkSendAbility
        Внимание: не вызывается автоматически перед каждой отправкой во избежание лишних списаний.
        """
        normalized_phone = self._normalize_phone(phone)
        url = f"{self.base_url.rstrip('/')}/checkSendAbility"
        payload = {"phone_number": normalized_phone}

        try:
            response = requests.post(
                url,
                json=payload,
                headers=self._headers,
                timeout=self.timeout,
            )
            return response.json()
        except Exception as exc:
            logger.warning(
                "Ошибка checkSendAbility для %s: %s",
                mask_phone(normalized_phone),
                exc.__class__.__name__,
            )
            return {"ok": False, "error": str(exc)}

    def send_code(
        self,
        phone: str,
        code: str,
        ttl: int | None = None,
    ) -> TelegramSendResult:
        """Реализация метода send_code для TelegramGatewayProvider."""
        return self.send_verification_message(phone, code, ttl=ttl)

    def send(
        self,
        phone: str,
        text: str,
        *,
        code: str | None = None,
        ttl: int | None = None,
        **kwargs: Any,
    ) -> TelegramSendResult:
        """Реализация общего интерфейса send.

        Если передан отдельный аргумент `code`, используется он. Иначе выполняется
        попытка извлечь числовой код из текста сообщения.
        """
        if code:
            return self.send_code(phone, code, ttl=ttl)

        digits_match = re.findall(r"\b\d{4,8}\b", text)
        if digits_match:
            return self.send_code(phone, digits_match[0], ttl=ttl)

        raise OtpDeliveryError(
            "Для Telegram Gateway требуется передача числового OTP-кода (от 4 до 8 цифр)."
        )


class ChatflowProvider:
    """WhatsApp OTP по контракту Safa-app-backend/apps/users/chatflow.py.

    Повторы выполняет существующая Celery-задача. Ответ не возвращает request_id:
    в текущей модели это поле используется для отчётов именно Telegram Gateway.
    """

    def __init__(self) -> None:
        self.token = settings.CHATFLOW_TOKEN.strip()
        self.flow_id = settings.CHATFLOW_FLOW_ID.strip()
        self.instance_id = settings.CHATFLOW_INSTANCE_ID.strip()
        self.base_url = settings.CHATFLOW_BASE_URL.strip().rstrip("/")
        self.timeout = settings.CHATFLOW_TIMEOUT_SECONDS
        if not self.token:
            raise ImproperlyConfigured("CHATFLOW_TOKEN не задан, а SMS_PROVIDER=chatflow.")
        if not self.flow_id and not self.instance_id:
            raise ImproperlyConfigured("Задайте CHATFLOW_FLOW_ID или CHATFLOW_INSTANCE_ID.")
        if not self.base_url.startswith("https://") or self.timeout <= 0:
            raise ImproperlyConfigured("Chatflow требует HTTPS URL и положительный таймаут.")

    def send(self, phone: str, text: str, **kwargs: Any) -> None:
        try:
            recipient = normalize_phone(phone).lstrip("+")
        except ValidationError:
            raise OtpDeliveryError("Некорректный номер телефона для Chatflow.") from None

        headers = {"Accept": "application/json"}
        if self.flow_id:
            path = "/api/v1/n8n/action/text"
            params = {"flow_id": self.flow_id, "recipient": recipient, "msg": text}
            headers["Authorization"] = f"Bearer {self.token}"
        else:
            path = "/api/v1/send-text"
            params = {
                "token": self.token,
                "instance_id": self.instance_id,
                "jid": f"{recipient}@c.us",
                "msg": text,
            }

        try:
            response = requests.get(
                f"{self.base_url}{path}",
                params=params,
                headers=headers,
                timeout=self.timeout,
                allow_redirects=False,
            )
        except requests.RequestException:
            # URL содержит OTP (и legacy token): исключение requests не должно
            # попасть в traceback Celery вместе с query string.
            raise OtpDeliveryError("Chatflow временно недоступен.") from None

        if not 200 <= response.status_code < 300:
            raise OtpDeliveryError(f"Chatflow вернул HTTP {response.status_code}.")
        try:
            data = response.json()
        except ValueError:
            raise OtpDeliveryError("Некорректный ответ Chatflow.") from None
        if data is True or (isinstance(data, dict) and data.get("success") is not False):
            return
        # Провайдер может вернуть исходный текст в ошибке: не раскрываем его.
        raise OtpDeliveryError("Chatflow отклонил отправку OTP.")

    def send_code(self, phone: str, code: str, ttl: int | None = None) -> None:
        # Chatflow отправляет текст; срок действия проверяет наш OTP-сервис.
        self.send(phone, settings.OTP_SMS_TEMPLATE.format(code=code))


def get_sms_provider() -> SmsProvider:
    """Провайдер по SMS_PROVIDER / OTP_PROVIDER: console | http | telegram | chatflow."""
    name = (
        getattr(settings, "SMS_PROVIDER", None)
        or getattr(settings, "OTP_PROVIDER", None)
        or "console"
    ).lower()

    if name == "console":
        return ConsoleSmsProvider()
    if name == "http":
        return HttpSmsProvider()
    if name == "telegram":
        return TelegramGatewayProvider()
    if name == "chatflow":
        return ChatflowProvider()

    raise ImproperlyConfigured(
        f"Неизвестный SMS_PROVIDER: {name!r}. Ожидается console, http, telegram или chatflow."
    )
