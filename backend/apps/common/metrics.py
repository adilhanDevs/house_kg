"""Прикладные метрики Prometheus.

django-prometheus снимает технические показатели (латентность, коды ответов,
запросы к БД). Здесь — бизнес-метрики: по ним видно, что система работает
неправильно, даже когда все ответы 200.

Метрики объявляются один раз на процесс; счётчики не сбрасываются, поэтому
в дашбордах используются приращения (`rate`, `increase`).
"""

from typing import Any

from prometheus_client import Counter, Gauge, Histogram

# -- каталог -----------------------------------------------------------------

listings_published = Counter(
    "house_listings_published_total",
    "Опубликованные объявления",
    ["moderated"],  # "auto" — доверенный автор, "manual" — через модерацию
)

media_processing_seconds = Histogram(
    "house_media_processing_seconds",
    "Время обработки медиафайла",
    ["kind"],
    # Фото укладывается в секунды, видео — в десятки; крайние корзины
    # показывают, когда обработка начала деградировать.
    buckets=(0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30, 60, 120),
)

moderation_queue_size = Gauge(
    "house_moderation_queue_size",
    "Задач в очереди модерации",
    ["target"],
)

# -- деньги ------------------------------------------------------------------

topup_amount = Counter(
    "house_topup_bricks_total",
    "Сумма пополнений в кирпичах",
)

payments_failed = Counter(
    "house_payments_failed_total",
    "Неуспешные платежи",
    ["provider", "reason"],
)

wallet_spend = Counter(
    "house_wallet_spend_bricks_total",
    "Списания с кошелька в кирпичах",
    ["purpose"],
)


def observe_listing_published(auto: bool) -> None:
    listings_published.labels(moderated="auto" if auto else "manual").inc()


def observe_media_processed(kind: str, seconds: float) -> None:
    media_processing_seconds.labels(kind=kind).observe(seconds)


def observe_topup(bricks: int) -> None:
    topup_amount.inc(max(bricks, 0))


def observe_payment_failed(provider: str, reason: str = "unknown") -> None:
    payments_failed.labels(provider=provider or "unknown", reason=reason).inc()


def observe_spend(amount: int, purpose: str = "other") -> None:
    wallet_spend.labels(purpose=purpose).inc(abs(amount))


def refresh_moderation_queue_size() -> dict[str, int]:
    """Обновляет gauge длины очереди. Вызывается периодической задачей.

    Gauge, а не счётчик: длина очереди — это состояние, и растущая очередь
    означает, что модераторы не справляются, ещё до всяких жалоб.
    """
    from apps.catalog.enums import ModerationStatus
    from apps.catalog.models import ModerationTask

    open_tasks = ModerationTask.objects.filter(status=ModerationStatus.OPEN)
    listings = open_tasks.filter(listing__isnull=False).count()
    reviews = open_tasks.filter(review__isnull=False).count()

    moderation_queue_size.labels(target="listing").set(listings)
    moderation_queue_size.labels(target="review").set(reviews)
    return {"listing": listings, "review": reviews}


def safe(action: Any, *args: Any, **kwargs: Any) -> None:
    """Метрика никогда не должна ронять бизнес-операцию."""
    import logging

    try:
        action(*args, **kwargs)
    except Exception:  # noqa: BLE001 - сбой метрики не повод отменять платёж
        logging.getLogger(__name__).warning("Не удалось записать метрику", exc_info=True)
