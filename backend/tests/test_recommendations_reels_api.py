"""Лента видеообзоров рекомендаций отдаёт сами видео.

Регрессия, из-за которой приложение показывало один ролик и не листалось:
сериализатор читает поле `videos` из атрибута `processed_videos`, который
навешивает Prefetch. Во вью рекомендаций его не было, и DRF отдавал
`videos: null` на каждую карточку — клиент такие карточки отбрасывает.
"""

import pytest
from rest_framework.test import APIClient

from apps.catalog.enums import ListingStatus, MediaKind, MediaStatus
from apps.catalog.models import ListingMedia
from tests.factories import ListingFactory, UserFactory

REELS_URL = "/api/v1/recommendations/reels/"
SESSION = "session-reels-test"


def _with_ready_video(listing):
    ListingMedia.objects.create(
        listing=listing,
        kind=MediaKind.VIDEO,
        status=MediaStatus.READY,
        order=0,
    )
    return listing


@pytest.mark.django_db
def test_reels_feed_returns_the_videos_themselves() -> None:
    owner = UserFactory()
    for _ in range(3):
        _with_ready_video(ListingFactory(owner=owner, status=ListingStatus.ACTIVE))

    response = APIClient().get(REELS_URL, {"session_id": SESSION, "feed_session_id": SESSION})

    assert response.status_code == 200
    results = response.data["results"]
    assert results, "лента не должна быть пустой при готовых видео"
    for item in results:
        assert item["videos"], f"у карточки {item['slug']} пустое поле videos"


@pytest.mark.django_db
def test_listing_without_ready_video_is_not_offered_as_a_reel() -> None:
    """Необработанный ролик — это карточка без единого воспроизводимого файла."""
    owner = UserFactory()
    pending = ListingFactory(owner=owner, status=ListingStatus.ACTIVE)
    ListingMedia.objects.create(
        listing=pending,
        kind=MediaKind.VIDEO,
        status=MediaStatus.PROCESSING,
        order=0,
    )
    ready = _with_ready_video(ListingFactory(owner=owner, status=ListingStatus.ACTIVE))

    response = APIClient().get(REELS_URL, {"session_id": SESSION, "feed_session_id": SESSION})

    slugs = {item["slug"] for item in response.data["results"]}
    assert ready.slug in slugs
    assert pending.slug not in slugs
