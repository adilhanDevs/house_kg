"""Счётчики показов и статистика объявления по дням.

Показ в выдаче — самое частое событие в системе: страница каталога из 20
карточек даёт 20 событий на один запрос. Писать их по одному UPDATE нельзя,
поэтому показы копятся в Redis и сбрасываются в БД пачкой раз в пять минут
(`catalog.flush_impressions`).

Ключ буфера — один хеш на сутки: HINCRBY атомарен, а HGETALL позволяет забрать
всё накопленное одним запросом, не перебирая ключи.
"""

import logging
from datetime import date, timedelta
from typing import Any

from django.core.cache import cache
from django.db.models import F, Sum
from django.utils import timezone

from apps.common.cache import safe_cache_call

logger = logging.getLogger(__name__)

IMPRESSIONS_KEY = "catalog:impressions:{day}"
# Буфер живёт дольше интервала сброса: если задача не отработала вовремя,
# накопленное не должно исчезнуть.
IMPRESSIONS_TTL = 6 * 60 * 60

# Поля ListingDailyStat, которые умеем инкрементировать.
COUNTERS = ("impressions", "views", "favourites", "phone_reveals")


def _today() -> date:
    """Сутки считаются по времени проекта (Asia/Bishkek), а не по UTC."""
    return timezone.localdate()


def _redis_client() -> Any:
    """Сырой клиент Redis, если бэкенд кэша — Redis. Иначе None."""
    backend = getattr(cache, "_cache", None)
    get_client = getattr(backend, "get_client", None)
    if get_client is None:
        return None
    try:
        return get_client(key=None, write=True)
    except Exception:  # pragma: no cover - недоступность Redis не должна ломать выдачу
        logger.warning("Redis для буфера показов недоступен", exc_info=True)
        return None


def buffer_impressions(listing_ids: list[int], day: date | None = None) -> None:
    """Копит показы в Redis. Никогда не роняет запрос каталога."""
    if not listing_ids:
        return

    key = IMPRESSIONS_KEY.format(day=day or _today())
    client = _redis_client()

    if client is not None:
        safe_cache_call(
            _incr_redis,
            client,
            key,
            listing_ids,
            warning="Не удалось записать показы в Redis",
        )
        return

    # Локальный кэш (тесты, dev без Redis): один словарь под тем же ключом.
    safe_cache_call(
        _incr_locmem,
        key,
        listing_ids,
        warning="Не удалось записать показы в кэш",
    )


def _incr_redis(client: Any, key: str, listing_ids: list[int]) -> None:
    pipeline = client.pipeline()
    for listing_id in listing_ids:
        pipeline.hincrby(key, str(listing_id), 1)
    pipeline.expire(key, IMPRESSIONS_TTL)
    pipeline.execute()


def _incr_locmem(key: str, listing_ids: list[int]) -> None:
    buffered: dict[str, int] = cache.get(key) or {}
    for listing_id in listing_ids:
        buffered[str(listing_id)] = buffered.get(str(listing_id), 0) + 1
    cache.set(key, buffered, IMPRESSIONS_TTL)


def drain_impressions(day: date | None = None) -> dict[int, int]:
    """Забирает накопленное и очищает буфер.

    Чтение и удаление идут одной транзакцией Redis: показы, пришедшие между
    ними, иначе потерялись бы.
    """
    key = IMPRESSIONS_KEY.format(day=day or _today())
    client = _redis_client()

    if client is not None:
        pipeline = client.pipeline()
        pipeline.hgetall(key)
        pipeline.delete(key)
        raw, _ = pipeline.execute()
        return {int(_decode(field)): int(value) for field, value in (raw or {}).items()}

    buffered = cache.get(key) or {}
    cache.delete(key)
    return {int(listing_id): int(count) for listing_id, count in buffered.items()}


def _decode(value: Any) -> str:
    return value.decode() if isinstance(value, bytes) else str(value)


def bump_stat(listing_id: int, field: str, amount: int = 1, day: date | None = None) -> None:
    """Инкрементирует показатель за сутки одним UPDATE.

    Строка создаётся при первом событии дня; дальше идёт только F-выражение —
    без чтения текущего значения и без гонки между параллельными запросами.
    """
    from apps.catalog.models import ListingDailyStat

    if field not in COUNTERS:
        raise ValueError(f"Неизвестный показатель: {field}")

    target_day = day or _today()
    updated = ListingDailyStat.objects.filter(listing_id=listing_id, date=target_day).update(
        **{field: F(field) + amount}
    )
    if updated:
        return

    ListingDailyStat.objects.get_or_create(
        listing_id=listing_id,
        date=target_day,
        defaults={field: amount},
    )


def daily_stats(listing: Any, days: int = 30) -> list[dict[str, Any]]:
    """Ряд по дням за последние `days` суток, включая дни без событий.

    Пропуски заполняются нулями: график с дырами читается как «данных нет»,
    хотя на деле показов в этот день просто не было.
    """
    from apps.catalog.models import ListingDailyStat

    last_day = _today()
    first_day = last_day - timedelta(days=days - 1)

    rows = {
        row.date: row
        for row in ListingDailyStat.objects.filter(
            listing=listing, date__gte=first_day, date__lte=last_day
        )
    }

    series = []
    for offset in range(days):
        current = first_day + timedelta(days=offset)
        row = rows.get(current)
        series.append(
            {
                "date": current,
                "impressions": row.impressions if row else 0,
                "views": row.views if row else 0,
                "favourites": row.favourites if row else 0,
                "phone_reveals": row.phone_reveals if row else 0,
            }
        )
    return series


def totals(series: list[dict[str, Any]]) -> dict[str, int]:
    return {field: sum(row[field] for row in series) for field in COUNTERS}


def promotion_effect(listing: Any, days: int = 30) -> dict[str, Any] | None:
    """Сравнение средних до продвижения и во время него.

    Без такого блока владелец не понимает, за что заплатил: абсолютные числа
    за месяц ничего не говорят, а разница средних — говорит.
    """
    from django.apps import apps as django_apps

    from apps.catalog.models import ListingDailyStat

    promotion_model = django_apps.get_model("billing", "Promotion")

    promotions = list(
        promotion_model.objects.filter(listing=listing)
        .order_by("starts_at")
        .values("starts_at", "ends_at")
    )
    if not promotions:
        return None

    # Дни, попавшие хотя бы в одно продвижение.
    promoted_days: set[date] = set()
    for promotion in promotions:
        start = timezone.localtime(promotion["starts_at"]).date()
        end = timezone.localtime(promotion["ends_at"]).date()
        current = start
        while current <= end:
            promoted_days.add(current)
            current += timedelta(days=1)

    last_day = _today()
    first_day = last_day - timedelta(days=days - 1)

    rows = ListingDailyStat.objects.filter(listing=listing, date__gte=first_day, date__lte=last_day)
    during = rows.filter(date__in=promoted_days)
    before = rows.exclude(date__in=promoted_days)

    return {
        "promoted_days": len(promoted_days & {first_day + timedelta(days=n) for n in range(days)}),
        "before": _averages(before),
        "during": _averages(during),
    }


def _averages(queryset: Any) -> dict[str, float]:
    """Среднее за сутки по каждому показателю."""
    aggregate = queryset.aggregate(**{field: Sum(field) for field in COUNTERS})
    count = queryset.count()

    if not count:
        return dict.fromkeys(COUNTERS, 0.0)

    return {field: round((aggregate[field] or 0) / count, 2) for field in COUNTERS}
