"""Контракт WhatsApp OTP из интеграции Safa-app-backend."""

from unittest.mock import Mock, patch

import pytest
import requests
from django.core.exceptions import ImproperlyConfigured

from apps.users.sms import OtpDeliveryError, get_sms_provider
from apps.users.tasks import send_otp_sms


@pytest.fixture(autouse=True)
def chatflow_settings(settings):
    settings.SMS_PROVIDER = "chatflow"
    settings.CHATFLOW_BASE_URL = "https://app.chatflow.kz"
    settings.CHATFLOW_TOKEN = "test-token"
    settings.CHATFLOW_FLOW_ID = "flow-123"
    settings.CHATFLOW_INSTANCE_ID = ""
    settings.CHATFLOW_TIMEOUT_SECONDS = 8
    settings.OTP_SMS_TEMPLATE = "house_kgz: код {code}"


@patch("apps.users.sms.requests.get")
def test_otp_task_sends_whatsapp_code(mock_get):
    mock_get.return_value = Mock(status_code=200, json=Mock(return_value={"success": True}))
    send_otp_sms.run("+996700123456", "0123")
    mock_get.assert_called_once_with(
        "https://app.chatflow.kz/api/v1/n8n/action/text",
        params={"flow_id": "flow-123", "recipient": "996700123456", "msg": "house_kgz: код 0123"},
        headers={"Authorization": "Bearer test-token", "Accept": "application/json"},
        timeout=8,
        allow_redirects=False,
    )


@patch("apps.users.sms.requests.get")
def test_legacy_account(mock_get, settings):
    settings.CHATFLOW_BASE_URL = "https://lk.chatflow.kz/"
    settings.CHATFLOW_FLOW_ID = ""
    settings.CHATFLOW_INSTANCE_ID = "instance-123"
    mock_get.return_value = Mock(status_code=200, json=Mock(return_value=True))
    get_sms_provider().send_code("+996700123456", "0123")
    assert mock_get.call_args.args == ("https://lk.chatflow.kz/api/v1/send-text",)
    assert mock_get.call_args.kwargs["params"] == {
        "token": "test-token",
        "instance_id": "instance-123",
        "jid": "996700123456@c.us",
        "msg": "house_kgz: код 0123",
    }


@pytest.mark.parametrize("name", ["CHATFLOW_TOKEN", "CHATFLOW_FLOW_ID"])
def test_missing_credentials(name, settings):
    setattr(settings, name, "")
    with pytest.raises(ImproperlyConfigured):
        get_sms_provider()


@pytest.mark.parametrize(
    "status,data",
    [
        (401, {"success": True}),
        (429, {}),
        (503, {}),
        (302, {}),
        (200, {"success": False, "message": "secret 0123 test-token"}),
        (200, False),
        (200, []),
        (200, None),
    ],
)
@patch("apps.users.sms.requests.get")
def test_rejected_response_is_safe(mock_get, status, data):
    mock_get.return_value = Mock(status_code=status, json=Mock(return_value=data))
    with pytest.raises(OtpDeliveryError) as error:
        get_sms_provider().send_code("+996700123456", "0123")
    assert "0123" not in str(error.value)
    assert "test-token" not in str(error.value)


@pytest.mark.parametrize("failure", [requests.Timeout("secret 0123"), ValueError("0123")])
@patch("apps.users.sms.requests.get")
def test_transport_and_json_errors_are_safe(mock_get, failure):
    if isinstance(failure, requests.RequestException):
        mock_get.side_effect = failure
    else:
        mock_get.return_value = Mock(status_code=200, json=Mock(side_effect=failure))
    with pytest.raises(OtpDeliveryError) as error:
        get_sms_provider().send_code("+996700123456", "0123")
    assert "0123" not in str(error.value)
    assert error.value.__suppress_context__


@patch("apps.users.sms.requests.get")
def test_invalid_phone_does_not_send(mock_get):
    with pytest.raises(OtpDeliveryError):
        get_sms_provider().send_code("bad-phone", "0123")
    mock_get.assert_not_called()
