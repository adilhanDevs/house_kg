"""Справочники и опции экрана фильтра.

Ответ `/catalog/filter-options/` собирается из справочников и агрегата по
активным объявлениям, поэтому кэшируется на 10 минут. Ключ учитывает город
и язык, а инвалидация идёт через счётчик версии: сбросить нужно все города
сразу, а перечислять их в сигнале — лишние запросы к БД.
"""

import hashlib
import logging
from datetime import timedelta
from decimal import Decimal
from typing import Any

from django.apps import apps
from django.conf import settings
from django.core.cache import cache
from django.core.exceptions import ValidationError as DjangoValidationError
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
from rest_framework.exceptions import Throttled

from apps.catalog.constants import MAX_PHOTOS_PER_LISTING, MAX_VIDEOS_PER_LISTING
from apps.catalog.enums import (
    BuildingLine,
    CommercialPurpose,
    Currency,
    ListingStatus,
    MediaKind,
    MediaStatus,
    PlotPurpose,
    PropertyKind,
    SellerKind,
)
from apps.catalog.field_rules import REQUIRED_BY_KIND
from apps.catalog.models import (
    Builder,
    City,
    District,
    HouseSeries,
    Listing,
    ListingMedia,
    ListingRoom,
)
from apps.catalog.stats import bump_stat
from apps.common.audit import audit
from apps.common.cache import safe_cache_call
from apps.common.exceptions import ApiValidationError, ConflictError
from apps.common.metrics import observe_listing_published, safe
from apps.common.models import AuditLog

