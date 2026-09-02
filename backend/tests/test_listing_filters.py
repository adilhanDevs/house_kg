"""Тесты фильтрации и поиска каталога."""

from decimal import Decimal

import pytest
from django.db import connection
from rest_framework.test import APIClient

from apps.catalog.enums import Currency, ListingStatus, MediaKind, PropertyKind, SellerKind
from apps.catalog.filters import parse_area_ranges
from apps.catalog.models import ExchangeRate
from apps.catalog.rates import get_rate, invalidate_rate_cache, to_usd
from tests.factories import (
    BuilderFactory,
    CityFactory,
    DistrictFactory,
    HouseSeriesFactory,
    ListingFactory,
    ListingMediaFactory,
)

LIST_URL = "/api/v1/listings/"
COUNT_URL = "/api/v1/listings/count/"

postgres_only = pytest.mark.skipif(
    connection.vendor != "postgresql",
    reason="полнотекстовый поиск и триграммы есть только в PostgreSQL",
)


def slugs(response) -> set[str]:
    return {card["slug"] for card in response.json()["results"]}


@pytest.fixture
def city(db):
    return CityFactory(name="Бишкек", slug="bishkek", is_default=True)


@pytest.fixture
def technopark(city):
    return DistrictFactory(city=city, name="Технопарк", slug="technopark")


@pytest.fixture
def asanbay(city):
    return DistrictFactory(city=city, name="Асанбай", slug="asanbay")


# -- отдельные параметры -----------------------------------------------------


@pytest.mark.django_db
def test_filter_by_kind_multiselect(api_client: APIClient, technopark) -> None:
    ListingFactory(district=technopark, kind=PropertyKind.APARTMENT, slug="flat")
    ListingFactory(district=technopark, kind=PropertyKind.HOUSE, slug="house")
    ListingFactory(district=technopark, kind=PropertyKind.PLOT, slug="plot")

    response = api_client.get(LIST_URL, {"kind": "apartment,house"})

    assert slugs(response) == {"flat", "house"}


@pytest.mark.django_db
def test_filter_by_district_and_city(api_client: APIClient, technopark, asanbay) -> None:
    ListingFactory(district=technopark, slug="in-technopark")
    ListingFactory(district=asanbay, slug="in-asanbay")
    other_city = CityFactory(name="Ош", slug="osh")
    ListingFactory(district=DistrictFactory(city=other_city, slug="zapadny"), slug="in-osh")

    assert slugs(api_client.get(LIST_URL, {"district": "technopark,asanbay"})) == {
        "in-technopark",
        "in-asanbay",
    }
    assert slugs(api_client.get(LIST_URL, {"city": "osh"})) == {"in-osh"}


@pytest.mark.django_db
def test_rooms_five_means_five_or_more(api_client: APIClient, technopark) -> None:
    ListingFactory(district=technopark, rooms=3, slug="three")
    ListingFactory(district=technopark, rooms=5, slug="five")
    ListingFactory(district=technopark, rooms=6, slug="six")

    assert slugs(api_client.get(LIST_URL, {"rooms": "5"})) == {"five", "six"}
    assert slugs(api_client.get(LIST_URL, {"rooms": "3,5"})) == {"three", "five", "six"}


@pytest.mark.django_db
def test_area_bounds(api_client: APIClient, technopark) -> None:
    ListingFactory(district=technopark, area=Decimal("40"), slug="small")
    ListingFactory(district=technopark, area=Decimal("70"), slug="medium")
    ListingFactory(district=technopark, area=Decimal("120"), slug="big")

    assert slugs(api_client.get(LIST_URL, {"area_min": 60, "area_max": 100})) == {"medium"}


@pytest.mark.django_db
def test_area_ranges_are_combined_by_or(api_client: APIClient, technopark) -> None:
    ListingFactory(district=technopark, area=Decimal("40"), slug="in-first-range")
    ListingFactory(district=technopark, area=Decimal("70"), slug="in-second-range")
    ListingFactory(district=technopark, area=Decimal("55"), slug="between-ranges")

    response = api_client.get(LIST_URL, {"area_ranges": "35-45,65-75"})

    assert slugs(response) == {"in-first-range", "in-second-range"}


