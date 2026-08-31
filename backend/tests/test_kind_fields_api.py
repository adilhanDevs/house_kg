"""Поведение API при полях, зависящих от типа недвижимости."""

import pytest
from django.utils import timezone
from rest_framework.test import APIClient

from apps.catalog.enums import CommercialPurpose, ListingStatus, PropertyKind
from apps.catalog.services import missing_fields_for_publish


def _make(district, owner, **kwargs):  # noqa: ANN001, ANN003, ANN202
    from tests.factories import ListingFactory

    kwargs.setdefault("status", ListingStatus.DRAFT)
    return ListingFactory(owner=owner, district=district, city=district.city, **kwargs)


@pytest.mark.django_db
def test_plot_does_not_require_rooms_or_floors(district, pro_user):  # noqa: ANN001
    plot = _make(district, pro_user, kind=PropertyKind.PLOT, rooms=0, floor=0, floors=0, land_area=8)

    missing = missing_fields_for_publish(plot)

    assert "rooms" not in missing
    assert "floor" not in missing
    assert "floors" not in missing


@pytest.mark.django_db
def test_plot_requires_land_area(district, pro_user):  # noqa: ANN001
    plot = _make(district, pro_user, kind=PropertyKind.PLOT, land_area=None)

    assert "land_area" in missing_fields_for_publish(plot)


@pytest.mark.django_db
def test_apartment_still_requires_rooms(district, pro_user):  # noqa: ANN001
    flat = _make(district, pro_user, kind=PropertyKind.APARTMENT, rooms=0, floor=0, floors=0)

    missing = missing_fields_for_publish(flat)

    assert "rooms" in missing
    assert "floor" in missing


@pytest.mark.django_db
def test_patch_drops_rooms_for_plot(district, pro_user, pro_client: APIClient):  # noqa: ANN001
    plot = _make(district, pro_user, kind=PropertyKind.PLOT, rooms=0)

    response = pro_client.patch(
        f"/api/v1/listings/{plot.slug}/",
        {"rooms": 3, "land_area": "8.00"},
        format="json",
    )

    assert response.status_code == 200, response.content
    plot.refresh_from_db()
    assert plot.rooms == 0
    assert str(plot.land_area) == "8.00"


@pytest.mark.django_db
def test_patch_saves_commercial_purpose(district, pro_user, pro_client: APIClient):  # noqa: ANN001
    shop = _make(district, pro_user, kind=PropertyKind.COMMERCIAL)

    response = pro_client.patch(
        f"/api/v1/listings/{shop.slug}/",
        {"commercial_purpose": CommercialPurpose.SHOP, "has_separate_entrance": True},
        format="json",
    )

    assert response.status_code == 200, response.content
    shop.refresh_from_db()
    assert shop.commercial_purpose == CommercialPurpose.SHOP
    assert shop.has_separate_entrance is True


@pytest.mark.django_db
def test_list_response_exposes_land_area(district, pro_user, api_client: APIClient):  # noqa: ANN001
    _make(
        district,
        pro_user,
        kind=PropertyKind.PLOT,
        land_area=8,
        status=ListingStatus.ACTIVE,
        published_at=timezone.now(),
    )

    response = api_client.get("/api/v1/listings/")

    assert response.status_code == 200
    assert "land_area" in response.json()["results"][0]


@pytest.mark.django_db
def test_filter_by_commercial_purpose(district, pro_user, api_client: APIClient):  # noqa: ANN001
    for purpose in (CommercialPurpose.SHOP, CommercialPurpose.OFFICE):
        _make(
            district,
            pro_user,
            kind=PropertyKind.COMMERCIAL,
            commercial_purpose=purpose,
            status=ListingStatus.ACTIVE,
            published_at=timezone.now(),
        )

    response = api_client.get("/api/v1/listings/?commercial_purpose=shop")

    results = response.json()["results"]
    assert len(results) == 1
    assert results[0]["slug"]


@pytest.mark.django_db
def test_filter_options_expose_new_dictionaries(api_client: APIClient):
    response = api_client.get("/api/v1/catalog/filter-options/")

    payload = response.json()
    assert {item["value"] for item in payload["plot_purposes"]} == {
        "ihs",
        "garden",
        "agricultural",
        "commercial",
    }
    assert "commercial_purposes" in payload
    assert "building_lines" in payload
