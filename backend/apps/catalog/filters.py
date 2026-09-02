"""Фильтры каталога.

Мультивыбор передаётся списком через запятую и внутри параметра объединяется
по ИЛИ (`__in`), разные параметры комбинируются по И. Исключение — площадь:
`area_ranges` и `area_min`/`area_max` объединяются по ИЛИ между собой, как
на экране фильтра во Flutter: чипы диапазонов и поле «своя квадратура»
дополняют друг друга, а не сужают.
"""

import logging
from decimal import Decimal, InvalidOperation
from typing import Any

import django_filters as filters
from django import forms
from django.db.models import Exists, F, OuterRef, Q, QuerySet

from apps.catalog.enums import Currency, MediaKind, PropertyKind, SellerKind
from apps.catalog.models import Listing, ListingMedia
from apps.catalog.rates import to_usd
from apps.catalog.search import apply_search

logger = logging.getLogger(__name__)

# С этого значения комнаты трактуются как «и более»: чип «5+» в макете.
ROOMS_PLUS_FROM = 5


class CharInFilter(filters.BaseInFilter, filters.CharFilter):
    """`?kind=apartment,house` -> kind IN (...)."""


class NumberInFilter(filters.BaseInFilter, filters.NumberFilter):
    """`?rooms=1,2,3` -> список чисел."""


def parse_area_ranges(raw: str) -> list[tuple[Decimal, Decimal]]:
    """«35-45,65-75» -> [(35, 45), (65, 75)]. Мусор молча пропускается."""
    ranges: list[tuple[Decimal, Decimal]] = []

    for chunk in (raw or "").split(","):
        parts = chunk.strip().split("-")
        if len(parts) != 2:
            continue
        try:
            low, high = Decimal(parts[0].strip()), Decimal(parts[1].strip())
        except (InvalidOperation, ValueError):
            continue
        if low > high:
            low, high = high, low
        ranges.append((low, high))

    return ranges


class ListingFilterForm(forms.Form):
    """Перекрёстные проверки, которые не выражаются отдельным полем.

    Одиночные значения django-filter проверяет сам (`rooms=banana` — 400).
    Здесь остаётся то, что видно только при взгляде на пару полей сразу:
    перевёрнутая вилка и отрицательные границы. Молча возвращать пустой
    список на `price_min=500000&price_max=1000` нельзя — это не пустой
    результат, а бессмысленный запрос, и клиент должен узнать об этом.
    """

    #: Поля, где значение ниже нуля не имеет смысла.
    NON_NEGATIVE = ("price_min", "price_max", "area_min", "area_max")

    #: Пары «от/до», которые нельзя задавать в обратном порядке.
    BOUNDS = (
        ("price_min", "price_max", "Цена «от» не может быть больше цены «до»"),
        ("area_min", "area_max", "Площадь «от» не может быть больше площади «до»"),
        ("floor_min", "floor_max", "Этаж «от» не может быть больше этажа «до»"),
    )

    #: Мультивыборы, значения которых обязаны совпадать с enum'ом каталога.
    CHOICES = (
        ("kind", PropertyKind, "Неизвестный тип недвижимости"),
        ("seller_kind", SellerKind, "Неизвестный тип продавца"),
    )

    def clean(self) -> dict[str, Any]:
        cleaned = super().clean()
        errors: dict[str, list[str]] = {}

        for name in self.NON_NEGATIVE:
            value = cleaned.get(name)
            if value is not None and value < 0:
                errors.setdefault(name, []).append("Значение не может быть отрицательным")

        for low_name, high_name, message in self.BOUNDS:
            low, high = cleaned.get(low_name), cleaned.get(high_name)
            # Проверяем только когда обе границы заданы и обе прошли своё поле.
            if low is not None and high is not None and low > high:
                errors.setdefault(low_name, []).append(message)

        for name, enum, message in self.CHOICES:
            values = cleaned.get(name) or []
            unknown = [item for item in values if item not in enum.values]
            if unknown:
                allowed = ", ".join(enum.values)
                errors.setdefault(name, []).append(
                    f"{message}: {', '.join(unknown)}. Допустимые значения: {allowed}"
                )

        if errors:
            raise forms.ValidationError(errors)

        return cleaned


