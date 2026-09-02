"""Regression tests for publishing and republishing listings from draft."""

from datetime import timedelta

import pytest
from django.test import override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.billing.models import Subscription, SubscriptionStatus, Tariff
from apps.catalog.enums import ListingStatus
from apps.catalog.models import Listing
from tests.factories import (
    CityFactory,
    DistrictFactory,
    ListingFactory,
    ListingMediaFactory,
    UserFactory,
)

DRAFT_URL = "/api/v1/listings/draft/"
DETAIL_URL = "/api/v1/listings/{slug}/"
PUBLISH_URL = "/api/v1/listings/{slug}/publish/"
ARCHIVE_URL = "/api/v1/listings/{slug}/archive/"


def client_for(user) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
    return client


@pytest.fixture
def district(db):
    return DistrictFactory(city=CityFactory(slug="bishkek", is_default=True), slug="technopark")


def fill_draft(auth: APIClient, slug: str, district, **overrides) -> None:
    payload = {
        "district": district.slug,
        "price": "95000.00",
        "area": "85.00",
        "rooms": 2,
        "floor": 4,
        "floors": 9,
        **overrides,
    }
    response = auth.patch(DETAIL_URL.format(slug=slug), payload, format="json")
    assert response.status_code == 200, response.json()


@pytest.mark.django_db
def test_a_draft_can_be_published_with_available_slot(district) -> None:
    """A. Draft можно опубликовать при наличии слота."""
    user = UserFactory(is_trusted=True)
    auth = client_for(user)

    # Создаём черновик
    draft_resp = auth.post(DRAFT_URL)
    assert draft_resp.status_code == 200
    slug = draft_resp.json()["slug"]

    # Заполняем обязательные поля и фото
    fill_draft(auth, slug, district)
    listing = Listing.objects.get(slug=slug)
    ListingMediaFactory(listing=listing, order=0, is_cover=True)

    # Публикуем
    pub_resp = auth.post(PUBLISH_URL.format(slug=slug))
    assert pub_resp.status_code == 200
    assert pub_resp.json()["status"] == ListingStatus.ACTIVE

    listing.refresh_from_db()
    assert listing.status == ListingStatus.ACTIVE
    assert listing.published_at is not None


@pytest.mark.django_db
@override_settings(FREE_ACTIVE_LISTINGS=1)
def test_b_draft_publish_rejected_when_limit_reached(district) -> None:
    """B. Нет места: черновик не публикуется, возвращается 409, статус остаётся draft."""
    user = UserFactory(is_trusted=True)
    auth = client_for(user)

    # 1 активное объявление уже есть (лимит исчерпан)
    ListingFactory(owner=user, district=district, status=ListingStatus.ACTIVE)

    # Черновик B
    draft_resp = auth.post(DRAFT_URL)
    slug = draft_resp.json()["slug"]
    fill_draft(auth, slug, district)
    listing_b = Listing.objects.get(slug=slug)
    ListingMediaFactory(listing=listing_b, order=0, is_cover=True)

    # Попытка публикации
    response = auth.post(PUBLISH_URL.format(slug=slug))
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "conflict"
    assert "лимит активных объявлений" in response.json()["error"]["message"]

    # Проверяем, что черновик остался черновиком
    listing_b.refresh_from_db()
    assert listing_b.status == ListingStatus.DRAFT
    assert listing_b.published_at is None


@pytest.mark.django_db
@override_settings(FREE_ACTIVE_LISTINGS=1)
def test_c_republish_same_draft_after_freeing_slot(district) -> None:
    """C. Лимит исчерпан -> отказ -> слот освободили -> повторный publish того же черновика."""
    user = UserFactory(is_trusted=True)
    auth = client_for(user)

    # 1. Лимит тарифа: 1 активное объявление
    listing_a = ListingFactory(owner=user, district=district, status=ListingStatus.ACTIVE)

    # 2. Listing B = draft
    draft_resp = auth.post(DRAFT_URL)
    slug_b = draft_resp.json()["slug"]
    fill_draft(auth, slug_b, district, description="Отличный пентхаус")
    listing_b = Listing.objects.get(slug=slug_b)
    media_b = ListingMediaFactory(listing=listing_b, order=0, is_cover=True)
    initial_pk = listing_b.pk

    # 3. Попытка publish B -> backend отклоняет из-за лимита
    first_pub = auth.post(PUBLISH_URL.format(slug=slug_b))
    assert first_pub.status_code == 409
    listing_b.refresh_from_db()
    assert listing_b.status == ListingStatus.DRAFT

    # 4. Пользователь освобождает слот: A перемещён в архив
    archive_resp = auth.post(ARCHIVE_URL.format(slug=listing_a.slug))
    assert archive_resp.status_code == 200
    listing_a.refresh_from_db()
    assert listing_a.status == ListingStatus.ARCHIVED

    # 5. Открывает B -> нажимает «Опубликовать» снова (тот же slug_b)
    second_pub = auth.post(PUBLISH_URL.format(slug=slug_b))
    assert second_pub.status_code == 200
    assert second_pub.json()["status"] == ListingStatus.ACTIVE

    # 6. Проверяем: тот же listing (ID и slug), статус active, данные не потеряны
    listing_b.refresh_from_db()
    assert listing_b.pk == initial_pk
    assert listing_b.slug == slug_b
    assert listing_b.status == ListingStatus.ACTIVE
    assert listing_b.description == "Отличный пентхаус"
    assert listing_b.media.filter(pk=media_b.pk).exists()
    assert listing_b.published_at is not None

    # В каталоге ровно 1 активное объявление (B), нет дубликатов
    assert Listing.objects.filter(owner=user, status=ListingStatus.ACTIVE).count() == 1


