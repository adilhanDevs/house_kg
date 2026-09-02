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

# Согласие на обработку ПДн обязательно при регистрации.
CONSENT = {"accepted_terms_version": "1"}
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

    response = api_client.post(VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, **CONSENT})

    assert response.status_code == 200
    assert response.json()["user"]["phone"] == TEST_PHONE


@pytest.mark.django_db
@override_settings(DEBUG=True)
def test_debug_mode_uses_static_code(api_client: APIClient) -> None:
    api_client.post(REQUEST_URL, {"phone": TEST_PHONE})

    response = api_client.post(VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, **CONSENT})
    assert response.status_code == 200


@pytest.mark.django_db
@with_test_phone
def test_verify_creates_new_user(api_client: APIClient) -> None:
    issue_otp(TEST_PHONE)

    response = api_client.post(
        VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, "name": "Азамат", **CONSENT}
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
        VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, "name": "Подменённое имя", **CONSENT}
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
    late = api_client.post(VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, **CONSENT})
    assert late.status_code == 400
    assert late.json()["error"]["message"] == "Код не найден, запросите новый."
    assert User.objects.filter(phone=TEST_PHONE).count() == 0


@pytest.mark.django_db
@with_test_phone
def test_expired_code_is_rejected(api_client: APIClient) -> None:
    otp, _ = issue_otp(TEST_PHONE)
    OtpCode.objects.filter(pk=otp.pk).update(expires_at=timezone.now() - timedelta(seconds=1))

    response = api_client.post(VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, **CONSENT})

    assert response.status_code == 400
    assert response.json()["error"]["message"] == "Код истёк, запросите новый."
    assert User.objects.count() == 0


@pytest.mark.django_db
def test_verify_without_requested_code(api_client: APIClient) -> None:
    response = api_client.post(VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, **CONSENT})

    assert response.status_code == 400
    assert response.json()["error"]["message"] == "Код не найден, запросите новый."


# -- refresh / logout --------------------------------------------------------


@pytest.fixture
def tokens(api_client: APIClient) -> dict[str, str]:
    with override_settings(OTP_TEST_PHONES=[TEST_PHONE]):
        issue_otp(TEST_PHONE)
        body = api_client.post(
            VERIFY_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, **CONSENT}
        ).json()
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


# -- регистрация с паролем ---------------------------------------------------
#
# Порядок такой: телефон, имя и пароль собираются на экране регистрации,
# уходят вместе с кодом в /auth/otp/verify/, и дальше человек входит уже
# только по паролю. Пароль задаётся после подтверждения кода — до него мы
# не знаем, владеет ли человек номером.

PASSWORD_LOGIN_URL = "/api/v1/auth/password/login/"
GOOD_PASSWORD = "Дом-Бишкек-2026"


@pytest.mark.django_db
@with_test_phone
def test_registration_sets_password_and_allows_password_login(api_client: APIClient) -> None:
    issue_otp(TEST_PHONE)

    registered = api_client.post(
        VERIFY_URL,
        {
            "phone": TEST_PHONE,
            "code": DEBUG_CODE,
            "name": "Азамат",
            "password": GOOD_PASSWORD,
            **CONSENT,
        },
    )

    assert registered.status_code == 200, registered.json()
    assert registered.json()["is_new_user"] is True

    logged_in = api_client.post(
        PASSWORD_LOGIN_URL, {"phone": TEST_PHONE, "password": GOOD_PASSWORD}
    )

    assert logged_in.status_code == 200
    assert logged_in.json()["access"]
    assert logged_in.json()["user"]["name"] == "Азамат"


@pytest.mark.django_db
@with_test_phone
def test_code_does_not_overwrite_password_of_existing_account(api_client: APIClient) -> None:
    """Код подтверждает владение номером, но не даёт сменить пароль."""
    user = UserFactory(phone=TEST_PHONE)
    user.set_password(GOOD_PASSWORD)
    user.save(update_fields=["password"])

    issue_otp(TEST_PHONE)
    response = api_client.post(
        VERIFY_URL,
        {"phone": TEST_PHONE, "code": DEBUG_CODE, "password": "Чужой-Пароль-77", **CONSENT},
    )

    assert response.status_code == 200
    user.refresh_from_db()
    assert user.check_password(GOOD_PASSWORD)


