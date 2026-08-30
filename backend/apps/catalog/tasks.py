"""Фоновые задачи каталога: курсы валют и поисковый индекс."""

import logging
from decimal import Decimal, InvalidOperation
from typing import Any
from xml.etree.ElementTree import ParseError

import requests
from celery import shared_task
from django.conf import settings
from django.core.files.base import ContentFile
from django.db.models import F

logger = logging.getLogger(__name__)


def parse_nbkr_usd_rate(payload: bytes) -> Decimal:
    """Достаёт курс доллара из XML НБКР.

    Формат: <Currency ISOCode="USD"><Nominal>1</Nominal><Value>87,4500</Value>.
    Значение приходит с запятой в качестве разделителя.
    """
    # defusedxml, а не стандартный ElementTree: XML приходит извне, а
    # обычный парсер разворачивает «миллиард смешков» и внешние сущности.
    from defusedxml.ElementTree import fromstring

    root = fromstring(payload)

    for currency in root.iter("Currency"):
        if currency.get("ISOCode") != "USD":
            continue

        value = (currency.findtext("Value") or "").replace(",", ".").strip()
        nominal = (currency.findtext("Nominal") or "1").replace(",", ".").strip()
        try:
            rate = Decimal(value) / Decimal(nominal or "1")
        except (InvalidOperation, ZeroDivisionError) as exc:
            raise ValueError("Некорректное значение курса в ответе НБКР") from exc

        if rate <= 0:
            raise ValueError("Курс НБКР должен быть положительным")
        return rate

    raise ValueError("В ответе НБКР нет курса USD")


@shared_task(name="catalog.fetch_exchange_rates", ignore_result=True)
def fetch_exchange_rates() -> str:
    """Раз в сутки тянет курс USD/KGS с сайта НБКР.

    Источник недоступен или ответил мусором — пишем в лог и оставляем прошлый
    курс: каталог должен работать и с вчерашним курсом.
    """
    from apps.catalog.enums import Currency
    from apps.catalog.models import ExchangeRate
    from apps.catalog.rates import invalidate_rate_cache

    try:
        response = requests.get(settings.NBKR_RATES_URL, timeout=settings.NBKR_TIMEOUT)
        response.raise_for_status()
        rate = parse_nbkr_usd_rate(response.content)
    except (requests.RequestException, ParseError, ValueError) as exc:
        logger.warning("Курс НБКР не обновлён (%s): %s", exc.__class__.__name__, exc)
        return "skipped"

    ExchangeRate.objects.create(
        currency_from=Currency.USD,
        currency_to=Currency.KGS,
        rate=rate,
    )
    invalidate_rate_cache()
    updated = recalculate_prices_in_usd(rate)

    logger.info("Курс USD/KGS обновлён: %s, пересчитано объявлений: %s", rate, updated)
    return "updated"


def recalculate_prices_in_usd(rate: Decimal) -> int:
    """Пересчитывает price_usd у объявлений в сомах одним UPDATE."""
    from apps.catalog.enums import Currency
    from apps.catalog.models import Listing

    Listing.objects.filter(currency=Currency.USD).exclude(price_usd=F("price")).update(
        price_usd=F("price")
    )
    return Listing.objects.filter(currency=Currency.KGS).update(price_usd=F("price") / rate)


@shared_task(name="catalog.rebuild_search_index", ignore_result=True)
def rebuild_search_index() -> int:
    """Полный пересчёт поискового индекса."""
    from apps.catalog.search import update_search_vectors

    updated = update_search_vectors()
    logger.info("Поисковый индекс пересобран, объявлений: %s", updated)
    return updated


@shared_task(name="catalog.update_listing_search_vector", ignore_result=True)
def update_listing_search_vector(listing_id: int) -> int:
    """Пересчёт индекса одного объявления — после публикации или правки."""
    from apps.catalog.models import Listing
    from apps.catalog.search import update_search_vectors

    return update_search_vectors(Listing.objects.filter(pk=listing_id))


