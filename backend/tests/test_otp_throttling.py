"""Ограничения на запрос кода: сколько их и какое время видит пользователь.

На устройстве человек за одну сессию получал «20 секунд», «40 секунд» и
«3062 секунды» и решил, что действуют три разных таймера. Числа были верные:
это остаток минутного лимита на номер и остаток часового. Проблема была в
подаче — сырые секунды и собственный отсчёт клиента поверх серверного.

Здесь фиксируется контракт: сколько бы ограничений ни сработало, ответ несёт
ОДНО retry_after, и это максимум из сработавших.
"""

import pytest
from rest_framework.test import APIClient

from apps.common.exceptions import format_wait

REQUEST_URL = "/api/v1/auth/otp/request/"
PHONE = "+996700123456"

# Боевая конфигурация: минута между кодами, пять кодов в час, двадцать с IP.
PRODUCTION_RATES = {
    "otp_phone_resend": "1/min",
    "otp_phone_hourly": "5/hour",
    "otp_ip": "20/hour",
}


@pytest.mark.django_db
def test_immediate_resend_is_blocked_by_the_minute_limit(
    api_client: APIClient, throttle_rates
) -> None:
    """Повтор сразу же — минутный лимит на номер, время меньше минуты."""
    throttle_rates(**PRODUCTION_RATES)
    assert api_client.post(REQUEST_URL, {"phone": PHONE}).status_code == 200

    response = api_client.post(REQUEST_URL, {"phone": PHONE})

    assert response.status_code == 429
    error = response.json()["error"]
    assert error["code"] == "throttled"
    retry_after = error["details"]["retry_after"]
    assert 0 < retry_after <= 60, "минутный лимит не может требовать больше минуты"


@pytest.mark.django_db
def test_hourly_limit_reports_time_until_the_window_frees(
    api_client: APIClient, throttle_rates
) -> None:
    """Часовой лимит исчерпан — ждать до часа, а не до минуты."""
    # Минутный лимит мешает набрать пять запросов подряд — поднимаем только его.
    throttle_rates(**{**PRODUCTION_RATES, "otp_phone_resend": "100/min"})

    for _ in range(5):
        assert api_client.post(REQUEST_URL, {"phone": PHONE}).status_code == 200

    response = api_client.post(REQUEST_URL, {"phone": PHONE})

    assert response.status_code == 429
    retry_after = response.json()["error"]["details"]["retry_after"]
    assert retry_after > 60, "часовой лимит не может освободиться через минуту"
    assert retry_after <= 3600


@pytest.mark.django_db
def test_response_carries_exactly_one_retry_after(api_client: APIClient, throttle_rates) -> None:
    """Сколько бы ограничений ни сработало, время в ответе одно.

    DRF складывает сработавшие ограничения и берёт из них максимум
    (APIView.check_throttles), поэтому клиенту не нужно ничего сводить.
    """
    throttle_rates(**PRODUCTION_RATES)
    api_client.post(REQUEST_URL, {"phone": PHONE})
    response = api_client.post(REQUEST_URL, {"phone": PHONE})

    details = response.json()["error"]["details"]
    assert list(details) == ["retry_after"]
    assert isinstance(details["retry_after"], int)


@pytest.mark.django_db
def test_message_is_human_readable_not_raw_seconds(api_client: APIClient, throttle_rates) -> None:
    """«Повторите через 3062 секунды» пользователь читать не должен."""
    throttle_rates(**PRODUCTION_RATES)
    api_client.post(REQUEST_URL, {"phone": PHONE})
    response = api_client.post(REQUEST_URL, {"phone": PHONE})

    message = response.json()["error"]["message"]
    assert message.startswith("Повторите через ")
    assert message.endswith(".")


def test_wait_is_formatted_by_scale() -> None:
    """Секунды до минуты, дальше минуты, дальше часы."""
    assert format_wait(1) == "1 секунду"
    assert format_wait(2) == "2 секунды"
    assert format_wait(20) == "20 секунд"
    assert format_wait(42) == "42 секунды"
    assert format_wait(60) == "1 минуту"
    assert format_wait(90) == "2 минуты"
    assert format_wait(3062) == "52 минуты"
    assert format_wait(3600) == "час"
    assert format_wait(7200) == "2 часа"
    assert format_wait(18000) == "5 часов"


def test_long_wait_never_shows_bare_seconds() -> None:
    assert "3062" not in format_wait(3062)
    assert "секунд" not in format_wait(3062)


@pytest.mark.django_db
def test_provider_retry_does_not_leak_into_user_wait(
    api_client: APIClient, throttle_rates, settings
) -> None:
    """Ретраи SMS-шлюза — внутренняя деталь, а не разрешение повторить.

    SMS_RETRIES и SMS_RETRY_BACKOFF живут внутри задачи отправки и в ответ
    API не попадают: пользователю показывается только лимит на запрос кода.
    """
    throttle_rates(**PRODUCTION_RATES)
    settings.SMS_RETRIES = 2
    settings.SMS_RETRY_BACKOFF = 20.0

    api_client.post(REQUEST_URL, {"phone": PHONE})
    response = api_client.post(REQUEST_URL, {"phone": PHONE})

    retry_after = response.json()["error"]["details"]["retry_after"]
    assert retry_after != 20
    assert retry_after != 40