@pytest.mark.django_db
@with_test_phone
def test_weak_password_is_rejected_at_registration(api_client: APIClient) -> None:
    issue_otp(TEST_PHONE)

    response = api_client.post(
        VERIFY_URL,
        {"phone": TEST_PHONE, "code": DEBUG_CODE, "password": "12345678", **CONSENT},
    )

    assert response.status_code == 400
    assert "password" in response.json()["error"]["details"]
    assert User.objects.filter(phone=TEST_PHONE).count() == 0


@pytest.mark.django_db
def test_static_code_does_not_work_for_an_ordinary_number(api_client: APIClient) -> None:
    """0000 подходил к любому номеру — это был вход в любой аккаунт.

    Номера нет в OTP_TEST_PHONES, значит код случайный, и подобрать его
    четырьмя нулями нельзя.
    """
    stranger = "+996700999888"
    api_client.post(REQUEST_URL, {"phone": stranger})

    response = api_client.post(VERIFY_URL, {"phone": stranger, "code": DEBUG_CODE, **CONSENT})

    assert response.status_code == 400
    assert User.objects.filter(phone=stranger).count() == 0


@pytest.mark.django_db
def test_account_without_password_cannot_log_in_with_one(api_client: APIClient) -> None:
    """Аккаунты, заведённые до пароля, входят не так — и не пускают чужого.

    Такие пользователи есть: до этих правок аккаунт создавался подтверждением
    кода и пароля не имел вовсе, а фабрика в тестах пароль ставит всегда.
    """
    user = User.objects.create_user(phone=TEST_PHONE, name="Без пароля")
    assert not user.has_usable_password()

    response = api_client.post(PASSWORD_LOGIN_URL, {"phone": TEST_PHONE, "password": GOOD_PASSWORD})

    assert response.status_code == 401


# -- восстановление пароля ---------------------------------------------------
#
# Вход парольный, поэтому забытый пароль означает потерю аккаунта. Код из SMS
# подтверждает владение номером и разрешает задать новый.

RESET_URL = "/api/v1/auth/password/reset/"
NEW_PASSWORD = "Новый-Пароль-2026"


@pytest.mark.django_db
@with_test_phone
def test_password_reset_sets_a_new_password_and_logs_in(api_client: APIClient) -> None:
    user = UserFactory(phone=TEST_PHONE)
    user.set_password(GOOD_PASSWORD)
    user.save(update_fields=["password"])

    issue_otp(TEST_PHONE, "password_reset")
    response = api_client.post(
        RESET_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, "password": NEW_PASSWORD}
    )

    assert response.status_code == 200, response.json()
    assert response.json()["access"]

    user.refresh_from_db()
    assert user.check_password(NEW_PASSWORD)

    logged_in = api_client.post(PASSWORD_LOGIN_URL, {"phone": TEST_PHONE, "password": NEW_PASSWORD})
    assert logged_in.status_code == 200


@pytest.mark.django_db
@with_test_phone
def test_password_reset_code_is_single_use(api_client: APIClient) -> None:
    user = UserFactory(phone=TEST_PHONE)
    issue_otp(TEST_PHONE, "password_reset")

    first = api_client.post(
        RESET_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, "password": NEW_PASSWORD}
    )
    second = api_client.post(
        RESET_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, "password": "Ещё-Один-Пароль-9"}
    )

    assert first.status_code == 200
    assert second.status_code == 400

    user.refresh_from_db()
    assert user.check_password(NEW_PASSWORD)


@pytest.mark.django_db
@with_test_phone
def test_login_code_does_not_work_for_password_reset(api_client: APIClient) -> None:
    """Код выписан на вход — сменить им пароль нельзя."""
    UserFactory(phone=TEST_PHONE)
    issue_otp(TEST_PHONE, "login")

    response = api_client.post(
        RESET_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, "password": NEW_PASSWORD}
    )

    assert response.status_code == 400
    assert "Код не найден" in response.json()["error"]["message"]


