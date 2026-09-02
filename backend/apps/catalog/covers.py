"""Обложка карточки объявления — какое медиа показывать в сетке каталога.

Правило одно и то же везде, где рисуется карточка: помеченное обложкой фото,
иначе первое фото по порядку, иначе кадр видеообзора.

Раньше обложка бралась строго из медиа с галкой «Обложка». Галку ставит только
загрузка через приложение (первому фото объявления); всё, что заливали через
админку или переносили импортом, оставалось в каталоге серым прямоугольником,
хотя фотографии у объявления были.
"""

from collections.abc import Iterable
from typing import Any

from django.db.models import QuerySet

from apps.catalog.enums import MediaKind
from apps.catalog.models import ListingMedia

# Имя атрибута, в который Prefetch кладёт кандидатов на обложку.
COVER_ATTR = "cover_media"


def cover_candidates() -> QuerySet[ListingMedia]:
    """Медиа, из которых может получиться обложка: всё, у чего есть файл."""
    return ListingMedia.objects.exclude(file="").order_by("order", "id")


def pick_cover(items: Iterable[ListingMedia] | None) -> ListingMedia | None:
    """Лучшее медиа под обложку из уже загруженного списка.

    Порядок предпочтения: фото с галкой «Обложка» → первое фото по порядку →
    видео, у которого есть кадр-превью.
    """
    media = list(items or [])
    if not media:
        return None

    def rank(item: ListingMedia) -> tuple[bool, int, int]:
        return (not item.is_cover, item.order, item.pk or 0)

    photos = [item for item in media if item.kind == MediaKind.PHOTO and item.file]
    if photos:
        return min(photos, key=rank)

    # Фотографий нет вовсе — показываем кадр ролика, если он есть.
    videos = [item for item in media if item.kind == MediaKind.VIDEO and item.thumbnail]
    if videos:
        return min(videos, key=rank)

    return None


def cover_file(media: ListingMedia | None) -> Any:
    """Файл обложки для карточки каталога: маленькое превью.

    В сетке карточка занимает 160 pt, поэтому её кормит `url_thumb` (400 px).
    Для детального экрана этого мало — там берётся `cover_detail_file`.
    """
    if media is None:
        return None
    if media.kind == MediaKind.VIDEO:
        return media.thumbnail or None
    return media.url_thumb or media.file or None


def cover_detail_file(media: ListingMedia | None) -> Any:
    """Файл той же обложки, но пригодный для крупного показа.

    Это ровно тот же `ListingMedia`, что и у `cover_file`, — просто другой
    вариант размера. Клиент по этим двум URL не должен решать, одно это фото
    или разные: идентичность даёт `cover_media_id`.
    """
    if media is None:
        return None
    if media.kind == MediaKind.VIDEO:
        return media.thumbnail or None
    return media.url_medium or media.url_original or media.file or None


def listing_cover(listing: Any) -> ListingMedia | None:
    """Медиа, выбранное обложкой объявления, — единственный источник истины.

    Берёт кандидатов из `cover_media` (их кладёт Prefetch списочных запросов),
    а если их нет — из обычной связи `media`.
    """
    candidates = getattr(listing, COVER_ATTR, None)
    if candidates is None:
        candidates = listing.media.all()
    return pick_cover(candidates)


def listing_cover_file(listing: Any) -> Any:
    """Файл обложки объявления для карточки каталога."""
    return cover_file(listing_cover(listing))
