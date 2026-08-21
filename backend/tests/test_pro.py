"""Тесты регистрации исполнителя (pro) и входа по паролю."""

import pytest
from django.test import override_settings
from rest_framework.test import APIClient

from apps.billing.models import Wallet
from apps.billing.services import apply_transaction, get_wallet
from apps.users.models import OtpCode, OtpPurpose, User
from apps.users.validators import validate_iin
from tests.factories import UserFactory

REGISTER_URL = "/api/v1/auth/pro/register/"
VERIFY_URL = "/api/v1/auth/otp/verify/"
LOGIN_URL = "/api/v1/auth/password/login/"

PHONE = "+996700123456"
OTHER_PHONE = "+996700654321"
IIN = "12345678901234"
OTHER_IIN = "43210987654321"
PASSWORD = "Bishkek2026!"
DEBUG_CODE = "0000"

with_test_phones = override_settings(OTP_TEST_PHONES=[PHONE, OTHER_PHONE])


def payload(**overrides: object) -> dict[str, object]:
    data: dict[str, object] = {
        "phone": PHONE,
        "name": "Азамат",
        "password": PASSWORD,
        "iin": IIN,
        "whatsapp": PHONE,
    }
    data.update(overrides)
    return data


# -- валидатор ИИН -----------------------------------------------------------


def test_validate_iin_accepts_14_digits() -> None:
    assert validate_iin(IIN) == IIN


@pytest.mark.parametrize("value", ["1234567890123", "123456789012345", "1234567890123a", ""])
def test_validate_iin_rejects_wrong_format(value: str) -> None:
    from django.core.exceptions import ValidationError

    with pytest.raises(ValidationError):
        validate_iin(value)


# -- регистрация -------------------------------------------------------------


@pytest.mark.django_db
def test_pro_register_creates_user_without_pro_flag(api_client: APIClient) -> None:
    response = api_client.post(REGISTER_URL, payload())

    assert response.status_code == 200
    assert response.json() == {"expires_in": 300, "resend_after": 60}

    user = User.objects.get(phone=PHONE)
    assert user.is_active is True
    assert user.is_pro is False  # до подтверждения кода
    assert user.name == "Азамат"
    assert user.iin == IIN
    assert user.whatsapp_phone == PHONE
    assert user.check_password(PASSWORD) is True

    otp = OtpCode.objects.get()
    assert otp.purpose == OtpPurpose.PRO_REGISTER
    # Кошелёк заводится вместе с аккаунтом, но пустой.
    assert Wallet.objects.get(user=user).balance == 0