logger = logging.getLogger(__name__)

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
        city = active.filter(slug=slug).first() or active.filter(name__iexact=slug).first()
        if city:
            return city
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
    builders = Builder.objects.filter(is_active=True).order_by("order", "name")

    return {
        "property_kinds": _choices_payload(PropertyKind.choices),
        "seller_kinds": _choices_payload(SellerKind.choices),
        "rooms": ROOM_OPTIONS,
        "area_ranges": [
            {"from": start, "to": end, "label": f"{start}-{end}"} for start, end in AREA_RANGES
        ],
        "series": [{"code": item.code, "name": item.name} for item in series],
        "plot_purposes": _choices_payload(PlotPurpose.choices),
        "commercial_purposes": _choices_payload(CommercialPurpose.choices),
        "building_lines": _choices_payload(BuildingLine.choices),
        "builders": [{"slug": item.slug, "name": item.name} for item in builders],
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


def free_media_slots(listing: Listing, kind: str) -> int:
    """Сколько файлов этого типа ещё можно приложить.

    Во Flutter это `freePhotoSlots`: форма показывает «осталось N» и не даёт
    выбрать больше, но решение всё равно за сервером.
    """
    return max(media_limit(kind) - listing.media.filter(kind=kind).count(), 0)


def _limit_message(kind: str, free_slots: int) -> str:
    word = "фото" if kind == MediaKind.PHOTO else "видео"
    if free_slots <= 0:
        return f"Достигнут лимит {media_limit(kind)} {word}"
    return f"Можно добавить ещё {free_slots} {word}"


def upload_listing_media(
    listing: Listing,
    files: list[Any],
    kind: str,
    title: str = "",
    description: str = "",
) -> dict[str, Any]:
    """Принимает пачку файлов — пользователь выбирает их в галерее скопом.

    Логика повторяет `AppState._append` во Flutter: сколько влезает в лимит,
    столько и берём, остальное отклоняем и честно сообщаем об этом в ответе.
    """
    free_slots = free_media_slots(listing, kind)

    if free_slots == 0:
        raise ApiValidationError(
            _limit_message(kind, 0),
            {"free_slots": 0, "message": _limit_message(kind, 0)},
        )

    accepted: list[ListingMedia] = []
    rejected: list[dict[str, str]] = []
    reason = ""

    for index, upload in enumerate(files):
        if index >= free_slots:
            reason = _limit_message(kind, 0)
            rejected.append({"file_index": str(index), "reason": reason})
            continue

        try:
            accepted.append(_store_upload(listing, upload, kind, title, description))
        except DjangoValidationError as exc:
            message = "; ".join(exc.messages)
            reason = reason or message
            rejected.append({"file_index": str(index), "reason": message})

    if not accepted:
        raise ApiValidationError(
            reason or "Ни один файл не принят.",
            {
                "free_slots": free_media_slots(listing, kind),
                "message": reason or "Ни один файл не принят.",
                "rejected": rejected,
            },
        )

    logger.info(
        "Объявление %s: принято %s, отклонено %s файлов (%s)",
        listing.slug,
        len(accepted),
        len(rejected),
        kind,
    )
    return {
        "accepted": len(accepted),
        "rejected": len(rejected),
        "reason": reason,
        "free_slots": free_media_slots(listing, kind),
        "media": accepted,
        "rejected_details": rejected,
    }


def _store_upload(
    listing: Listing,
    upload: Any,
    kind: str,
    title: str = "",
    description: str = "",
) -> ListingMedia:
    """Проверяет один файл и кладёт его в хранилище со статусом `processing`.

    Проверка идёт по содержимому файла до записи в бакет: 200-мегабайтное
    видео на четыре минуты не должно попасть в хранилище даже на секунду.
    """
    from django.db import transaction

    from apps.catalog.media import (
        source_extension,
        temporary_bytes,
        validate_photo,
        validate_video,
    )
    from apps.catalog.tasks import process_media

    data = upload.read()
    upload.seek(0)

    extra: dict[str, Any] = {
        "size_bytes": len(data),
        "title": title,
        "description": description,
    }

    if kind == MediaKind.PHOTO:
        width, height = validate_photo(data)
        extra |= {"width": width, "height": height}
    else:
        # ffprobe работает с путём, поэтому валидируем по временной копии,
        # а не по файлу в хранилище — в бакет он ещё не попал.
        source = temporary_bytes(data, suffix=".mp4")
        try:
            probe = validate_video(data, str(source))
        finally:
            source.unlink(missing_ok=True)
        extra |= {key: value for key, value in probe.items() if value is not None}

    media = ListingMedia(
        listing=listing,
        kind=kind,
        status=MediaStatus.PROCESSING,
        order=_next_media_order(listing),
        is_cover=(kind == MediaKind.PHOTO and not listing.media.filter(is_cover=True).exists()),
        **extra,
    )
    # Имя файла с телефона отбрасывается: оно может содержать ПДн, а попадёт
    # в публичный URL. Ключ собирается из UUID объявления и записи.
    media.file.save(f"{media.uuid}_source.{source_extension(data, kind)}", upload, save=False)
    media.save()

    transaction.on_commit(lambda: process_media.delay(media.pk))
    return media


def _next_media_order(listing: Listing) -> int:
    """Следующий порядковый номер. Явная проверка на None — нулевой порядок ложен."""
    top_order = listing.media.aggregate(top=Max("order"))["top"]
    return 0 if top_order is None else top_order + 1


# Временное смещение при перестановке: снимает конфликт уникального
# ограничения (listing, order) между старыми и новыми номерами.
REORDER_OFFSET = 1000


def reorder_listing_media(listing: Listing, order: list[int]) -> list[ListingMedia]:
    """Переставляет файлы объявления в присланном порядке.

    Чужой id в списке — 400: клиент прислал порядок не от того объявления,
    и применять его частично нельзя.
    """
    from django.db import transaction

    media_by_id = {item.pk: item for item in listing.media.all()}

    unknown = [item_id for item_id in order if item_id not in media_by_id]
    if unknown:
        raise ApiValidationError(
            "В списке порядка есть файлы из другого объявления.",
            {"order": unknown},
        )

    if len(set(order)) != len(order):
        raise ApiValidationError("В списке порядка есть повторы.", {"order": order})

    if len(order) != len(media_by_id):
        raise ApiValidationError(
            "Список порядка должен содержать все файлы объявления.",
            {"expected": len(media_by_id), "received": len(order)},
        )

    items = [media_by_id[item_id] for item_id in order]

    with transaction.atomic():
        # Ограничение (listing, order) уникально и проверяется построчно,
        # поэтому перестановка идёт в два прохода: сначала номера уводятся
        # за пределы занятого диапазона, потом проставляются нужные.
        for position, item in enumerate(items):
            item.order = REORDER_OFFSET + position
        ListingMedia.objects.bulk_update(items, ["order"])

        for position, item in enumerate(items):
            item.order = position
        ListingMedia.objects.bulk_update(items, ["order"])

    return items


def set_media_cover(listing: Listing, media: ListingMedia) -> ListingMedia:
    """Делает файл обложкой. Обложка всегда ровно одна."""
    from django.db import transaction

    if media.kind != MediaKind.PHOTO:
        raise ApiValidationError("Обложкой может быть только фотография.")

    with transaction.atomic():
        listing.media.filter(is_cover=True).exclude(pk=media.pk).update(is_cover=False)
        if not media.is_cover:
            media.is_cover = True
            media.save(update_fields=["is_cover", "updated_at"])

    return media


def delete_listing_media(listing: Listing, media: ListingMedia) -> None:
    """Удаляет запись и файлы всех вариантов размеров.

    Удалили обложку — обложкой становится первая оставшаяся фотография:
    карточка без обложки в выдаче выглядит сломанной.
    """
    from django.db import transaction

    was_cover = media.is_cover

    with transaction.atomic():
        media.delete_files()
        media.delete()

        if was_cover:
            replacement = listing.media.filter(kind=MediaKind.PHOTO).order_by("order", "id").first()
            if replacement is not None:
                replacement.is_cover = True
                replacement.save(update_fields=["is_cover", "updated_at"])


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


def priority_annotation() -> Case:
    """1 для объявлений подписчиков с приоритетом в поиске, иначе 0.

    Один подзапрос EXISTS на весь список: проверять тариф каждого владельца
    по отдельности означало бы запрос на карточку.
    """
    subscription_model = apps.get_model("billing", "Subscription")
    now = timezone.now()

    priority = subscription_model.objects.filter(
        user_id=OuterRef("owner_id"),
        status="active",
        starts_at__lte=now,
        ends_at__gt=now,
        tariff__features__priority_in_search=True,
    )
    return Case(
        When(Exists(priority), then=Value(1)),
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
            priority_rank=priority_annotation(),
            photos_count=Count(
                "media",
                filter=Q(media__kind=MediaKind.PHOTO),
                distinct=True,
            ),
            is_favourite_flag=favourite_annotation(user),
        )
    )


