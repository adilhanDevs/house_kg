"""Тесты избранного и истории просмотров."""

from datetime import timedelta
from zoneinfo import ZoneInfo

import pytest
from django.utils import timezone
from freezegun import freeze_time
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.catalog.enums import ListingStatus
from apps.catalog.models import Listing
from apps.engagement.models import Favourite, ViewHistory
from apps.engagement.services import note_view
from apps.engagement.tasks import purge_view_history
from tests.factories import CityFactory, DistrictFactory, ListingFactory, UserFactory

FAVOURITE_URL = "/api/v1/listings/{slug}/favourite/"
FAVOURITES_URL = "/api/v1/favourites/"
HISTORY_URL = "/api/v1/view-history/"
VIEW_URL = "/api/v1/listings/{slug}/view/"

BISHKEK = ZoneInfo("Asia/Bishkek")


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


@pytest.fixture
def listing(district):
    return ListingFactory(district=district, slug="technopark-3k-aaaa")


# -- избранное ---------------------------------------------------------------


@pytest.mark.django_db
def test_double_post_does_not_duplicate(auth: APIClient, user, listing: Listing) -> None:
    first = auth.post(FAVOURITE_URL.format(slug=listing.slug))
    second = auth.post(FAVOURITE_URL.format(slug=listing.slug))

    assert first.json() == {"is_favourite": True, "favourites_count": 1}
    assert second.json() == {"is_favourite": True, "favourites_count": 1}

    assert Favourite.objects.filter(user=user, listing=listing).count() == 1
    listing.refresh_from_db()
    assert listing.favourites_count == 1


@pytest.mark.django_db
def test_delete_missing_favourite_is_ok(auth: APIClient, listing: Listing) -> None:
    response = auth.delete(FAVOURITE_URL.format(slug=listing.slug))

    assert response.status_code == 200
    assert response.json() == {"is_favourite": False, "favourites_count": 0}

    listing.refresh_from_db()
    assert listing.favourites_count == 0


@pytest.mark.django_db
def test_add_then_remove_returns_counter_back(auth: APIClient, listing: Listing) -> None:
    other = UserFactory()
    client_for(other).post(FAVOURITE_URL.format(slug=listing.slug))

    added = auth.post(FAVOURITE_URL.format(slug=listing.slug))
    removed = auth.delete(FAVOURITE_URL.format(slug=listing.slug))

    assert added.json()["favourites_count"] == 2
    assert removed.json()["favourites_count"] == 1
    assert Favourite.objects.count() == 1


@pytest.mark.django_db
def test_favourite_requires_authentication(api_client: APIClient, listing: Listing) -> None:
    assert api_client.post(FAVOURITE_URL.format(slug=listing.slug)).status_code == 401
    assert api_client.get(FAVOURITES_URL).status_code == 401


@pytest.mark.django_db
def test_favourites_list_is_ordered_by_added_at(auth: APIClient, district) -> None:
    first = ListingFactory(district=district, slug="added-first")
    second = ListingFactory(district=district, slug="added-second")

    auth.post(FAVOURITE_URL.format(slug=first.slug))
    auth.post(FAVOURITE_URL.format(slug=second.slug))

    body = auth.get(FAVOURITES_URL).json()

    assert [card["slug"] for card in body["results"]] == ["added-second", "added-first"]
    assert all(card["is_favourite"] is True for card in body["results"])


@pytest.mark.django_db
def test_archived_listing_stays_in_favourites(auth: APIClient, district) -> None:
    archived = ListingFactory(district=district, slug="archived", status=ListingStatus.ARCHIVED)
    active = ListingFactory(district=district, slug="active")
    auth.post(FAVOURITE_URL.format(slug=archived.slug))
    auth.post(FAVOURITE_URL.format(slug=active.slug))

    cards = {card["slug"]: card for card in auth.get(FAVOURITES_URL).json()["results"]}

    assert set(cards) == {"archived", "active"}
    assert cards["archived"]["is_available"] is False
    assert cards["active"]["is_available"] is True


# -- история просмотров ------------------------------------------------------


@pytest.mark.django_db
def test_note_view_ignores_anonymous(listing: Listing) -> None:
    from django.contrib.auth.models import AnonymousUser

    assert note_view(AnonymousUser(), listing) is None
    assert ViewHistory.objects.count() == 0


@pytest.mark.django_db
def test_repeat_view_updates_timestamp_and_order(auth: APIClient, user, district) -> None:
    first = ListingFactory(district=district, slug="seen-first")
    second = ListingFactory(district=district, slug="seen-second")

    with freeze_time("2026-08-20 06:00:00"):
        note_view(user, first)
    with freeze_time("2026-08-20 07:00:00"):
        note_view(user, second)

    body = auth.get(HISTORY_URL).json()
    assert [card["slug"] for card in body["results"][0]["items"]] == [
        "seen-second",
        "seen-first",
    ]

    with freeze_time("2026-08-20 08:00:00"):
        note_view(user, first)

    body = auth.get(HISTORY_URL).json()
    assert [card["slug"] for card in body["results"][0]["items"]] == [
        "seen-first",
        "seen-second",
    ]
    assert ViewHistory.objects.filter(user=user).count() == 2
    assert ViewHistory.objects.get(user=user, listing=first).view_count == 2
    assert ViewHistory.objects.get(user=user, listing=second).view_count == 1


