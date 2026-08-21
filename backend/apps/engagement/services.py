"""Сохранённые фильтры и подборки: валидация параметров и выборки."""

import logging
from datetime import date, datetime
from typing import Any

from django.db import transaction
from django.db.models import F, QuerySet
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.catalog.enums import ListingStatus
from apps.catalog.filters import ListingFilterSet
from apps.catalog.models import Listing
from apps.catalog.services import decrement_favourites, increment_favourites, listing_queryset
from apps.common.dates import local_day, relative_day_keys, start_of_day
from apps.common.exceptions import ApiValidationError, ConflictError
from apps.engagement.models import Favourite, SavedFilter, ViewHistory

logger = logging.getLogger(__name__)

MAX_SAVED_FILTERS_PER_USER = 20

# Параметры, которые к отбору не относятся: сортировка и пагинация.
IGNORED_PARAMS = frozenset({"ordering", "page_size", "cursor", "format"})


def _stringify(value: Any) -> str:
    """Значение в том виде, в каком оно пришло бы из query string."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, list | tuple | set):
        return ",".join(str(item).strip() for item in value if str(item).strip())
    return str(value).strip()


def normalize_filter_params(params: Any, request: Any = None) -> dict[str, str]:
    """Проверяет параметры через ListingFilterSet и приводит к каноническому виду.

    В базу должен попадать только тот набор, который каталог действительно
    умеет применять: иначе сохранённый фильтр однажды молча перестанет работать.
    """
    if not isinstance(params, dict):
        raise ValidationError({"params": "Ожидается объект с параметрами фильтра."})

    known = set(ListingFilterSet.base_filters)
    cleaned: dict[str, str] = {}

    for key, raw in params.items():
        if key in IGNORED_PARAMS:
            continue
        if key not in known:
            raise ValidationError(
                {"params": f"Неизвестный параметр фильтра: «{key}». Доступны: {sorted(known)}."}
            )
        value = _stringify(raw)
        if value:
            cleaned[key] = value

    filterset = ListingFilterSet(data=cleaned, queryset=Listing.objects.none())
    if not filterset.is_valid():
        raise ValidationError({"params": filterset.errors})

    return dict(sorted(cleaned.items()))


def filtered_listings(params: dict[str, str], user: Any = None) -> QuerySet[Listing]:
    """Выдача каталога по сохранённым параметрам."""
    filterset = ListingFilterSet(data=params, queryset=listing_queryset(user))
    return filterset.qs


def matching_listings(params: dict[str, str]) -> QuerySet[Listing]:
    """Лёгкий queryset для подсчётов: без аннотаций карточки."""
    base = Listing.objects.filter(status=ListingStatus.ACTIVE)
    return ListingFilterSet(data=params, queryset=base).qs


def create_saved_filter(
    user: Any,
    name: str,
    params: dict[str, str],
    notify_on_new: bool = True,
) -> SavedFilter:
    """Создаёт сохранённый фильтр с проверкой лимита и уникальности названия."""
    if SavedFilter.objects.filter(user=user).count() >= MAX_SAVED_FILTERS_PER_USER:
        raise ConflictError(
            f"Можно сохранить не больше {MAX_SAVED_FILTERS_PER_USER} фильтров. "
            "Удалите ненужный и повторите."
        )

    if SavedFilter.objects.filter(user=user, name=name).exists():
        raise ConflictError("Фильтр с таким названием уже сохранён.")

    saved_filter = SavedFilter.objects.create(
        user=user,
        name=name,
        params=params,
        notify_on_new=notify_on_new,
        matches_count=matching_listings(params).count(),
    )
    logger.info("Пользователь %s сохранил фильтр %s", user.pk, saved_filter.pk)
    return saved_filter


def collection_listings(collection: Any, user: Any = None) -> QuerySet[Listing]:
    """Объекты подборки: по фильтру или из ручного списка, в заданном порядке."""
    if collection.is_manual:
        return (
            listing_queryset(user)
            .filter(collection_items__collection=collection)
            .annotate(item_order=F("collection_items__order"))
            .order_by("item_order", "id")
        )
    return filtered_listings(collection.params or {}, user)


# -- избранное ---------------------------------------------------------------


@transaction.atomic
def add_favourite(user: Any, listing: Listing) -> tuple[bool, int]:
    """Добавляет объявление в избранное. Повторный вызов ничего не меняет.

    Возвращает (в избранном ли, актуальный счётчик).
    """
    _, created = Favourite.objects.get_or_create(
        user=user,
        listing=listing,
        defaults={"price_at_add": listing.price_usd},
    )
    if created:
        increment_favourites(listing.pk)

    return True, current_favourites_count(listing)


@transaction.atomic
def remove_favourite(user: Any, listing: Listing) -> tuple[bool, int]:
    """Убирает из избранного. Если записи не было — просто сообщаем счётчик."""
    deleted, _ = Favourite.objects.filter(user=user, listing=listing).delete()
    if deleted:
        decrement_favourites(listing.pk)

    return False, current_favourites_count(listing)


def current_favourites_count(listing: Listing) -> int:
    """Свежее значение счётчика: после F-выражения объект в памяти устарел."""
    return Listing.objects.values_list("favourites_count", flat=True).get(pk=listing.pk)


def favourite_listings(user: Any) -> QuerySet[Listing]:
    """Избранное пользователя в порядке добавления, объявления в любом статусе."""
    return (
        listing_queryset(user, only_active=False)
        .filter(favourited_by__user=user)
        .annotate(favourited_at=F("favourited_by__created_at"))
        .order_by("-favourited_at", "-id")
    )


# -- история просмотров ------------------------------------------------------


def note_view(user: Any, listing: Listing) -> ViewHistory | None:
    """Отмечает просмотр в истории. Для анонима история не ведётся."""
    if not (user and user.is_authenticated):
        return None

    history, _ = ViewHistory.objects.update_or_create(
        user=user,
        listing=listing,
        defaults={"viewed_at": timezone.now()},
    )
    return history


def viewed_listings(user: Any) -> QuerySet[Listing]:
    """История просмотров: свежие сверху, объявления в любом статусе."""
    return (
        listing_queryset(user, only_active=False)
        .filter(view_history__user=user)
        .annotate(viewed_at=F("view_history__viewed_at"))
        .order_by("-viewed_at", "-id")
    )


def clear_view_history(user: Any, listing_slugs: list[str] | None = None) -> int:
    """Удаляет историю целиком или только по перечисленным объявлениям."""
    queryset = ViewHistory.objects.filter(user=user)
    if listing_slugs:
        queryset = queryset.filter(listing__slug__in=listing_slugs)

    deleted, _ = queryset.delete()
    return deleted


# -- группировка истории по дням ---------------------------------------------

DAYS_PER_PAGE = 3


def parse_history_cursor(raw: str | None) -> datetime | None:
    """Курсор — дата: страница отдаёт дни строго раньше неё."""
    if not raw:
        return None
    try:
        boundary = date.fromisoformat(raw)
    except ValueError as exc:
        raise ApiValidationError("Некорректный курсор истории просмотров.") from exc

    return start_of_day(boundary)


def group_view_history(
    user: Any,
    cursor: str | None = None,
    days: int = DAYS_PER_PAGE,
) -> tuple[list[dict[str, Any]], str | None]:
    """Отдаёт целые дни истории и курсор на следующую страницу.

    Группировка идёт по уже отсортированной выборке в один проход — отдельного
    запроса на каждый день нет.
    """
    queryset = viewed_listings(user)

    boundary = parse_history_cursor(cursor)
    if boundary is not None:
        queryset = queryset.filter(viewed_at__lt=boundary)

    today = local_day(timezone.now())
    groups: list[dict[str, Any]] = []
    bucket_day: date | None = None
    bucket: list[Any] = []
    has_more = False

    for listing in queryset.iterator(chunk_size=100):
        day = local_day(listing.viewed_at)

        if bucket_day is None:
            bucket_day, bucket = day, [listing]
            continue

        if day == bucket_day:
            bucket.append(listing)
            continue

        groups.append(_build_group(bucket_day, bucket, today))
        if len(groups) >= days:
            # Начался день, который уже не помещается на эту страницу.
            has_more = True
            bucket_day, bucket = None, []
            break

        bucket_day, bucket = day, [listing]

    if bucket_day is not None and len(groups) < days:
        groups.append(_build_group(bucket_day, bucket, today))

    next_cursor = groups[-1]["date"].isoformat() if (has_more and groups) else None
    return groups, next_cursor


def _build_group(day: date, listings: list[Any], today: date) -> dict[str, Any]:
    key, label = relative_day_keys(day, today)
    return {"date": day, "day": key, "day_label": label, "items": listings}
