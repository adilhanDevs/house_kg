"""Фоновые задачи: уведомления по сохранённым фильтрам."""

import json
import logging
from bisect import bisect_right
from collections import defaultdict
from typing import Any

try:
    from itertools import batched
except ImportError:
    from itertools import islice

    def batched(iterable: Any, n: int) -> Any:
        if n < 1:
            raise ValueError("n must be at least one")
        it = iter(iterable)
        while batch := tuple(islice(it, n)):
            yield batch


from celery import shared_task
from django.utils import timezone

logger = logging.getLogger(__name__)

BATCH_SIZE = 200
NOTIFICATION_TITLE = "Новые объекты по фильтру"


def _group_key(params: dict[str, str]) -> str:
    return json.dumps(params or {}, sort_keys=True, ensure_ascii=False)


def _process_batch(saved_filters: tuple[Any, ...], now: Any) -> int:
    """Обрабатывает пачку фильтров, группируя одинаковые наборы параметров."""
    from apps.engagement.services import matching_listings
    from apps.notifications.models import Notification, NotificationType
    from apps.notifications.services import notify_many

    groups: dict[str, list[Any]] = defaultdict(list)
    for saved_filter in saved_filters:
        groups[_group_key(saved_filter.params)].append(saved_filter)

    notifications: list[Notification] = []
    to_update: list[Any] = []

    for raw_params, filters in groups.items():
        queryset = matching_listings(json.loads(raw_params))
        total = queryset.count()

        # Один запрос на группу: берём отметки публикации новее самой ранней
        # границы в группе, дальше считаем в памяти.
        earliest = min(item.notify_since for item in filters)
        published = sorted(
            queryset.filter(published_at__gt=earliest)
            .exclude(published_at__isnull=True)
            .values_list("published_at", flat=True)
        )

        for saved_filter in filters:
            fresh = len(published) - bisect_right(published, saved_filter.notify_since)

            saved_filter.matches_count = total
            saved_filter.last_notified_at = now
            to_update.append(saved_filter)

            if fresh <= 0:
                continue

            notifications.append(
                Notification(
                    user_id=saved_filter.user_id,
                    type=NotificationType.SAVED_FILTER_MATCH,
                    title=NOTIFICATION_TITLE,
                    body=f"По фильтру «{saved_filter.name}» — {fresh} новых объектов",
                    payload={"saved_filter_id": saved_filter.pk, "count": fresh},
                )
            )

    # Уведомления создаются только через сервис: он же ставит задачи на push.
    notify_many(notifications)
    if to_update:
        type(to_update[0]).objects.bulk_update(
            to_update, ["matches_count", "last_notified_at", "updated_at"]
        )

    return len(notifications)


@shared_task(name="engagement.notify_saved_filters", ignore_result=True)
def notify_saved_filters(batch_size: int = BATCH_SIZE) -> int:
    """Раз в час уведомляет о новых объектах по сохранённым фильтрам.

    Идемпотентна: после прогона `last_notified_at` сдвигается на «сейчас»,
    поэтому повторный запуск ничего не создаёт.
    """
    from apps.engagement.models import SavedFilter

    now = timezone.now()
    created = 0

    queryset = SavedFilter.objects.filter(notify_on_new=True).order_by("pk")
    for batch in batched(queryset.iterator(chunk_size=batch_size), batch_size):
        created += _process_batch(batch, now)

    logger.info("Уведомлений по сохранённым фильтрам создано: %s", created)
    return created


@shared_task(name="engagement.purge_view_history", ignore_result=True)
def purge_view_history() -> int:
    """Раз в сутки чистит историю просмотров старше VIEW_HISTORY_RETENTION_DAYS."""
    from datetime import timedelta

    from django.conf import settings

    from apps.engagement.models import ViewHistory

    threshold = timezone.now() - timedelta(days=settings.VIEW_HISTORY_RETENTION_DAYS)
    deleted, _ = ViewHistory.objects.filter(viewed_at__lt=threshold).delete()

    logger.info("Удалено записей истории просмотров: %s", deleted)
    return deleted
