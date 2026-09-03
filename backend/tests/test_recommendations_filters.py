"""Фильтры пользователя строже персонализации.

Персонализация переставляет подходящие объявления, а не расширяет выборку:
попросив однокомнатную до 60 тысяч, человек не должен увидеть двухкомнатную
за сто — какой бы высокий балл она ни набрала по его вкусам.
"""

from decimal import Decimal

import pytest
from rest_framework.test import APIClient

from apps.catalog.enums import ListingStatus, PropertyKind
from tests.factories import ListingFactory, UserFactory

URL = "/api/v1/recommendations/listings/"
SESSION = "session-filters-test"


def _get(**params):
    return APIClient().get(URL, {"session_id": SESSION, **params})


@pytest.mark.django_db
def test_rooms_filter_is_strict() -> None:
    owner = UserFactory()
    one_room = ListingFactory(owner=owner, status=ListingStatus.ACTIVE, rooms=1)
    two_rooms = ListingFactory(owner=owner, status=ListingStatus.ACTIVE, rooms=2)

    slugs = {item["slug"] for item in _get(rooms="1").data["results"]}

    assert one_room.slug in slugs
    assert two_rooms.slug not in slugs, "персонализация не должна обходить фильтр"


@pytest.mark.django_db
def test_price_bounds_are_strict() -> None:
    owner = UserFactory()
    cheap = ListingFactory(owner=owner, status=ListingStatus.ACTIVE, price=Decimal("50000.00"))
    pricey = ListingFactory(owner=owner, status=ListingStatus.ACTIVE, price=Decimal("150000.00"))

    slugs = {item["slug"] for item in _get(price_max="60000").data["results"]}

    assert cheap.slug in slugs
    assert pricey.slug not in slugs


@pytest.mark.django_db
def test_kind_filter_is_strict() -> None:
    owner = UserFactory()
    flat = ListingFactory(owner=owner, status=ListingStatus.ACTIVE, kind=PropertyKind.APARTMENT)
    house = ListingFactory(owner=owner, status=ListingStatus.ACTIVE, kind=PropertyKind.HOUSE)

    slugs = {item["slug"] for item in _get(kind="house").data["results"]}

    assert house.slug in slugs
    assert flat.slug not in slugs


@pytest.mark.django_db
def test_without_filters_the_whole_pool_is_eligible() -> None:
    """Без фильтров лента остаётся персонализированной по всей выдаче."""
    owner = UserFactory()
    listings = [
        ListingFactory(owner=owner, status=ListingStatus.ACTIVE, rooms=rooms) for rooms in (1, 2, 3)
    ]

    slugs = {item["slug"] for item in _get().data["results"]}

    for listing in listings:
        assert listing.slug in slugs


@pytest.mark.django_db
def test_service_keys_are_not_treated_as_filters() -> None:
    """session_id и курсор — служебные, объявления по ним не отсеиваются."""
    owner = UserFactory()
    listing = ListingFactory(owner=owner, status=ListingStatus.ACTIVE)

    response = _get(feed_session_id="feed-abc", limit="20")

    assert response.status_code == 200
    assert listing.slug in {item["slug"] for item in response.data["results"]}