@pytest.mark.django_db
def test_area_ranges_union_with_manual_bounds(api_client: APIClient, technopark) -> None:
    """Чипы и поле «своя квадратура» дополняют друг друга."""
    ListingFactory(district=technopark, area=Decimal("40"), slug="chip")
    ListingFactory(district=technopark, area=Decimal("200"), slug="manual")
    ListingFactory(district=technopark, area=Decimal("55"), slug="neither")

    response = api_client.get(LIST_URL, {"area_ranges": "35-45", "area_min": 150})

    assert slugs(response) == {"chip", "manual"}


def test_parse_area_ranges_ignores_garbage() -> None:
    assert parse_area_ranges("35-45,,broken,65-75") == [
        (Decimal("35"), Decimal("45")),
        (Decimal("65"), Decimal("75")),
    ]
    assert parse_area_ranges("45-35") == [(Decimal("35"), Decimal("45"))]


@pytest.mark.django_db
def test_filter_by_price_in_usd(api_client: APIClient, technopark) -> None:
    ListingFactory(district=technopark, price=Decimal("50000"), slug="cheap")
    ListingFactory(district=technopark, price=Decimal("150000"), slug="expensive")

    assert slugs(api_client.get(LIST_URL, {"price_min": 100000})) == {"expensive"}
    assert slugs(api_client.get(LIST_URL, {"price_max": 100000})) == {"cheap"}


@pytest.mark.django_db
def test_price_min_in_kgs_is_converted(api_client: APIClient, technopark) -> None:
    invalidate_rate_cache()
    ExchangeRate.objects.create(currency_from=Currency.USD, currency_to=Currency.KGS, rate=90)
    invalidate_rate_cache()

    ListingFactory(district=technopark, price=Decimal("50000"), slug="usd-cheap")
    ListingFactory(district=technopark, price=Decimal("150000"), slug="usd-expensive")
    # Объявление в сомах: 9 000 000 сом = 100 000 USD по курсу 90.
    in_soms = ListingFactory(
        district=technopark,
        price=Decimal("9000000"),
        currency=Currency.KGS,
        slug="kgs-listing",
    )

    assert in_soms.price_usd == Decimal("100000.00")

    # 9 000 000 сом ≈ 100 000 USD: остаются объявления дороже этого порога.
    response = api_client.get(LIST_URL, {"price_min": 9_000_000, "currency": "KGS"})

    assert slugs(response) == {"usd-expensive", "kgs-listing"}


@pytest.mark.django_db
def test_filter_by_seller_kind_and_series(api_client: APIClient, technopark) -> None:
    series = HouseSeriesFactory(code="103")
    ListingFactory(
        district=technopark, seller_kind=SellerKind.AGENCY, series=series, slug="agency-103"
    )
    ListingFactory(district=technopark, seller_kind=SellerKind.OWNER, slug="owner")

    assert slugs(api_client.get(LIST_URL, {"seller_kind": "agency,realtor"})) == {"agency-103"}
    assert slugs(api_client.get(LIST_URL, {"series": "103"})) == {"agency-103"}


@pytest.mark.django_db
def test_boolean_flags(api_client: APIClient, technopark) -> None:
    ListingFactory(district=technopark, is_secondary=True, slug="secondary")
    ListingFactory(district=technopark, below_market=True, slug="cheap")
    ListingFactory(district=technopark, red_book=True, slug="red-book")

    assert slugs(api_client.get(LIST_URL, {"is_secondary": "true"})) == {"secondary"}
    assert slugs(api_client.get(LIST_URL, {"below_market": "true"})) == {"cheap"}
    assert slugs(api_client.get(LIST_URL, {"red_book": "true"})) == {"red-book"}


@pytest.mark.django_db
def test_floor_filters(api_client: APIClient, technopark) -> None:
    ListingFactory(district=technopark, floor=1, floors=9, slug="first")
    ListingFactory(district=technopark, floor=5, floors=9, slug="middle")
    ListingFactory(district=technopark, floor=9, floors=9, slug="last")

    assert slugs(api_client.get(LIST_URL, {"not_first_floor": "true"})) == {"middle", "last"}
    assert slugs(api_client.get(LIST_URL, {"not_last_floor": "true"})) == {"first", "middle"}
    assert slugs(api_client.get(LIST_URL, {"floor_min": 5, "floor_max": 9})) == {
        "middle",
        "last",
    }


@pytest.mark.django_db
def test_has_video(api_client: APIClient, technopark) -> None:
    with_video = ListingFactory(district=technopark, slug="with-video")
    ListingMediaFactory(listing=with_video, kind=MediaKind.VIDEO, order=0)
    ListingFactory(district=technopark, slug="photos-only")

    assert slugs(api_client.get(LIST_URL, {"has_video": "true"})) == {"with-video"}
    assert slugs(api_client.get(LIST_URL, {"has_video": "false"})) == {"photos-only"}


