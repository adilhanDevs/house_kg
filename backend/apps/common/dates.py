"""Локальные даты и их подписи.

Пользователь живёт в Бишкеке: «сегодня» и границы суток считаются по местному
времени, независимо от таймзоны сервера.
"""

from datetime import date, datetime, time, timedelta
from typing import Any
from zoneinfo import ZoneInfo

from django.utils import timezone

LOCAL_TIMEZONE = ZoneInfo("Asia/Bishkek")

MONTHS_GENITIVE = {
    1: "января",
    2: "февраля",
    3: "марта",
    4: "апреля",
    5: "мая",
    6: "июня",
    7: "июля",
    8: "августа",
    9: "сентября",
    10: "октября",
    11: "ноября",
    12: "декабря",
}


def local_day(moment: Any) -> date:
    """Дата по бишкекскому времени."""
    return timezone.localtime(moment, LOCAL_TIMEZONE).date()


def today_local() -> date:
    """Сегодняшняя дата по бишкекскому времени."""
    return local_day(timezone.now())


def start_of_day(day: date) -> datetime:
    return datetime.combine(day, time.min, tzinfo=LOCAL_TIMEZONE)


def date_label(day: date, today: date | None = None) -> str:
    """«18 августа», с годом — если год не текущий."""
    reference = today or local_day(timezone.now())
    label = f"{day.day} {MONTHS_GENITIVE[day.month]}"
    return label if day.year == reference.year else f"{label} {day.year}"


def relative_day_keys(day: date, today: date) -> tuple[str, str]:
    """(машинный ключ, подпись): сегодня и вчера — словами, дальше — датой."""
    if day == today:
        return "today", "Сегодня"
    if day == today - timedelta(days=1):
        return "yesterday", "Вчера"
    return day.isoformat(), date_label(day, today)
