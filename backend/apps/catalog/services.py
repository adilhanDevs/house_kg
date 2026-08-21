"""Справочники и опции экрана фильтра.

Ответ `/catalog/filter-options/` собирается из справочников и агрегата по
активным объявлениям, поэтому кэшируется на 10 минут. Ключ учитывает город
и язык, а инвалидация идёт через счётчик версии: сбросить нужно все города
сразу, а перечислять их в сигнале — лишние запросы к БД.
"""

import hashlib
from decimal import Decimal
from typing import Any

from django.apps import apps
from django.conf import settings
from django.core.cache import cache
from django.db.models import (
    BooleanField,
    Case,
    Count,
    Exists,
    F,
    IntegerField,
    Max,
    Min,
    OuterRef,
    Prefetch,
    Q,
    QuerySet,
    Value,
    When,
)
from django.db.models.functions import Abs
from django.utils import timezone

from apps.catalog.constants import MAX_PHOTOS_PER_LISTING, MAX_VIDEOS_PER_LISTING
from apps.catalog.enums import Currency, ListingStatus, MediaKind, PropertyKind, SellerKind
from apps.catalog.models import City, District, HouseSeries, Listing, ListingMedia
from apps.common.cache import safe_cache_call

CACHE_TTL = 10 * 60  # 10 минут
VERSION_CACHE_KEY = "catalog:filter-options:version"
CACHE_KEY = "catalog:filter-options:v{version}:{city}:{language}"

SUPPORTED_LANGUAGES = ("ru", "ky", "en")
DEFAULT_LANGUAGE = "ru"

# Чипы «Комнаты» и «Квадратура» из макета (lib/data/listings.dart, kAreaRanges).
ROOM_OPTIONS = [1, 2, 3, 4, 5]
AREA_RANGES = [(35, 45), (45, 55), (65, 75), (75, 85)]


def normalize_language(header: str | None) -> str:
    """Первый тег из Accept-Language, если он поддерживается."""
    tag = (header or "").split(",")[0].strip().lower()[:2]
    return tag if tag in SUPPORTED_LANGUAGES else DEFAULT_LANGUAGE


def resolve_city(slug: str | None) -> City | None:
    """Город по слагу; без слага — город по умолчанию."""
    active = City.objects.filter(is_active=True)
    if slug:
        return active.filter(slug=slug).first()
    return active.filter(is_default=True).first() or active.first()


def _choices_payload(choices: Any) -> list[dict[str, str]]:
    """[("house", "Дома"), ...] -> [{"value": "house", "label": "Дома"}, ...].

    Значения совпадают с enum'ами Flutter — переименовывать нельзя.
    """
    return [{"value": value, "label": label} for value, label in choices]


def _districts_payload(city: City | None) -> list[dict[str, Any]]:
    if city is None:
        return []
    districts = District.objects.filter(city=city, is_active=True).order_by("order", "name")
    return [
        {
            "id": district.id,
            "name": district.name,
            "slug": district.slug,
            "city": city.slug,
            "latitude": str(district.latitude) if district.latitude is not None else None,
            "longitude": str(district.longitude) if district.longitude is not None else None,
        }
        for district in districts
    ]


def _price_range(city: City | None) -> dict[str, Any]:
    """Минимум и максимум по активным объявлениям города."""
    listings = Listing.objects.filter(status=ListingStatus.ACTIVE, currency=Currency.USD)
    if city is not None:
        listings = listings.filter(city=city)

    bounds = listings.aggregate(min_price=Min("price"), max_price=Max("price"))
    minimum = bounds["min_price"]
    maximum = bounds["max_price"]

    return {
        "currency": Currency.USD.value,
        "min": int(minimum) if minimum is not None else settings.CATALOG_DEFAULT_PRICE_MIN,
        "max": int(maximum) if maximum is not None else settings.CATALOG_DEFAULT_PRICE_MAX,
    }


def build_filter_options(city: City | None) -> dict[str, Any]:
    """Собирает ответ экрана фильтра."""
    series = HouseSeries.objects.filter(is_active=True).order_by("order", "code")

    return {
        "property_kinds": _choices_payload(PropertyKind.choices),
        "seller_kinds": _choices_payload(SellerKind.choices),
        "rooms": ROOM_OPTIONS,
        "area_ranges": [
            {"from": start, "to": end, "label": f"{start}-{end}"} for start, end in AREA_RANGES
        ],
        "series": [{"code": item.code, "name": item.name} for item in series],
        "districts": _districts_payload(city),
        "price_range": _price_range(city),
    }


# -- кэш ---------------------------------------------------------------------


def _cache_version() -> int:
    version = cache.get(VERSION_CACHE_KEY)
    if version is None:
        version = 1
        cache.set(VERSION_CACHE_KEY, version, None)
    return int(version)


