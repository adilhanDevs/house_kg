"""Тесты модели пользователя и эндпоинтов профиля."""

from io import BytesIO

import pytest
from django.core.exceptions import ValidationError
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image
from rest_framework.test import APIClient, APIRequestFactory

from apps.catalog.enums import ListingStatus
from apps.users.models import User, mask_iin
from apps.users.serializers import UserMeSerializer
from tests.factories import ListingFactory, UserFactory

ME_URL = "/api/v1/users/me/"


def make_image(name: str = "avatar.png") -> SimpleUploadedFile:
    buffer = BytesIO()
    Image.new("RGB", (4, 4), (10, 120, 200)).save(buffer, format="PNG")
    return SimpleUploadedFile(name, buffer.getvalue(), content_type="image/png")


# -- телефон -----------------------------------------------------------------


@pytest.mark.django_db
@pytest.mark.parametrize("raw", ["", "123", "не телефон", "+996 70", "+9961234567890123"])
def test_invalid_phone_is_rejected(raw: str) -> None:
    with pytest.raises(ValidationError):
        User.objects.create_user(phone=raw)


@pytest.mark.django_db
@pytest.mark.parametrize(
    ("raw", "normalized"),
    [
        ("0700123456", "+996700123456"),
        ("996700123456", "+996700123456"),
        ("+996 700 12-34-56", "+996700123456"),
        ("+996700123456", "+996700123456"),
    ],
)
def test_phone_is_normalized_to_e164(raw: str, normalized: str) -> None:
    user = User.objects.create_user(phone=raw)

    user.refresh_from_db()
    assert user.phone == normalized


# -- GET /users/me/ ----------------------------------------------------------


@pytest.mark.django_db
def test_me_requires_authentication(api_client: APIClient) -> None:
    response = api_client.get(ME_URL)

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "authentication_failed"


@pytest.mark.django_db
def test_me_returns_profile(auth_client: APIClient, user: User) -> None:
    response = auth_client.get(ME_URL)

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == user.pk
    assert body["phone"] == user.phone
    assert body["name"] == user.name
    assert body["is_pro"] is False
    assert body["avatar_url"] is None
    assert body["wallet_balance"] == {"balance": 0, "currency": "brick"}
    assert "date_joined" in body


@pytest.mark.django_db
def test_me_shows_wallet_balance(auth_client: APIClient, user: User) -> None:
    from apps.billing.services import apply_transaction, get_wallet

    apply_transaction(wallet=get_wallet(user), amount=16_700, kind="topup", label="Пополнение")

    body = auth_client.get(ME_URL).json()

    assert body["wallet_balance"] == {"balance": 16_700, "currency": "brick"}


# -- ИИН как персональные данные ---------------------------------------------


def test_mask_iin() -> None:
    assert mask_iin("20101199001234") == "20101199******"
    assert mask_iin("") == ""


@pytest.mark.django_db
def test_owner_sees_own_iin(auth_client: APIClient, user: User) -> None:
    user.is_pro = True
    user.iin = "20101199001234"
    user.save()

    assert auth_client.get(ME_URL).json()["iin"] == "20101199001234"


@pytest.mark.django_db
def test_iin_of_another_user_is_masked() -> None:
    stranger = UserFactory(pro=True)
    viewer = UserFactory()

    request = APIRequestFactory().get(ME_URL)
    request.user = viewer
    data = UserMeSerializer(stranger, context={"request": request}).data

    assert data["iin"] == "20101199******"
    assert stranger.iin not in str(data)


@pytest.mark.django_db
def test_staff_sees_full_iin() -> None:
    stranger = UserFactory(pro=True)
    staff = UserFactory(is_staff=True)

    request = APIRequestFactory().get(ME_URL)
    request.user = staff
    data = UserMeSerializer(stranger, context={"request": request}).data

    assert data["iin"] == "20101199001234"


# -- PATCH /users/me/ --------------------------------------------------------


@pytest.mark.django_db
def test_patch_updates_name_and_avatar(auth_client: APIClient, user: User) -> None:
    response = auth_client.patch(
        ME_URL,
        {"name": "Айбек", "avatar": make_image()},
        format="multipart",
    )

    assert response.status_code == 200
    user.refresh_from_db()
    assert user.name == "Айбек"
    assert user.avatar
    assert response.json()["avatar_url"].startswith("http")


