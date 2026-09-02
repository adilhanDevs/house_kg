"""Публичный профиль продавца, отзывы и раскрытие контактов."""

from decimal import Decimal

import pytest
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.catalog.enums import ListingStatus, ModerationStatus
from apps.catalog.models import ModerationTask
from apps.users.models import (
    ContactEvent,
    Review,
    ReviewStatus,
    SellerProfile,
    SellerVerification,
    VerificationStatus,
)
from apps.users.sellers import (
    delete_review,
    get_seller_profile,
    publish_review,
    recalc_seller_rating,
    reject_review,
    review_seller_verification,
)
from tests.factories import DistrictFactory, ListingFactory, UserFactory

pytestmark = pytest.mark.django_db


def client_for(user) -> APIClient:
    client = APIClient()
    token = RefreshToken.for_user(user)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {token.access_token}")
    return client


@pytest.fixture
def seller():
    user = UserFactory(is_pro=True, name="Айбек")
    profile = get_seller_profile(user)
    profile.company_name = "Агентство «Бишкек-Недвижимость»"
    profile.about = "Работаю с 2015 года"
    profile.experience_years = 11
    profile.whatsapp = "+996700111222"
    profile.telegram = "@aibek_kg"
    profile.save()
    return user


def review_url(seller) -> str:
    return reverse("users:seller-reviews", args=[seller.pk])


def leave_review(client, seller, rating: int = 5, text: str = "Всё отлично"):
    return client.post(review_url(seller), {"rating": rating, "text": text}, format="json")


# -- публичная карточка ------------------------------------------------------


def test_seller_card_is_public(api_client, seller):
    ListingFactory(owner=seller, status=ListingStatus.ACTIVE)
    ListingFactory(owner=seller, status=ListingStatus.ARCHIVED)
    ListingFactory(owner=seller, status=ListingStatus.SOLD)

    response = api_client.get(reverse("users:seller-detail", args=[seller.pk]))

    assert response.status_code == 200, response.data
    body = response.data
    assert body["id"] == seller.pk
    assert body["name"] == "Айбек"
    assert body["company_name"] == "Агентство «Бишкек-Недвижимость»"
    assert body["experience_years"] == 11
    assert body["active_listings_count"] == 1  # архивное и проданное не считаются в активных
    assert body["sold_listings_count"] == 1
    assert body["cover_url"] is None
    assert body["rating"] == "0.00"
    assert body["reviews_count"] == 0
    assert body["is_verified"] is False


def test_anonymous_sees_masked_phone(api_client, seller):
    response = api_client.get(reverse("users:seller-detail", args=[seller.pk]))

    contacts = response.data["contacts"]
    assert contacts["phone"] != seller.phone
    assert "X" in contacts["phone"]  # маска вида «+996 7XX XXX XX1»
    # Мессенджеры анониму тоже не отдаём: это те же контакты.
    assert contacts["whatsapp"] == ""
    assert contacts["telegram"] == ""


def test_authenticated_sees_full_contacts(seller):
    response = client_for(UserFactory()).get(reverse("users:seller-detail", args=[seller.pk]))

    contacts = response.data["contacts"]
    assert contacts["phone"] == seller.phone
    assert contacts["whatsapp"] == "+996700111222"
    assert contacts["telegram"] == "@aibek_kg"


def test_seller_listings_are_filtered_like_catalog(api_client, seller):
    active = ListingFactory(owner=seller, status=ListingStatus.ACTIVE)
    ListingFactory(owner=seller, status=ListingStatus.DRAFT)
    ListingFactory(status=ListingStatus.ACTIVE)  # чужое

    response = api_client.get(reverse("users:seller-listings", args=[seller.pk]))

    assert response.status_code == 200
    assert [item["slug"] for item in response.data["results"]] == [active.slug]
    assert response.data["results"][0]["owner_id"] == seller.pk


def test_seller_listings_accept_catalog_filters(api_client, seller):
    from apps.catalog.enums import PropertyKind

    house = ListingFactory(owner=seller, status=ListingStatus.ACTIVE, kind=PropertyKind.HOUSE)
    ListingFactory(owner=seller, status=ListingStatus.ACTIVE, kind=PropertyKind.APARTMENT)

    response = api_client.get(
        reverse("users:seller-listings", args=[seller.pk]), {"kind": PropertyKind.HOUSE}
    )

    assert [item["slug"] for item in response.data["results"]] == [house.slug]