@pytest.mark.django_db
def test_filter_by_builder(api_client: APIClient, technopark) -> None:
    builder = BuilderFactory(name="Авангард Стиль", slug="avangard-style")
    ListingFactory(district=technopark, builder=builder, slug="from-builder")
    ListingFactory(district=technopark, slug="no-builder")

    assert slugs(api_client.get(LIST_URL, {"builder": "avangard-style"})) == {"from-builder"}


@pytest.mark.django_db
def test_filters_are_combined_by_and(api_client: APIClient, technopark, asanbay) -> None:
    ListingFactory(district=technopark, kind=PropertyKind.APARTMENT, rooms=3, slug="match")
    ListingFactory(district=asanbay, kind=PropertyKind.APARTMENT, rooms=3, slug="other-district")
    ListingFactory(district=technopark, kind=PropertyKind.HOUSE, rooms=3, slug="other-kind")

    response = api_client.get(
        LIST_URL, {"district": "technopark", "kind": "apartment", "rooms": "3"}
    )

    assert slugs(response) == {"match"}


# -- поиск -------------------------------------------------------------------


@pytest.mark.django_db
def test_search_finds_by_district_name(api_client: APIClient, technopark, asanbay) -> None:
    ListingFactory(district=technopark, slug="in-technopark")
    ListingFactory(district=asanbay, slug="in-asanbay")

    assert slugs(api_client.get(LIST_URL, {"search": "Технопарк"})) == {"in-technopark"}


@pytest.mark.django_db
@postgres_only
def test_search_with_typo_falls_back_to_trigrams(api_client: APIClient, technopark) -> None:
    """«технпарк» с опечаткой должен находить «Технопарк»."""
    from apps.catalog.search import update_search_vectors

    ListingFactory(district=technopark, slug="in-technopark")
    update_search_vectors()

    assert slugs(api_client.get(LIST_URL, {"search": "технпарк"})) == {"in-technopark"}


@pytest.mark.django_db
@postgres_only
def test_search_ranks_district_above_description(api_client: APIClient, technopark, asanbay):
    from apps.catalog.search import update_search_vectors

    ListingFactory(district=technopark, slug="by-district", description="обычная квартира")
    ListingFactory(district=asanbay, slug="by-description", description="рядом Технопарк")
    update_search_vectors()

    results = api_client.get(LIST_URL, {"search": "Технопарк"}).json()["results"]

    assert [card["slug"] for card in results] == ["by-district", "by-description"]


# -- количество --------------------------------------------------------------


@pytest.mark.django_db
def test_count_matches_full_listing(api_client: APIClient, technopark, asanbay) -> None:
    for index in range(7):
        ListingFactory(district=technopark, kind=PropertyKind.APARTMENT, slug=f"flat-{index}")
    for index in range(3):
        ListingFactory(district=asanbay, kind=PropertyKind.HOUSE, slug=f"house-{index}")
    ListingFactory(district=technopark, status=ListingStatus.DRAFT, slug="draft")

    params = {"district": "technopark", "kind": "apartment"}
    listed = api_client.get(LIST_URL, {**params, "page_size": 100}).json()

    assert api_client.get(COUNT_URL, params).json() == {"count": 7}
    assert len(listed["results"]) == 7
    assert api_client.get(COUNT_URL).json() == {"count": 10}


@pytest.mark.django_db
def test_count_is_cached(api_client: APIClient, technopark, django_assert_num_queries) -> None:
    ListingFactory(district=technopark)
    api_client.get(COUNT_URL, {"kind": "apartment"})

    with django_assert_num_queries(0):
        api_client.get(COUNT_URL, {"kind": "apartment"})


@pytest.mark.django_db
def test_count_cache_key_ignores_pagination(api_client: APIClient, technopark) -> None:
    ListingFactory(district=technopark, kind=PropertyKind.APARTMENT)

    first = api_client.get(COUNT_URL, {"kind": "apartment", "page_size": 5}).json()
    second = api_client.get(COUNT_URL, {"kind": "apartment", "page_size": 50}).json()

    assert first == second == {"count": 1}


# -- курсы валют -------------------------------------------------------------


