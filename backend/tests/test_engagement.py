"""Тесты сохранённых фильтров и подборок."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.catalog.enums import ListingStatus, PropertyKind
from apps.engagement.models import Collection, CollectionItem, CollectionMode, SavedFilter
from apps.engagement.services import MAX_SAVED_FILTERS_PER_USER
from apps.engagement.tasks import notify_saved_filters
from apps.notifications.models import Notification, NotificationType
from tests.factories import CityFactory, DistrictFactory, ListingFactory, UserFactory

FILTERS_URL = "/api/v1/saved-filters/"
FILTER_URL = "/api/v1/saved-filters/{pk}/"
FILTER_LISTINGS_URL = "/api/v1/saved-filters/{pk}/listings/"
COLLECTIONS_URL = "/api/v1/collections/"
COLLECTION_LISTINGS_URL = "/api/v1/collections/{slug}/listings/"
LIST_URL = "/api/v1/listings/"


def client_for(user) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
    return client


@pytest.fixture
def city(db):
    return CityFactory(name="Бишкек", slug="bishkek", is_default=True)


@pytest.fixture
def technopark(city):
    return DistrictFactory(city=city, name="Технопарк", slug="technopark")


@pytest.fixture
def asanbay(city):
    return DistrictFactory(city=city, name="Асанбай", slug="asanbay")


@pytest.fixture
def user(db):
    return UserFactory()


@pytest.fixture
def auth(user):
    return client_for(user)


# -- создание и валидация ----------------------------------------------------


@pytest.mark.django_db
def test_saved_filter_reproduces_original_query(auth: APIClient, technopark, asanbay) -> None:
    """Сохранённый фильтр отдаёт ровно то же, что исходный запрос каталога."""
    for index in range(3):
        ListingFactory(
            district=technopark,
            kind=PropertyKind.APARTMENT,
            rooms=3,
            price=Decimal("90000"),
            slug=f"match-{index}",
        )
    ListingFactory(district=asanbay, kind=PropertyKind.APARTMENT, rooms=3, slug="other-district")
    ListingFactory(district=technopark, kind=PropertyKind.HOUSE, rooms=3, slug="other-kind")
    ListingFactory(district=technopark, kind=PropertyKind.APARTMENT, rooms=1, slug="other-rooms")

    params = {"district": "technopark", "kind": "apartment", "rooms": "3"}
    direct = auth.get(LIST_URL, {**params, "page_size": 100}).json()

    created = auth.post(
        FILTERS_URL, {"name": "Трёшки в Технопарке", "params": params}, format="json"
    )
    assert created.status_code == 201
    assert created.json()["matches_count"] == 3

    saved = auth.get(FILTER_LISTINGS_URL.format(pk=created.json()["id"]), {"page_size": 100}).json()

    assert saved["count"] == direct["count"] == 3
    assert [card["slug"] for card in saved["results"]] == [
        card["slug"] for card in direct["results"]
    ]


@pytest.mark.django_db
def test_params_with_unknown_key_are_rejected(auth: APIClient) -> None:
    response = auth.post(
        FILTERS_URL,
        {"name": "Странный", "params": {"district": "technopark", "hack": "1"}},
        format="json",
    )

    assert response.status_code == 400
    error = response.json()["error"]
    assert error["code"] == "validation_error"
    assert "hack" in str(error["details"])
    assert SavedFilter.objects.count() == 0


@pytest.mark.django_db
def test_params_with_invalid_value_are_rejected(auth: APIClient) -> None:
    response = auth.post(
        FILTERS_URL, {"name": "Кривой", "params": {"price_min": "дорого"}}, format="json"
    )

    assert response.status_code == 400
    assert SavedFilter.objects.count() == 0


@pytest.mark.django_db
def test_params_are_stored_normalized(auth: APIClient, technopark) -> None:
    response = auth.post(
        FILTERS_URL,
        {
            "name": "Нормализованный",
            "params": {
                "kind": ["apartment", "house"],
                "below_market": True,
                "city": "  bishkek  ",
                "ordering": "-price",
                "search": "",
            },
        },
        format="json",
    )

    assert response.status_code == 201
    assert SavedFilter.objects.get().params == {
        "below_market": "true",
        "city": "bishkek",
        "kind": "apartment,house",
    }


@pytest.mark.django_db
def test_twenty_first_filter_returns_409(auth: APIClient, user) -> None:
    for index in range(MAX_SAVED_FILTERS_PER_USER):
        SavedFilter.objects.create(user=user, name=f"Фильтр {index}", params={})

    response = auth.post(FILTERS_URL, {"name": "Лишний", "params": {}}, format="json")

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "conflict"
    assert SavedFilter.objects.count() == MAX_SAVED_FILTERS_PER_USER


@pytest.mark.django_db
def test_duplicate_name_returns_409(auth: APIClient, user) -> None:
    SavedFilter.objects.create(user=user, name="Мой поиск", params={})

    response = auth.post(FILTERS_URL, {"name": "Мой поиск", "params": {}}, format="json")

    assert response.status_code == 409


# -- доступ и правки ---------------------------------------------------------


@pytest.mark.django_db
def test_only_own_filters_are_visible(auth: APIClient, user) -> None:
    mine = SavedFilter.objects.create(user=user, name="Мой", params={})
    stranger = SavedFilter.objects.create(user=UserFactory(), name="Чужой", params={})

    listed = auth.get(FILTERS_URL).json()

    assert [item["id"] for item in listed] == [mine.pk]
    assert auth.get(FILTER_URL.format(pk=stranger.pk)).status_code == 404
    assert auth.delete(FILTER_URL.format(pk=stranger.pk)).status_code == 404


@pytest.mark.django_db
def test_patch_renames_and_toggles_notifications(auth: APIClient, user) -> None:
    saved = SavedFilter.objects.create(
        user=user, name="Старое", params={"city": "bishkek"}, notify_on_new=True
    )

    response = auth.patch(
        FILTER_URL.format(pk=saved.pk),
        {"name": "Новое", "notify_on_new": False, "params": {"city": "osh"}},
        format="json",
    )

    assert response.status_code == 200
    saved.refresh_from_db()
    assert saved.name == "Новое"
    assert saved.notify_on_new is False
    # Параметры менять нельзя — иначе last_notified_at относился бы к другому поиску.
    assert saved.params == {"city": "bishkek"}


@pytest.mark.django_db
def test_delete_filter(auth: APIClient, user) -> None:
    saved = SavedFilter.objects.create(user=user, name="Ненужный", params={})

    assert auth.delete(FILTER_URL.format(pk=saved.pk)).status_code == 204
    assert SavedFilter.objects.count() == 0


@pytest.mark.django_db
def test_saved_filters_require_authentication(api_client: APIClient) -> None:
    assert api_client.get(FILTERS_URL).status_code == 401


# -- уведомления -------------------------------------------------------------


@pytest.mark.django_db
def test_notify_creates_single_notification(user, technopark) -> None:
    saved = SavedFilter.objects.create(
        user=user, name="Технопарк", params={"district": "technopark"}
    )
    SavedFilter.objects.filter(pk=saved.pk).update(created_at=timezone.now() - timedelta(days=1))

    for index in range(3):
        ListingFactory(district=technopark, slug=f"fresh-{index}", published_at=timezone.now())

    assert notify_saved_filters() == 1

    notification = Notification.objects.get()
    assert notification.user == user
    assert notification.type == NotificationType.SAVED_FILTER_MATCH
    assert notification.body == "По фильтру «Технопарк» — 3 новых объектов"
    assert notification.payload == {"saved_filter_id": saved.pk, "count": 3}

    saved.refresh_from_db()
    assert saved.last_notified_at is not None
    assert saved.matches_count == 3


@pytest.mark.django_db
def test_second_run_creates_nothing(user, technopark) -> None:
    saved = SavedFilter.objects.create(user=user, name="Технопарк", params={})
    SavedFilter.objects.filter(pk=saved.pk).update(created_at=timezone.now() - timedelta(days=1))
    ListingFactory(district=technopark, published_at=timezone.now())

    assert notify_saved_filters() == 1
    assert notify_saved_filters() == 0
    assert Notification.objects.count() == 1


@pytest.mark.django_db
def test_notify_skips_disabled_and_empty(user, technopark) -> None:
    disabled = SavedFilter.objects.create(
        user=user, name="Выключен", params={}, notify_on_new=False
    )
    empty = SavedFilter.objects.create(
        user=user, name="Без новинок", params={"district": "asanbay"}
    )
    SavedFilter.objects.filter(pk__in=[disabled.pk, empty.pk]).update(
        created_at=timezone.now() - timedelta(days=1)
    )
    ListingFactory(district=technopark, published_at=timezone.now())

    assert notify_saved_filters() == 0
    assert Notification.objects.count() == 0
    disabled.refresh_from_db()
    assert disabled.last_notified_at is None


@pytest.mark.django_db
def test_notify_ignores_listings_published_before_filter(user, technopark) -> None:
    ListingFactory(district=technopark, published_at=timezone.now() - timedelta(days=2))
    SavedFilter.objects.create(user=user, name="Свежий фильтр", params={})

    assert notify_saved_filters() == 0


@pytest.mark.django_db
def test_notify_groups_identical_params(user, technopark, django_assert_max_num_queries) -> None:
    """Одинаковые параметры считаются одним запросом на группу."""
    for index in range(5):
        saved = SavedFilter.objects.create(
            user=UserFactory(), name=f"Фильтр {index}", params={"district": "technopark"}
        )
        SavedFilter.objects.filter(pk=saved.pk).update(
            created_at=timezone.now() - timedelta(days=1)
        )
    ListingFactory(district=technopark, published_at=timezone.now())

    # Выборка фильтров + count + published_at + bulk_create + bulk_update.
    with django_assert_max_num_queries(6):
        assert notify_saved_filters() == 5


# -- подборки ----------------------------------------------------------------


@pytest.mark.django_db
def test_collections_list(api_client: APIClient) -> None:
    Collection.objects.create(title="Вторая", slug="second", order=2)
    Collection.objects.create(title="Первая", slug="first", order=1)
    Collection.objects.create(title="Скрытая", slug="hidden", is_active=False)

    body = api_client.get(COLLECTIONS_URL).json()

    assert [item["slug"] for item in body] == ["first", "second"]
    assert body[0]["title"] == "Первая"


@pytest.mark.django_db
def test_manual_collection_keeps_editor_order(api_client: APIClient, technopark) -> None:
    collection = Collection.objects.create(
        title="Выбор редакции", slug="editors", mode=CollectionMode.MANUAL
    )
    first = ListingFactory(district=technopark, slug="third-by-date")
    second = ListingFactory(district=technopark, slug="second-by-date")
    third = ListingFactory(district=technopark, slug="first-by-date")

    CollectionItem.objects.create(collection=collection, listing=first, order=0)
    CollectionItem.objects.create(collection=collection, listing=second, order=1)
    CollectionItem.objects.create(collection=collection, listing=third, order=2)

    body = api_client.get(COLLECTION_LISTINGS_URL.format(slug="editors")).json()

    assert [card["slug"] for card in body["results"]] == [
        "third-by-date",
        "second-by-date",
        "first-by-date",
    ]
    assert api_client.get(COLLECTIONS_URL).json()[0]["listings_count"] == 3


@pytest.mark.django_db
def test_query_collection_uses_params(api_client: APIClient, technopark, asanbay) -> None:
    Collection.objects.create(
        title="Только Технопарк",
        slug="technopark",
        mode=CollectionMode.QUERY,
        params={"district": "technopark"},
    )
    ListingFactory(district=technopark, slug="inside")
    ListingFactory(district=asanbay, slug="outside")

    body = api_client.get(COLLECTION_LISTINGS_URL.format(slug="technopark")).json()

    assert [card["slug"] for card in body["results"]] == ["inside"]


@pytest.mark.django_db
def test_collection_listings_show_only_active(api_client: APIClient, technopark) -> None:
    collection = Collection.objects.create(
        title="Ручная", slug="manual", mode=CollectionMode.MANUAL
    )
    active = ListingFactory(district=technopark, slug="active")
    draft = ListingFactory(district=technopark, slug="draft", status=ListingStatus.DRAFT)
    CollectionItem.objects.create(collection=collection, listing=active, order=0)
    CollectionItem.objects.create(collection=collection, listing=draft, order=1)

    body = api_client.get(COLLECTION_LISTINGS_URL.format(slug="manual")).json()

    assert [card["slug"] for card in body["results"]] == ["active"]


@pytest.mark.django_db
def test_inactive_collection_is_hidden(api_client: APIClient) -> None:
    Collection.objects.create(title="Скрытая", slug="hidden", is_active=False)

    assert api_client.get(COLLECTION_LISTINGS_URL.format(slug="hidden")).status_code == 404