# -- свой профиль ------------------------------------------------------------


def test_pro_can_edit_own_profile(seller):
    district = DistrictFactory()
    client = client_for(seller)

    response = client.patch(
        reverse("users:seller-me"),
        {
            "about": "Новый текст",
            "experience_years": 12,
            "work_districts": [district.pk],
            "working_hours": {"mon": ["09:00", "18:00"], "sun": []},
        },
        format="json",
    )

    assert response.status_code == 200, response.data
    assert response.data["about"] == "Новый текст"
    assert response.data["work_districts"] == [district.pk]
    assert response.data["working_hours"]["mon"] == ["09:00", "18:00"]


def test_rating_and_verified_are_read_only(seller):
    profile = get_seller_profile(seller)
    profile.rating = Decimal("4.50")
    profile.save()

    response = client_for(seller).patch(
        reverse("users:seller-me"),
        {"rating": "5.00", "is_verified": True, "reviews_count": 999},
        format="json",
    )

    profile.refresh_from_db()
    assert response.status_code == 200
    assert profile.rating == Decimal("4.50")
    assert profile.is_verified is False
    assert profile.reviews_count == 0


def test_working_hours_are_validated(seller):
    client = client_for(seller)

    bad_day = client.patch(
        reverse("users:seller-me"), {"working_hours": {"monday": ["09:00", "18:00"]}}, format="json"
    )
    bad_time = client.patch(
        reverse("users:seller-me"), {"working_hours": {"mon": ["9 утра", "18:00"]}}, format="json"
    )

    assert bad_day.status_code == 400
    assert bad_time.status_code == 400


def test_non_pro_cannot_open_seller_profile():
    assert client_for(UserFactory(is_pro=False)).get(reverse("users:seller-me")).status_code == 403


# -- отзывы ------------------------------------------------------------------


def test_review_about_self_is_rejected(seller):
    response = leave_review(client_for(seller), seller)

    assert response.status_code == 400
    assert "самому себе" in response.data["error"]["message"]
    assert Review.objects.count() == 0


def test_second_review_to_same_seller_is_conflict(seller):
    author = UserFactory()
    client = client_for(author)

    first = leave_review(client, seller)
    second = leave_review(client, seller, rating=1, text="Передумал")

    assert first.status_code == 201
    assert second.status_code == 409
    assert Review.objects.filter(seller=seller).count() == 1


def test_pending_review_is_invisible_and_does_not_affect_rating(api_client, seller):
    leave_review(client_for(UserFactory()), seller, rating=5)

    listed = api_client.get(review_url(seller))
    profile = get_seller_profile(seller)

    assert listed.status_code == 200
    assert listed.data["results"] == []
    assert profile.rating == Decimal("0.00")
    assert profile.reviews_count == 0


def test_publishing_review_recalculates_rating(seller):
    leave_review(client_for(UserFactory()), seller, rating=5)
    leave_review(client_for(UserFactory()), seller, rating=4)

    for review in Review.objects.all():
        publish_review(review)

    profile = get_seller_profile(seller)
    profile.refresh_from_db()
    assert profile.reviews_count == 2
    assert profile.rating == Decimal("4.50")


def test_deleting_review_recalculates_back(seller):
    leave_review(client_for(UserFactory()), seller, rating=5)
    leave_review(client_for(UserFactory()), seller, rating=1)
    for review in Review.objects.all():
        publish_review(review)

    profile = get_seller_profile(seller)
    profile.refresh_from_db()
    assert profile.rating == Decimal("3.00")

    delete_review(Review.objects.get(rating=1))

    profile.refresh_from_db()
    assert profile.reviews_count == 1
    assert profile.rating == Decimal("5.00")


def test_rejecting_published_review_recalculates(seller):
    leave_review(client_for(UserFactory()), seller, rating=5)
    review = Review.objects.get()
    publish_review(review)

    reject_review(review, comment="Реклама")

    profile = get_seller_profile(seller)
    profile.refresh_from_db()
    assert profile.reviews_count == 0
    assert profile.rating == Decimal("0.00")


def test_published_review_is_visible(api_client, seller):
    author = UserFactory(name="Нурбек")
    leave_review(client_for(author), seller, rating=5, text="Помог быстро")
    publish_review(Review.objects.get())

    response = api_client.get(review_url(seller))

    assert len(response.data["results"]) == 1
    item = response.data["results"][0]
    assert item["rating"] == 5
    assert item["text"] == "Помог быстро"
    assert item["author"]["name"] == "Нурбек"


