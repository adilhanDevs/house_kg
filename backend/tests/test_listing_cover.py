"""Обложка объявления: сервер решает, клиент показывает.

Главный инвариант: у объявления одна логическая обложка, и она одинакова на
всех эндпоинтах. Раньше клиент выбирал её сам — сравнивал строки URL и, если
`cover_url` совпал с одним из `media[]`, показывал первый элемент галереи.
Совпадение зависело от того, успел ли сервер собрать варианты размеров,
поэтому карточка и детальная страница расходились через раз.
"""

from typing import Any

import pytest
from django.core.cache import cache
from django.core.files.base import ContentFile
from django.urls import reverse
from rest_framework.test import APIClient

from apps.catalog.covers import pick_cover
from apps.catalog.enums import ListingStatus, MediaKind
from apps.catalog.models import ListingMedia
from tests.factories import ListingFactory, ListingMediaFactory

pytestmark = pytest.mark.django_db

LIST_URL = "/api/v1/listings/"
FEATURED_URL = "/api/v1/listings/featured/"


def detail_url(listing: Any) -> str:
    return f"/api/v1/listings/{listing.slug}/"


def card_of(response: Any, slug: str) -> dict[str, Any]:
    """Карточка объявления из списочного ответа."""
    return next(card for card in response.json()["results"] if card["slug"] == slug)


@pytest.fixture
def active_listing(district, pro_user):  # noqa: ANN001, ANN201
    return ListingFactory(owner=pro_user, district=district, status=ListingStatus.ACTIVE)


# -- какое медиа считается обложкой ------------------------------------------


def test_listing_without_media_has_no_cover(api_client: APIClient, active_listing) -> None:
    body = api_client.get(detail_url(active_listing)).json()

    assert body["cover_url"] is None
    assert body["cover_media_id"] is None
    assert body["cover_detail_url"] is None


def test_single_photo_becomes_the_cover(api_client: APIClient, active_listing) -> None:
    photo = ListingMediaFactory(listing=active_listing, order=0, is_cover=False)

    body = api_client.get(detail_url(active_listing)).json()

    assert body["cover_media_id"] == photo.pk


def test_is_cover_flag_wins_over_order(api_client: APIClient, active_listing) -> None:
    ListingMediaFactory(listing=active_listing, order=0)
    marked = ListingMediaFactory(listing=active_listing, order=1, is_cover=True)
    ListingMediaFactory(listing=active_listing, order=2)

    body = api_client.get(detail_url(active_listing)).json()

    assert body["cover_media_id"] == marked.pk


def test_without_is_cover_the_first_photo_by_order_wins(
    api_client: APIClient, active_listing
) -> None:
    """Медиа заводятся в обратном порядке — выбор идёт по order, а не по id."""
    later = ListingMediaFactory(listing=active_listing, order=5)
    first = ListingMediaFactory(listing=active_listing, order=1)

    body = api_client.get(detail_url(active_listing)).json()

    assert body["cover_media_id"] == first.pk
    assert body["cover_media_id"] != later.pk


def test_video_is_cover_only_when_there_are_no_photos(
    api_client: APIClient, active_listing
) -> None:
    video = ListingMediaFactory(listing=active_listing, kind=MediaKind.VIDEO, order=0)
    # Кадр-обложку ролика присылает приложение; без него видео обложкой не станет.
    video.thumbnail.save("poster.jpg", ContentFile(b"fake-poster"), save=True)
    body = api_client.get(detail_url(active_listing)).json()
    assert body["cover_media_id"] == video.pk

    photo = ListingMediaFactory(listing=active_listing, order=1)
    body = api_client.get(detail_url(active_listing)).json()
    assert body["cover_media_id"] == photo.pk


def test_cover_media_id_matches_pick_cover(api_client: APIClient, active_listing) -> None:
    ListingMediaFactory(listing=active_listing, order=0)
    ListingMediaFactory(listing=active_listing, order=1, is_cover=True)

    body = api_client.get(detail_url(active_listing)).json()
    expected = pick_cover(active_listing.media.all())

    assert body["cover_media_id"] == expected.pk


# -- одинаково на всех поверхностях ------------------------------------------


