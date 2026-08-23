"""Автопроверки объявления перед публикацией.

Каждая проверка — чистая функция `(listing) -> CheckResult`; ничего не пишет
в БД и не принимает решений. Решение всегда за модератором: проверки только
поднимают объявление в очереди.

Формат результата единый: {"triggered": bool, "details": {...}} — он уходит
в `ModerationTask.checks` и показывается модератору как есть.
"""

import logging
import re
import statistics
from dataclasses import dataclass, field
from datetime import timedelta
from typing import Any

from django.conf import settings
from django.utils import timezone

logger = logging.getLogger(__name__)


@dataclass
class CheckResult:
    triggered: bool = False
    details: dict[str, Any] = field(default_factory=dict)

    def as_dict(self) -> dict[str, Any]:
        return {"triggered": self.triggered, "details": self.details}


# -- 1. Контакты в тексте ----------------------------------------------------
#
# Телефон в описании — способ увести сделку мимо площадки, поэтому проверка
# обязательна и намеренно параноидальная: ловятся и цифры с любыми
# разделителями, и числа, записанные словами, и ссылки на мессенджеры.

# Цифры телефона с разделителями: «0 555 12 34 56», «+996-555-123456»,
# «0(555)123456». Требуется не меньше девяти цифр подряд с учётом разделителей.
PHONE_DIGITS_RE = re.compile(r"(?:\+?\d[\s\-().]{0,3}){8,}\d")

# Числительные, которыми диктуют номер: «ноль пятьсот пятьдесят пять».
NUMBER_WORDS = (
    r"нол[ья]|ноль|зеро|один|одна|два|две|три|четыре|пять|шесть|семь|восемь|девять|"
    r"десять|одиннадцать|двенадцать|тринадцать|четырнадцать|пятнадцать|шестнадцать|"
    r"семнадцать|восемнадцать|девятнадцать|двадцать|тридцать|сорок|пятьдесят|"
    r"шестьдесят|семьдесят|восемьдесят|девяносто|сто|двести|триста|четыреста|"
    r"пятьсот|шестьсот|семьсот|восемьсот|девятьсот"
)
# Четыре числительных подряд — уже не «две комнаты», а продиктованный номер.
SPELLED_PHONE_RE = re.compile(
    rf"\b(?:{NUMBER_WORDS})\b(?:[\s,\-]+\b(?:{NUMBER_WORDS})\b){{3,}}",
    re.I,
)

LINK_RE = re.compile(
    r"(?:https?://|www\.)\S+|\b[\w-]+\.(?:ru|com|kg|net|org|io|me|su)\b",
    re.I,
)

MESSENGER_RE = re.compile(
    r"\b(?:whats\s?app|whatsapp|ватсап|вацап|ватцап|"
    r"telegram|телеграм|телега|"
    r"instagram|инстаграм|инста|"
    r"viber|вайбер|imo|"
    r"@[a-z0-9_]{4,})\b",
    re.I,
)

# Минимальная и максимальная длина номера в Кыргызстане (без и с кодом страны).
PHONE_MIN_DIGITS = 9
PHONE_MAX_DIGITS = 13


def _digit_matches(text: str) -> list[str]:
    """Куски текста, которые после чистки выглядят как телефон."""
    found = []
    for match in PHONE_DIGITS_RE.finditer(text):
        digits = re.sub(r"\D", "", match.group())
        if PHONE_MIN_DIGITS <= len(digits) <= PHONE_MAX_DIGITS:
            found.append(match.group().strip())
    return found


def contacts_in_text(listing: Any) -> CheckResult:
    """Ищет телефоны, ссылки и мессенджеры в описании и адресе."""
    text = " ".join(filter(None, [listing.description or "", listing.address or ""]))
    if not text.strip():
        return CheckResult()

    hits: dict[str, list[str]] = {}

    phones = _digit_matches(text)
    if phones:
        hits["phones"] = phones[:5]

    spelled = [match.group().strip() for match in SPELLED_PHONE_RE.finditer(text)]
    if spelled:
        hits["spelled_phones"] = spelled[:5]

    links = [match.group() for match in LINK_RE.finditer(text)]
    if links:
        hits["links"] = links[:5]

    messengers = sorted({match.group().lower() for match in MESSENGER_RE.finditer(text)})
    if messengers:
        hits["messengers"] = messengers[:5]

    return CheckResult(triggered=bool(hits), details=hits)


# -- 2. Выброс по цене -------------------------------------------------------


def price_outlier(listing: Any) -> CheckResult:
    """Сравнивает цену за м² с районом: отклонение больше трёх сигм — метка.

    Мало данных — проверка пропускается: на пяти объектах «медиана района»
    ничего не значит, а ложная метка стоит модератору времени.
    """
    from apps.catalog.enums import ListingStatus
    from apps.catalog.models import Listing

    if not (listing.price_usd and listing.area and listing.district_id):
        return CheckResult(details={"skipped": "нет цены, площади или района"})

    since = timezone.now() - timedelta(days=settings.MODERATION_PRICE_WINDOW_DAYS)
    peers = (
        Listing.objects.filter(
            district_id=listing.district_id,
            kind=listing.kind,
            status=ListingStatus.ACTIVE,
            published_at__gte=since,
            price_usd__gt=0,
            area__gt=0,
        )
        .exclude(pk=listing.pk)
        .values_list("price_usd", "area")
    )

    per_meter = [float(price) / float(area) for price, area in peers]
    minimum = settings.MODERATION_PRICE_MIN_PEERS

    if len(per_meter) < minimum:
        return CheckResult(
            details={
                "skipped": "мало объектов в районе",
                "peers": len(per_meter),
                "required": minimum,
            }
        )

    value = float(listing.price_usd) / float(listing.area)
    median = statistics.median(per_meter)
    sigma = statistics.pstdev(per_meter)

    if sigma > 0:
        deviation = abs(value - median) / sigma
        triggered = deviation > settings.MODERATION_PRICE_SIGMAS
    else:
        # Все соседи стоят одинаково: сигма нулевая, делить не на что —
        # смотрим на относительное отклонение от медианы.
        deviation = abs(value - median) / median if median else 0.0
        triggered = deviation > settings.MODERATION_PRICE_FALLBACK_RATIO

    return CheckResult(
        triggered=triggered,
        details={
            "price_per_sqm": round(value, 2),
            "median_per_sqm": round(median, 2),
            "sigma": round(sigma, 2),
            "deviation": round(deviation, 2),
            "peers": len(per_meter),
        },
    )