def order_listings(queryset: QuerySet[Listing], ordering: str) -> QuerySet[Listing]:
    """Порядок ленты: продвинутые, затем подписчики с приоритетом, затем все.

    Купленное продвижение всегда выше тарифного приоритета: за него заплатили
    отдельно и за конкретное объявление.
    """
    return queryset.order_by("-promoted_rank", "-priority_rank", ordering, "-id")


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
        bump_stat(listing.pk, "views")

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


# -- черновик и жизненный цикл объявления ------------------------------------

# Те же значения, что в AppState Flutter: форма открывается уже заполненной.
DRAFT_DEFAULTS: dict[str, Any] = {
    "kind": PropertyKind.NEW_BUILDING,
    "rooms": 1,
    "floor": 1,
    "floors": 1,
    "currency": Currency.USD,
    "seller_kind": SellerKind.OWNER,
    "allow_media_download": True,
}

# Поля формы, которые клиент шлёт по мере заполнения.
EDITABLE_FIELDS = (
    "kind",
    "district",
    "city",
    "address",
    "rooms",
    "area",
    "land_area",
    "floor",
    "floors",
    "series",
    "builder",
    "price",
    "currency",
    "seller_kind",
    "is_secondary",
    "description",
    "allow_media_download",
    "contact_name",
    "contact_phone",
    "latitude",
    "longitude",
)

# Что обязательно для публикации.
# Поля, где 0 — это «не заполнено»: модель хранит их как PositiveSmallInteger
# с default=0, отличить «ноль» от «пусто» больше нечем.
ZERO_MEANS_EMPTY = frozenset({"rooms", "floor", "floors"})


