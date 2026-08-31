"""Какие поля объявления применимы к какому типу недвижимости.

Единственный источник правды для трёх мест: очистки входных данных в
сериализаторе, проверки готовности к публикации и набора фильтров. Зеркало
этой таблицы живёт в клиенте — `flutter_app/lib/data/kind_fields.dart`; при
правке здесь правьте и там.

Модуль намеренно не импортирует ничего из `services.py`: им пользуются и
сериализаторы, и фильтры, а цикл импортов здесь дорого отлаживать.
"""

from typing import Any

from apps.catalog.enums import PropertyKind

# Поля, осмысленные для любого типа: адрес, деньги, описание, контакты.
COMMON_FIELDS = frozenset(
    {
        "kind",
        "district",
        "city",
        "address",
        "latitude",
        "longitude",
        "price",
        "currency",
        "area",
        "description",
        "seller_kind",
        "has_direct_sale",
        "has_mortgage",
        "landmarks",
        "below_market",
        "allow_media_download",
        "contact_name",
        "contact_phone",
        # Обмен возможен на объект любого типа, включая участок.
        "exchange_possible",
    }
)

# Поквартирные площади, мебель и инженерия — только там, где есть внутренние
# помещения: у участка ни ремонта, ни отопления быть не может.
INTERIOR_FIELDS = frozenset(
    {
        "living_room_area",
        "hall_area",
        "kitchen_area",
        "bedroom_area",
        "bedroom_2_area",
        "balcony_area",
        "bathroom_area",
        "furniture",
        "condition",
        "heating",
        "has_gas",
    }
)

KIND_FIELDS: dict[str, frozenset[str]] = {
    PropertyKind.APARTMENT: COMMON_FIELDS
    | INTERIOR_FIELDS
    | {"rooms", "floor", "floors", "series", "is_secondary"},
    PropertyKind.ROOM: COMMON_FIELDS
    | INTERIOR_FIELDS
    | {"floor", "floors", "series", "is_secondary"},
    PropertyKind.HOUSE: COMMON_FIELDS
    | INTERIOR_FIELDS
    | {"rooms", "floors", "is_secondary", "land_area", "red_book"},
    PropertyKind.NEW_BUILDING: COMMON_FIELDS
    | INTERIOR_FIELDS
    | {"rooms", "floor", "floors", "builder"},
    PropertyKind.PLOT: COMMON_FIELDS | {"land_area", "red_book", "plot_purpose"},
    PropertyKind.COMMERCIAL: COMMON_FIELDS
    | {
        "floor",
        "floors",
        "commercial_purpose",
        "has_separate_entrance",
        "building_line",
        "ceiling_height",
    },
}

# Что обязательно заполнить перед публикацией. Фото проверяются отдельно:
# они живут не в полях объявления, а в связанных медиа.
REQUIRED_BY_KIND: dict[str, tuple[str, ...]] = {
    PropertyKind.APARTMENT: ("kind", "district", "price", "area", "rooms", "floor", "floors"),
    PropertyKind.ROOM: ("kind", "district", "price", "area", "floor", "floors"),
    PropertyKind.HOUSE: ("kind", "district", "price", "area", "rooms", "floors"),
    PropertyKind.NEW_BUILDING: ("kind", "district", "price", "area", "rooms", "floor", "floors"),
    PropertyKind.PLOT: ("kind", "district", "price", "land_area"),
    PropertyKind.COMMERCIAL: ("kind", "district", "price", "area"),
}


def applicable_fields(kind: str) -> frozenset[str]:
    """Поля, осмысленные для типа. Для неизвестного типа — пустое множество."""
    return KIND_FIELDS.get(kind, frozenset())


def strip_inapplicable(kind: str, data: dict[str, Any]) -> dict[str, Any]:
    """Убирает из данных всё, что к типу не относится.

    Неизвестный тип возвращается как есть: молча стирать данные из-за
    опечатки в `kind` хуже, чем пропустить лишнее поле — его отсечёт
    валидация типа на уровне сериализатора.
    """
    allowed = KIND_FIELDS.get(kind)
    if allowed is None:
        return data
    return {key: value for key, value in data.items() if key in allowed}
