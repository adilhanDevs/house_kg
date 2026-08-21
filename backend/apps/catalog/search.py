"""Полнотекстовый поиск по объявлениям.

Основной путь — PostgreSQL: tsvector с весами и `websearch`-синтаксис. Если
точных совпадений нет, включается поиск по триграммам, чтобы «технпарк»
с опечаткой находил «Технопарк».

На других СУБД (локальный прогон тестов идёт на SQLite) поиск деградирует
до `icontains`: это заглушка для разработки, целевая БД проекта — Postgres 16.
"""

import logging
from typing import Any

from django.contrib.postgres.search import (
    SearchQuery,
    SearchRank,
    SearchVector,
    TrigramSimilarity,
)
from django.db import connection
from django.db.models import F, FloatField, OuterRef, Q, QuerySet, Subquery, Value
from django.db.models.functions import Greatest

logger = logging.getLogger(__name__)

SEARCH_CONFIG = "russian"
TRIGRAM_THRESHOLD = 0.3


def is_postgres() -> bool:
    return connection.vendor == "postgresql"


def search_vector_expression() -> Any:
    """Веса: район важнее адреса, адрес важнее описания."""
    return (
        SearchVector("district__name", weight="A", config=SEARCH_CONFIG)
        + SearchVector("address", weight="B", config=SEARCH_CONFIG)
        + SearchVector("description", weight="C", config=SEARCH_CONFIG)
        + SearchVector("builder__name", weight="B", config=SEARCH_CONFIG)
    )


def update_search_vectors(queryset: QuerySet | None = None) -> int:
    """Пересчитывает search_vector одним UPDATE.

    Вектор собирается из полей связанных таблиц, поэтому идёт подзапросом:
    `update()` напрямую по join'ам Django не умеет.
    """
    from apps.catalog.models import Listing

    if not is_postgres():
        logger.info("Полнотекстовый индекс поддерживается только PostgreSQL — пропускаю")
        return 0

    base = Listing.objects.all() if queryset is None else queryset
    vector = (
        Listing.objects.filter(pk=OuterRef("pk"))
        .annotate(vector=search_vector_expression())
        .values("vector")[:1]
    )
    return base.update(search_vector=Subquery(vector))


def _fallback_search(queryset: QuerySet, term: str) -> QuerySet:
    """Поиск подстрокой — только для разработки на SQLite."""
    return queryset.annotate(search_rank=Value(0.0, output_field=FloatField())).filter(
        Q(district__name__icontains=term)
        | Q(address__icontains=term)
        | Q(description__icontains=term)
    )


def apply_search(queryset: QuerySet, term: str) -> QuerySet:
    """Полнотекстовый поиск с откатом на триграммы."""
    term = (term or "").strip()
    if not term:
        return queryset

    if not is_postgres():
        return _fallback_search(queryset, term)

    query = SearchQuery(term, config=SEARCH_CONFIG, search_type="websearch")
    ranked = queryset.annotate(search_rank=SearchRank(F("search_vector"), query)).filter(
        search_vector=query
    )

    if ranked.exists():
        return ranked

    # Точных совпадений нет — вероятно, опечатка. Ищем похожие по триграммам.
    similarity = Greatest(
        TrigramSimilarity("district__name", term),
        TrigramSimilarity("address", term),
    )
    return queryset.annotate(search_rank=similarity).filter(search_rank__gte=TRIGRAM_THRESHOLD)
