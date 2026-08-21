"""Фоновые задачи каталога: курсы валют и поисковый индекс."""

import logging
from decimal import Decimal, InvalidOperation
from xml.etree import ElementTree

import requests
from celery import shared_task
from django.conf import settings
from django.db.models import F

logger = logging.getLogger(__name__)


def parse_nbkr_usd_rate(payload: bytes) -> Decimal:
    """Достаёт курс доллара из XML НБКР.

    Формат: <Currency ISOCode="USD"><Nominal>1</Nominal><Value>87,4500</Value>.
    Значение приходит с запятой в качестве разделителя.
    """
    root = ElementTree.fromstring(payload)

    for currency in root.iter("Currency"):
        if currency.get("ISOCode") != "USD":
            continue

        value = (currency.findtext("Value") or "").replace(",", ".").strip()
        nominal = (currency.findtext("Nominal") or "1").replace(",", ".").strip()
        try:
            rate = Decimal(value) / Decimal(nominal or "1")
        except (InvalidOperation, ZeroDivisionError) as exc:
            raise ValueError("Некорректное значение курса в ответе НБКР") from exc

        if rate <= 0:
            raise ValueError("Курс НБКР должен быть положительным")
        return rate

    raise ValueError("В ответе НБКР нет курса USD")


@shared_task(name="catalog.fetch_exchange_rates", ignore_result=True)
def fetch_exchange_rates() -> str:
    """Раз в сутки тянет курс USD/KGS с сайта НБКР.

    Источник недоступен или ответил мусором — пишем в лог и оставляем прошлый
    курс: каталог должен работать и с вчерашним курсом.
    """
    from apps.catalog.enums import Currency
    from apps.catalog.models import ExchangeRate
    from apps.catalog.rates import invalidate_rate_cache

    try:
        response = requests.get(settings.NBKR_RATES_URL, timeout=settings.NBKR_TIMEOUT)
        response.raise_for_status()
        rate = parse_nbkr_usd_rate(response.content)
    except (requests.RequestException, ElementTree.ParseError, ValueError) as exc:
        logger.warning("Курс НБКР не обновлён (%s): %s", exc.__class__.__name__, exc)
        return "skipped"

    ExchangeRate.objects.create(
        currency_from=Currency.USD,
        currency_to=Currency.KGS,
        rate=rate,
    )
    invalidate_rate_cache()
    updated = recalculate_prices_in_usd(rate)

    logger.info("Курс USD/KGS обновлён: %s, пересчитано объявлений: %s", rate, updated)
    return "updated"


def recalculate_prices_in_usd(rate: Decimal) -> int:
    """Пересчитывает price_usd у объявлений в сомах одним UPDATE."""
    from apps.catalog.enums import Currency
    from apps.catalog.models import Listing

    Listing.objects.filter(currency=Currency.USD).exclude(price_usd=F("price")).update(
        price_usd=F("price")
    )
    return Listing.objects.filter(currency=Currency.KGS).update(price_usd=F("price") / rate)


@shared_task(name="catalog.rebuild_search_index", ignore_result=True)
def rebuild_search_index() -> int:
    """Полный пересчёт поискового индекса."""
    from apps.catalog.search import update_search_vectors

    updated = update_search_vectors()
    logger.info("Поисковый индекс пересобран, объявлений: %s", updated)
    return updated


@shared_task(name="catalog.update_listing_search_vector", ignore_result=True)
def update_listing_search_vector(listing_id: int) -> int:
    """Пересчёт индекса одного объявления — после публикации или правки."""
    from apps.catalog.models import Listing
    from apps.catalog.search import update_search_vectors

    return update_search_vectors(Listing.objects.filter(pk=listing_id))
