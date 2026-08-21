"""Тесты модели объявления и его медиа."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.core.exceptions import ValidationError
from django.db.utils import IntegrityError
from django.utils import timezone

from apps.catalog.constants import MAX_PHOTOS_PER_LISTING, MAX_VIDEOS_PER_LISTING
from apps.catalog.enums import ListingStatus, MediaKind, PropertyKind
from apps.catalog.models import Listing, ListingMedia, build_listing_slug
from apps.catalog.services import (
    add_listing_media,
    decrement_favourites,
    increment_favourites,
    register_view,
)
from tests.factories import DistrictFactory, ListingFactory, ListingMediaFactory


def photo(name: str = "photo.jpg") -> object:
    from django.core.files.uploadedfile import SimpleUploadedFile

    return SimpleUploadedFile(name, b"fake-photo-bytes", content_type="image/jpeg")


# -- слаг --------------------------------------------------------------------


def test_slug_pattern() -> None:
    slug = build_listing_slug("technopark", 3)

    assert slug.startswith("technopark-3k-")
    assert len(slug.split("-")[-1]) == 8


def test_slug_fits_max_length() -> None:
    slug = build_listing_slug("a" * 200, 12)

    assert len(slug) <= 140
    assert slug.endswith("-12k-" + slug.split("-")[-1])


@pytest.mark.django_db
def test_generated_slugs_are_unique() -> None:
    district = DistrictFactory(slug="technopark")

    listings = [ListingFactory(district=district, rooms=3) for _ in range(25)]

    slugs = {listing.slug for listing in listings}
    assert len(slugs) == 25
    assert all(slug.startswith("technopark-3k-") for slug in slugs)


@pytest.mark.django_db
def test_slug_is_stable_after_creation() -> None:
    listing = ListingFactory(rooms=2)
    original = listing.slug

    listing.rooms = 4
    listing.save()
    listing.refresh_from_db()

    assert listing.slug == original


@pytest.mark.django_db
def test_explicit_slug_is_kept() -> None:
    listing = ListingFactory(slug="technopark")

    assert listing.slug == "technopark"


# -- свойства ----------------------------------------------------------------


@pytest.mark.django_db
def test_is_plot() -> None:
    assert ListingFactory(kind=PropertyKind.PLOT).is_plot is True
    assert ListingFactory(kind=PropertyKind.APARTMENT).is_plot is False


@pytest.mark.django_db
def test_is_promoted() -> None:
    now = timezone.now()

    assert ListingFactory(promoted_until=None).is_promoted is False
    assert ListingFactory(promoted_until=now - timedelta(seconds=1)).is_promoted is False
    assert ListingFactory(promoted_until=now + timedelta(days=1)).is_promoted is True


@pytest.mark.django_db
def test_price_display_and_discount() -> None:
    listing = ListingFactory(price=Decimal("102000"), old_price=Decimal("107000"))

    assert listing.price_display == "102 000$"
    assert listing.discount_percent == 5

    without_discount = ListingFactory(price=Decimal("102000"), old_price=None)
    assert without_discount.discount_percent is None

    cheaper_before = ListingFactory(price=Decimal("102000"), old_price=Decimal("90000"))
    assert cheaper_before.discount_percent is None


# -- медиа и лимиты ----------------------------------------------------------


@pytest.mark.django_db
def test_first_photo_becomes_cover() -> None:
    listing = ListingFactory()

    first = add_listing_media(listing, photo("one.jpg"))
    second = add_listing_media(listing, photo("two.jpg"))

    assert first.is_cover is True
    assert first.order == 0
    assert second.is_cover is False
    assert second.order == 1


@pytest.mark.django_db
def test_twenty_first_photo_is_rejected() -> None:
    listing = ListingFactory()
    for index in range(MAX_PHOTOS_PER_LISTING):
        ListingMediaFactory(listing=listing, order=index, kind=MediaKind.PHOTO)

    with pytest.raises(ValidationError) as exc:
        add_listing_media(listing, photo("extra.jpg"))

    assert "не больше 20" in str(exc.value)
    assert listing.media.filter(kind=MediaKind.PHOTO).count() == MAX_PHOTOS_PER_LISTING


@pytest.mark.django_db
def test_photo_limit_is_enforced_by_model_clean() -> None:
    """Запись мимо сервиса тоже не проходит."""
    listing = ListingFactory()
    for index in range(MAX_PHOTOS_PER_LISTING):
        ListingMediaFactory(listing=listing, order=index)

    extra = ListingMedia(listing=listing, kind=MediaKind.PHOTO, order=99, file="x.jpg")

    with pytest.raises(ValidationError):
        extra.full_clean(exclude=["file"])


@pytest.mark.django_db
def test_video_limit_is_separate_from_photo_limit() -> None:
    listing = ListingFactory()
    for index in range(MAX_PHOTOS_PER_LISTING):
        ListingMediaFactory(listing=listing, order=index, kind=MediaKind.PHOTO)

    # Фотографии исчерпаны, а видео можно приложить.
    video = add_listing_media(listing, photo("clip.mp4"), kind=MediaKind.VIDEO)
    assert video.pk

    for index in range(MAX_VIDEOS_PER_LISTING - 1):
        ListingMediaFactory(listing=listing, order=100 + index, kind=MediaKind.VIDEO)

    with pytest.raises(ValidationError):
        add_listing_media(listing, photo("extra.mp4"), kind=MediaKind.VIDEO)


@pytest.mark.django_db
def test_two_covers_violate_constraint() -> None:
    listing = ListingFactory()
    ListingMediaFactory(listing=listing, order=0, is_cover=True)

    with pytest.raises(IntegrityError):
        ListingMediaFactory(listing=listing, order=1, is_cover=True)


@pytest.mark.django_db
def test_cover_constraint_is_per_listing() -> None:
    first = ListingFactory()
    second = ListingFactory()

    ListingMediaFactory(listing=first, order=0, is_cover=True)
    other_cover = ListingMediaFactory(listing=second, order=0, is_cover=True)

    assert other_cover.pk


@pytest.mark.django_db
def test_media_are_ordered() -> None:
    listing = ListingFactory()
    ListingMediaFactory(listing=listing, order=2)
    ListingMediaFactory(listing=listing, order=0)
    ListingMediaFactory(listing=listing, order=1)

    assert [media.order for media in listing.media.all()] == [0, 1, 2]


# -- счётчики ----------------------------------------------------------------


@pytest.mark.django_db
def test_view_counter_uses_f_expression() -> None:
    listing = ListingFactory(views_count=0)

    register_view(listing.pk)
    register_view(listing.pk)

    listing.refresh_from_db()
    assert listing.views_count == 2


@pytest.mark.django_db
def test_favourites_counter_never_goes_below_zero() -> None:
    listing = ListingFactory(favourites_count=0)

    increment_favourites(listing.pk)
    listing.refresh_from_db()
    assert listing.favourites_count == 1

    decrement_favourites(listing.pk)
    decrement_favourites(listing.pk)
    listing.refresh_from_db()
    assert listing.favourites_count == 0


@pytest.mark.django_db
def test_counters_survive_stale_python_state() -> None:
    """Устаревший объект в памяти не затирает чужой инкремент."""
    listing = ListingFactory(views_count=0)
    stale = Listing.objects.get(pk=listing.pk)

    register_view(listing.pk)

    stale.status = ListingStatus.ACTIVE
    stale.save(update_fields=["status"])

    listing.refresh_from_db()
    assert listing.views_count == 1
