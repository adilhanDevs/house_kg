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