@pytest.mark.django_db
def test_patch_ignores_protected_fields(auth_client: APIClient, user: User) -> None:
    original_phone = user.phone

    response = auth_client.patch(
        ME_URL,
        {
            "name": "Новое имя",
            "phone": "+996555999999",
            "is_pro": True,
            "iin": "99999999999999",
            "is_staff": True,
        },
    )

    assert response.status_code == 200
    user.refresh_from_db()
    assert user.name == "Новое имя"
    assert user.phone == original_phone
    assert user.is_pro is False
    assert user.iin == ""
    assert user.is_staff is False


# -- DELETE /users/me/ -------------------------------------------------------


@pytest.mark.django_db
def test_delete_anonymizes_user_and_archives_listings(auth_client: APIClient, user: User) -> None:
    user.is_pro = True
    user.iin = "20101199001234"
    user.avatar = make_image()
    user.save()
    listing = ListingFactory(owner=user)
    other_listing = ListingFactory()

    response = auth_client.delete(ME_URL)

    assert response.status_code == 204
    assert response.content == b""

    user.refresh_from_db()
    assert user.is_active is False
    assert user.phone.startswith("deleted-")
    assert len(user.phone) <= 16
    assert user.name == ""
    assert user.iin == ""
    assert not user.avatar
    assert user.has_usable_password() is False

    listing.refresh_from_db()
    other_listing.refresh_from_db()
    assert listing.status == ListingStatus.ARCHIVED
    assert other_listing.status == ListingStatus.ACTIVE


@pytest.mark.django_db
def test_deleted_user_cannot_authenticate(auth_client: APIClient, user: User) -> None:
    auth_client.delete(ME_URL)

    # Токен ещё валиден по подписи, но пользователь деактивирован.
    assert auth_client.get(ME_URL).status_code == 401


# -- Обложка профиля (profile_cover) и независимость от аватара ----------------


@pytest.mark.django_db
def test_me_returns_cover_url(auth_client: APIClient, user: User) -> None:
    user.profile_cover = make_image("cover.png")
    user.save()

    response = auth_client.get(ME_URL)
    assert response.status_code == 200
    body = response.json()
    assert body["cover_url"].startswith("http")
    assert body["profile_cover_url"] == body["cover_url"]


@pytest.mark.django_db
def test_patch_profile_cover(auth_client: APIClient, user: User) -> None:
    response = auth_client.patch(
        ME_URL,
        {"profile_cover": make_image("banner.png")},
        format="multipart",
    )

    assert response.status_code == 200
    user.refresh_from_db()
    assert user.profile_cover
    assert response.json()["cover_url"].startswith("http")


@pytest.mark.django_db
def test_avatar_and_cover_are_independent(auth_client: APIClient, user: User) -> None:
    # 1. Загружаем аватар
    auth_client.patch(ME_URL, {"avatar": make_image("av1.png")}, format="multipart")
    user.refresh_from_db()
    avatar_url = user.avatar.url
    assert not user.profile_cover

    # 2. Загружаем обложку — аватар не должен измениться
    auth_client.patch(ME_URL, {"profile_cover": make_image("cov1.png")}, format="multipart")
    user.refresh_from_db()
    assert user.avatar.url == avatar_url
    cover_url = user.profile_cover.url
    assert cover_url

    # 3. Меняем аватар — обложка остаётся прежней
    auth_client.patch(ME_URL, {"avatar": make_image("av2.png")}, format="multipart")
    user.refresh_from_db()
    assert user.profile_cover.url == cover_url
    assert user.avatar.url != avatar_url

    # 4. Меняем имя — ни аватар, ни обложка не тронуты
    auth_client.patch(ME_URL, {"name": "Новое Имя"})
    user.refresh_from_db()
    assert user.name == "Новое Имя"
    assert user.profile_cover.url == cover_url


@pytest.mark.django_db
def test_delete_avatar_and_cover(auth_client: APIClient, user: User) -> None:
    user.avatar = make_image("av.png")
    user.profile_cover = make_image("cov.png")
    user.save()

    # Удаление аватара через delete_avatar
    resp1 = auth_client.patch(ME_URL, {"delete_avatar": True})
    assert resp1.status_code == 200
    user.refresh_from_db()
    assert not user.avatar
    assert user.profile_cover
    assert resp1.json()["avatar_url"] is None
    assert resp1.json()["cover_url"] is not None

    # Удаление обложки через delete_cover
    resp2 = auth_client.patch(ME_URL, {"delete_cover": True})
    assert resp2.status_code == 200
    user.refresh_from_db()
    assert not user.profile_cover
    assert resp2.json()["cover_url"] is None


