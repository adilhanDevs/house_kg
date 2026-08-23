"""Тесты создания и жизненного цикла объявления."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.test import override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.catalog.enums import ListingStatus, PropertyKind
from apps.catalog.models import Listing
from apps.catalog.tasks import expire_listings
from apps.notifications.models import Notification
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
RESTORE_URL = "/api/v1/listings/{slug}/restore/"
SOLD_URL = "/api/v1/listings/{slug}/mark-sold/"
BUMP_URL = "/api/v1/listings/{slug}/bump/"
MY_URL = "/api/v1/users/me/listings/"
LIST_URL = "/api/v1/listings/"


def client_for(user) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
    return client


@pytest.fixture
def district(db):
    return DistrictFactory(city=CityFactory(slug="bishkek", is_default=True), slug="technopark")


@pytest.fixture
def user(db):
    return UserFactory()


@pytest.fixture
def auth(user):
    return client_for(user)


def fill_draft(auth: APIClient, slug: str, district, **overrides) -> None:
    payload = {
        "district": district.slug,
        "price": "102000.00",
        "area": "92.00",
        "rooms": 3,
        "floor": 8,
        "floors": 12,
        **overrides,
    }
    response = auth.patch(DETAIL_URL.format(slug=slug), payload, format="json")
    assert response.status_code == 200, response.json()


# -- черновик ----------------------------------------------------------------


@pytest.mark.django_db
def test_draft_is_created_once(auth: APIClient, user) -> None:
    first = auth.post(DRAFT_URL)
    second = auth.post(DRAFT_URL)

    assert first.status_code == 200
    assert first.json()["slug"] == second.json()["slug"]
    assert Listing.objects.filter(owner=user, status=ListingStatus.DRAFT).count() == 1


@pytest.mark.django_db
def test_draft_has_flutter_defaults(auth: APIClient, user) -> None:
    body = auth.post(DRAFT_URL).json()

    assert body["kind"] == PropertyKind.NEW_BUILDING
    assert body["rooms"] == 1
    assert body["floor"] == 1
    assert body["floors"] == 1
    assert body["currency"] == "USD"
    assert body["seller_kind"] == "owner"
    assert body["allow_media_download"] is True
    assert body["completeness"] == {
        "is_complete": False,
        "missing_fields": ["district", "price", "area", "photos"],
    }


@pytest.mark.django_db
def test_draft_is_not_public(api_client: APIClient, auth: APIClient) -> None:
    slug = auth.post(DRAFT_URL).json()["slug"]

    assert api_client.get(DETAIL_URL.format(slug=slug)).status_code == 404
    assert api_client.get(LIST_URL).json()["count"] == 0


@pytest.mark.django_db
def test_patch_saves_partial_data(auth: APIClient, district) -> None:
    slug = auth.post(DRAFT_URL).json()["slug"]

    first = auth.patch(DETAIL_URL.format(slug=slug), {"price": "99000.00"}, format="json")
    second = auth.patch(DETAIL_URL.format(slug=slug), {"district": district.slug}, format="json")

    assert first.status_code == second.status_code == 200
    listing = Listing.objects.get(slug=slug)
    assert listing.price == Decimal("99000.00")
    assert listing.district == district
    # Город подставляется по району.
    assert listing.city == district.city
    assert second.json()["completeness"]["missing_fields"] == ["area", "photos"]


@pytest.mark.django_db
def test_patch_requires_ownership(auth: APIClient, district) -> None:
    stranger_listing = ListingFactory(district=district, status=ListingStatus.ACTIVE)

    response = auth.patch(
        DETAIL_URL.format(slug=stranger_listing.slug), {"price": "1.00"}, format="json"
    )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "permission_denied"


@pytest.mark.django_db
def test_foreign_draft_is_invisible(auth: APIClient, district) -> None:
    stranger_draft = ListingFactory(district=district, status=ListingStatus.DRAFT)

    # Чужой черновик — 404: сам факт его существования не раскрываем.
    assert (
        auth.patch(
            DETAIL_URL.format(slug=stranger_draft.slug), {"price": "1.00"}, format="json"
        ).status_code
        == 404
    )


@pytest.mark.django_db
def test_price_drop_on_active_listing_saves_old_price(auth: APIClient, user, district) -> None:
    listing = ListingFactory(
        owner=user, district=district, status=ListingStatus.ACTIVE, price=Decimal("107000")
    )

    auth.patch(DETAIL_URL.format(slug=listing.slug), {"price": "102000.00"}, format="json")

    listing.refresh_from_db()
    assert listing.price == Decimal("102000.00")
    assert listing.old_price == Decimal("107000.00")


@pytest.mark.django_db
def test_price_growth_does_not_touch_old_price(auth: APIClient, user, district) -> None:
    listing = ListingFactory(
        owner=user, district=district, status=ListingStatus.ACTIVE, price=Decimal("100000")
    )

    auth.patch(DETAIL_URL.format(slug=listing.slug), {"price": "120000.00"}, format="json")

    listing.refresh_from_db()
    assert listing.old_price is None


# -- публикация --------------------------------------------------------------


@pytest.mark.django_db
def test_publish_without_photos_fails(auth: APIClient, district) -> None:
    slug = auth.post(DRAFT_URL).json()["slug"]
    fill_draft(auth, slug, district)

    response = auth.post(PUBLISH_URL.format(slug=slug))

    assert response.status_code == 400
    error = response.json()["error"]
    assert error["code"] == "validation_error"
    assert error["details"]["missing_fields"] == ["photos"]
    assert Listing.objects.get(slug=slug).status == ListingStatus.DRAFT


@pytest.mark.django_db
def test_publish_goes_to_moderation(auth: APIClient, user, district) -> None:
    slug = auth.post(DRAFT_URL).json()["slug"]
    fill_draft(auth, slug, district)
    ListingMediaFactory(listing=Listing.objects.get(slug=slug), order=0, is_cover=True)

    response = auth.post(PUBLISH_URL.format(slug=slug))

    assert response.status_code == 200
    assert response.json()["status"] == ListingStatus.PENDING
    listing = Listing.objects.get(slug=slug)
    assert listing.published_at is None


@pytest.mark.django_db
def test_trusted_user_publishes_immediately(district) -> None:
    user = UserFactory(is_trusted=True)
    auth = client_for(user)
    slug = auth.post(DRAFT_URL).json()["slug"]
    fill_draft(auth, slug, district)
    ListingMediaFactory(listing=Listing.objects.get(slug=slug), order=0, is_cover=True)

    body = auth.post(PUBLISH_URL.format(slug=slug)).json()

    assert body["status"] == ListingStatus.ACTIVE
    listing = Listing.objects.get(slug=slug)
    assert listing.published_at is not None
    assert listing.expires_at is not None
    assert (listing.expires_at - listing.published_at).days == 30


@pytest.mark.django_db
@override_settings(FREE_ACTIVE_LISTINGS=3)
def test_fourth_publication_is_rejected(district) -> None:
    user = UserFactory(is_trusted=True)
    auth = client_for(user)
    for _ in range(3):
        ListingFactory(owner=user, district=district, status=ListingStatus.ACTIVE)

    slug = auth.post(DRAFT_URL).json()["slug"]
    fill_draft(auth, slug, district)
    ListingMediaFactory(listing=Listing.objects.get(slug=slug), order=0, is_cover=True)

    response = auth.post(PUBLISH_URL.format(slug=slug))

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "conflict"
    # Лимит теперь зависит от тарифа; без подписки это FREE_ACTIVE_LISTINGS.
    assert "лимит активных объявлений" in response.json()["error"]["message"]
    assert Listing.objects.get(slug=slug).status == ListingStatus.DRAFT


@pytest.mark.django_db
def test_publish_requires_ownership(auth: APIClient, district) -> None:
    stranger = ListingFactory(district=district, status=ListingStatus.DRAFT)
    other = ListingFactory(district=district, status=ListingStatus.REJECTED)

    assert auth.post(PUBLISH_URL.format(slug=stranger.slug)).status_code == 404
    assert auth.post(PUBLISH_URL.format(slug=other.slug)).status_code == 403


# -- действия владельца ------------------------------------------------------


@pytest.mark.django_db
def test_archive_restore_and_sold(auth: APIClient, user, district) -> None:
    listing = ListingFactory(owner=user, district=district, status=ListingStatus.ACTIVE)

    archived = auth.post(ARCHIVE_URL.format(slug=listing.slug))
    assert archived.json()["status"] == ListingStatus.ARCHIVED

    restored = auth.post(RESTORE_URL.format(slug=listing.slug))
    assert restored.json()["status"] == ListingStatus.ACTIVE
    listing.refresh_from_db()
    assert listing.expires_at > timezone.now() + timedelta(days=29)

    sold = auth.post(SOLD_URL.format(slug=listing.slug))
    assert sold.json()["status"] == ListingStatus.SOLD


@pytest.mark.django_db
def test_sold_listing_leaves_catalog(api_client: APIClient, auth: APIClient, user, district):
    listing = ListingFactory(owner=user, district=district, status=ListingStatus.ACTIVE)
    assert api_client.get(LIST_URL).json()["count"] == 1

    auth.post(SOLD_URL.format(slug=listing.slug))

    assert api_client.get(LIST_URL).json()["count"] == 0


@pytest.mark.django_db
@override_settings(FREE_ACTIVE_LISTINGS=1)
def test_restore_respects_limit(auth: APIClient, user, district) -> None:
    archived = ListingFactory(owner=user, district=district, status=ListingStatus.ARCHIVED)
    ListingFactory(owner=user, district=district, status=ListingStatus.ACTIVE)

    response = auth.post(RESTORE_URL.format(slug=archived.slug))

    assert response.status_code == 409
    archived.refresh_from_db()
    assert archived.status == ListingStatus.ARCHIVED


@pytest.mark.django_db
def test_soft_delete(auth: APIClient, api_client: APIClient, user, district) -> None:
    listing = ListingFactory(owner=user, district=district, status=ListingStatus.ACTIVE)

    assert auth.delete(DETAIL_URL.format(slug=listing.slug)).status_code == 204

    assert Listing.objects.filter(pk=listing.pk).count() == 0
    assert Listing.all_objects.filter(pk=listing.pk, is_deleted=True).count() == 1
    assert api_client.get(DETAIL_URL.format(slug=listing.slug)).status_code == 404
    assert auth.get(MY_URL).json()["count"] == 0


@pytest.mark.django_db
def test_bump_twice_is_throttled(auth: APIClient, user, district) -> None:
    listing = ListingFactory(
        owner=user,
        district=district,
        status=ListingStatus.ACTIVE,
        published_at=timezone.now() - timedelta(days=5),
    )

    first = auth.post(BUMP_URL.format(slug=listing.slug))
    second = auth.post(BUMP_URL.format(slug=listing.slug))

    assert first.status_code == 200
    assert second.status_code == 429
    error = second.json()["error"]
    assert error["code"] == "throttled"
    assert 0 < error["details"]["retry_after"] <= 24 * 3600

    listing.refresh_from_db()
    assert listing.published_at > timezone.now() - timedelta(minutes=1)


# -- мои объявления ----------------------------------------------------------


@pytest.mark.django_db
def test_my_listings_order_and_filter(auth: APIClient, user, district) -> None:
    now = timezone.now()
    ListingFactory(
        owner=user, district=district, status=ListingStatus.ACTIVE, published_at=now, slug="active"
    )
    ListingFactory(owner=user, district=district, status=ListingStatus.DRAFT, slug="draft")
    ListingFactory(owner=user, district=district, status=ListingStatus.REJECTED, slug="rejected")
    ListingFactory(district=district, status=ListingStatus.ACTIVE, slug="stranger")

    body = auth.get(MY_URL).json()
    slugs = [card["slug"] for card in body["results"]]

    assert "stranger" not in slugs
    # Черновики и отклонённые — наверх, они требуют внимания.
    assert set(slugs[:2]) == {"draft", "rejected"}
    assert slugs[-1] == "active"

    only_drafts = auth.get(MY_URL, {"status": "draft"}).json()
    assert [card["slug"] for card in only_drafts["results"]] == ["draft"]


@pytest.mark.django_db
def test_my_listings_include_stats(auth: APIClient, user, district) -> None:
    listing = ListingFactory(
        owner=user,
        district=district,
        status=ListingStatus.ACTIVE,
        views_count=42,
        favourites_count=7,
        promoted_until=timezone.now() + timedelta(days=1),
    )
    ListingMediaFactory(listing=listing, order=0, is_cover=True)

    card = auth.get(MY_URL).json()["results"][0]

    assert card["views_count"] == 42
    assert card["favourites_count"] == 7
    assert card["is_promoted"] is True
    assert card["promoted_until"]
    assert card["completeness"]["is_complete"] is True


@pytest.mark.django_db
def test_my_listings_require_authentication(api_client: APIClient) -> None:
    assert api_client.get(MY_URL).status_code == 401


# -- истечение срока ---------------------------------------------------------


@pytest.mark.django_db
def test_expire_listings_archives_and_notifies(user, district) -> None:
    stale = ListingFactory(
        owner=user,
        district=district,
        status=ListingStatus.ACTIVE,
        expires_at=timezone.now() - timedelta(hours=1),
    )
    soon = ListingFactory(
        owner=user,
        district=district,
        status=ListingStatus.ACTIVE,
        expires_at=timezone.now() + timedelta(days=2),
    )
    fresh = ListingFactory(
        owner=user,
        district=district,
        status=ListingStatus.ACTIVE,
        expires_at=timezone.now() + timedelta(days=20),
    )

    result = expire_listings()

    assert result == {"archived": 1, "warned": 1}
    stale.refresh_from_db()
    soon.refresh_from_db()
    fresh.refresh_from_db()
    assert stale.status == ListingStatus.ARCHIVED
    assert soon.status == ListingStatus.ACTIVE
    assert fresh.status == ListingStatus.ACTIVE

    kinds = {item.payload.get("kind") for item in Notification.objects.all()}
    assert kinds == {"listing_expired", "listing_expiring"}