def test_editing_own_review_returns_it_to_moderation(seller):
    author = UserFactory()
    leave_review(client_for(author), seller, rating=5)
    review = Review.objects.get()
    publish_review(review)

    response = client_for(author).patch(
        reverse("users:review-detail", args=[review.pk]),
        {"rating": 2, "text": "Передумал"},
        format="json",
    )

    review.refresh_from_db()
    profile = get_seller_profile(seller)
    profile.refresh_from_db()

    assert response.status_code == 200
    assert review.status == ReviewStatus.PENDING
    assert review.rating == 2
    # Пока не опубликован заново — в рейтинге его нет.
    assert profile.reviews_count == 0


def test_foreign_review_cannot_be_edited(seller):
    leave_review(client_for(UserFactory()), seller)
    review = Review.objects.get()

    response = client_for(UserFactory()).patch(
        reverse("users:review-detail", args=[review.pk]), {"rating": 1}, format="json"
    )

    assert response.status_code == 403


def test_review_rating_is_bounded(seller):
    client = client_for(UserFactory())

    assert leave_review(client, seller, rating=0).status_code == 400
    assert leave_review(client, seller, rating=6).status_code == 400


def test_anonymous_cannot_leave_review(api_client, seller):
    assert api_client.post(review_url(seller), {"rating": 5}, format="json").status_code == 401


def test_review_goes_to_the_moderation_queue(seller):
    leave_review(client_for(UserFactory()), seller)

    task = ModerationTask.objects.get()
    assert task.target_kind == "review"
    assert task.listing_id is None
    assert task.status == ModerationStatus.OPEN


def test_moderator_publishes_review_from_the_queue(seller):
    leave_review(client_for(UserFactory()), seller, rating=4)
    task = ModerationTask.objects.get()
    moderator = UserFactory(is_staff=True)

    response = client_for(moderator).post(reverse("catalog:moderation-approve", args=[task.pk]))

    assert response.status_code == 200, response.data
    assert response.data["target_kind"] == "review"
    assert Review.objects.get().status == ReviewStatus.PUBLISHED

    profile = get_seller_profile(seller)
    profile.refresh_from_db()
    assert profile.rating == Decimal("4.00")


def test_moderator_rejects_review_from_the_queue(seller):
    leave_review(client_for(UserFactory()), seller)
    task = ModerationTask.objects.get()

    response = client_for(UserFactory(is_staff=True)).post(
        reverse("catalog:moderation-reject", args=[task.pk]),
        {"reason_code": "spam-not-needed", "comment": "Реклама"},
        format="json",
    )

    assert response.status_code == 200, response.data
    review = Review.objects.get()
    assert review.status == ReviewStatus.REJECTED
    assert review.moderator_comment == "Реклама"


def test_queue_can_be_filtered_by_target(seller):
    from apps.catalog.moderation.services import enqueue_moderation
    from tests.factories import ListingMediaFactory

    listing = ListingFactory(status=ListingStatus.PENDING)
    ListingMediaFactory(listing=listing, is_cover=True)
    enqueue_moderation(listing)
    leave_review(client_for(UserFactory()), seller)

    client = client_for(UserFactory(is_staff=True))
    reviews = client.get(reverse("catalog:moderation-queue"), {"target": "review"})
    listings = client.get(reverse("catalog:moderation-queue"), {"target": "listing"})

    assert [item["target_kind"] for item in reviews.data["results"]] == ["review"]
    assert [item["target_kind"] for item in listings.data["results"]] == ["listing"]


def test_recalc_handles_seller_without_reviews(seller):
    profile = recalc_seller_rating(seller)

    assert profile.rating == Decimal("0.00")
    assert profile.reviews_count == 0


# -- подтверждение агентства -------------------------------------------------


def document(name: str = "ustav.pdf") -> SimpleUploadedFile:
    return SimpleUploadedFile(name, b"%PDF-1.7\nfake", content_type="application/pdf")


def test_verification_submit_creates_application(seller):
    response = client_for(seller).post(
        reverse("users:seller-verification"),
        {"documents": [document(), document("licence.pdf")]},
        format="multipart",
    )

    assert response.status_code == 201, response.data
    verification = SellerVerification.objects.get()
    assert verification.status == VerificationStatus.PENDING
    assert len(verification.documents) == 2