@pytest.mark.django_db
def test_d_stranger_cannot_publish_another_users_draft(auth_client: APIClient, district) -> None:
    """D. Чужой draft: нельзя опубликовать чужое объявление."""
    stranger = UserFactory()
    stranger_draft = ListingFactory(owner=stranger, district=district, status=ListingStatus.DRAFT)

    response = auth_client.post(PUBLISH_URL.format(slug=stranger_draft.slug))
    assert response.status_code == 404


@pytest.mark.django_db
def test_e_already_published_listing_cannot_be_republished(district) -> None:
    """E. Повторный publish активного возвращает 409 Conflict, не создавая дубликат."""
    user = UserFactory(is_trusted=True)
    auth = client_for(user)

    listing = ListingFactory(owner=user, district=district, status=ListingStatus.ACTIVE)
    response = auth.post(PUBLISH_URL.format(slug=listing.slug))

    assert response.status_code == 409
    assert "уже опубликовано" in response.json()["error"]["message"]
    assert Listing.objects.filter(owner=user).count() == 1


@pytest.mark.django_db
@override_settings(FREE_ACTIVE_LISTINGS=1)
def test_f_data_preserved_after_failed_publish(district) -> None:
    """F. Данные сохраняются после failed publish."""
    user = UserFactory(is_trusted=True)
    auth = client_for(user)

    ListingFactory(owner=user, district=district, status=ListingStatus.ACTIVE)

    draft_resp = auth.post(DRAFT_URL)
    slug = draft_resp.json()["slug"]
    fill_draft(auth, slug, district, price="125000.00", area="110.00")
    listing = Listing.objects.get(slug=slug)
    media = ListingMediaFactory(listing=listing, order=0, is_cover=True)

    # Неудачная публикация
    response = auth.post(PUBLISH_URL.format(slug=slug))
    assert response.status_code == 409

    # Всё на месте
    listing.refresh_from_db()
    assert listing.status == ListingStatus.DRAFT
    assert listing.price == 125000
    assert listing.area == 110
    assert listing.media.count() == 1
    assert listing.media.first().pk == media.pk


@pytest.mark.django_db
@override_settings(FREE_ACTIVE_LISTINGS=1)
def test_g_expired_tariff_message_distinguished(district) -> None:
    """G. Если у пользователя истёк платный тариф, выводится сообщение о завершении тарифа."""
    user = UserFactory(is_trusted=True)
    auth = client_for(user)

    # Уже есть 1 активное объявление
    ListingFactory(owner=user, district=district, status=ListingStatus.ACTIVE)

    # Истекший тариф agency (лимит был 20, но истёк)
    tariff = Tariff.objects.create(
        code="agency_test",
        name="Agency Test",
        price_bricks_per_month=1000,
        listings_limit=20,
    )
    now = timezone.now()
    Subscription.objects.create(
        user=user,
        tariff=tariff,
        status=SubscriptionStatus.EXPIRED,
        starts_at=now - timedelta(days=60),
        ends_at=now - timedelta(days=1),
    )

    draft_resp = auth.post(DRAFT_URL)
    slug = draft_resp.json()["slug"]
    fill_draft(auth, slug, district)
    listing = Listing.objects.get(slug=slug)
    ListingMediaFactory(listing=listing, order=0, is_cover=True)

    response = auth.post(PUBLISH_URL.format(slug=slug))
    assert response.status_code == 409
    message = response.json()["error"]["message"]
    assert "Срок действия вашего тарифа закончился" in message
