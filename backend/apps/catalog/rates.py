"""Курсы валют и приведение цены к долларам.

Все фильтры и сортировки каталога работают по `price_usd`: объявления
выставляются и в долларах, и в сомах, а ползунок цены на экране фильтра один.
"""

import logging
from decimal import ROUND_HALF_UP, Decimal

from django.apps import apps
from django.conf import settings
from django.core.cache import cache

from apps.catalog.enums import Currency
from apps.common.cache import safe_cache_call

logger = logging.getLogger(__name__)

RATE_CACHE_KEY = "catalog:rate:{currency_from}:{currency_to}"
RATE_CACHE_TTL = 60 * 60
CENTS = Decimal("0.01")


def get_rate(currency_from: str = Currency.USD, currency_to: str = Currency.KGS) -> Decimal:
    """Свежий курс из БД. Если курсов ещё нет — резервное значение из настроек."""
    key = RATE_CACHE_KEY.format(currency_from=currency_from, currency_to=currency_to)

    cached = safe_cache_call(cache.get, key, warning="Кэш курсов недоступен")
    if cached is not None:
        return Decimal(cached)

    rate_model = apps.get_model("catalog", "ExchangeRate")
    latest = (
        rate_model.objects.filter(currency_from=currency_from, currency_to=currency_to)
        .order_by("-fetched_at")
        .values_list("rate", flat=True)
        .first()
    )

    rate = Decimal(latest) if latest is not None else Decimal(str(settings.FALLBACK_USD_KGS_RATE))
    safe_cache_call(cache.set, key, str(rate), RATE_CACHE_TTL, warning="Кэш курсов недоступен")
    return rate


def invalidate_rate_cache() -> None:
    keys = [
        RATE_CACHE_KEY.format(currency_from=Currency.USD, currency_to=Currency.KGS),
        RATE_CACHE_KEY.format(currency_from=Currency.KGS, currency_to=Currency.USD),
    ]
    safe_cache_call(cache.delete_many, keys, warning="Не удалось сбросить кэш курсов")


def to_usd(amount: Decimal | None, currency: str) -> Decimal | None:
    """Приводит сумму к долларам по текущему курсу."""
    if amount is None:
        return None
    if currency == Currency.USD:
        return Decimal(amount).quantize(CENTS, rounding=ROUND_HALF_UP)

    rate = get_rate(Currency.USD, Currency.KGS)
    if not rate:
        logger.warning("Курс USD/KGS нулевой — цена не пересчитана")
        return Decimal(amount).quantize(CENTS, rounding=ROUND_HALF_UP)

    return (Decimal(amount) / rate).quantize(CENTS, rounding=ROUND_HALF_UP)