def test_verification_document_key_has_no_user_filename(seller):
    client_for(seller).post(
        reverse("users:seller-verification"),
        {"documents": [document("устав_Иванов.pdf")]},
        format="multipart",
    )

    stored = SellerVerification.objects.get().documents[0]["path"]
    assert "Иванов" not in stored
    assert stored.endswith(".pdf")


def test_second_pending_application_is_conflict(seller):
    client = client_for(seller)
    url = reverse("users:seller-verification")

    first = client.post(url, {"documents": [document()]}, format="multipart")
    second = client.post(url, {"documents": [document()]}, format="multipart")

    assert first.status_code == 201
    assert second.status_code == 409


def test_approved_verification_sets_the_badge(seller):
    client_for(seller).post(
        reverse("users:seller-verification"), {"documents": [document()]}, format="multipart"
    )
    verification = SellerVerification.objects.get()

    review_seller_verification(verification, UserFactory(is_staff=True), approved=True)

    profile = SellerProfile.objects.get(user=seller)
    assert profile.is_verified is True
    assert profile.verified_at is not None


# -- раскрытие контактов -----------------------------------------------------


def contact_url(listing) -> str:
    return reverse("users:listing-contact", args=[listing.slug])


def test_contact_returns_phone_and_records_event(seller):
    from apps.catalog.models import ListingDailyStat

    listing = ListingFactory(owner=seller, status=ListingStatus.ACTIVE)
    viewer = UserFactory()

    response = client_for(viewer).post(contact_url(listing))

    assert response.status_code == 200, response.data
    assert response.data["phone"] == seller.phone
    assert response.data["whatsapp"] == "+996700111222"

    event = ContactEvent.objects.get()
    assert event.listing_id == listing.pk
    assert event.user_id == viewer.pk
    assert ListingDailyStat.objects.get(listing=listing).phone_reveals == 1


def test_owner_contact_does_not_inflate_stats(seller):
    listing = ListingFactory(owner=seller, status=ListingStatus.ACTIVE)

    client_for(seller).post(contact_url(listing))

    assert ContactEvent.objects.count() == 0


def test_anonymous_cannot_reveal_contacts(api_client, seller):
    listing = ListingFactory(owner=seller, status=ListingStatus.ACTIVE)

    assert api_client.post(contact_url(listing)).status_code == 401


def test_thirty_first_reveal_in_an_hour_is_throttled(seller, settings, monkeypatch):
    """Живой человек за час открывает единицы номеров, скрипт — сотни."""
    from apps.common.throttling import ContactRevealThrottle

    rates = {
        **settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"],
        "contact_reveal": "30/hour",
    }
    monkeypatch.setattr(ContactRevealThrottle, "THROTTLE_RATES", rates)
    settings.REST_FRAMEWORK = {
        **settings.REST_FRAMEWORK,
        "DEFAULT_THROTTLE_RATES": rates,
    }
    cache.clear()

    listings = [ListingFactory(owner=seller, status=ListingStatus.ACTIVE) for _ in range(31)]
    client = client_for(UserFactory())

    for listing in listings[:30]:
        assert client.post(contact_url(listing)).status_code == 200

    blocked = client.post(contact_url(listings[30]))

    assert blocked.status_code == 429
    assert blocked.data["error"]["code"] == "throttled"
    assert ContactEvent.objects.count() == 30


def test_seller_card_does_not_leak_private_data(api_client, seller):
    """Аудит приватности: публичная карточка продавца не должна раскрывать личные данные."""
    response = api_client.get(reverse("users:seller-detail", args=[seller.pk]))
    assert response.status_code == 200
    data = response.data

    forbidden_keys = {
        "password",
        "iin",
        "otp",
        "token",
        "refresh",
        "access",
        "wallet",
        "balance",
        "is_staff",
        "is_superuser",
        "is_active",
        "email",
        "kyc",
        "document",
        "selfie",
        "moderation",
        "notes",
    }
    for key in forbidden_keys:
        assert key not in data, f"Private field '{key}' leaked in public seller detail response!"

    # Контакты для анонима маскируются
    assert data["contacts"]["phone"] != seller.phone
    assert "X" in data["contacts"]["phone"]
    assert data["contacts"]["whatsapp"] == ""
    assert data["contacts"]["telegram"] == ""