@pytest.mark.django_db
@with_test_phone
def test_password_reset_hides_whether_the_phone_is_registered(api_client: APIClient) -> None:
    """На незарегистрированный номер — тот же ответ, что и на неверный код."""
    issue_otp(TEST_PHONE, "password_reset")

    response = api_client.post(
        RESET_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, "password": NEW_PASSWORD}
    )

    assert response.status_code == 400
    assert response.json()["error"]["message"] == "Неверный код"
    assert User.objects.filter(phone=TEST_PHONE).count() == 0


@pytest.mark.django_db
@with_test_phone
def test_password_reset_rejects_a_weak_password(api_client: APIClient) -> None:
    user = UserFactory(phone=TEST_PHONE)
    user.set_password(GOOD_PASSWORD)
    user.save(update_fields=["password"])

    issue_otp(TEST_PHONE, "password_reset")
    response = api_client.post(
        RESET_URL, {"phone": TEST_PHONE, "code": DEBUG_CODE, "password": "12345678"}
    )

    assert response.status_code == 400
    assert "password" in response.json()["error"]["details"]

    user.refresh_from_db()
    assert user.check_password(GOOD_PASSWORD)


# -- регистрация не плодит пользователей -------------------------------------


@pytest.mark.django_db
@with_test_phone
def test_registration_with_an_existing_phone_does_not_create_a_second_user(
    api_client: APIClient,
) -> None:
    """Номер уже зарегистрирован — регистрация приводит к тому же аккаунту."""
    existing = UserFactory(phone=TEST_PHONE, name="Азамат")

    issue_otp(TEST_PHONE, "register")
    response = api_client.post(
        VERIFY_URL,
        {
            "phone": TEST_PHONE,
            "code": DEBUG_CODE,
            "purpose": "register",
            "name": "Кто-то другой",
            "password": GOOD_PASSWORD,
            **CONSENT,
        },
    )

    assert response.status_code == 200
    assert response.json()["is_new_user"] is False
    assert User.objects.filter(phone=TEST_PHONE).count() == 1

    existing.refresh_from_db()
    assert existing.name == "Азамат", "имя владельца номера перезаписывать нельзя"


@pytest.mark.django_db
@with_test_phone
def test_repeated_verification_does_not_create_a_duplicate(api_client: APIClient) -> None:
    """Двойной тап по «Подтвердить»: второй запрос не заводит второй аккаунт."""
    issue_otp(TEST_PHONE, "register")
    payload = {
        "phone": TEST_PHONE,
        "code": DEBUG_CODE,
        "purpose": "register",
        "name": "Азамат",
        "password": GOOD_PASSWORD,
        **CONSENT,
    }

    first = api_client.post(VERIFY_URL, payload)
    second = api_client.post(VERIFY_URL, payload)

    assert first.status_code == 200
    # Код одноразовый, поэтому повтор отклоняется — но аккаунт остаётся один.
    assert second.status_code == 400
    assert User.objects.filter(phone=TEST_PHONE).count() == 1


@pytest.mark.django_db
@with_test_phone
def test_registration_name_reaches_the_profile(api_client: APIClient) -> None:
    """Имя из формы должно вернуться в /users/me — иначе поле собрано зря."""
    issue_otp(TEST_PHONE, "register")
    registered = api_client.post(
        VERIFY_URL,
        {
            "phone": TEST_PHONE,
            "code": DEBUG_CODE,
            "purpose": "register",
            "name": "Азамат Осмонов",
            "password": GOOD_PASSWORD,
            **CONSENT,
        },
    )
    assert registered.status_code == 200

    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {registered.json()['access']}")
    me = api_client.get(ME_URL)

    assert me.status_code == 200
    assert me.json()["name"] == "Азамат Осмонов"
    assert me.json()["phone"] == TEST_PHONE
