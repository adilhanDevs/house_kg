"""Тесты SMS-провайдеров и фоновых задач аутентификации."""

import logging
from datetime import timedelta
from unittest.mock import patch

import pytest
import requests
from django.core.exceptions import ImproperlyConfigured
from django.test import override_settings
from django.utils import timezone

from apps.users.models import OtpCode
from apps.users.sms import (
    ConsoleSmsProvider,
    HttpSmsProvider,
    SmsSendError,
    get_sms_provider,
    mask_phone,
)
from apps.users.tasks import purge_old_otp_codes, send_otp_sms

PHONE = "+996700123456"
TEXT = "house_kgz: код 1234"


def test_mask_phone() -> None:
    assert mask_phone(PHONE) == "+9967****3456"
    assert mask_phone("123") == "***"


# -- фабрика -----------------------------------------------------------------


def test_get_sms_provider_console() -> None:
    with override_settings(SMS_PROVIDER="console"):
        assert isinstance(get_sms_provider(), ConsoleSmsProvider)


def test_get_sms_provider_http() -> None:
    with override_settings(SMS_PROVIDER="http", SMS_API_URL="https://sms.example/send"):
        assert isinstance(get_sms_provider(), HttpSmsProvider)


def test_get_sms_provider_rejects_unknown() -> None:
    with override_settings(SMS_PROVIDER="pigeon"), pytest.raises(ImproperlyConfigured):
        get_sms_provider()


def test_http_provider_requires_url() -> None:
    with (
        override_settings(SMS_PROVIDER="http", SMS_API_URL=""),
        pytest.raises(ImproperlyConfigured),
    ):
        get_sms_provider()


# -- ConsoleSmsProvider ------------------------------------------------------


@override_settings(DEBUG=True)
def test_console_provider_prints_code_in_debug(caplog) -> None:
    with caplog.at_level(logging.INFO):
        ConsoleSmsProvider().send(PHONE, TEXT)

    assert f"SMS to {PHONE}: {TEXT}" in caplog.text


@override_settings(DEBUG=False)
def test_console_provider_hides_code_outside_debug(caplog) -> None:
    with caplog.at_level(logging.INFO):
        ConsoleSmsProvider().send(PHONE, TEXT)

    assert "1234" not in caplog.text
    assert PHONE not in caplog.text


# -- HttpSmsProvider ---------------------------------------------------------


@override_settings(SMS_API_URL="https://sms.example/send", SMS_API_TOKEN="secret")
def test_http_provider_posts_once_on_success() -> None:
    with patch("apps.users.sms.requests.post") as post:
        post.return_value.raise_for_status.return_value = None

        HttpSmsProvider().send(PHONE, TEXT)

    assert post.call_count == 1
    _, kwargs = post.call_args
    assert kwargs["json"] == {"phone": PHONE, "text": TEXT}
    assert kwargs["headers"] == {"Authorization": "Bearer secret"}
    assert kwargs["timeout"] == 10


@override_settings(SMS_API_URL="https://sms.example/send")
def test_http_provider_retries_twice_then_gives_up() -> None:
    with (
        patch("apps.users.sms.requests.post", side_effect=requests.ConnectionError("нет сети")),
        patch("apps.users.sms.time.sleep") as sleep,
        pytest.raises(SmsSendError),
    ):
        HttpSmsProvider().send(PHONE, TEXT)

    # Три попытки суммарно и экспоненциальная задержка между ними.
    assert sleep.call_args_list[0].args[0] == 1.0
    assert sleep.call_args_list[1].args[0] == 2.0
    assert sleep.call_count == 2


@override_settings(SMS_API_URL="https://sms.example/send")
def test_http_provider_succeeds_on_second_attempt() -> None:
    ok = patch("apps.users.sms.requests.post")
    with ok as post, patch("apps.users.sms.time.sleep"):
        post.side_effect = [requests.Timeout("таймаут"), post.return_value]

        HttpSmsProvider().send(PHONE, TEXT)

    assert post.call_count == 2


# -- задачи ------------------------------------------------------------------


@override_settings(SMS_PROVIDER="console")
def test_send_otp_sms_task_does_not_log_code(caplog) -> None:
    with caplog.at_level(logging.INFO):
        send_otp_sms(PHONE, "4321")

    assert "4321" not in caplog.text
    assert "+9967****3456" in caplog.text


@pytest.mark.django_db
def test_purge_old_otp_codes_removes_stale_rows() -> None:
    fresh = OtpCode.objects.create(
        phone=PHONE, code_hash="x", expires_at=timezone.now() + timedelta(minutes=5)
    )
    stale = OtpCode.objects.create(
        phone=PHONE, code_hash="x", expires_at=timezone.now() - timedelta(days=8)
    )
    OtpCode.objects.filter(pk=stale.pk).update(created_at=timezone.now() - timedelta(days=8))

    assert purge_old_otp_codes() == 1
    assert list(OtpCode.objects.values_list("pk", flat=True)) == [fresh.pk]