def test_list_and_detail_agree_on_the_cover(api_client: APIClient, active_listing) -> None:
    ListingMediaFactory(listing=active_listing, order=0)
    ListingMediaFactory(listing=active_listing, order=1, is_cover=True)
    ListingMediaFactory(listing=active_listing, order=2)

    card = card_of(api_client.get(LIST_URL), active_listing.slug)
    detail = api_client.get(detail_url(active_listing)).json()

    assert card["cover_media_id"] == detail["cover_media_id"]
    assert card["cover_url"] == detail["cover_url"]


def test_every_public_surface_reports_the_same_cover(
    api_client: APIClient, client_for, user, active_listing
) -> None:
    """Каталог, подборки, избранное и «мои объявления» — одна обложка."""
    from apps.engagement.models import Favourite

    ListingMediaFactory(listing=active_listing, order=0)
    cover = ListingMediaFactory(listing=active_listing, order=1, is_cover=True)
    Favourite.objects.create(user=user, listing=active_listing)

    auth = client_for(user)
    owner = client_for(active_listing.owner)

    surfaces = {
        "list": card_of(api_client.get(LIST_URL), active_listing.slug),
        "detail": api_client.get(detail_url(active_listing)).json(),
        "favourites": card_of(auth.get("/api/v1/favourites/"), active_listing.slug),
        "my": card_of(owner.get("/api/v1/users/me/listings/"), active_listing.slug),
    }
    featured = api_client.get(FEATURED_URL).json()
    for cards in featured.values():
        for card in cards:
            if card["slug"] == active_listing.slug:
                surfaces["featured"] = card

    for name, payload in surfaces.items():
        assert payload["cover_media_id"] == cover.pk, f"{name} выбрал другую обложку"


def test_detail_cover_is_the_same_media_in_a_bigger_size(
    api_client: APIClient, active_listing
) -> None:
    """cover_url и cover_detail_url — один снимок, разные варианты размера."""
    cover = ListingMediaFactory(listing=active_listing, order=0, is_cover=True)
    # Варианты размеров собирает фоновая обработка — здесь подставляем их сами.
    cover.url_thumb.save("a_thumb.webp", ContentFile(b"thumb"), save=False)
    cover.url_medium.save("a_medium.webp", ContentFile(b"medium"), save=False)
    cover.save(update_fields=["url_thumb", "url_medium"])
    ListingMediaFactory(listing=active_listing, order=1)

    body = api_client.get(detail_url(active_listing)).json()

    assert body["cover_media_id"] == cover.pk
    assert body["cover_url"] != body["cover_detail_url"]
    assert "thumb" in body["cover_url"]
    assert "medium" in body["cover_detail_url"]


def test_public_cover_url_is_absolute(api_client: APIClient, active_listing) -> None:
    ListingMediaFactory(listing=active_listing, order=0, is_cover=True)

    card = card_of(api_client.get(LIST_URL), active_listing.slug)
    detail = api_client.get(detail_url(active_listing)).json()

    for url in (card["cover_url"], detail["cover_url"], detail["cover_detail_url"]):
        assert url is not None
        assert url.startswith("http://") or url.startswith("https://")


# -- изменение обложки --------------------------------------------------------


def test_set_cover_changes_the_cover_everywhere(
    api_client: APIClient, client_for, active_listing
) -> None:
    first = ListingMediaFactory(listing=active_listing, order=0, is_cover=True)
    third = ListingMediaFactory(listing=active_listing, order=2)
    owner = client_for(active_listing.owner)

    assert card_of(api_client.get(LIST_URL), active_listing.slug)["cover_media_id"] == first.pk

    response = owner.post(
        reverse("catalog:listing-media-cover", args=[active_listing.slug, third.pk])
    )

    assert response.status_code == 200
    assert active_listing.media.filter(is_cover=True).count() == 1
    assert card_of(api_client.get(LIST_URL), active_listing.slug)["cover_media_id"] == third.pk
    assert api_client.get(detail_url(active_listing)).json()["cover_media_id"] == third.pk


