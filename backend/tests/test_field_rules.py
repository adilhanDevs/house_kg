"""Поля объявления, применимые к типу недвижимости.

Проверяется сама таблица правил и то, что новые поля модели существуют:
поведение API, построенное поверх них, живёт в `test_kind_fields_api.py`.
"""

import pytest

from apps.catalog.enums import (
    BuildingLine,
    CommercialPurpose,
    FurnitureKind,
    PlotPurpose,
    PropertyKind,
)
from apps.catalog.field_rules import (
    KIND_FIELDS,
    REQUIRED_BY_KIND,
    applicable_fields,
    strip_inapplicable,
)
from apps.catalog.models import Listing


def test_commercial_fields_exist_on_model():
    """Новые поля должны существовать и иметь пустое значение по умолчанию."""
    listing = Listing(kind=PropertyKind.COMMERCIAL)

    assert listing.commercial_purpose == ""
    assert listing.building_line == ""
    assert listing.has_separate_entrance is False
    assert listing.ceiling_height is None


def test_plot_purpose_field_exists():
    listing = Listing(kind=PropertyKind.PLOT)

    assert listing.plot_purpose == ""


def test_new_enums_have_expected_values():
    assert set(PlotPurpose.values) == {"ihs", "garden", "agricultural", "commercial"}
    assert set(CommercialPurpose.values) == {
        "office",
        "shop",
        "warehouse",
        "production",
        "catering",
        "free",
    }
    assert set(BuildingLine.values) == {"first", "second", "inside"}


def test_plot_has_no_rooms_or_floors():
    fields = applicable_fields(PropertyKind.PLOT)

    assert "rooms" not in fields
    assert "floor" not in fields
    assert "floors" not in fields
    assert "series" not in fields
    assert "plot_purpose" in fields
    assert "land_area" in fields


def test_commercial_has_own_parameters():
    fields = applicable_fields(PropertyKind.COMMERCIAL)

    assert "commercial_purpose" in fields
    assert "has_separate_entrance" in fields
    assert "building_line" in fields
    assert "ceiling_height" in fields
    assert "rooms" not in fields
    assert "series" not in fields


def test_room_has_no_rooms_field():
    """«Комната» — это и есть одна комната, счётчик комнат ей не нужен."""
    assert "rooms" not in applicable_fields(PropertyKind.ROOM)
    assert "floor" in applicable_fields(PropertyKind.ROOM)


def test_new_building_has_builder_but_no_series():
    fields = applicable_fields(PropertyKind.NEW_BUILDING)

    assert "builder" in fields
    assert "series" not in fields
    assert "is_secondary" not in fields


def test_strip_inapplicable_drops_rooms_for_plot():
    cleaned = strip_inapplicable(PropertyKind.PLOT, {"rooms": 3, "price": 100, "land_area": 8})

    assert cleaned == {"price": 100, "land_area": 8}


def test_strip_inapplicable_keeps_rooms_for_apartment():
    cleaned = strip_inapplicable(PropertyKind.APARTMENT, {"rooms": 3, "price": 100})

    assert cleaned == {"rooms": 3, "price": 100}


def test_strip_inapplicable_passes_unknown_kind_through():
    """Неизвестный тип не должен молча стирать данные."""
    assert strip_inapplicable("", {"rooms": 3}) == {"rooms": 3}


def test_ceiling_height_never_required():
    for required in REQUIRED_BY_KIND.values():
        assert "ceiling_height" not in required


@pytest.mark.parametrize("kind", PropertyKind.values)
def test_every_kind_has_rules(kind: str):
    assert kind in KIND_FIELDS
    assert kind in REQUIRED_BY_KIND


# -- смена типа чистит за собой ----------------------------------------------
#
# `strip_inapplicable` убирает лишнее из ВХОДЯЩИХ данных, но у объекта
# остаётся то, что записали раньше: квартира, ставшая участком, уезжала
# в каталог с прежними комнатами и этажом.


def test_kind_change_clears_fields_of_the_previous_kind():
    from apps.catalog.services import reset_inapplicable_fields

    listing = Listing(
        kind=PropertyKind.APARTMENT,
        rooms=3,
        floor=5,
        floors=9,
        furniture=FurnitureKind.FULL,
        is_secondary=True,
    )

    cleared = reset_inapplicable_fields(listing, PropertyKind.PLOT)

    assert listing.rooms == 0
    assert listing.floor == 0
    assert listing.floors == 0
    assert listing.furniture == ""
    assert listing.is_secondary is False
    assert {"rooms", "floor", "floors", "furniture", "is_secondary"} <= set(cleared)


def test_kind_change_keeps_common_fields():
    from apps.catalog.services import reset_inapplicable_fields

    listing = Listing(
        kind=PropertyKind.APARTMENT,
        address="Ахунбаева 12",
        description="Тихий двор",
        contact_name="Айбек",
    )

    reset_inapplicable_fields(listing, PropertyKind.PLOT)

    assert listing.address == "Ахунбаева 12"
    assert listing.description == "Тихий двор"
    assert listing.contact_name == "Айбек"


def test_unknown_kind_leaves_the_object_alone():
    from apps.catalog.services import reset_inapplicable_fields

    listing = Listing(kind=PropertyKind.APARTMENT, rooms=3)

    assert reset_inapplicable_fields(listing, "spaceship") == []
    assert listing.rooms == 3