def get_or_create_draft(user: Any) -> Listing:
    """Черновик пользователя — один на всех: форма не должна теряться.

    Черновик живёт на сервере, поэтому пользователь может закрыть приложение
    и вернуться к заполненной форме с другого устройства.
    """
    draft = (
        Listing.objects.filter(owner=user, status=ListingStatus.DRAFT)
        .order_by("-created_at")
        .first()
    )
    if draft is not None:
        return draft

    draft = Listing.objects.create(owner=user, contact_phone=user.phone, **DRAFT_DEFAULTS)
    logger.info("Пользователь %s начал черновик %s", user.pk, draft.slug)
    return draft


RELATION_FIELDS = frozenset({"district", "city", "series", "builder"})


def _is_blank(listing: Listing, name: str) -> bool:
    """Пустое ли поле формы. Для связей смотрим на *_id, чтобы не тянуть объект."""
    if name in RELATION_FIELDS:
        return getattr(listing, f"{name}_id", None) is None
    value = getattr(listing, name, None)
    if name in ZERO_MEANS_EMPTY:
        return not value
    return value in (None, "")


def missing_fields_for_publish(listing: Listing) -> list[str]:
    """Чего не хватает, чтобы объявление можно было опубликовать.

    Набор обязательных полей зависит от типа: у участка нет ни комнат, ни
    этажей, зато обязательна площадь участка (apps/catalog/field_rules.py).
    """
    required = REQUIRED_BY_KIND.get(listing.kind, ())
    missing = [name for name in required if _is_blank(listing, name)]

    if not listing.media.filter(kind=MediaKind.PHOTO).exists():
        missing.append("photos")

    return missing


def listing_completeness(listing: Listing) -> dict[str, Any]:
    """Готовность черновика к публикации — для прогресса в форме."""
    missing = missing_fields_for_publish(listing)
    return {"is_complete": not missing, "missing_fields": missing}


def active_listings_count(user: Any) -> int:
    return Listing.objects.filter(owner=user, status=ListingStatus.ACTIVE).count()


def listings_limit(user: Any) -> int:
    """Сколько активных объявлений разрешено пользователю. 0 — без ограничений.

    Считает биллинг: лимит зависит от тарифа. Импорт локальный — каталог не
    должен зависеть от биллинга на уровне модуля.
    """
    from apps.billing.subscriptions import get_listings_limit

    return get_listings_limit(user)


def ensure_free_slot(listing: Listing) -> None:
    """Проверяет лимит активных объявлений по тарифу пользователя."""
    limit = listings_limit(listing.owner)
    if limit == 0:
        return

    if active_listings_count(listing.owner) >= limit:
        raise ConflictError(
            f"Достигнут лимит активных объявлений: одновременно можно держать {limit}. "
            "Архивируйте одно из активных или перейдите на другой тариф."
        )


def update_listing(listing: Listing, data: dict[str, Any]) -> Listing:
    """Частичное обновление формы.

    У активного объявления снижение цены сохраняет прежнюю в old_price —
    из неё карточка рисует зачёркнутую цену «было 107 000$».
    """
    new_price = data.get("price")
    if (
        new_price is not None
        and listing.status == ListingStatus.ACTIVE
        and listing.price is not None
        and new_price < listing.price
    ):
        listing.old_price = listing.price

    previous_price = listing.price

    # Экспликация помещений — не поле модели, а связанный список; форма
    # присылает его целиком, поэтому прежний набор заменяется, а не
    # дополняется: удалённая владельцем комната иначе осталась бы навсегда.
    rooms = data.pop("rooms_breakdown", None)

    for field, value in data.items():
        setattr(listing, field, value)

    listing.save()

    if rooms is not None:
        listing.rooms_data.all().delete()
        ListingRoom.objects.bulk_create(
            [
                ListingRoom(
                    listing=listing,
                    name=room["name"],
                    area=room["area"],
                    order=room.get("order", index),
                )
                for index, room in enumerate(rooms)
            ]
        )

    if new_price is not None and previous_price != new_price:
        # Цена — то, ради чего объявление и открывают; её изменения должны
        # быть восстановимы по журналу, а не только по последнему значению.
        audit(
            actor=listing.owner,
            action=AuditLog.Action.LISTING_PRICE_CHANGED,
            target=listing,
            changes={"price": {"before": str(previous_price), "after": str(new_price)}},
            target_user=listing.owner,
            extra={"currency": listing.currency, "status": listing.status},
        )

    return listing