@shared_task(name="catalog.expire_listings", ignore_result=True)
def expire_listings() -> dict[str, int]:
    """Снимает с публикации истёкшие объявления и предупреждает о скором снятии."""
    from datetime import timedelta

    from django.conf import settings
    from django.utils import timezone

    from apps.catalog.enums import ListingStatus
    from apps.catalog.models import Listing
    from apps.notifications.models import Notification, NotificationType
    from apps.notifications.services import notify_many

    now = timezone.now()

    expiring_soon = now + timedelta(days=settings.LISTING_EXPIRY_WARNING_DAYS)
    warnings = [
        Notification(
            user=listing.owner,
            type=NotificationType.LISTING_MODERATED,
            title="Объявление скоро будет снято с публикации",
            body=f"«{listing}» перестанет показываться {listing.expires_at:%d.%m.%Y}.",
            payload={"kind": "listing_expiring", "listing_slug": listing.slug},
            listing=listing,
        )
        for listing in Listing.objects.filter(
            status=ListingStatus.ACTIVE,
            expires_at__gt=now,
            expires_at__lte=expiring_soon,
        ).select_related("owner", "district")
    ]
    notify_many(warnings)

    stale = list(
        Listing.objects.filter(status=ListingStatus.ACTIVE, expires_at__lt=now).select_related(
            "owner", "district"
        )
    )
    archived = Listing.objects.filter(pk__in=[item.pk for item in stale]).update(
        status=ListingStatus.ARCHIVED, updated_at=now
    )

    notify_many(
        [
            Notification(
                user=listing.owner,
                type=NotificationType.LISTING_MODERATED,
                title="Объявление снято с публикации",
                body=f"«{listing}» ушло в архив. Его можно вернуть из «Моих объявлений».",
                payload={"kind": "listing_expired", "listing_slug": listing.slug},
                listing=listing,
            )
            for listing in stale
        ]
    )

    logger.info("Снято с публикации: %s, предупреждений: %s", archived, len(warnings))
    return {"archived": archived, "warned": len(warnings)}


@shared_task(
    name="catalog.process_media",
    bind=True,
    max_retries=2,
    default_retry_delay=30,
    ignore_result=True,
)
def process_media(self, media_id: int) -> str:  # noqa: ANN001 - self у bind-задачи
    """Обработка загруженного файла: EXIF, варианты размеров, WebP, phash.

    Порядок шагов не случаен: EXIF снимается ПЕРВЫМ. В метаданных снимка
    квартиры лежат GPS-координаты, модель телефона и время съёмки; ни один
    вариант изображения не должен собираться из данных, где они ещё есть.
    """
    import time

    from apps.catalog.enums import MediaKind, MediaStatus
    from apps.catalog.models import ListingMedia
    from apps.common.metrics import observe_media_processed, safe

    media = ListingMedia.objects.select_related("listing").filter(pk=media_id).first()
    if media is None:
        logger.info("Медиа %s удалено до начала обработки", media_id)
        return "missing"

    started = time.monotonic()
    try:
        if media.kind == MediaKind.PHOTO:
            _process_photo(media)
        else:
            _process_video(media)
        safe(observe_media_processed, media.kind, time.monotonic() - started)
    except Exception as exc:  # noqa: BLE001 - причина уходит в поле и в лог
        logger.exception("Обработка медиа %s не удалась", media_id)
        ListingMedia.objects.filter(pk=media_id).update(
            status=MediaStatus.FAILED,
            processing_error=f"{exc.__class__.__name__}: {exc}"[:255],
        )
        if self.request.retries < self.max_retries:
            raise self.retry(exc=exc) from exc
        return "failed"

    return "ready"


def _process_photo(media: Any) -> None:
    """EXIF -> три варианта размера -> WebP + JPEG-фолбэк -> phash."""
    from io import BytesIO

    from django.conf import settings
    from PIL import Image

    from apps.catalog.enums import MediaStatus
    from apps.catalog.media import (
        encode,
        perceptual_hash,
        resize_to,
        strip_exif,
        variant_name,
    )

    media.file.open("rb")
    try:
        data = media.file.read()
    finally:
        media.file.close()

    with Image.open(BytesIO(data)) as raw:
        # Шаг 1. EXIF снимается до всего остального.
        clean = strip_exif(raw)

    media.phash = perceptual_hash(clean)
    media.width, media.height = clean.size
    media.size_bytes = len(data)

    updated = ["phash", "width", "height", "size_bytes", "status", "updated_at"]

    for variant, max_side in settings.LISTING_IMAGE_VARIANTS.items():
        resized = resize_to(clean, max_side)

        webp_field = getattr(media, f"url_{variant}")
        webp_field.save(
            variant_name(media, variant, "webp"),
            ContentFile(encode(resized, "WEBP")),
            save=False,
        )
        updated.append(f"url_{variant}")

        jpeg_field = getattr(media, f"url_{variant}_jpeg")
        jpeg_field.save(
            variant_name(media, variant, "jpg"),
            ContentFile(encode(resized, "JPEG")),
            save=False,
        )
        updated.append(f"url_{variant}_jpeg")

    media.status = MediaStatus.READY
    media.processing_error = ""
    updated.append("processing_error")
    media.save(update_fields=updated)

    logger.info("Медиа %s обработано: %sx%s", media.pk, media.width, media.height)


