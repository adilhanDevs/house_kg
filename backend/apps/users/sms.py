"""Отправка SMS: абстракция провайдера и его реализации.

Открытый код нигде не логируется — исключение только одно: ConsoleSmsProvider
в режиме отладки, он для того и нужен.
"""

import logging
import time
from typing import Protocol

import requests
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured

logger = logging.getLogger(__name__)


class SmsSendError(Exception):
    """Провайдер не смог отправить сообщение."""


def mask_phone(phone: str) -> str:
    """+996700123456 -> +9967****3456. Для логов."""
    if len(phone) < 8:
        return "***"
    return f"{phone[:5]}****{phone[-4:]}"


class SmsProvider(Protocol):
    """Контракт провайдера SMS."""

    def send(self, phone: str, text: str) -> None: ...


class ConsoleSmsProvider:
    """Пишет сообщение в лог вместо отправки — для разработки."""

    def send(self, phone: str, text: str) -> None:
        if settings.DEBUG:
            logger.info("SMS to %s: %s", phone, text)
        else:
            # Вне отладки текст (а в нём код) в лог не пишем.
            logger.info("SMS to %s: %s символов текста", mask_phone(phone), len(text))


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
        self.url = url or settings.SMS_API_URL
        self.token = token or settings.SMS_API_TOKEN
        self.timeout = timeout if timeout is not None else settings.SMS_TIMEOUT
        self.retries = retries if retries is not None else settings.SMS_RETRIES
        self.backoff = backoff if backoff is not None else settings.SMS_RETRY_BACKOFF
        if not self.url:
            raise ImproperlyConfigured("SMS_API_URL не задан, а SMS_PROVIDER=http.")

    def send(self, phone: str, text: str) -> None:
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


def get_sms_provider() -> SmsProvider:
    """Провайдер по настройке SMS_PROVIDER: console | http."""
    name = (settings.SMS_PROVIDER or "console").lower()
    if name == "console":
        return ConsoleSmsProvider()
    if name == "http":
        return HttpSmsProvider()
    raise ImproperlyConfigured(f"Неизвестный SMS_PROVIDER: {name!r}. Ожидается console или http.")