@pytest.mark.django_db
def test_rate_falls_back_to_settings(settings) -> None:
    invalidate_rate_cache()
    settings.FALLBACK_USD_KGS_RATE = 87.5

    assert get_rate() == Decimal("87.5")
    assert to_usd(Decimal("8750"), Currency.KGS) == Decimal("100.00")
    assert to_usd(Decimal("100"), Currency.USD) == Decimal("100.00")


@pytest.mark.django_db
def test_latest_rate_wins() -> None:
    invalidate_rate_cache()
    ExchangeRate.objects.create(currency_from=Currency.USD, currency_to=Currency.KGS, rate=80)
    ExchangeRate.objects.create(currency_from=Currency.USD, currency_to=Currency.KGS, rate=90)
    invalidate_rate_cache()

    assert get_rate() == Decimal("90.000000")


# -- задача НБКР -------------------------------------------------------------

NBKR_XML = b"""<?xml version="1.0" encoding="UTF-8"?>
<CurrencyRates Date="20.08.2026">
  <Currency ISOCode="USD"><Nominal>1</Nominal><Value>87,4500</Value></Currency>
  <Currency ISOCode="EUR"><Nominal>1</Nominal><Value>95,1200</Value></Currency>
</CurrencyRates>
"""


def test_parse_nbkr_rate() -> None:
    from apps.catalog.tasks import parse_nbkr_usd_rate

    assert parse_nbkr_usd_rate(NBKR_XML) == Decimal("87.4500")


def test_parse_nbkr_rate_without_usd() -> None:
    from apps.catalog.tasks import parse_nbkr_usd_rate

    payload = (
        b'<CurrencyRates><Currency ISOCode="EUR"><Value>95,12</Value></Currency></CurrencyRates>'
    )
    with pytest.raises(ValueError):
        parse_nbkr_usd_rate(payload)


@pytest.mark.django_db
def test_fetch_exchange_rates_updates_prices(technopark) -> None:
    from unittest.mock import patch

    from apps.catalog.tasks import fetch_exchange_rates

    invalidate_rate_cache()
    listing = ListingFactory(district=technopark, price=Decimal("8745000"), currency=Currency.KGS)

    with patch("apps.catalog.tasks.requests.get") as request:
        request.return_value.content = NBKR_XML
        request.return_value.raise_for_status.return_value = None

        assert fetch_exchange_rates() == "updated"

    assert ExchangeRate.objects.count() == 1
    listing.refresh_from_db()
    # 8 745 000 сом по курсу 87.45 = 100 000 USD.
    assert listing.price_usd == Decimal("100000.00")


@pytest.mark.django_db
def test_fetch_exchange_rates_survives_outage(caplog) -> None:
    from unittest.mock import patch

    import requests as requests_lib

    from apps.catalog.tasks import fetch_exchange_rates

    ExchangeRate.objects.create(currency_from=Currency.USD, currency_to=Currency.KGS, rate=90)

    with patch("apps.catalog.tasks.requests.get", side_effect=requests_lib.Timeout("нет связи")):
        assert fetch_exchange_rates() == "skipped"

    # Прошлый курс на месте, задача не упала.
    assert ExchangeRate.objects.count() == 1
    invalidate_rate_cache()
    assert get_rate() == Decimal("90.000000")


# -- валидация параметров ----------------------------------------------------


@pytest.mark.django_db
@pytest.mark.parametrize(
    "params",
    [
        {"rooms": "banana"},
        {"price_min": "abc"},
        {"area_min": "not-a-number"},
        {"floor_min": "x"},
        {"currency": "XXX"},
        {"kind": "not_a_kind"},
        {"seller_kind": "landlord"},
        {"price_min": "-1"},
        {"area_max": "-5"},
        {"price_min": "500000", "price_max": "1000"},
        {"area_min": "90", "area_max": "40"},
        {"floor_min": "9", "floor_max": "2"},
    ],
)
def test_invalid_filters_give_400_not_500(api_client: APIClient, params) -> None:
    """Мусор и бессмыслица — контролируемая ошибка, а не 500 и не пустой список."""
    response = api_client.get(LIST_URL, params)
    assert response.status_code == 400, (params, response.status_code)


@pytest.mark.django_db
def test_reversed_price_range_names_the_field(api_client: APIClient) -> None:
    response = api_client.get(LIST_URL, {"price_min": "500000", "price_max": "1000"})
    assert response.status_code == 400
    assert "price_min" in response.data["error"]["details"]


