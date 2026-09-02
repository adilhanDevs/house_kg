"""Тесты интеграции с Telegram Gateway API и провайдера TelegramGatewayProvider."""

import io
import logging
from unittest.mock import MagicMock, patch

import pytest
import requests
from django.core.exceptions import ImproperlyConfigured
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import override_settings

from apps.users.models import OtpCode
from apps.users.sms import (
    ConsoleSmsProvider,
    HttpSmsProvider,
    OtpDeliveryError,
    TelegramGatewayProvider,
    TelegramSendResult,
    get_sms_provider,
)
from apps.users.tasks import report_telegram_verification_status, send_otp_sms

TEST_PHONE = "+996700123456"
TEST_CODE = "1234"
TEST_TOKEN = "test-tg-gateway-token-xyz"
GATEWAY_BASE_URL = "https://gatewayapi.telegram.org"


@pytest.fixture
def tg_provider():
    return TelegramGatewayProvider(
        token=TEST_TOKEN,
        base_url=GATEWAY_BASE_URL,
        ttl=300,
        timeout=5,
    )


# ---------------------------------------------------------------------------
# 1. Фабрика и конфигурация
# ---------------------------------------------------------------------------


def test_factory_selects_telegram_provider() -> None:
    with override_settings(SMS_PROVIDER="telegram", TELEGRAM_GATEWAY_TOKEN=TEST_TOKEN):
        provider = get_sms_provider()
        assert isinstance(provider, TelegramGatewayProvider)
        assert provider.token == TEST_TOKEN


def test_factory_selects_telegram_via_otp_provider_alias() -> None:
    with override_settings(
        SMS_PROVIDER="", OTP_PROVIDER="telegram", TELEGRAM_GATEWAY_TOKEN=TEST_TOKEN
    ):
        provider = get_sms_provider()
        assert isinstance(provider, TelegramGatewayProvider)


def test_factory_still_selects_console_and_http() -> None:
    with override_settings(SMS_PROVIDER="console"):
        assert isinstance(get_sms_provider(), ConsoleSmsProvider)
    with override_settings(SMS_PROVIDER="http", SMS_API_URL="https://sms.example/send"):
        assert isinstance(get_sms_provider(), HttpSmsProvider)


def test_provider_raises_when_token_missing() -> None:
    with (
        override_settings(TELEGRAM_GATEWAY_TOKEN=""),
        pytest.raises(ImproperlyConfigured) as exc_info,
    ):
        TelegramGatewayProvider(token="")
    assert "TELEGRAM_GATEWAY_TOKEN не задан" in str(exc_info.value)


# ---------------------------------------------------------------------------
# 2. Успешная отправка, URL, Headers, Payload
# ---------------------------------------------------------------------------


def test_send_verification_message_success(tg_provider) -> None:
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "ok": True,
        "result": {
            "request_id": "req-123456",
            "phone_number": TEST_PHONE,
            "request_cost": 0.015,
            "delivery_status": {"status": "sent"},
            "remaining_balance": 99.5,
        },
    }

    with patch("apps.users.sms.requests.post", return_value=mock_response) as mock_post:
        result = tg_provider.send_verification_message(TEST_PHONE, TEST_CODE, ttl=300)

        assert isinstance(result, TelegramSendResult)
        assert result.request_id == "req-123456"
        assert result.phone_number == TEST_PHONE
        assert result.request_cost == 0.015
        assert result.delivery_status == "sent"
        assert result.remaining_balance == 99.5

        # Проверка URL
        assert mock_post.call_count == 1
        call_url, call_kwargs = mock_post.call_args
        assert call_url[0] == "https://gatewayapi.telegram.org/sendVerificationMessage"

        # Проверка заголовков
        headers = call_kwargs["headers"]
        assert headers["Authorization"] == f"Bearer {TEST_TOKEN}"
        assert headers["Content-Type"] == "application/json"

        # Проверка payload
        payload = call_kwargs["json"]
        assert payload == {
            "phone_number": TEST_PHONE,
            "code": TEST_CODE,
            "ttl": 300,
        }
        assert call_kwargs["timeout"] == 5


def test_send_code_and_send_methods(tg_provider) -> None:
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "ok": True,
        "result": {
            "request_id": "req-send-code",
            "phone_number": TEST_PHONE,
            "delivery_status": "sent",
        },
    }

    with patch("apps.users.sms.requests.post", return_value=mock_response):
        # Метод send_code
        res1 = tg_provider.send_code(TEST_PHONE, "5678")
        assert res1.request_id == "req-send-code"

        # Метод send с явным code
        res2 = tg_provider.send(TEST_PHONE, "some text", code="5678")
        assert res2.request_id == "req-send-code"

        # Метод send с извлечением кода из текста
        res3 = tg_provider.send(TEST_PHONE, "Ваш код подтверждения 9876")
        assert res3.request_id == "req-send-code"


