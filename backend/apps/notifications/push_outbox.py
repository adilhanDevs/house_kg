"""Обработка очереди push из PostgreSQL.

Транспорт доставки на проде — таблица, а не брокер: на сервере 458 МБ
памяти, и Redis с воркером Celery вдвоём не помещаются в остаток до порога
безопасности. Здесь только логика разбора очереди; сама отправка живёт в
`deliver_notification_push`, общем для всех транспортов.
"""

import logging
from datetime import timedelta
from typing import Any

from django.conf import settings
from django.db import transaction
from django.utils import timezone

logger = logging.getLogger(__name__)

#: Сколько строк берём за один проход. Маленькая пачка намеренно: памяти
#: мало, а торопиться некуда — уведомление не теряется, просто ждёт.
BATCH_SIZE = 10

#: Пауза, когда очередь пуста.
IDLE_SLEEP_SECONDS = 3.0

#: Через сколько строка, зависшая в processing, снова считается свободной.
#: Если процесс умер посреди отправки, без этого она осталась бы навсегда.
STUCK_AFTER = timedelta(minutes=10)

#: Отсрочки повторов. Длина списка задаёт и предел попыток: после последней
#: строка уходит в failed, а не крутится вечно.
RETRY_BACKOFF = [
    timedelta(minutes=1),
    timedelta(minutes=5),
    timedelta(minutes=15),
    timedelta(hours=1),
]
MAX_ATTEMPTS = len(RETRY_BACKOFF) + 1


def _claimable(statuses: Any, stuck_before: Any) -> Any:
    """Условие «строку можно брать»: свободна или зависла в обработке.

    Зависшие подбираются наравне со свежими: если процесс умер посреди
    отправки, строка так и осталась бы в processing навсегда.
    """
    from django.db.models import Q

    return Q(status__in=[statuses.PENDING, statuses.RETRY]) | Q(
        status=statuses.PROCESSING, locked_at__lt=stuck_before
    )


def _claim_batch(limit: int = BATCH_SIZE) -> list[Any]:
    """Забирает пачку строк себе. Короткая транзакция, без сети внутри.

    `skip_locked` нужен даже при одном воркере: он делает безопасным запуск
    второго процесса, случайный или намеренный, — строки не задвоятся.
    """
    from apps.notifications.models import PushOutbox, PushOutboxStatus

    now = timezone.now()
    stuck_before = now - STUCK_AFTER

    with transaction.atomic():
        rows = list(
            PushOutbox.objects.select_for_update(skip_locked=True)
            .filter(next_attempt_at__lte=now)
            .filter(_claimable(PushOutboxStatus, stuck_before))
            .order_by("next_attempt_at", "id")[:limit]
        )
        if not rows:
            return []

        PushOutbox.objects.filter(pk__in=[row.pk for row in rows]).update(
            status=PushOutboxStatus.PROCESSING,
            locked_at=now,
        )
    return rows


def process_row(row: Any) -> str:
    """Обрабатывает одну строку очереди. Возвращает итоговое состояние.

    Сеть вызывается вне транзакции: держать её открытой на время запроса к
    Firebase значило бы занимать соединение к базе на секунды.
    """
    from apps.notifications.models import PushOutbox, PushOutboxStatus
    from apps.notifications.tasks import deliver_notification_push

    now = timezone.now()

    if not settings.PUSH_ENABLED:
        # Не возвращаем в pending: иначе к моменту включения Firebase
        # накопился бы месяц старых уведомлений и разом улетел людям.
        PushOutbox.objects.filter(pk=row.pk).update(
            status=PushOutboxStatus.SKIPPED_DISABLED,
            locked_at=None,
            updated_at=now,
        )
        return PushOutboxStatus.SKIPPED_DISABLED

    try:
        deliver_notification_push(row.notification_id)
    except Exception as exc:  # noqa: BLE001 - решение о повторе принимаем ниже
        attempts = row.attempts + 1
        if attempts >= MAX_ATTEMPTS:
            PushOutbox.objects.filter(pk=row.pk).update(
                status=PushOutboxStatus.FAILED,
                attempts=attempts,
                locked_at=None,
                last_error=f"{type(exc).__name__}: {exc}"[:255],
            )
            logger.error(
                "Push %s не доставлен после %s попыток: %s",
                row.notification_id,
                attempts,
                type(exc).__name__,
            )
            return PushOutboxStatus.FAILED

        delay = RETRY_BACKOFF[min(attempts - 1, len(RETRY_BACKOFF) - 1)]
        PushOutbox.objects.filter(pk=row.pk).update(
            status=PushOutboxStatus.RETRY,
            attempts=attempts,
            next_attempt_at=timezone.now() + delay,
            locked_at=None,
            last_error=f"{type(exc).__name__}: {exc}"[:255],
        )
        logger.warning(
            "Push %s отложен на %s (попытка %s): %s",
            row.notification_id,
            delay,
            attempts,
            type(exc).__name__,
        )
        return PushOutboxStatus.RETRY

    PushOutbox.objects.filter(pk=row.pk).update(
        status=PushOutboxStatus.SENT,
        attempts=row.attempts + 1,
        locked_at=None,
        sent_at=timezone.now(),
        last_error="",
    )
    return PushOutboxStatus.SENT


def process_once(limit: int = BATCH_SIZE) -> int:
    """Один проход по очереди. Возвращает число обработанных строк."""
    rows = _claim_batch(limit)
    for row in rows:
        process_row(row)
    return len(rows)