# -- Смена пароля (PasswordChangeView) ----------------------------------------

PASSWORD_CHANGE_URL = "/api/v1/auth/password/change/"


@pytest.mark.django_db
def test_password_change_requires_authentication(api_client: APIClient) -> None:
    response = api_client.post(
        PASSWORD_CHANGE_URL,
        {"new_password": "new-strong-password-123"},
    )
    assert response.status_code == 401


@pytest.mark.django_db
def test_password_change_wrong_current_password(auth_client: APIClient, user: User) -> None:
    user.set_password("correct-password-123")
    user.save()

    response = auth_client.post(
        PASSWORD_CHANGE_URL,
        {
            "current_password": "wrong-password",
            "new_password": "new-strong-password-123",
            "new_password_confirmation": "new-strong-password-123",
        },
    )
    assert response.status_code == 400
    assert "current_password" in response.json()["error"]["details"]


@pytest.mark.django_db
def test_password_change_weak_new_password(auth_client: APIClient, user: User) -> None:
    user.set_password("correct-password-123")
    user.save()

    response = auth_client.post(
        PASSWORD_CHANGE_URL,
        {
            "current_password": "correct-password-123",
            "new_password": "123",  # слишком короткий
            "new_password_confirmation": "123",
        },
    )
    assert response.status_code == 400
    assert "new_password" in response.json()["error"]["details"]


@pytest.mark.django_db
def test_password_change_confirmation_mismatch(auth_client: APIClient, user: User) -> None:
    user.set_password("correct-password-123")
    user.save()

    response = auth_client.post(
        PASSWORD_CHANGE_URL,
        {
            "current_password": "correct-password-123",
            "new_password": "new-strong-password-123",
            "new_password_confirmation": "different-password-123",
        },
    )
    assert response.status_code == 400
    assert "new_password_confirmation" in response.json()["error"]["details"]


@pytest.mark.django_db
def test_password_change_success(auth_client: APIClient, user: User) -> None:
    user.set_password("old-password-123")
    user.save()

    response = auth_client.post(
        PASSWORD_CHANGE_URL,
        {
            "current_password": "old-password-123",
            "new_password": "new-password-456",
            "new_password_confirmation": "new-password-456",
        },
    )
    assert response.status_code == 200
    assert response.json()["message"] == "Пароль успешно изменён."

    user.refresh_from_db()
    assert user.check_password("new-password-456")
    assert not user.check_password("old-password-123")
    # Проверка, что сырой пароль нигде не сохранился
    assert "new-password-456" not in user.password


@pytest.mark.django_db
def test_password_change_otp_user_without_password(auth_client: APIClient, user: User) -> None:
    user.set_unusable_password()
    user.save()
    assert not user.has_usable_password()

    response = auth_client.post(
        PASSWORD_CHANGE_URL,
        {
            "new_password": "first-password-123",
            "new_password_confirmation": "first-password-123",
        },
    )
    assert response.status_code == 200
    user.refresh_from_db()
    assert user.has_usable_password()
    assert user.check_password("first-password-123")


@pytest.mark.django_db
def test_patch_whatsapp_phone(auth_client: APIClient, user: User) -> None:
    # 1. Установка корректного номера в местном формате
    response = auth_client.patch(ME_URL, {"whatsapp_phone": "0700123456"})
    assert response.status_code == 200
    user.refresh_from_db()
    assert user.whatsapp_phone == "+996700123456"
    assert response.json()["whatsapp_phone"] == "+996700123456"

    # 2. Очистка номера
    resp_clear = auth_client.patch(ME_URL, {"whatsapp_phone": ""})
    assert resp_clear.status_code == 200
    user.refresh_from_db()
    assert user.whatsapp_phone is None


@pytest.mark.django_db
def test_patch_invalid_whatsapp_phone(auth_client: APIClient, user: User) -> None:
    response = auth_client.patch(ME_URL, {"whatsapp_phone": "not-a-valid-phone"})
    assert response.status_code == 400
    assert "whatsapp_phone" in response.json()["error"]["details"]