def test_send_fails_when_no_code_in_text(tg_provider) -> None:
    with pytest.raises(OtpDeliveryError) as exc_info:
        tg_provider.send(TEST_PHONE, "текст без цифр")
    assert "требуется передача числового OTP-кода" in str(exc_info.value)


# ---------------------------------------------------------------------------
# 3. Валидация телефона и кода
# ---------------------------------------------------------------------------


def test_invalid_phone_raises_delivery_error(tg_provider) -> None:
    with pytest.raises(OtpDeliveryError) as exc_info:
        tg_provider.send_verification_message("invalid-phone", TEST_CODE)
    assert "Некорректный номер телефона" in str(exc_info.value)


def test_local_phone_format_is_normalized_to_e164(tg_provider) -> None:
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {"ok": True, "result": {"request_id": "req-norm"}}

    with patch("apps.users.sms.requests.post", return_value=mock_response) as mock_post:
        tg_provider.send_verification_message("0700123456", TEST_CODE)
        call_url, call_kwargs = mock_post.call_args
        assert call_kwargs["json"]["phone_number"] == "+996700123456"


def test_invalid_code_length_raises_error(tg_provider) -> None:
    with pytest.raises(OtpDeliveryError) as exc_info:
        tg_provider.send_verification_message(TEST_PHONE, "12")  # less than 4
    assert "4-8 цифр" in str(exc_info.value)

    with pytest.raises(OtpDeliveryError) as exc_info:
        tg_provider.send_verification_message(TEST_PHONE, "123456789")  # more than 8
    assert "4-8 цифр" in str(exc_info.value)


def test_invalid_ttl_raises_error(tg_provider) -> None:
    with pytest.raises(OtpDeliveryError) as exc_info:
        tg_provider.send_verification_message(TEST_PHONE, TEST_CODE, ttl=10)
    assert "Недопустимый TTL" in str(exc_info.value)


# ---------------------------------------------------------------------------
# 4. Обработка ошибок Telegram API и HTTP
# ---------------------------------------------------------------------------


def test_telegram_ok_false_response(tg_provider) -> None:
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "ok": False,
        "error": "PHONE_NUMBER_INVALID",
    }

    with patch("apps.users.sms.requests.post", return_value=mock_response):
        with pytest.raises(OtpDeliveryError) as exc_info:
            tg_provider.send_verification_message(TEST_PHONE, TEST_CODE)
        assert "PHONE_NUMBER_INVALID" in str(exc_info.value)


def test_http_401_unauthorized(tg_provider) -> None:
    mock_response = MagicMock()
    mock_response.status_code = 401
    mock_response.json.return_value = {"ok": False, "error": "UNAUTHORIZED"}

    with patch("apps.users.sms.requests.post", return_value=mock_response):
        with pytest.raises(OtpDeliveryError) as exc_info:
            tg_provider.send_verification_message(TEST_PHONE, TEST_CODE)
        assert "авторизации" in str(exc_info.value)


def test_http_429_rate_limit(tg_provider) -> None:
    mock_response = MagicMock()
    mock_response.status_code = 429
    mock_response.json.return_value = {"ok": False, "error": "FLOOD_WAIT_300"}

    with patch("apps.users.sms.requests.post", return_value=mock_response):
        with pytest.raises(OtpDeliveryError) as exc_info:
            tg_provider.send_verification_message(TEST_PHONE, TEST_CODE)
        assert "лимит" in str(exc_info.value)


def test_http_500_server_error(tg_provider) -> None:
    mock_response = MagicMock()
    mock_response.status_code = 500
    mock_response.json.return_value = {"ok": False, "error": "INTERNAL_SERVER_ERROR"}

    with patch("apps.users.sms.requests.post", return_value=mock_response):
        with pytest.raises(OtpDeliveryError) as exc_info:
            tg_provider.send_verification_message(TEST_PHONE, TEST_CODE)
        assert "временно недоступен" in str(exc_info.value)


def test_network_timeout(tg_provider) -> None:
    with patch(
        "apps.users.sms.requests.post", side_effect=requests.Timeout("Connection timed out")
    ):
        with pytest.raises(OtpDeliveryError) as exc_info:
            tg_provider.send_verification_message(TEST_PHONE, TEST_CODE)
        assert "таймаут" in str(exc_info.value)


def test_network_connection_error(tg_provider) -> None:
    with patch(
        "apps.users.sms.requests.post",
        side_effect=requests.ConnectionError("Failed to establish a connection"),
    ):
        with pytest.raises(OtpDeliveryError) as exc_info:
            tg_provider.send_verification_message(TEST_PHONE, TEST_CODE)
        assert "соединения" in str(exc_info.value)


