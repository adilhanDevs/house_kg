"""Тесты публичных эндпоинтов каталога."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.catalog.enums import ListingStatus, PropertyKind
from apps.catalog.models import Listing
from apps.engagement.models import ViewHistory
from tests.factories import (
    CityFactory,
    DistrictFactory,
    FavouriteFactory,
    ListingFactory,
    ListingMediaFactory,
    UserFactory,
)

LIST_URL = "/api/v1/listings/"
DETAIL_URL = "/api/v1/listings/{slug}/"
VIEW_URL = "/api/v1/listings/{slug}/view/"
FEATURED_URL = "/api/v1/listings/featured/"
SIMILAR_URL = "/api/v1/listings/{slug}/similar/"


def photo(name: str = "cover.jpg") -> SimpleUploadedFile:
    return SimpleUploadedFile(name, b"fake-photo", content_type="image/jpeg")


def client_for(user) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
    return client


@pytest.fixture
def district(db):
    return DistrictFactory(city=CityFactory(slug="bishkek", is_default=True), slug="technopark")


@pytest.fixture
def listing(district):
    item = ListingFactory(
        district=district,
        kind=PropertyKind.APARTMENT,
        price=Decimal("102000"),
        published_at=timezone.now(),
    )
    ListingMediaFactory(listing=item, order=0, is_cover=True, file=photo())
    ListingMediaFactory(listing=item, order=1, file=photo("second.jpg"))
    return item


# -- список ------------------------------------------------------------------


@pytest.mark.django_db
def test_list_returns_only_active(api_client: APIClient, district) -> None:
    active = ListingFactory(district=district, status=ListingStatus.ACTIVE)
    for status_value in (ListingStatus.DRAFT, ListingStatus.PENDING, ListingStatus.ARCHIVED):
        ListingFactory(district=district, status=status_value)

    body = api_client.get(LIST_URL).json()

    assert body["count"] == 1
    assert [card["slug"] for card in body["results"]] == [active.slug]


@pytest.mark.django_db
def test_promoted_listing_goes_first(api_client: APIClient, district) -> None:
    now = timezone.now()
    ListingFactory(district=district, published_at=now, slug="newest")
    ListingFactory(district=district, published_at=now - timedelta(days=1), slug="middle")
    promoted = ListingFactory(
        district=district,
        published_at=now - timedelta(days=10),
        promoted_until=now + timedelta(days=1),
        slug="promoted",
    )

    for ordering in ("-published_at", "price", "-price", "-views_count", "area"):
        results = api_client.get(LIST_URL, {"ordering": ordering}).json()["results"]
        assert results[0]["slug"] == promoted.slug, ordering
        assert results[0]["is_promoted"] is True


@pytest.mark.django_db
def test_ordering_by_price(api_client: APIClient, district) -> None:
    ListingFactory(district=district, price=Decimal("300000"), slug="expensive")
    ListingFactory(district=district, price=Decimal("50000"), slug="cheap")

    results = api_client.get(LIST_URL, {"ordering": "price"}).json()["results"]

    assert [card["slug"] for card in results] == ["cheap", "expensive"]


@pytest.mark.django_db
def test_unknown_ordering_falls_back_to_default(api_client: APIClient, district) -> None:
    now = timezone.now()
    ListingFactory(district=district, published_at=now - timedelta(days=1), slug="older")
    ListingFactory(district=district, published_at=now, slug="newer")

    results = api_client.get(LIST_URL, {"ordering": "; DROP TABLE"}).json()["results"]

    assert [card["slug"] for card in results] == ["newer", "older"]


@pytest.mark.django_db
def test_card_contains_cover_and_counts(api_client: APIClient, listing: Listing) -> None:
    card = api_client.get(LIST_URL).json()["results"][0]

    assert card["slug"] == listing.slug
    assert card["kind"] == PropertyKind.APARTMENT
    assert card["kind_label"] == "Квартиры"
    assert card["district"]["slug"] == "technopark"
    assert card["cover_url"].startswith("http")
    assert card["photos_count"] == 2
    assert card["is_favourite"] is False
    assert card["price"] == "102000.00"


@pytest.mark.django_db
def test_is_favourite_for_authenticated(listing: Listing) -> None:
    user = UserFactory()
    FavouriteFactory(user=user, listing=listing)
    other = ListingFactory(district=listing.district)

    results = client_for(user).get(LIST_URL).json()["results"]

    flags = {card["slug"]: card["is_favourite"] for card in results}
    assert flags[listing.slug] is True
    assert flags[other.slug] is False


@pytest.mark.django_db
def test_list_has_no_n_plus_one(api_client: APIClient, district, django_assert_max_num_queries):
    for index in range(12):
        item = ListingFactory(district=district, slug=f"listing-{index}")
        ListingMediaFactory(listing=item, order=0, is_cover=True, file=photo())
        ListingMediaFactory(listing=item, order=1, file=photo())

    with django_assert_max_num_queries(5):
        small = api_client.get(LIST_URL, {"page_size": 3})

    with django_assert_max_num_queries(5):
        large = api_client.get(LIST_URL, {"page_size": 100})

    assert len(small.json()["results"]) == 3
    assert len(large.json()["results"]) == 12
    assert all(card["cover_url"] for card in large.json()["results"])


# -- карточка ----------------------------------------------------------------


@pytest.mark.django_db
def test_detail_returns_full_card(api_client: APIClient, listing: Listing) -> None:
    body = api_client.get(DETAIL_URL.format(slug=listing.slug)).json()

    assert body["slug"] == listing.slug
    assert body["description"] == listing.description
    assert len(body["media"]) == 2
    assert body["media"][0]["is_cover"] is True
    assert body["media"][0]["url"].startswith("http")
    assert body["seller"]["kind"] == listing.seller_kind
    assert body["seller"]["listings_count"] == 1


@pytest.mark.django_db
def test_anonymous_gets_masked_phone(api_client: APIClient, listing: Listing) -> None:
    listing.owner.phone = "+996700123456"
    listing.owner.save()

    seller = api_client.get(DETAIL_URL.format(slug=listing.slug)).json()["seller"]

    assert seller["phone"] == "+996 7XX XXX XX6"


@pytest.mark.django_db
def test_authenticated_gets_full_phone(listing: Listing) -> None:
    listing.owner.phone = "+996700123456"
    listing.owner.save()

    seller = client_for(UserFactory()).get(DETAIL_URL.format(slug=listing.slug)).json()["seller"]

    assert seller["phone"] == "+996700123456"


@pytest.mark.django_db
def test_detail_hides_inactive(api_client: APIClient, district) -> None:
    draft = ListingFactory(district=district, status=ListingStatus.DRAFT)

    assert api_client.get(DETAIL_URL.format(slug=draft.slug)).status_code == 404


# -- отметка просмотра -------------------------------------------------------


@pytest.mark.django_db
def test_view_is_counted_once_per_window(api_client: APIClient, listing: Listing) -> None:
    first = api_client.post(VIEW_URL.format(slug=listing.slug))
    second = api_client.post(VIEW_URL.format(slug=listing.slug))

    assert first.status_code == 200
    assert first.json() == {"views_count": 1}
    assert second.status_code == 200
    assert second.json() == {"views_count": 1}

    listing.refresh_from_db()
    assert listing.views_count == 1


@pytest.mark.django_db
def test_view_from_another_user_is_counted(listing: Listing) -> None:
    first_user = UserFactory()
    second_user = UserFactory()

    client_for(first_user).post(VIEW_URL.format(slug=listing.slug))
    response = client_for(second_user).post(VIEW_URL.format(slug=listing.slug))

    assert response.json() == {"views_count": 2}
    assert ViewHistory.objects.count() == 2


@pytest.mark.django_db
def test_view_updates_history_without_duplicates(listing: Listing) -> None:
    user = UserFactory()
    client = client_for(user)

    client.post(VIEW_URL.format(slug=listing.slug))
    client.post(VIEW_URL.format(slug=listing.slug))

    assert ViewHistory.objects.filter(user=user, listing=listing).count() == 1


# -- подборки ----------------------------------------------------------------


@pytest.mark.django_db
def test_featured_groups_by_kind(api_client: APIClient, district) -> None:
    for kind in PropertyKind.values:
        for index in range(5):
            ListingFactory(
                district=district,
                kind=kind,
                published_at=timezone.now() - timedelta(hours=index),
            )

    body = api_client.get(FEATURED_URL).json()

    assert set(body) == set(PropertyKind.values)
    assert all(len(cards) == 4 for cards in body.values())
    assert all(card["kind"] == "plot" for card in body["plot"])


@pytest.mark.django_db
def test_featured_is_cached(api_client: APIClient, district, django_assert_num_queries) -> None:
    ListingFactory(district=district, kind=PropertyKind.APARTMENT)
    api_client.get(FEATURED_URL)

    with django_assert_num_queries(0):
        api_client.get(FEATURED_URL)


@pytest.mark.django_db
def test_featured_favourites_are_personal(district) -> None:
    listing = ListingFactory(district=district, kind=PropertyKind.APARTMENT)
    user = UserFactory()
    FavouriteFactory(user=user, listing=listing)

    APIClient().get(FEATURED_URL)  # прогреваем кэш анонимным запросом
    body = client_for(user).get(FEATURED_URL).json()

    assert body["apartment"][0]["is_favourite"] is True
    assert APIClient().get(FEATURED_URL).json()["apartment"][0]["is_favourite"] is False


# -- похожие -----------------------------------------------------------------


@pytest.mark.django_db
def test_similar_excludes_self_and_inactive(api_client: APIClient, district) -> None:
    base = ListingFactory(district=district, price=Decimal("100000"), slug="base")
    same_district = ListingFactory(district=district, price=Decimal("110000"), slug="neighbour")
    ListingFactory(
        district=district,
        price=Decimal("100000"),
        slug="archived",
        status=ListingStatus.ARCHIVED,
    )
    ListingFactory(district=district, price=Decimal("400000"), slug="too-expensive")

    slugs = [card["slug"] for card in api_client.get(SIMILAR_URL.format(slug="base")).json()]

    assert base.slug not in slugs
    assert "archived" not in slugs
    assert "too-expensive" not in slugs
    assert same_district.slug in slugs


@pytest.mark.django_db
def test_similar_prefers_same_district_then_price(api_client: APIClient) -> None:
    city = CityFactory(slug="bishkek", is_default=True)
    home = DistrictFactory(city=city, slug="technopark")
    away = DistrictFactory(city=city, slug="asanbay")

    ListingFactory(district=home, kind=PropertyKind.APARTMENT, price=Decimal("100000"), slug="base")
    ListingFactory(
        district=away, kind=PropertyKind.APARTMENT, price=Decimal("101000"), slug="away-close"
    )
    ListingFactory(
        district=home, kind=PropertyKind.APARTMENT, price=Decimal("115000"), slug="home-far"
    )

    slugs = [card["slug"] for card in api_client.get(SIMILAR_URL.format(slug="base")).json()]

    assert slugs == ["home-far", "away-close"]


@pytest.mark.django_db
def test_similar_returns_at_most_six(api_client: APIClient, district) -> None:
    ListingFactory(district=district, price=Decimal("100000"), slug="base")
    for index in range(10):
        ListingFactory(district=district, price=Decimal("100000"), slug=f"neighbour-{index}")

    assert len(api_client.get(SIMILAR_URL.format(slug="base")).json()) == 6