class ListingFilterSet(filters.FilterSet):
    """Все параметры экрана фильтра и поисковой строки каталога."""

    search = filters.CharFilter(method="filter_search", label="Поисковый запрос")

    kind = CharInFilter(field_name="kind", lookup_expr="in", label="Типы недвижимости")
    district = CharInFilter(field_name="district__slug", lookup_expr="in", label="Районы")
    city = filters.CharFilter(field_name="city__slug", label="Город")

    rooms = NumberInFilter(method="filter_rooms", label="Комнат")

    # Площадь собирается целиком в filter_queryset — здесь только приём значений.
    area_min = filters.NumberFilter(method="noop", label="Площадь от")
    area_max = filters.NumberFilter(method="noop", label="Площадь до")
    area_ranges = filters.CharFilter(method="noop", label="Диапазоны площади")

    price_min = filters.NumberFilter(method="filter_price_min", label="Цена от")
    price_max = filters.NumberFilter(method="filter_price_max", label="Цена до")
    currency = filters.ChoiceFilter(
        choices=Currency.choices,
        method="noop",
        label="Валюта, в которой заданы price_min/price_max",
    )

    seller_kind = CharInFilter(field_name="seller_kind", lookup_expr="in", label="Продавец")
    is_secondary = filters.BooleanFilter(field_name="is_secondary", label="Вторичка")
    series = CharInFilter(field_name="series__code", lookup_expr="in", label="Серии домов")

    floor_min = filters.NumberFilter(field_name="floor", lookup_expr="gte", label="Этаж от")
    floor_max = filters.NumberFilter(field_name="floor", lookup_expr="lte", label="Этаж до")
    not_first_floor = filters.BooleanFilter(method="filter_not_first_floor", label="Не первый этаж")
    not_last_floor = filters.BooleanFilter(
        method="filter_not_last_floor", label="Не последний этаж"
    )

    below_market = filters.BooleanFilter(field_name="below_market", label="Ниже рынка")
    red_book = filters.BooleanFilter(field_name="red_book", label="Красная книга")
    has_video = filters.BooleanFilter(method="filter_has_video", label="С видео")

    builder = filters.CharFilter(field_name="builder__slug", label="Застройщик")

    # Параметры, применимые только к отдельным типам (apps/catalog/field_rules.py).
    plot_purpose = CharInFilter(
        field_name="plot_purpose", lookup_expr="in", label="Назначение участка"
    )
    commercial_purpose = CharInFilter(
        field_name="commercial_purpose", lookup_expr="in", label="Назначение помещения"
    )
    building_line = CharInFilter(field_name="building_line", lookup_expr="in", label="Линия")
    has_separate_entrance = filters.BooleanFilter(
        field_name="has_separate_entrance", label="Отдельный вход"
    )

    class Meta:
        model = Listing
        form = ListingFilterForm
        fields: list[str] = []

    # -- служебное -----------------------------------------------------------

    def noop(self, queryset: QuerySet, name: str, value: Any) -> QuerySet:
        """Значение используется в другом месте (площадь, валюта)."""
        return queryset

    def filter_queryset(self, queryset: QuerySet) -> QuerySet:
        queryset = super().filter_queryset(queryset)

        area_q = self._area_q()
        if area_q is not None:
            queryset = queryset.filter(area_q)

        return queryset

    def _area_q(self) -> Q | None:
        """Диапазоны-чипы ИЛИ введённая вручную вилка."""
        data = self.form.cleaned_data

        ranges_q: Q | None = None
        for low, high in parse_area_ranges(data.get("area_ranges") or ""):
            chunk = Q(area__range=(low, high))
            ranges_q = chunk if ranges_q is None else ranges_q | chunk

        bounds_q: Q | None = None
        if data.get("area_min") is not None:
            bounds_q = Q(area__gte=data["area_min"])
        if data.get("area_max") is not None:
            upper = Q(area__lte=data["area_max"])
            bounds_q = upper if bounds_q is None else bounds_q & upper

        if ranges_q is not None and bounds_q is not None:
            return ranges_q | bounds_q
        return ranges_q if ranges_q is not None else bounds_q

    def _selected_currency(self) -> str:
        value = self.form.cleaned_data.get("currency") if hasattr(self, "form") else None
        return value or Currency.USD

    # -- методы фильтров -----------------------------------------------------

    def filter_search(self, queryset: QuerySet, name: str, value: str) -> QuerySet:
        return apply_search(queryset, value)

    def filter_rooms(self, queryset: QuerySet, name: str, value: list[Any]) -> QuerySet:
        """5 — это «пять и больше»: шестикомнатная квартира тоже подходит."""
        exact = [int(item) for item in value if item is not None and int(item) < ROOMS_PLUS_FROM]
        wants_plus = any(item is not None and int(item) >= ROOMS_PLUS_FROM for item in value)

        rooms_q = Q(rooms__in=exact) if exact else None
        if wants_plus:
            plus = Q(rooms__gte=ROOMS_PLUS_FROM)
            rooms_q = plus if rooms_q is None else rooms_q | plus

        return queryset.filter(rooms_q) if rooms_q is not None else queryset

    def filter_price_min(self, queryset: QuerySet, name: str, value: Decimal) -> QuerySet:
        return queryset.filter(price_usd__gte=to_usd(value, self._selected_currency()))

    def filter_price_max(self, queryset: QuerySet, name: str, value: Decimal) -> QuerySet:
        return queryset.filter(price_usd__lte=to_usd(value, self._selected_currency()))

    def filter_not_first_floor(self, queryset: QuerySet, name: str, value: bool) -> QuerySet:
        return queryset.filter(floor__gt=1) if value else queryset

    def filter_not_last_floor(self, queryset: QuerySet, name: str, value: bool) -> QuerySet:
        return queryset.filter(floor__lt=F("floors")) if value else queryset

    def filter_has_video(self, queryset: QuerySet, name: str, value: bool) -> QuerySet:
        has_video = Exists(
            ListingMedia.objects.filter(listing_id=OuterRef("pk"), kind=MediaKind.VIDEO)
        )
        if value is None:
            return queryset
        return queryset.filter(has_video) if value else queryset.filter(~has_video)


# Значения, которые фронт может прислать в мультивыборе — для документации схемы.
KIND_VALUES = ", ".join(PropertyKind.values)
SELLER_KIND_VALUES = ", ".join(SellerKind.values)