def test_invalid_json_response(tg_provider) -> None:
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.side_effect = ValueError("Invalid JSON")

    with patch("apps.users.sms.requests.post", return_value=mock_response):
        with pytest.raises(OtpDeliveryError) as exc_info:
            tg_provider.send_verification_message(TEST_PHONE, TEST_CODE)
        assert "Некорректный ответ" in str(exc_info.value)


# ---------------------------------------------------------------------------
# 5. Безопасность и логирование
# ---------------------------------------------------------------------------


def test_no_token_leakage_in_logs_or_exceptions(tg_provider, caplog) -> None:
    secret_token = "SUPER_SECRET_TOKEN_DO_NOT_LEAK"
    provider = TelegramGatewayProvider(token=secret_token)

    mock_response = MagicMock()
    mock_response.status_code = 401
    mock_response.json.return_value = {"ok": False, "error": "UNAUTHORIZED"}

    with patch("apps.users.sms.requests.post", return_value=mock_response):
        with caplog.at_level(logging.DEBUG):
            with pytest.raises(OtpDeliveryError) as exc_info:
                provider.send_verification_message(TEST_PHONE, TEST_CODE)

    assert secret_token not in str(exc_info.value)
    assert secret_token not in caplog.text
    # Номер телефона замаскирован в логах
    assert "+9967****3456" in caplog.text or "***" in caplog.text
    assert TEST_PHONE not in caplog.text


# ---------------------------------------------------------------------------
# 6. checkVerificationStatus и checkSendAbility
# ---------------------------------------------------------------------------


def test_check_verification_status_success(tg_provider) -> None:
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "ok": True,
        "result": {
            "request_id": "req-123456",
            "verification_status": {"status": "code_valid"},
        },
    }

    with patch("apps.users.sms.requests.post", return_value=mock_response) as mock_post:
        res = tg_provider.check_verification_status("req-123456", "1234")
        assert res.get("ok") is True
        call_url, call_kwargs = mock_post.call_args
        assert call_url[0] == "https://gatewayapi.telegram.org/checkVerificationStatus"
        assert call_kwargs["json"] == {"request_id": "req-123456", "code": "1234"}


def test_check_verification_status_gracefully_handles_errors(tg_provider) -> None:
    with patch("apps.users.sms.requests.post", side_effect=requests.RequestException("error")):
        res = tg_provider.check_verification_status("req-123456", "1234")
        assert res.get("ok") is False


def test_check_send_ability(tg_provider) -> None:
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "ok": True,
        "result": {"phone_number": TEST_PHONE, "can_send": True},
    }

    with patch("apps.users.sms.requests.post", return_value=mock_response) as mock_post:
        res = tg_provider.check_send_ability(TEST_PHONE)
        assert res.get("ok") is True
        call_url, call_kwargs = mock_post.call_args
        assert call_url[0] == "https://gatewayapi.telegram.org/checkSendAbility"
        assert call_kwargs["json"] == {"phone_number": TEST_PHONE}


# ---------------------------------------------------------------------------
# 7. Задачи Celery и сохранение request_id
# ---------------------------------------------------------------------------


@pytest.mark.django_db
def test_send_otp_sms_saves_request_id_in_otp_code() -> None:
    otp = OtpCode.objects.create(
        phone=TEST_PHONE,
        code_hash="fake_hash",
        expires_at="2030-01-01T00:00:00Z",
    )

    fake_result = TelegramSendResult(
        request_id="tg-request-id-999",
        phone_number=TEST_PHONE,
        delivery_status="sent",
    )

    with (
        override_settings(SMS_PROVIDER="telegram", TELEGRAM_GATEWAY_TOKEN=TEST_TOKEN),
        patch.object(TelegramGatewayProvider, "send_code", return_value=fake_result),
    ):
        send_otp_sms(TEST_PHONE, "1234", otp_id=otp.pk)

    otp.refresh_from_db()
    assert otp.request_id == "tg-request-id-999"


@pytest.mark.django_db
def test_report_telegram_verification_status_task() -> None:
    with (
        override_settings(TELEGRAM_GATEWAY_TOKEN=TEST_TOKEN),
        patch.object(TelegramGatewayProvider, "check_verification_status") as mock_check,
    ):
        report_telegram_verification_status("tg-req-777", "1234")
        assert mock_check.call_count == 1
        mock_check.assert_called_once_with("tg-req-777", "1234")


# ---------------------------------------------------------------------------
# 8. Management command test_telegram_gateway
# ---------------------------------------------------------------------------