def filter_options_cache_key(city_slug: str, language: str) -> str:
    return CACHE_KEY.format(
        version=_cache_version(),
        city=city_slug or "default",
        language=language,
    )


def get_filter_options(city_slug: str | None, language: str) -> dict[str, Any]:
    """Кэшированные опции фильтра для города и языка.

    Город резолвится только при промахе кэша: иначе попадание всё равно
    стоило бы запроса в БД, а смысл кэша в том, чтобы не ходить туда вовсе.
    """
    key = filter_options_cache_key(city_slug or "", language)

    payload = cache.get(key)
    if payload is None:
        payload = build_filter_options(resolve_city(city_slug))
        cache.set(key, payload, CACHE_TTL)
    return payload


def _bump_version() -> None:
    try:
        cache.incr(VERSION_CACHE_KEY)
    except ValueError:
        # Счётчика ещё нет — заводим.
        cache.set(VERSION_CACHE_KEY, 1, None)


def invalidate_filter_options_cache() -> None:
    """Поднимает версию — все закэшированные варианты разом становятся неактуальными."""
    safe_cache_call(_bump_version, warning="Не удалось сбросить кэш опций фильтра")


# -- денормализованные счётчики ----------------------------------------------
#
# Только F-выражения: read-modify-write в Python теряет параллельные изменения,
# а сигнал на каждый просмотр добавил бы лишний UPDATE в горячий путь.


def register_view(listing_id: int) -> None:
    """+1 к счётчику просмотров объявления."""
    Listing.objects.filter(pk=listing_id).update(views_count=F("views_count") + 1)


def increment_favourites(listing_id: int) -> None:
    Listing.objects.filter(pk=listing_id).update(favourites_count=F("favourites_count") + 1)


def decrement_favourites(listing_id: int) -> None:
    """-1, но не ниже нуля."""
    Listing.objects.filter(pk=listing_id, favourites_count__gt=0).update(
        favourites_count=F("favourites_count") - 1
    )


# -- медиа объявления --------------------------------------------------------


def media_limit(kind: str) -> int:
    return MAX_PHOTOS_PER_LISTING if kind == MediaKind.PHOTO else MAX_VIDEOS_PER_LISTING


def add_listing_media(
    listing: Listing,
    file: Any,
    kind: str = MediaKind.PHOTO,
    *,
    is_cover: bool | None = None,
    **extra: Any,
) -> ListingMedia:
    """Прикладывает файл к объявлению с проверкой лимита.

    Порядок и обложка проставляются автоматически: первое фото становится
    обложкой карточки.
    """
    existing = listing.media.filter(kind=kind).count()
    # Явная проверка на None: `or` сломался бы на нулевом порядке первого файла.
    top_order = listing.media.aggregate(top=Max("order"))["top"]
    next_order = 0 if top_order is None else top_order + 1

    media = ListingMedia(
        listing=listing,
        file=file,
        kind=kind,
        order=next_order,
        is_cover=(existing == 0 and kind == MediaKind.PHOTO) if is_cover is None else is_cover,
        **extra,
    )
    # Лимит проверяется и здесь, и в модели: сервис даёт понятную ошибку,
    # clean() страхует запись мимо сервиса.
    media.full_clean(exclude=["file"])
    media.save()
    return media


# -- публичные выборки каталога ----------------------------------------------

FEATURED_CACHE_KEY = "catalog:featured:v{version}:{host}"
FEATURED_CACHE_TTL = 5 * 60
FEATURED_PER_KIND = 4

SIMILAR_LIMIT = 6
SIMILAR_PRICE_SPREAD = Decimal("0.25")


def promoted_annotation() -> Case:
    """1 для продвинутых объявлений, 0 для остальных.

    Аннотация называется не `is_promoted`, потому что у модели есть одноимённое
    свойство: Django присвоил бы значение аннотации в атрибут и упал на
    read-only property.
    """
    return Case(
        When(promoted_until__gt=timezone.now(), then=Value(1)),
        default=Value(0),
        output_field=IntegerField(),
    )


def favourite_annotation(user: Any) -> Exists | Value:
    """Есть ли объявление в избранном у текущего пользователя.

    Подзапрос EXISTS — без дополнительных запросов на каждый объект.
    """
    if not (user and user.is_authenticated):
        return Value(False, output_field=BooleanField())

    favourite_model = apps.get_model("engagement", "Favourite")
    return Exists(favourite_model.objects.filter(user_id=user.pk, listing_id=OuterRef("pk")))