@pytest.mark.django_db
def test_unknown_kind_lists_allowed_values(api_client: APIClient) -> None:
    response = api_client.get(LIST_URL, {"kind": "villa"})
    assert response.status_code == 400
    message = " ".join(response.data["error"]["details"]["kind"])
    assert "villa" in message
    assert "apartment" in message


@pytest.mark.django_db
def test_equal_bounds_are_allowed(api_client: APIClient, technopark) -> None:
    """price_min == price_max — законный запрос «ровно столько»."""
    ListingFactory(district=technopark, price=Decimal("100000"), slug="exact")
    response = api_client.get(LIST_URL, {"price_min": "100000", "price_max": "100000"})
    assert response.status_code == 200
    assert [item["slug"] for item in response.data["results"]] == ["exact"]


@pytest.mark.django_db
def test_price_boundaries_are_inclusive(api_client: APIClient, technopark) -> None:
    ListingFactory(district=technopark, price=Decimal("100000"), slug="low")
    ListingFactory(district=technopark, price=Decimal("200000"), slug="high")
    response = api_client.get(LIST_URL, {"price_min": "100000", "price_max": "200000"})
    slugs = {item["slug"] for item in response.data["results"]}
    assert slugs == {"low", "high"}


# -- фильтр + пагинация ------------------------------------------------------


@pytest.mark.django_db
def test_filter_survives_pagination_without_duplicates(
    api_client: APIClient, technopark, asanbay
) -> None:
    """Вторая страница остаётся внутри фильтра и не повторяет первую."""
    for index in range(25):
        ListingFactory(
            district=technopark,
            kind=PropertyKind.APARTMENT,
            slug=f"wanted-{index:02d}",
        )
    for index in range(5):
        ListingFactory(district=asanbay, kind=PropertyKind.HOUSE, slug=f"other-{index}")

    first = api_client.get(LIST_URL, {"kind": "apartment", "page_size": "10"})
    assert first.status_code == 200
    assert first.data["count"] == 25

    seen = [item["slug"] for item in first.data["results"]]
    next_link = first.data["next"]
    assert next_link is not None

    while next_link:
        page = api_client.get(next_link)
        assert page.status_code == 200
        seen.extend(item["slug"] for item in page.data["results"])
        next_link = page.data["next"]

    assert len(seen) == len(set(seen)), "объявление попало в две страницы"
    assert len(seen) == 25
    assert all(slug.startswith("wanted-") for slug in seen)


@pytest.mark.django_db
def test_sorting_is_global_across_pages(api_client: APIClient, technopark) -> None:
    """Сортировка по цене сквозная, а не внутри страницы."""
    for index in range(15):
        ListingFactory(
            district=technopark,
            price=Decimal(str(50000 + index * 1000)),
            slug=f"p{index:02d}",
        )

    prices: list[float] = []
    link = f"{LIST_URL}?ordering=price&page_size=5"
    while link:
        page = api_client.get(link)
        assert page.status_code == 200
        prices.extend(float(item["price"]) for item in page.data["results"])
        link = page.data["next"]

    assert prices == sorted(prices)
    assert len(prices) == 15


@pytest.mark.django_db
def test_filtered_catalog_does_not_scale_queries_with_page_size(
    api_client: APIClient, technopark, django_assert_num_queries
) -> None:
    """Карточек больше — запросов столько же.

    Район, серия, застройщик и обложка тянутся одним заходом каждый; если
    какой-то из них сорвётся в ленивую загрузку, число запросов поедет за
    размером страницы.
    """
    for index in range(30):
        listing = ListingFactory(
            district=technopark,
            kind=PropertyKind.APARTMENT,
            slug=f"n{index:02d}",
        )
        ListingMediaFactory(listing=listing, is_cover=True)

    small = api_client.get(LIST_URL, {"kind": "apartment", "page_size": "5"})
    assert small.status_code == 200
    assert len(small.data["results"]) == 5

    with django_assert_num_queries(_count_queries(api_client, {"page_size": "5"})):
        api_client.get(LIST_URL, {"kind": "apartment", "page_size": "25"})


def _count_queries(api_client: APIClient, extra: dict) -> int:
    """Сколько запросов уходит на страницу — измеряем на маленькой."""
    from django.db import connection
    from django.test.utils import CaptureQueriesContext

    params = {"kind": "apartment", **extra}
    with CaptureQueriesContext(connection) as captured:
        api_client.get(LIST_URL, params)
    return len(captured)