def publish_listing(listing: Listing) -> Listing:
    """Отправляет объявление на модерацию или сразу в публикацию.

    Доверенным пользователям модерация не нужна — объявление уходит в эфир
    немедленно.
    """
    from django.db import transaction

    from apps.catalog.tasks import update_listing_search_vector

    missing = missing_fields_for_publish(listing)
    if missing:
        raise ApiValidationError(
            "Заполните обязательные поля перед публикацией.",
            {"missing_fields": missing},
        )

    ensure_free_slot(listing)

    now = timezone.now()
    listing.rejection_reason = ""

    listing.status = ListingStatus.ACTIVE
    listing.published_at = now
    listing.expires_at = now + timedelta(days=settings.LISTING_ACTIVE_DAYS)

    listing.save(
        update_fields=["status", "published_at", "expires_at", "rejection_reason", "updated_at"]
    )

    transaction.on_commit(lambda: update_listing_search_vector.delay(listing.pk))
    safe(observe_listing_published, auto=True)
    logger.info("Объявление %s -> %s", listing.slug, listing.status)
    return listing


def approve_listing(listing: Listing) -> Listing:
    """Модерация одобрила: объявление уходит в эфир на LISTING_ACTIVE_DAYS."""
    from django.db import transaction

    from apps.catalog.tasks import update_listing_search_vector

    now = timezone.now()
    listing.status = ListingStatus.ACTIVE
    listing.published_at = now
    listing.expires_at = now + timedelta(days=settings.LISTING_ACTIVE_DAYS)
    listing.rejection_reason = ""
    listing.save(
        update_fields=["status", "published_at", "expires_at", "rejection_reason", "updated_at"]
    )

    transaction.on_commit(lambda: update_listing_search_vector.delay(listing.pk))
    return listing


def archive_listing(listing: Listing) -> Listing:
    listing.status = ListingStatus.ARCHIVED
    listing.save(update_fields=["status", "updated_at"])
    return listing


def restore_listing(listing: Listing) -> Listing:
    """Возвращает объявление из архива, продлевая срок публикации."""
    if listing.status != ListingStatus.ARCHIVED:
        raise ConflictError("Вернуть из архива можно только архивное объявление.")

    ensure_free_slot(listing)

    now = timezone.now()
    listing.status = ListingStatus.ACTIVE
    listing.published_at = listing.published_at or now
    listing.expires_at = now + timedelta(days=settings.LISTING_ACTIVE_DAYS)
    listing.save(update_fields=["status", "published_at", "expires_at", "updated_at"])
    return listing


def mark_listing_sold(listing: Listing) -> Listing:
    listing.status = ListingStatus.SOLD
    listing.save(update_fields=["status", "updated_at"])
    return listing


def soft_delete_listing(listing: Listing) -> Listing:
    """Мягкое удаление: объявление пропадает из выдачи, но остаётся в БД.

    На него ссылаются история просмотров, избранное и операции по кошельку —
    физическое удаление порвало бы эти связи.
    """
    listing.is_deleted = True
    listing.save(update_fields=["is_deleted", "updated_at"])
    logger.info("Объявление %s удалено владельцем", listing.slug)
    return listing


def bump_listing(listing: Listing) -> Listing:
    """Поднимает объявление в выдаче. Бесплатно — не чаще раза в сутки."""
    cooldown = timedelta(hours=settings.LISTING_BUMP_COOLDOWN_HOURS)
    now = timezone.now()

    if listing.bumped_at and now - listing.bumped_at < cooldown:
        wait = (listing.bumped_at + cooldown - now).total_seconds()
        raise Throttled(wait=int(wait))

    listing.published_at = now
    listing.bumped_at = now
    listing.save(update_fields=["published_at", "bumped_at", "updated_at"])
    return listing