def _process_video(media: Any) -> None:
    """Само видео не перекодируем — дорого. Только метаданные и кадр-превью."""
    from apps.catalog.enums import MediaStatus
    from apps.catalog.media import (
        extract_video_frame,
        local_path,
        probe_video,
        temporary_copy,
        variant_name,
    )

    path = local_path(media.file)
    temporary: Any = None
    if path is None:
        temporary = temporary_copy(media.file, suffix=".mp4")
        path = str(temporary)

    try:
        probe = probe_video(path)
        frame = extract_video_frame(path, at_second=1)
        if not frame:
            frame = extract_video_frame(path, at_second=0)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)

    media.duration_seconds = probe.get("duration_seconds") or media.duration_seconds
    media.width = probe.get("width") or media.width
    media.height = probe.get("height") or media.height
    media.size_bytes = media.size_bytes or media.file.size

    updated = ["duration_seconds", "width", "height", "size_bytes", "status", "updated_at"]

    if frame:
        media.thumbnail.save(
            variant_name(media, "poster", "jpg"),
            ContentFile(frame),
            save=False,
        )
        updated.append("thumbnail")

    media.status = MediaStatus.READY
    media.processing_error = ""
    updated.append("processing_error")
    media.save(update_fields=updated)

    logger.info("Видео %s обработано: %s с", media.pk, media.duration_seconds)


@shared_task(name="catalog.run_moderation_checks", ignore_result=True)
def run_moderation_checks(listing_id: int) -> dict[str, Any]:
    """Прогоняет автопроверки и записывает их в открытую задачу модерации.

    Проверки ходят в БД и считают перцептивные хеши, поэтому выполняются
    в фоне: подача объявления не должна ждать сравнения с базой фотографий.
    """
    from apps.catalog.models import Listing
    from apps.catalog.moderation.checks import count_triggered, run_all
    from apps.catalog.moderation.services import apply_check_results

    listing = Listing.objects.select_related("district", "owner").filter(pk=listing_id).first()
    if listing is None:
        logger.info("Объявление %s исчезло до прогона автопроверок", listing_id)
        return {}

    results = run_all(listing)
    task = apply_check_results(listing_id, results)

    triggered = count_triggered(results)
    logger.info(
        "Автопроверки объявления %s: сработало %s (задача %s)",
        listing.slug,
        triggered,
        getattr(task, "pk", None),
    )
    return results


@shared_task(name="catalog.flush_impressions", ignore_result=True)
def flush_impressions() -> int:
    """Сбрасывает накопленные показы из Redis в ListingDailyStat.

    Страница каталога из двадцати карточек даёт двадцать показов за запрос —
    писать их по одному UPDATE нельзя. Здесь они превращаются в один UPDATE
    на объявление за пять минут.
    """
    from apps.catalog.models import ListingDailyStat
    from apps.catalog.stats import _today, drain_impressions

    buffered = drain_impressions()
    if not buffered:
        return 0

    day = _today()
    existing = dict(
        ListingDailyStat.objects.filter(listing_id__in=buffered, date=day).values_list(
            "listing_id", "pk"
        )
    )

    updated = 0
    for listing_id, count in buffered.items():
        if listing_id in existing:
            ListingDailyStat.objects.filter(pk=existing[listing_id]).update(
                impressions=F("impressions") + count
            )
        else:
            # Объявление могли удалить, пока показы лежали в буфере.
            ListingDailyStat.objects.get_or_create(
                listing_id=listing_id, date=day, defaults={"impressions": count}
            )
        updated += 1

    logger.info("Показы сброшены в статистику: объявлений %s", updated)
    return updated