def test_deleting_the_cover_promotes_the_next_photo(
    api_client: APIClient, client_for, active_listing
) -> None:
    cover = ListingMediaFactory(listing=active_listing, order=0, is_cover=True)
    second = ListingMediaFactory(listing=active_listing, order=1)
    owner = client_for(active_listing.owner)

    response = owner.delete(
        reverse("catalog:listing-media-item", args=[active_listing.slug, cover.pk])
    )

    assert response.status_code == 204
    assert card_of(api_client.get(LIST_URL), active_listing.slug)["cover_media_id"] == second.pk
    assert api_client.get(detail_url(active_listing)).json()["cover_media_id"] == second.pk


def test_reorder_does_not_move_an_explicit_cover(
    api_client: APIClient, client_for, active_listing
) -> None:
    first = ListingMediaFactory(listing=active_listing, order=0)
    marked = ListingMediaFactory(listing=active_listing, order=1, is_cover=True)
    owner = client_for(active_listing.owner)

    response = owner.patch(
        reverse("catalog:listing-media-reorder", args=[active_listing.slug]),
        {"order": [marked.pk, first.pk]},
        format="json",
    )

    assert response.status_code == 200
    assert api_client.get(detail_url(active_listing)).json()["cover_media_id"] == marked.pk


def test_reorder_moves_the_fallback_cover(
    api_client: APIClient, client_for, active_listing
) -> None:
    """Явной обложки нет — её роль играет первое фото по порядку."""
    first = ListingMediaFactory(listing=active_listing, order=0)
    second = ListingMediaFactory(listing=active_listing, order=1)
    owner = client_for(active_listing.owner)

    assert api_client.get(detail_url(active_listing)).json()["cover_media_id"] == first.pk

    owner.patch(
        reverse("catalog:listing-media-reorder", args=[active_listing.slug]),
        {"order": [second.pk, first.pk]},
        format="json",
    )

    assert api_client.get(detail_url(active_listing)).json()["cover_media_id"] == second.pk


# -- кэш подборок -------------------------------------------------------------


def test_featured_cache_does_not_keep_the_old_cover(
    api_client: APIClient, client_for, active_listing
) -> None:
    """Ответ главной кэшируется на пять минут — смена обложки должна его сбросить."""
    first = ListingMediaFactory(listing=active_listing, order=0, is_cover=True)
    other = ListingMediaFactory(listing=active_listing, order=1)

    def featured_cover() -> int | None:
        for cards in api_client.get(FEATURED_URL).json().values():
            for card in cards:
                if card["slug"] == active_listing.slug:
                    return card["cover_media_id"]
        return None

    assert featured_cover() == first.pk  # ответ попал в кэш

    client_for(active_listing.owner).post(
        reverse("catalog:listing-media-cover", args=[active_listing.slug, other.pk])
    )

    assert featured_cover() == other.pk


def test_featured_cache_survives_unrelated_reads(api_client: APIClient, active_listing) -> None:
    """Инвалидация не должна означать «кэш никогда не работает»."""
    ListingMediaFactory(listing=active_listing, order=0, is_cover=True)

    first = api_client.get(FEATURED_URL)
    assert first.status_code == 200

    from apps.catalog.services import featured_cache_key

    assert cache.get(featured_cache_key("testserver")) is not None


# -- регрессия add_listing_media ---------------------------------------------


def test_add_listing_media_does_not_fight_the_promoted_cover(active_listing) -> None:
    """Была IntegrityError: счётчик фото обнулялся, а обложка уже существовала.

    Сценарий: обложка удалена, её роль перешла второму фото, после чего через
    `add_listing_media` добавляется третье.
    """
    from django.core.files.base import ContentFile

    from apps.catalog.services import add_listing_media, delete_listing_media

    cover = ListingMediaFactory(listing=active_listing, order=0, is_cover=True)
    second = ListingMediaFactory(listing=active_listing, order=1)

    delete_listing_media(active_listing, cover)
    second.refresh_from_db()
    assert second.is_cover is True

    added = add_listing_media(
        active_listing,
        ContentFile(b"another-photo", name="another.jpg"),
    )

    assert added.is_cover is False
    assert active_listing.media.filter(is_cover=True).count() == 1
    assert ListingMedia.objects.get(pk=second.pk).is_cover is True
