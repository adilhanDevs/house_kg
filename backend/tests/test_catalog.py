"""Тесты справочников каталога и опций экрана фильтра."""

from decimal import Decimal

import pytest
from rest_framework.test import APIClient

from apps.catalog.enums import (
    BuildingLine,
    CommercialPurpose,
    ListingStatus,
    PlotPurpose,
    PropertyKind,
    SellerKind,
)
from apps.catalog.models import City, District
from tests.factories import BuilderFactory, CityFactory, DistrictFactory, ListingFactory

CITIES_URL = "/api/v1/catalog/cities/"
DISTRICTS_URL = "/api/v1/catalog/districts/"
BUILDERS_URL = "/api/v1/catalog/builders/"
OPTIONS_URL = "/api/v1/catalog/filter-options/"


@pytest.fixture
def bishkek(db) -> City:
    return CityFactory(name="Бишкек", slug="bishkek", is_default=True)


@pytest.fixture
def technopark(bishkek: City) -> District:
    return DistrictFactory(
        city=bishkek,
        name="Технопарк",
        slug="technopark",
        latitude=Decimal("42.876000"),
        longitude=Decimal("74.588000"),
    )


# -- справочники -------------------------------------------------------------


@pytest.mark.django_db
def test_cities_list(api_client: APIClient, bishkek: City) -> None:
    CityFactory(name="Ош", slug="osh", order=1)
    CityFactory(name="Скрытый", slug="hidden", is_active=False)

    response = api_client.get(CITIES_URL)

    assert response.status_code == 200
    body = response.json()
    assert [city["slug"] for city in body] == ["bishkek", "osh"]
    assert body[0] == {
        "id": bishkek.id,
        "name": "Бишкек",
        "slug": "bishkek",
        "is_default": True,
    }


@pytest.mark.django_db
def test_districts_are_filtered_by_city(
    api_client: APIClient, bishkek: City, technopark: District
) -> None:
    osh = CityFactory(name="Ош", slug="osh")
    DistrictFactory(city=osh, name="Западный", slug="zapadny")

    body = api_client.get(DISTRICTS_URL, {"city": "bishkek"}).json()

    assert len(body) == 1
    assert body[0] == {
        "id": technopark.id,
        "name": "Технопарк",
        "slug": "technopark",
        "city": "bishkek",
        "latitude": "42.876000",
        "longitude": "74.588000",
    }
    assert len(api_client.get(DISTRICTS_URL).json()) == 2


@pytest.mark.django_db
def test_inactive_districts_are_hidden(api_client: APIClient, bishkek: City) -> None:
    DistrictFactory(city=bishkek, slug="visible")
    DistrictFactory(city=bishkek, slug="hidden", is_active=False)

    assert [d["slug"] for d in api_client.get(DISTRICTS_URL).json()] == ["visible"]


@pytest.mark.django_db
def test_builders_list(api_client: APIClient) -> None:
    BuilderFactory(name="Авангард Стиль", slug="avangard-style")
    BuilderFactory(name="Скрытый", slug="hidden", is_active=False)

    body = api_client.get(BUILDERS_URL).json()

    assert len(body) == 1
    assert body[0]["slug"] == "avangard-style"
    assert body[0]["logo_url"] is None


# -- опции фильтра -----------------------------------------------------------


@pytest.mark.django_db
def test_filter_options_returns_full_structure(
    api_client: APIClient, bishkek: City, technopark: District
) -> None:
    from tests.factories import HouseSeriesFactory

    HouseSeriesFactory(code="103", name="103 серия")
    ListingFactory(district=technopark, price=Decimal("102000"), status=ListingStatus.ACTIVE)
    ListingFactory(district=technopark, price=Decimal("45000"), status=ListingStatus.ACTIVE)
    ListingFactory(district=technopark, price=Decimal("999999"), status=ListingStatus.DRAFT)

    response = api_client.get(OPTIONS_URL, {"city": "bishkek"})

    assert response.status_code == 200
    body = response.json()
    assert set(body) == {
        "property_kinds",
        "seller_kinds",
        "rooms",
        "area_ranges",
        "series",
        "builders",
        # Словари параметров, применимых только к отдельным типам.
        "plot_purposes",
        "commercial_purposes",
        "building_lines",
        "districts",
        "price_range",
    }

    # Значения enum'ов совпадают с Flutter — их переименовывать нельзя.
    assert [option["value"] for option in body["property_kinds"]] == list(PropertyKind.values)
    assert [option["value"] for option in body["seller_kinds"]] == list(SellerKind.values)
    assert body["property_kinds"][0] == {"value": "house", "label": "Дома"}
    assert body["seller_kinds"][0] == {"value": "owner", "label": "Только собственник"}

    assert body["rooms"] == [1, 2, 3, 4, 5]
    assert body["area_ranges"][0] == {"from": 35, "to": 45, "label": "35-45"}
    assert [item["label"] for item in body["area_ranges"]] == ["35-45", "45-55", "65-75", "75-85"]
    assert body["series"] == [{"code": "103", "name": "103 серия"}]
    assert [option["value"] for option in body["plot_purposes"]] == list(PlotPurpose.values)
    assert [option["value"] for option in body["commercial_purposes"]] == list(
        CommercialPurpose.values
    )
    assert [option["value"] for option in body["building_lines"]] == list(BuildingLine.values)
    assert [district["slug"] for district in body["districts"]] == ["technopark"]
    # Черновик в границы цены не попадает.
    assert body["price_range"] == {"currency": "USD", "min": 45000, "max": 102000}


