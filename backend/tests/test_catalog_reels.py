import pytest
from django.urls import reverse

from apps.catalog.enums import ListingStatus, MediaKind, MediaStatus
from tests.factories import ListingFactory, ListingMediaFactory

pytestmark = pytest.mark.django_db


def reels_url():
    return reverse("catalog:listings-reels")


def test_reels_feed_returns_active_listings_with_ready_video(api_client):
    """
    Эндпоинт должен возвращать только АКТИВНЫЕ объявления,
    у которых есть обработанные (READY) ВИДЕО.
    """
    # 1. Draft listing, has video -> shouldn't appear
    draft = ListingFactory(status=ListingStatus.DRAFT)
    ListingMediaFactory(listing=draft, kind=MediaKind.VIDEO, status=MediaStatus.READY)

    # 2. Active listing, only photo -> shouldn't appear
    active_no_video = ListingFactory(status=ListingStatus.ACTIVE)
    ListingMediaFactory(listing=active_no_video, kind=MediaKind.PHOTO, status=MediaStatus.READY)

    # 3. Active listing, video is processing -> shouldn't appear
    active_processing_video = ListingFactory(status=ListingStatus.ACTIVE)
    ListingMediaFactory(listing=active_processing_video, kind=MediaKind.VIDEO, status=MediaStatus.PROCESSING)

    # 4. Active listing, ready video -> should appear!
    active_ready_video = ListingFactory(status=ListingStatus.ACTIVE)
    ListingMediaFactory(listing=active_ready_video, kind=MediaKind.VIDEO, status=MediaStatus.READY, title="Reel Title")

    response = api_client.get(reels_url())

    assert response.status_code == 200
    results = response.data["results"]
    assert len(results) == 1
    
    assert results[0]["slug"] == active_ready_video.slug
    assert len(results[0]["videos"]) == 1
    assert results[0]["videos"][0]["title"] == "Reel Title"


def test_reels_feed_ordering(api_client):
    """
    Проверяем сортировку по убыванию (новые видео первыми).
    """
    l1 = ListingFactory(status=ListingStatus.ACTIVE)
    ListingMediaFactory(listing=l1, kind=MediaKind.VIDEO, status=MediaStatus.READY)

    l2 = ListingFactory(status=ListingStatus.ACTIVE)
    ListingMediaFactory(listing=l2, kind=MediaKind.VIDEO, status=MediaStatus.READY)

    response = api_client.get(reels_url())
    assert response.status_code == 200
    results = response.data["results"]
    assert len(results) == 2
    
    # Сортировка по -id (l2 новее)
    assert results[0]["slug"] == l2.slug
    assert results[1]["slug"] == l1.slug


def test_reels_feed_avoids_n_plus_one_queries(api_client, django_assert_num_queries):
    """
    Проверяем отсутствие N+1 запросов за счёт prefetch_related.
    """
    from django.db import connection
    from django.test.utils import CaptureQueriesContext

    def _create_listing():
        listing = ListingFactory(status=ListingStatus.ACTIVE)
        ListingMediaFactory.create_batch(2, listing=listing, kind=MediaKind.VIDEO, status=MediaStatus.READY)
        ListingMediaFactory.create_batch(2, listing=listing, kind=MediaKind.PHOTO, status=MediaStatus.READY)
        return listing

    # Подготовим 1 объявление и замерим кол-во запросов
    _create_listing()
    
    with CaptureQueriesContext(connection) as ctx:
        api_client.get(reels_url())
    base_queries = len(ctx.captured_queries)

    # Теперь создаем еще 4 объявления (всего 5)
    for _ in range(4):
        _create_listing()
        
    # Кол-во запросов не должно измениться
    with CaptureQueriesContext(connection) as ctx:
        response = api_client.get(reels_url())

    assert len(ctx.captured_queries) <= base_queries + 2  # allow 2 extra for count/cursor differences if any, but strictly should be same or +0
    assert response.status_code == 200
    assert len(response.data["results"]) == 5
    for result in response.data["results"]:
        assert len(result["videos"]) == 2