def listing_queryset(user: Any = None, only_active: bool = True) -> QuerySet[Listing]:
    """Базовый queryset карточек со всем, что нужно списку.

    `only_active=False` нужен избранному и истории просмотров: объявление могло
    уйти в архив, но из списка пользователя исчезать не должно.
    """
    cover_media = ListingMedia.objects.filter(is_cover=True)
    base = Listing.objects.all()
    if only_active:
        base = base.filter(status=ListingStatus.ACTIVE)

    return (
        base.select_related("district", "city", "series", "builder", "owner")
        .prefetch_related(Prefetch("media", queryset=cover_media, to_attr="cover_media"))
        .annotate(
            promoted_rank=promoted_annotation(),
            photos_count=Count(
                "media",
                filter=Q(media__kind=MediaKind.PHOTO),
                distinct=True,
            ),
            is_favourite_flag=favourite_annotation(user),
        )
    )


def order_listings(queryset: QuerySet[Listing], ordering: str) -> QuerySet[Listing]:
    """Продвинутые объявления всегда сверху, дальше — выбранная сортировка."""
    return queryset.order_by("-promoted_rank", ordering, "-id")


# -- отметка просмотра -------------------------------------------------------

VIEW_DEDUP_KEY = "view:{slug}:{actor}"
VIEW_DEDUP_TTL = 30 * 60


def register_listing_view(listing: Listing, user: Any, actor_key: str) -> int:
    """Считает просмотр не чаще раза в 30 минут на пользователя (или IP).

    Возвращает актуальное значение счётчика.
    """
    key = VIEW_DEDUP_KEY.format(slug=listing.slug, actor=actor_key)
    # cache.add ставит значение, только если ключа ещё нет — атомарно.
    first_time = cache.add(key, 1, VIEW_DEDUP_TTL)

    if first_time:
        register_view(listing.pk)

    from apps.engagement.services import note_view

    note_view(user, listing)

    return Listing.objects.values_list("views_count", flat=True).get(pk=listing.pk)


# -- подборки для главного экрана --------------------------------------------


def build_featured(user: Any = None) -> dict[str, list[Listing]]:
    """По четыре свежих объявления каждого типа, продвинутые впереди."""
    featured: dict[str, list[Listing]] = {}
    for kind in PropertyKind.values:
        queryset = listing_queryset(user).filter(kind=kind)
        featured[kind] = list(order_listings(queryset, "-published_at")[:FEATURED_PER_KIND])
    return featured


def featured_cache_key(host: str) -> str:
    return FEATURED_CACHE_KEY.format(version=_cache_version(), host=host or "default")


# -- похожие объявления ------------------------------------------------------


def similar_listings(listing: Listing, user: Any = None) -> QuerySet[Listing]:
    """Тот же район или тип, цена в пределах ±25%, сам объект исключён."""
    low = listing.price * (1 - SIMILAR_PRICE_SPREAD)
    high = listing.price * (1 + SIMILAR_PRICE_SPREAD)

    queryset = (
        listing_queryset(user)
        .filter(Q(district_id=listing.district_id) | Q(kind=listing.kind))
        .filter(price__gte=low, price__lte=high)
        .exclude(pk=listing.pk)
        .annotate(
            same_district=Case(
                When(district_id=listing.district_id, then=Value(1)),
                default=Value(0),
                output_field=IntegerField(),
            ),
            price_distance=Abs(F("price") - listing.price),
        )
        .order_by("-same_district", "price_distance", "-promoted_rank", "-id")
    )
    return queryset[:SIMILAR_LIMIT]


# -- количество объектов под фильтром ----------------------------------------

LISTINGS_COUNT_CACHE_TTL = 60
LISTINGS_COUNT_CACHE_KEY = "catalog:listings-count:v{version}:{digest}"

# Параметры, не влияющие на количество.
COUNT_IGNORED_PARAMS = frozenset({"page_size", "cursor", "ordering", "format"})


def listings_count_cache_key(params: Any) -> str:
    """Ключ по нормализованной строке параметров: порядок и регистр не важны."""
    normalized = sorted(
        (key.lower(), ",".join(sorted(params.getlist(key))))
        for key in params.keys()
        if key.lower() not in COUNT_IGNORED_PARAMS
    )
    raw = "&".join(f"{key}={value}" for key, value in normalized)
    digest = hashlib.md5(raw.encode("utf-8"), usedforsecurity=False).hexdigest()
    return LISTINGS_COUNT_CACHE_KEY.format(version=_cache_version(), digest=digest)


# -- публикация --------------------------------------------------------------


def publish_listing(listing: Listing) -> Listing:
    """Публикует объявление и ставит пересчёт поискового индекса.

    Индекс обновляется после коммита: до него задача не увидит новые данные.
    """
    from django.db import transaction

    from apps.catalog.tasks import update_listing_search_vector

    listing.status = ListingStatus.ACTIVE
    listing.published_at = listing.published_at or timezone.now()
    listing.rejection_reason = ""
    listing.save(update_fields=["status", "published_at", "rejection_reason", "updated_at"])

    transaction.on_commit(lambda: update_listing_search_vector.delay(listing.pk))
    return listing