def test_three_different_seller_roles_detail_and_listings(api_client):
    """Проверка трёх разных ролей продавцов (owner, realtor, agency) и изоляции их листингов."""
    from apps.users.models import SellerProfile

    # 1. Собственник (owner)
    owner = UserFactory(name="Улан", seller_kind="owner")
    l_owner_act1 = ListingFactory(owner=owner, status=ListingStatus.ACTIVE)
    l_owner_act2 = ListingFactory(owner=owner, status=ListingStatus.ACTIVE)
    ListingFactory(owner=owner, status=ListingStatus.SOLD)
    ListingFactory(owner=owner, status=ListingStatus.DRAFT)

    # 2. Риелтор (realtor)
    realtor = UserFactory(name="Аскар", seller_kind="realtor")
    SellerProfile.objects.create(
        user=realtor,
        company_name="Риелтор Аскар",
        about="Помогу выгодно купить квартиру",
        experience_years=7,
        is_verified=True,
    )
    l_realtor_act = ListingFactory(owner=realtor, status=ListingStatus.ACTIVE)
    ListingFactory(owner=realtor, status=ListingStatus.SOLD)
    ListingFactory(owner=realtor, status=ListingStatus.SOLD)

    # 3. Агентство (agency)
    agency = UserFactory(name="Бишкек Элит", seller_kind="agency")
    SellerProfile.objects.create(
        user=agency,
        company_name="Агентство Недвижимости Бишкек Элит",
        about="Ведущее агентство столицы",
        experience_years=15,
        is_verified=True,
    )
    l_agency_act1 = ListingFactory(owner=agency, status=ListingStatus.ACTIVE)
    l_agency_act2 = ListingFactory(owner=agency, status=ListingStatus.ACTIVE)
    l_agency_act3 = ListingFactory(owner=agency, status=ListingStatus.ACTIVE)

    # Проверка Owner
    r_owner = api_client.get(reverse("users:seller-detail", args=[owner.pk]))
    assert r_owner.status_code == 200
    assert r_owner.data["name"] == "Улан"
    assert r_owner.data["seller_kind"] == "owner"
    assert r_owner.data["active_listings_count"] == 2
    assert r_owner.data["sold_listings_count"] == 1

    r_owner_listings = api_client.get(reverse("users:seller-listings", args=[owner.pk]))
    assert r_owner_listings.status_code == 200
    owner_slugs = {item["slug"] for item in r_owner_listings.data["results"]}
    assert owner_slugs == {l_owner_act1.slug, l_owner_act2.slug}
    for item in r_owner_listings.data["results"]:
        assert item["owner_id"] == owner.pk

    # Проверка Realtor
    r_realtor = api_client.get(reverse("users:seller-detail", args=[realtor.pk]))
    assert r_realtor.status_code == 200
    assert r_realtor.data["name"] == "Аскар"
    assert r_realtor.data["company_name"] == "Риелтор Аскар"
    assert r_realtor.data["seller_kind"] == "realtor"
    assert r_realtor.data["is_verified"] is True
    assert r_realtor.data["experience_years"] == 7
    assert r_realtor.data["active_listings_count"] == 1
    assert r_realtor.data["sold_listings_count"] == 2

    r_realtor_listings = api_client.get(reverse("users:seller-listings", args=[realtor.pk]))
    assert r_realtor_listings.status_code == 200
    realtor_slugs = {item["slug"] for item in r_realtor_listings.data["results"]}
    assert realtor_slugs == {l_realtor_act.slug}
    for item in r_realtor_listings.data["results"]:
        assert item["owner_id"] == realtor.pk

    # Проверка Agency
    r_agency = api_client.get(reverse("users:seller-detail", args=[agency.pk]))
    assert r_agency.status_code == 200
    assert r_agency.data["company_name"] == "Агентство Недвижимости Бишкек Элит"
    assert r_agency.data["seller_kind"] == "agency"
    assert r_agency.data["is_verified"] is True
    assert r_agency.data["active_listings_count"] == 3
    assert r_agency.data["sold_listings_count"] == 0

    r_agency_listings = api_client.get(reverse("users:seller-listings", args=[agency.pk]))
    assert r_agency_listings.status_code == 200
    agency_slugs = {item["slug"] for item in r_agency_listings.data["results"]}
    assert agency_slugs == {l_agency_act1.slug, l_agency_act2.slug, l_agency_act3.slug}
    for item in r_agency_listings.data["results"]:
        assert item["owner_id"] == agency.pk