@pytest.mark.django_db
def test_filter_options_price_range_falls_back_to_defaults(
    api_client: APIClient, bishkek: City
) -> None:
    body = api_client.get(OPTIONS_URL).json()

    assert body["price_range"] == {"currency": "USD", "min": 30000, "max": 350000}


@pytest.mark.django_db
def test_filter_options_uses_default_city_without_parameter(
    api_client: APIClient, bishkek: City, technopark: District
) -> None:
    osh = CityFactory(name="Ош", slug="osh")
    DistrictFactory(city=osh, slug="zapadny")

    body = api_client.get(OPTIONS_URL).json()

    assert [district["slug"] for district in body["districts"]] == ["technopark"]


@pytest.mark.django_db
def test_second_filter_options_request_hits_cache(
    api_client: APIClient, bishkek: City, technopark: District, django_assert_num_queries
) -> None:
    """Второй запрос обслуживается из кэша — в БД не ходим вовсе."""
    first = api_client.get(OPTIONS_URL, {"city": "bishkek"})

    with django_assert_num_queries(0):
        second = api_client.get(OPTIONS_URL, {"city": "bishkek"})

    assert first.json() == second.json()


@pytest.mark.django_db
def test_district_change_invalidates_cache(
    api_client: APIClient, bishkek: City, technopark: District
) -> None:
    assert [d["name"] for d in api_client.get(OPTIONS_URL).json()["districts"]] == ["Технопарк"]

    technopark.name = "Технопарк-2"
    technopark.save()

    assert [d["name"] for d in api_client.get(OPTIONS_URL).json()["districts"]] == ["Технопарк-2"]

    DistrictFactory(city=bishkek, name="Асанбай", slug="asanbay", order=1)

    assert [d["name"] for d in api_client.get(OPTIONS_URL).json()["districts"]] == [
        "Технопарк-2",
        "Асанбай",
    ]


@pytest.mark.django_db
def test_new_listing_invalidates_price_range(
    api_client: APIClient, bishkek: City, technopark: District
) -> None:
    ListingFactory(district=technopark, price=Decimal("100000"), status=ListingStatus.ACTIVE)
    assert api_client.get(OPTIONS_URL).json()["price_range"]["max"] == 100000

    ListingFactory(district=technopark, price=Decimal("250000"), status=ListingStatus.ACTIVE)

    assert api_client.get(OPTIONS_URL).json()["price_range"]["max"] == 250000


@pytest.mark.django_db
def test_series_change_invalidates_cache(api_client: APIClient, bishkek: City) -> None:
    from tests.factories import HouseSeriesFactory

    assert api_client.get(OPTIONS_URL).json()["series"] == []

    HouseSeriesFactory(code="105", name="105 серия")

    assert api_client.get(OPTIONS_URL).json()["series"] == [{"code": "105", "name": "105 серия"}]


@pytest.mark.django_db
def test_cache_is_separate_per_city_and_language(
    api_client: APIClient, bishkek: City, technopark: District, django_assert_num_queries
) -> None:
    osh = CityFactory(name="Ош", slug="osh")
    DistrictFactory(city=osh, name="Западный", slug="zapadny")

    bishkek_body = api_client.get(OPTIONS_URL, {"city": "bishkek"}).json()
    osh_body = api_client.get(OPTIONS_URL, {"city": "osh"}).json()

    assert [d["slug"] for d in bishkek_body["districts"]] == ["technopark"]
    assert [d["slug"] for d in osh_body["districts"]] == ["zapadny"]

    # Другой язык — другой ключ, поэтому запросы к БД будут.
    api_client.get(OPTIONS_URL, {"city": "bishkek"}, HTTP_ACCEPT_LANGUAGE="en")
    with django_assert_num_queries(0):
        api_client.get(OPTIONS_URL, {"city": "bishkek"}, HTTP_ACCEPT_LANGUAGE="en")


@pytest.mark.django_db
def test_filter_options_supports_etag(
    api_client: APIClient, bishkek: City, technopark: District
) -> None:
    first = api_client.get(OPTIONS_URL)
    etag = first.headers["ETag"]

    second = api_client.get(OPTIONS_URL, HTTP_IF_NONE_MATCH=etag)

    assert second.status_code == 304
    assert second.content == b""