@pytest.mark.django_db
@with_test_phones
def test_verify_pro_register_enables_pro_and_creates_wallet(api_client: APIClient) -> None:
    api_client.post(REGISTER_URL, payload())

    response = api_client.post(
        VERIFY_URL,
        {"phone": PHONE, "code": DEBUG_CODE, "purpose": OtpPurpose.PRO_REGISTER},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["user"]["is_pro"] is True
    assert body["access"] and body["refresh"]

    user = User.objects.get(phone=PHONE)
    assert user.is_pro is True
    wallet = Wallet.objects.get(user=user)
    assert wallet.balance == 0


@pytest.mark.django_db
@with_test_phones
def test_verify_pro_register_is_idempotent_for_wallet(api_client: APIClient) -> None:
    user = UserFactory(phone=PHONE, is_pro=True)
    apply_transaction(wallet=get_wallet(user), amount=16_700, kind="topup", label="Пополнение")
    api_client.post(REGISTER_URL, payload())

    api_client.post(
        VERIFY_URL,
        {"phone": PHONE, "code": DEBUG_CODE, "purpose": OtpPurpose.PRO_REGISTER},
    )

    assert Wallet.objects.count() == 1
    assert Wallet.objects.get(user=user).balance == 16_700


@pytest.mark.django_db
def test_pro_register_fills_existing_client_account(api_client: APIClient) -> None:
    client_user = UserFactory(phone=PHONE, name="Азамат Осмонов")

    response = api_client.post(REGISTER_URL, payload(name="Азамат Осмонов"))

    assert response.status_code == 200
    assert User.objects.count() == 1

    client_user.refresh_from_db()
    assert client_user.pk == User.objects.get().pk
    assert client_user.iin == IIN
    assert client_user.is_pro is False
    assert client_user.check_password(PASSWORD) is True


@pytest.mark.django_db
def test_pro_register_rejects_short_iin(api_client: APIClient) -> None:
    response = api_client.post(REGISTER_URL, payload(iin="1234567890123"))

    assert response.status_code == 400
    error = response.json()["error"]
    assert error["code"] == "validation_error"
    assert "iin" in error["details"]
    assert User.objects.count() == 0


@pytest.mark.django_db
def test_pro_register_rejects_iin_of_another_user(api_client: APIClient) -> None:
    UserFactory(phone=OTHER_PHONE, is_pro=True, iin=IIN)

    response = api_client.post(REGISTER_URL, payload())

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "conflict"
    assert User.objects.count() == 1


@pytest.mark.django_db
def test_pro_register_rejects_second_iin_for_same_phone(api_client: APIClient) -> None:
    UserFactory(phone=PHONE, iin=OTHER_IIN)

    response = api_client.post(REGISTER_URL, payload())

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "conflict"
    assert User.objects.get(phone=PHONE).iin == OTHER_IIN


@pytest.mark.django_db
def test_pro_register_rejects_weak_password(api_client: APIClient) -> None:
    response = api_client.post(REGISTER_URL, payload(password="1234567"))

    assert response.status_code == 400
    assert "password" in response.json()["error"]["details"]
    assert User.objects.count() == 0


@pytest.mark.django_db
def test_pro_register_rejects_invalid_phone(api_client: APIClient) -> None:
    response = api_client.post(REGISTER_URL, payload(phone="123"))

    assert response.status_code == 400
    assert "phone" in response.json()["error"]["details"]


# -- вход по паролю ----------------------------------------------------------


@pytest.mark.django_db
def test_password_login_returns_tokens_for_pro(api_client: APIClient) -> None:
    user = UserFactory(phone=PHONE, is_pro=True, iin=IIN, password=PASSWORD)

    response = api_client.post(LOGIN_URL, {"phone": PHONE, "password": PASSWORD})

    assert response.status_code == 200
    body = response.json()
    assert body["access"] and body["refresh"]
    assert body["user"]["id"] == user.pk
    assert body["is_new_user"] is False


@pytest.mark.django_db
def test_password_login_rejects_non_pro(api_client: APIClient) -> None:
    UserFactory(phone=PHONE, is_pro=False, password=PASSWORD)

    response = api_client.post(LOGIN_URL, {"phone": PHONE, "password": PASSWORD})

    assert response.status_code == 401
    error = response.json()["error"]
    assert error["code"] == "authentication_failed"
    assert error["message"] == "Неверный номер телефона или пароль."


@pytest.mark.django_db
def test_password_login_hides_whether_phone_exists(api_client: APIClient) -> None:
    UserFactory(phone=PHONE, is_pro=True, password=PASSWORD)

    wrong_password = api_client.post(LOGIN_URL, {"phone": PHONE, "password": "другой пароль"})
    unknown_phone = api_client.post(LOGIN_URL, {"phone": OTHER_PHONE, "password": PASSWORD})

    assert wrong_password.status_code == unknown_phone.status_code == 401
    assert wrong_password.json() == unknown_phone.json()


@pytest.mark.django_db
def test_password_login_brute_force_is_throttled(api_client: APIClient) -> None:
    UserFactory(phone=PHONE, is_pro=True, password=PASSWORD)

    for _ in range(10):
        attempt = api_client.post(LOGIN_URL, {"phone": PHONE, "password": "неверный"})
        assert attempt.status_code == 401

    response = api_client.post(LOGIN_URL, {"phone": PHONE, "password": "неверный"})

    assert response.status_code == 429
    assert response.json()["error"]["details"]["retry_after"] > 0

    # Даже с верным паролем — сначала подождать.
    assert api_client.post(LOGIN_URL, {"phone": PHONE, "password": PASSWORD}).status_code == 429