# -- 3. Дубликат объявления --------------------------------------------------


def duplicate_listing(listing: Any) -> CheckResult:
    """Тот же объект, выставленный другим пользователем.

    Совпадение у одного владельца — не дубликат, а правка; ищем только чужие.
    """
    from decimal import Decimal

    from apps.catalog.enums import ListingStatus
    from apps.catalog.models import Listing

    if not (listing.district_id and listing.area and listing.price):
        return CheckResult(details={"skipped": "нет района, площади или цены"})

    area_spread = Decimal(str(settings.MODERATION_DUPLICATE_AREA_SPREAD))
    price_ratio = Decimal(str(settings.MODERATION_DUPLICATE_PRICE_RATIO))

    candidates = (
        Listing.objects.filter(
            district_id=listing.district_id,
            status=ListingStatus.ACTIVE,
            rooms=listing.rooms,
            floor=listing.floor,
            area__gte=listing.area - area_spread,
            area__lte=listing.area + area_spread,
            currency=listing.currency,
            price__gte=listing.price * (1 - price_ratio),
            price__lte=listing.price * (1 + price_ratio),
        )
        .exclude(pk=listing.pk)
        .exclude(owner_id=listing.owner_id)
        .values_list("slug", flat=True)[:5]
    )

    matches = list(candidates)
    return CheckResult(triggered=bool(matches), details={"listings": matches})


# -- 4. Дубликат фотографий --------------------------------------------------


def hamming_distance(left: str, right: str) -> int:
    """Расстояние Хэмминга между двумя phash в шестнадцатеричной записи."""
    if not left or not right or len(left) != len(right):
        return 64

    try:
        return bin(int(left, 16) ^ int(right, 16)).count("1")
    except ValueError:
        return 64


def duplicate_photos(listing: Any) -> CheckResult:
    """Ищет те же фотографии в объявлениях других пользователей.

    Перцептивный хеш переживает пережатие и изменение размера, поэтому
    переклеенный чужой снимок находится, даже если его пересохранили.
    """
    from apps.catalog.enums import ListingStatus
    from apps.catalog.models import ListingMedia

    own = list(
        ListingMedia.objects.filter(listing_id=listing.pk)
        .exclude(phash="")
        .values_list("id", "phash")
    )
    if not own:
        return CheckResult(details={"skipped": "нет фотографий с хешем"})

    # Сравнение идёт в Python: побитовое расстояние в SQL не выразить.
    # Кандидатов ограничиваем свежими объявлениями в работе, иначе на большой
    # базе проверка вычитает всю таблицу медиа.
    others = (
        ListingMedia.objects.filter(
            listing__status__in=[ListingStatus.ACTIVE, ListingStatus.PENDING],
        )
        .exclude(phash="")
        .exclude(listing__owner_id=listing.owner_id)
        .order_by("-id")
        .values_list("id", "phash", "listing__slug")[: settings.MODERATION_PHASH_SCAN_LIMIT]
    )

    limit = settings.MODERATION_PHASH_MAX_DISTANCE
    matches = []

    for own_id, own_hash in own:
        for other_id, other_hash, other_slug in others:
            distance = hamming_distance(own_hash, other_hash)
            if distance <= limit:
                matches.append(
                    {
                        "media_id": own_id,
                        "match_media_id": other_id,
                        "listing": other_slug,
                        "distance": distance,
                    }
                )
                break

    return CheckResult(triggered=bool(matches), details={"matches": matches[:5]})


# Порядок в очереди не зависит от порядка здесь, но ответ API читается
# стабильнее, когда проверки всегда идут одинаково.
CHECKS = {
    "contacts_in_text": contacts_in_text,
    "price_outlier": price_outlier,
    "duplicate_listing": duplicate_listing,
    "duplicate_photos": duplicate_photos,
}


def run_all(listing: Any) -> dict[str, dict[str, Any]]:
    """Прогоняет все проверки. Упавшая проверка не роняет остальные."""
    results: dict[str, dict[str, Any]] = {}

    for name, check in CHECKS.items():
        try:
            results[name] = check(listing).as_dict()
        except Exception as exc:  # noqa: BLE001 - одна проверка не должна ронять модерацию
            logger.exception("Автопроверка %s упала на объявлении %s", name, listing.pk)
            results[name] = {
                "triggered": False,
                "details": {"error": exc.__class__.__name__},
            }

    return results


def count_triggered(checks: dict[str, Any]) -> int:
    return sum(1 for result in checks.values() if result.get("triggered"))
