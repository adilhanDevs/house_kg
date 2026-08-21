"""Тесты входа по SMS-коду и работы с JWT."""

import logging
from datetime import timedelta

import pytest
from django.test import override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from apps.users.models import OtpCode, User
from apps.users.services import issue_otp
from tests.factories import UserFactory

REQUEST_URL = "/api/v1/auth/otp/request/"
VERIFY_URL = "/api/v1/auth/otp/verify/"
REFRESH_URL = "/api/v1/auth/refresh/"
LOGOUT_URL = "/api/v1/auth/logout/"
ME_URL = "/api/v1/users/me/"

TEST_PHONE = "+996700123456"
DEBUG_CODE = "0000"
WRONG_CODE = "1111"

with_test_phone = override_settings(OTP_TEST_PHONES=[TEST_PHONE])


# -- запрос кода -------------------------------------------------------------


@pytest.mark.django_db
def test_otp_request_creates_code_and_never_returns_it(api_client: APIClient) -> None:
    response = api_client.post(REQUEST_URL, {"phone": "0700123456"})

    assert response.status_code == 200
    body = response.json()
    assert set(body) == {"expires_in", "resend_after", "is_new_user"}
    assert body == {"expires_in": 300, "resend_after": 60, "is_new_user": True}

    otp = OtpCode.objects.get()
    # Номер нормализован, в базе только хеш.
    assert otp.phone == TEST_PHONE
    assert otp.code_hash and otp.code_hash not in response.content.decode()


@pytest.mark.django_db
def test_otp_request_reports_existing_user(api_client: APIClient) -> None:
    UserFactory(phone=TEST_PHONE)

    body = api_client.post(REQUEST_URL, {"phone": TEST_PHONE}).json()

    assert body["is_new_user"] is False


@pytest.mark.django_db
def test_second_otp_request_in_a_row_is_throttled(api_client: APIClient) -> None:
    assert api_client.post(REQUEST_URL, {"phone": TEST_PHONE}).status_code == 200

    response = api_client.post(REQUEST_URL, {"phone": TEST_PHONE})

    assert response.status_code == 429
    error = response.json()["error"]
    assert error["code"] == "throttled"
    assert error["message"].startswith("Повторите через")
    assert 0 < error["details"]["retry_after"] <= 60
    assert OtpCode.objects.count() == 1


@pytest.mark.django_db
def test_invalid_phone_is_rejected(api_client: APIClient) -> None:
    response = api_client.post(REQUEST_URL, {"phone": "123"})

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "validation_error"
    assert "phone" in response.json()["error"]["details"]
    assert OtpCode.objects.count() == 0


@pytest.mark.django_db
def test_plain_code_is_not_logged(api_client: APIClient, caplog) -> None:
    with caplog.at_level(logging.DEBUG):
        api_client.post(REQUEST_URL, {"phone": TEST_PHONE})

    otp = OtpCode.objects.get()
    assert otp.code_hash not in caplog.text
    # Номер в логах — только замаскированный.
    assert TEST_PHONE not in caplog.text


# -- подтверждение кода ------------------------------------------------------


@pytest.mark.django_db
@with_test_phone
def test_debug_code_works_for_test_phone(api_client: APIClient) -> None:
    api_client.post(REQUEST_URL, {"phone": TEST_PHONE})

    response = api_client.post(VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE})

    assert response.status_code == 200
    assert response.json()["user"]["phone"] == TEST_PHONE


@pytest.mark.django_db
@override_settings(DEBUG=True)
def test_debug_mode_uses_static_code(api_client: APIClient) -> None:
    api_client.post(REQUEST_URL, {"phone": TEST_PHONE})

    assert api_client.post(VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE}).status_code == 200


@pytest.mark.django_db
@with_test_phone
def test_verify_creates_new_user(api_client: APIClient) -> None:
    issue_otp(TEST_PHONE)

    response = api_client.post(
        VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, "name": "Азамат"}
    )

    assert response.status_code == 200
    body = response.json()
    assert body["is_new_user"] is True
    assert body["access"] and body["refresh"]
    assert body["user"]["name"] == "Азамат"

    user = User.objects.get(phone=TEST_PHONE)
    assert user.is_active is True
    assert OtpCode.objects.get().is_used is True