@pytest.mark.django_db
def test_view_endpoint_writes_history(auth: APIClient, user, listing: Listing) -> None:
    auth.post(VIEW_URL.format(slug=listing.slug))

    assert ViewHistory.objects.filter(user=user, listing=listing).exists()
    assert auth.get(HISTORY_URL).json()["results"][0]["day"] == "today"


@pytest.mark.django_db
def test_history_groups_by_bishkek_days(user, district) -> None:
    """Границу суток считаем по Бишкеку, а не по UTC."""
    late_evening = ListingFactory(district=district, slug="late-evening")
    after_midnight = ListingFactory(district=district, slug="after-midnight")

    # 20 августа 23:30 по Бишкеку — это ещё 17:30 UTC.
    with freeze_time("2026-08-20 17:30:00"):
        note_view(user, late_evening)
    # 21 августа 00:30 по Бишкеку — 20 августа 18:30 UTC, но день уже другой.
    with freeze_time("2026-08-20 18:30:00"):
        note_view(user, after_midnight)

    # «Сейчас» — 21 августа 10:00 по Бишкеку. Токен выпускаем внутри окна:
    # снаружи он был бы «из будущего» для замороженного времени.
    with freeze_time("2026-08-21 04:00:00"):
        body = client_for(user).get(HISTORY_URL).json()

    days = [(group["day"], [card["slug"] for card in group["items"]]) for group in body["results"]]
    assert days == [
        ("today", ["after-midnight"]),
        ("yesterday", ["late-evening"]),
    ]


@pytest.mark.django_db
def test_history_labels_older_days(user, district) -> None:
    old = ListingFactory(district=district, slug="old")

    with freeze_time("2026-08-18 06:00:00"):
        note_view(user, old)
    with freeze_time("2026-08-21 06:00:00"):
        body = client_for(user).get(HISTORY_URL).json()

    assert body["results"][0]["day"] == "2026-08-18"
    assert body["results"][0]["day_label"] == "18 августа"


@pytest.mark.django_db
def test_history_paginates_by_whole_days(user, district) -> None:
    for day in range(1, 6):
        listing = ListingFactory(district=district, slug=f"day-{day}")
        with freeze_time(f"2026-08-{10 + day:02d} 06:00:00"):
            note_view(user, listing)

    with freeze_time("2026-08-20 06:00:00"):
        client = client_for(user)
        first_page = client.get(HISTORY_URL).json()
        assert len(first_page["results"]) == 3
        assert first_page["next"] is not None

        second_page = client.get(first_page["next"]).json()

    assert [group["day"] for group in second_page["results"]] == ["2026-08-12", "2026-08-11"]
    assert second_page["next"] is None


@pytest.mark.django_db
def test_history_shows_availability_and_viewed_at(auth: APIClient, user, district) -> None:
    archived = ListingFactory(district=district, slug="archived", status=ListingStatus.ARCHIVED)
    note_view(user, archived)

    card = auth.get(HISTORY_URL).json()["results"][0]["items"][0]

    assert card["is_available"] is False
    assert card["viewed_at"]


@pytest.mark.django_db
def test_delete_history_by_slugs(auth: APIClient, user, district) -> None:
    first = ListingFactory(district=district, slug="first")
    second = ListingFactory(district=district, slug="second")
    note_view(user, first)
    note_view(user, second)

    response = auth.delete(HISTORY_URL, {"listing_slugs": ["first"]}, format="json")

    assert response.status_code == 204
    assert list(ViewHistory.objects.values_list("listing__slug", flat=True)) == ["second"]


@pytest.mark.django_db
def test_delete_all_history(auth: APIClient, user, district) -> None:
    for index in range(3):
        note_view(user, ListingFactory(district=district, slug=f"seen-{index}"))
    stranger = UserFactory()
    note_view(stranger, ListingFactory(district=district, slug="stranger"))

    response = auth.delete(HISTORY_URL, {"all": True}, format="json")

    assert response.status_code == 204
    assert ViewHistory.objects.filter(user=user).count() == 0
    # Чужая история не пострадала.
    assert ViewHistory.objects.filter(user=stranger).count() == 1


@pytest.mark.django_db
def test_delete_history_without_body(auth: APIClient, user, district) -> None:
    note_view(user, ListingFactory(district=district))

    assert auth.delete(HISTORY_URL).status_code == 204
    assert ViewHistory.objects.count() == 0


@pytest.mark.django_db
def test_purge_old_view_history(user, district) -> None:
    fresh = ListingFactory(district=district, slug="fresh")
    stale = ListingFactory(district=district, slug="stale")
    note_view(user, fresh)
    note_view(user, stale)
    ViewHistory.objects.filter(listing=stale).update(viewed_at=timezone.now() - timedelta(days=91))

    assert purge_view_history() == 1
    assert list(ViewHistory.objects.values_list("listing__slug", flat=True)) == ["fresh"]