def test_test_telegram_gateway_command_success() -> None:
    fake_result = TelegramSendResult(
        request_id="cli-req-123",
        phone_number=TEST_PHONE,
        request_cost=0.01,
        delivery_status="sent",
        remaining_balance=50.0,
    )

    out = io.StringIO()
    with (
        override_settings(TELEGRAM_GATEWAY_TOKEN=TEST_TOKEN),
        patch.object(
            TelegramGatewayProvider, "send_verification_message", return_value=fake_result
        ),
    ):
        call_command("test_telegram_gateway", TEST_PHONE, "--code=123456", stdout=out)

    output = out.getvalue()
    assert "cli-req-123" in output
    assert "sent" in output
    assert "0.01" in output
    assert "50.0" in output
    assert TEST_TOKEN not in output


def test_test_telegram_gateway_command_invalid_phone() -> None:
    out = io.StringIO()
    with pytest.raises(CommandError) as exc_info:
        call_command("test_telegram_gateway", "invalid-phone", stdout=out)
    assert "Некорректный номер телефона" in str(exc_info.value)


# ---------------------------------------------------------------------------
# 9. Full Registration Flow with Telegram Gateway
# ---------------------------------------------------------------------------


@pytest.mark.django_db
def test_full_registration_flow_with_telegram_gateway(
    api_client, django_capture_on_commit_callbacks
) -> None:
    reg_phone = "+996700999888"
    fake_tg_result = TelegramSendResult(
        request_id="flow-req-id-888",
        phone_number=reg_phone,
        delivery_status="sent",
    )

    with (
        override_settings(
            DEBUG=False,
            OTP_TEST_PHONES=[],
            SMS_PROVIDER="telegram",
            TELEGRAM_GATEWAY_TOKEN=TEST_TOKEN,
            CELERY_TASK_ALWAYS_EAGER=True,
        ),
        patch.object(
            TelegramGatewayProvider, "send_verification_message", return_value=fake_tg_result
        ) as mock_send,
        patch.object(TelegramGatewayProvider, "check_verification_status") as mock_check,
    ):
        # 1. Запрос OTP
        with django_capture_on_commit_callbacks(execute=True):
            req_resp = api_client.post(
                "/api/v1/auth/otp/request/",
                {"phone": reg_phone, "purpose": "login"},
            )
        assert req_resp.status_code == 200
        assert mock_send.call_count == 1

        otp = OtpCode.objects.filter(phone=reg_phone).order_by("-created_at").first()
        assert otp is not None
        assert otp.request_id == "flow-req-id-888"

        # Для верификации подменяем хэш на известный код
        from django.contrib.auth.hashers import make_password

        otp.code_hash = make_password("7777")
        otp.save(update_fields=["code_hash"])

        # 2. Подтверждение OTP
        with django_capture_on_commit_callbacks(execute=True):
            verify_resp = api_client.post(
                "/api/v1/auth/otp/verify/",
                {
                    "phone": reg_phone,
                    "code": "7777",
                    "name": "Тестовый Пользователь",
                    "purpose": "login",
                    "accepted_terms_version": "1",
                },
            )
        assert verify_resp.status_code == 200
        data = verify_resp.json()
        assert "access" in data
        assert "refresh" in data
        assert data["user"]["phone"] == reg_phone
        assert data["user"]["name"] == "Тестовый Пользователь"

        # 3. Проверка вызова checkVerificationStatus
        assert mock_check.call_count == 1
        mock_check.assert_called_with("flow-req-id-888", "7777")


@pytest.mark.django_db
def test_verification_succeeds_without_request_id_race_condition(
    api_client, django_capture_on_commit_callbacks
) -> None:
    """Проверка race condition: если пользователь ввёл правильный код до того, как

    Celery сохранил request_id, авторизация всё равно должна завершиться успешно (200 OK),
    а отсутствие request_id не должно приводить к ошибкам.
    """
    from django.contrib.auth.hashers import make_password

    phone = "+996700111222"
    otp = OtpCode.objects.create(
        phone=phone,
        code_hash=make_password("5555"),
        purpose="login",
        request_id="",  # request_id ещё не пришёл / не сохранён
        expires_at="2030-01-01T00:00:00Z",
    )

    with (
        override_settings(
            DEBUG=False,
            OTP_TEST_PHONES=[],
            SMS_PROVIDER="telegram",
            TELEGRAM_GATEWAY_TOKEN=TEST_TOKEN,
        ),
        patch.object(TelegramGatewayProvider, "check_verification_status") as mock_check,
    ):
        with django_capture_on_commit_callbacks(execute=True):
            resp = api_client.post(
                "/api/v1/auth/otp/verify/",
                {
                    "phone": phone,
                    "code": "5555",
                    "name": "Пользователь До Шлюза",
                    "purpose": "login",
                    "accepted_terms_version": "1",
                },
            )

        assert resp.status_code == 200
        data = resp.json()
        assert "access" in data
        assert data["user"]["phone"] == phone
        # checkVerificationStatus не вызывается, если request_id пуст, и это не ломает вход
        assert mock_check.call_count == 0

        otp.refresh_from_db()
        assert otp.is_used is True