@pytest.mark.django_db
@with_test_phone
def test_verify_existing_user_keeps_name(api_client: APIClient) -> None:
    UserFactory(phone=TEST_PHONE, name="Азамат Осмонов")
    issue_otp(TEST_PHONE)

    body = api_client.post(
        VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, "name": "Подменённое имя"}
    ).json()

    assert body["is_new_user"] is False
    assert body["user"]["name"] == "Азамат Осмонов"
    assert User.objects.get(phone=TEST_PHONE).name == "Азамат Осмонов"


@pytest.mark.django_db
@with_test_phone
def test_wrong_code_increments_attempts_and_burns_code(api_client: APIClient) -> None:
    issue_otp(TEST_PHONE)

    for attempt in range(1, 5):
        response = api_client.post(VERIFY_URL, {"phone": TEST_PHONE, "code": WRONG_CODE})

        assert response.status_code == 400
        error = response.json()["error"]
        assert error["code"] == "validation_error"
        assert error["message"] == "Неверный код"
        assert error["details"]["attempts_left"] == 5 - attempt
        assert OtpCode.objects.get().attempts == attempt

    # Пятая неудачная попытка сжигает код.
    response = api_client.post(VERIFY_URL, {"phone": TEST_PHONE, "code": WRONG_CODE})

    assert response.status_code == 400
    assert response.json()["error"]["message"] == "Код заблокирован, запросите новый."
    otp = OtpCode.objects.get()
    assert otp.attempts == 5
    assert otp.is_used is True

    # Правильный код после блокировки уже не поможет.
    late = api_client.post(VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE})
    assert late.status_code == 400
    assert late.json()["error"]["message"] == "Код не найден, запросите новый."
    assert User.objects.filter(phone=TEST_PHONE).count() == 0


@pytest.mark.django_db
@with_test_phone
def test_expired_code_is_rejected(api_client: APIClient) -> None:
    otp, _ = issue_otp(TEST_PHONE)
    OtpCode.objects.filter(pk=otp.pk).update(expires_at=timezone.now() - timedelta(seconds=1))

    response = api_client.post(VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE})

    assert response.status_code == 400
    assert response.json()["error"]["message"] == "Код истёк, запросите новый."
    assert User.objects.count() == 0


@pytest.mark.django_db
def test_verify_without_requested_code(api_client: APIClient) -> None:
    response = api_client.post(VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE})

    assert response.status_code == 400
    assert response.json()["error"]["message"] == "Код не найден, запросите новый."


# -- refresh / logout --------------------------------------------------------


@pytest.fixture
def tokens(api_client: APIClient) -> dict[str, str]:
    with override_settings(OTP_TEST_PHONES=[TEST_PHONE]):
        issue_otp(TEST_PHONE)
        body = api_client.post(VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE}).json()
    return {"access": body["access"], "refresh": body["refresh"]}


@pytest.mark.django_db
def test_refresh_returns_new_access(api_client: APIClient, tokens: dict[str, str]) -> None:
    response = api_client.post(REFRESH_URL, {"refresh": tokens["refresh"]})

    assert response.status_code == 200
    assert response.json()["access"]


@pytest.mark.django_db
def test_logout_blacklists_refresh_token(api_client: APIClient, tokens: dict[str, str]) -> None:
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")

    response = api_client.post(LOGOUT_URL, {"refresh": tokens["refresh"]})

    assert response.status_code == 204
    assert response.content == b""

    refreshed = api_client.post(REFRESH_URL, {"refresh": tokens["refresh"]})
    assert refreshed.status_code == 401


@pytest.mark.django_db
def test_logout_requires_authentication(api_client: APIClient, tokens: dict[str, str]) -> None:
    assert api_client.post(LOGOUT_URL, {"refresh": tokens["refresh"]}).status_code == 401


@pytest.mark.django_db
def test_access_token_opens_profile(api_client: APIClient, tokens: dict[str, str]) -> None:
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")

    assert api_client.get(ME_URL).status_code == 200
