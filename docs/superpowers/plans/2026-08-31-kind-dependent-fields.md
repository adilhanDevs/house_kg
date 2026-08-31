# Kind-Dependent Listing Fields Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Набор полей объявления — в форме подачи, в фильтре, в карточке и в валидации — определяется типом недвижимости, а не показывается всем типам одинаково.

**Architecture:** Одна таблица «тип → применимые поля» существует в двух зеркальных копиях: `backend/apps/catalog/field_rules.py` (её читают сериализатор, проверка публикации и фильтры) и `flutter_app/lib/data/kind_fields.dart` (её читают форма, фильтр и карточка). Пять новых полей модели покрывают параметры участков и коммерции. Экран фильтра пересобирается из кадра Figma с абсолютными координатами в прокручиваемый список секций с переиспользованием тех же `Fig*`-виджетов.

**Tech Stack:** Django 5 + DRF, pytest + pytest-django, Flutter/Dart.

## Global Constraints

- Значения enum'ов `PropertyKind`, `SellerKind`, `ListingStatus` менять нельзя — на них завязан клиент (§1.6 ТЗ).
- Пути API — под `/api/v1/`, поля JSON — `snake_case` (§1.5 ТЗ).
- Бизнес-логика живёт в `services.py` / отдельных модулях, не во `views` (§1.3 ТЗ).
- `ruff` line-length 100; форматирование `ruff format`.
- Добавление полей и вариантов enum — совместимое изменение; снапшот OpenAPI обновляется осознанно через `make schema-update` (`backend/tests/test_openapi_contract.py`).
- Новые поля модели допускают пустое значение: миграция не должна ломать существующие записи.
- Неприменимые к типу значения отбрасываются молча, без ошибки валидации.

## Файловая структура

**Создаются:**

| Файл | Ответственность |
|---|---|
| `backend/apps/catalog/field_rules.py` | Таблица «тип → применимые/обязательные поля» и две чистые функции над ней. Ничего не импортирует из `services.py`. |
| `backend/apps/catalog/migrations/00XX_kind_specific_fields.py` | Добавление пяти колонок. |
| `backend/tests/test_field_rules.py` | Юнит-тесты таблицы и `strip_inapplicable`. |
| `flutter_app/lib/data/kind_fields.dart` | Зеркало таблицы для клиента: `ListingField`, `kindFields`, `showsField`. |

**Изменяются:**

| Файл | Что меняется |
|---|---|
| `backend/apps/catalog/enums.py` | Три новых `TextChoices`. |
| `backend/apps/catalog/models.py:244-272` | Пять новых полей. |
| `backend/apps/catalog/serializers.py` | Новые поля в `ListingListSerializer` (`land_area`), `ListingDetailSerializer`, `ListingUpdateSerializer`; `strip_inapplicable` в `validate()`; новые опции в `FilterOptionsSerializer`. |
| `backend/apps/catalog/services.py:742-753` | `missing_fields_for_publish` через `REQUIRED_BY_KIND`; `build_filter_options` отдаёт новые словари опций. |
| `backend/apps/catalog/filters.py` | Четыре новых фильтра. |
| `backend/apps/catalog/admin.py` | Новые поля в форме объявления. |
| `flutter_app/lib/data/listings.dart` | Новые поля модели `Listing` и их разбор из JSON. |
| `flutter_app/lib/app/app_state.dart` | Черновик: новые поля, сброс неприменимых при смене типа; состояние фильтра для новых параметров. |
| `flutter_app/lib/ui/pages/ad_form_page.dart` | Условные секции + пять новых. |
| `flutter_app/lib/ui/pages/filter_page.dart` | Полная пересборка в список секций. |
| `flutter_app/lib/ui/object_card.dart:178-186` | Характеристики по типу. |
| `flutter_app/lib/ui/pages/listing_page.dart:648-651, 934-959` | Характеристики по типу, снятие фолбэка «из 12». |
| `flutter_app/lib/ui/pages/ad_preview_page.dart:406, 422` | Условные комнаты и этажи. |

---

### Task 1: Перечисления и поля модели

**Files:**
- Modify: `backend/apps/catalog/enums.py`
- Modify: `backend/apps/catalog/models.py:244-272`
- Create: `backend/apps/catalog/migrations/00XX_kind_specific_fields.py` (генерируется)
- Test: `backend/tests/test_field_rules.py`

**Interfaces:**
- Produces: `PlotPurpose`, `CommercialPurpose`, `BuildingLine` в `apps.catalog.enums`; поля `Listing.plot_purpose`, `Listing.commercial_purpose`, `Listing.has_separate_entrance`, `Listing.building_line`, `Listing.ceiling_height`.

- [ ] **Step 1: Написать падающий тест**

Создать `backend/tests/test_field_rules.py`:

```python
"""Поля, применимые к типу недвижимости."""

import pytest

from apps.catalog.enums import BuildingLine, CommercialPurpose, PlotPurpose, PropertyKind
from apps.catalog.models import Listing


@pytest.mark.django_db
def test_commercial_fields_exist_on_model():
    """Новые поля должны существовать и иметь пустое значение по умолчанию."""
    listing = Listing(kind=PropertyKind.COMMERCIAL)

    assert listing.commercial_purpose == ""
    assert listing.building_line == ""
    assert listing.has_separate_entrance is False
    assert listing.ceiling_height is None


@pytest.mark.django_db
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
```

- [ ] **Step 2: Запустить и убедиться, что падает**

Run: `cd backend && pytest tests/test_field_rules.py -v`
Expected: FAIL — `ImportError: cannot import name 'PlotPurpose'`

- [ ] **Step 3: Добавить перечисления**

В `backend/apps/catalog/enums.py` после класса `PropertyKind`:

```python
class PlotPurpose(models.TextChoices):
    """Назначение участка — показывается только для kind=plot."""

    IHS = "ihs", "ИЖС"
    GARDEN = "garden", "Садовый"
    AGRICULTURAL = "agricultural", "Сельхозназначение"
    COMMERCIAL = "commercial", "Коммерческий"


class CommercialPurpose(models.TextChoices):
    """Назначение помещения — показывается только для kind=commercial."""

    OFFICE = "office", "Офис"
    SHOP = "shop", "Магазин"
    WAREHOUSE = "warehouse", "Склад"
    PRODUCTION = "production", "Производство"
    CATERING = "catering", "Общепит"
    FREE = "free", "Свободного назначения"


class BuildingLine(models.TextChoices):
    """Расположение относительно дороги — важно для торговых помещений."""

    FIRST = "first", "Первая линия"
    SECOND = "second", "Вторая линия"
    INSIDE = "inside", "Внутри квартала"
```

- [ ] **Step 4: Добавить поля модели**

В `backend/apps/catalog/models.py` импорт дополнить: `from apps.catalog.enums import BuildingLine, CommercialPurpose, PlotPurpose` (к существующему импорту enums). Поля добавить сразу после `has_mortgage`:

```python
    # -- параметры, применимые только к отдельным типам ----------------------
    #
    # Какое поле к какому типу относится — в apps/catalog/field_rules.py.
    plot_purpose = models.CharField(
        "Назначение участка", max_length=16, choices=PlotPurpose.choices, blank=True
    )
    commercial_purpose = models.CharField(
        "Назначение помещения", max_length=16, choices=CommercialPurpose.choices, blank=True
    )
    has_separate_entrance = models.BooleanField("Отдельный вход", default=False)
    building_line = models.CharField(
        "Линия", max_length=8, choices=BuildingLine.choices, blank=True
    )
    ceiling_height = models.DecimalField(
        "Высота потолков, м", max_digits=4, decimal_places=2, blank=True, null=True
    )
```

- [ ] **Step 5: Сгенерировать миграцию**

Run: `cd backend && python manage.py makemigrations catalog -n kind_specific_fields`
Expected: создан файл миграции с пятью `AddField`.

- [ ] **Step 6: Запустить тест**

Run: `cd backend && pytest tests/test_field_rules.py -v`
Expected: PASS (3 теста)

- [ ] **Step 7: Коммит**

```bash
git add backend/apps/catalog/enums.py backend/apps/catalog/models.py backend/apps/catalog/migrations backend/tests/test_field_rules.py
git commit -m "feat(catalog): поля участка и коммерции в модели объявления"
```

---

### Task 2: Таблица правил

**Files:**
- Create: `backend/apps/catalog/field_rules.py`
- Test: `backend/tests/test_field_rules.py` (дополняется)

**Interfaces:**
- Consumes: `PropertyKind` из Task 1.
- Produces: `KIND_FIELDS: dict[str, frozenset[str]]`, `REQUIRED_BY_KIND: dict[str, tuple[str, ...]]`, `applicable_fields(kind: str) -> frozenset[str]`, `strip_inapplicable(kind: str, data: dict) -> dict`.

- [ ] **Step 1: Написать падающий тест**

Дописать в `backend/tests/test_field_rules.py`:

```python
from apps.catalog.field_rules import (
    KIND_FIELDS,
    REQUIRED_BY_KIND,
    applicable_fields,
    strip_inapplicable,
)


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


def test_every_kind_has_rules():
    for kind in PropertyKind.values:
        assert kind in KIND_FIELDS
        assert kind in REQUIRED_BY_KIND
```

- [ ] **Step 2: Запустить и убедиться, что падает**

Run: `cd backend && pytest tests/test_field_rules.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'apps.catalog.field_rules'`

- [ ] **Step 3: Написать модуль**

Создать `backend/apps/catalog/field_rules.py`:

```python
"""Какие поля объявления применимы к какому типу недвижимости.

Единственный источник правды для трёх мест: очистки входных данных в
сериализаторе, проверки готовности к публикации и набора фильтров. Зеркало
этой таблицы живёт в клиенте — `flutter_app/lib/data/kind_fields.dart`; при
правке здесь правьте и там.

Модуль намеренно не импортирует ничего из `services.py`: им пользуются и
сериализаторы, и фильтры, а цикл импортов здесь дорого отлаживать.
"""

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
    }
)

# Поквартирные площади и мебель — только там, где есть внутренние помещения.
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


def strip_inapplicable(kind: str, data: dict) -> dict:
    """Убирает из данных всё, что к типу не относится.

    Неизвестный тип возвращается как есть: молча стирать данные из-за
    опечатки в `kind` хуже, чем пропустить лишнее поле — его отсечёт
    валидация типа на уровне сериализатора.
    """
    allowed = KIND_FIELDS.get(kind)
    if allowed is None:
        return data
    return {key: value for key, value in data.items() if key in allowed}
```

- [ ] **Step 4: Запустить тесты**

Run: `cd backend && pytest tests/test_field_rules.py -v`
Expected: PASS (12 тестов)

- [ ] **Step 5: Проверить линтером**

Run: `cd backend && ruff check apps/catalog/field_rules.py tests/test_field_rules.py`
Expected: `All checks passed!`

- [ ] **Step 6: Коммит**

```bash
git add backend/apps/catalog/field_rules.py backend/tests/test_field_rules.py
git commit -m "feat(catalog): таблица применимости полей по типу недвижимости"
```

---

### Task 3: Публикация и очистка входных данных

**Files:**
- Modify: `backend/apps/catalog/services.py:709-753`
- Modify: `backend/apps/catalog/serializers.py:465-528`
- Test: `backend/tests/test_kind_fields_api.py` (создаётся)

**Interfaces:**
- Consumes: `strip_inapplicable`, `REQUIRED_BY_KIND` из Task 2.
- Produces: `missing_fields_for_publish(listing)` учитывает тип; `ListingUpdateSerializer` принимает новые поля и отбрасывает неприменимые.

- [ ] **Step 1: Написать падающий тест**

Создать `backend/tests/test_kind_fields_api.py`:

```python
"""Поведение API при полях, зависящих от типа недвижимости."""

import pytest
from rest_framework.test import APIClient

from apps.catalog.enums import CommercialPurpose, ListingStatus, PropertyKind
from apps.catalog.models import Listing
from apps.catalog.services import missing_fields_for_publish


@pytest.mark.django_db
def test_plot_does_not_require_rooms_or_floors(listing_factory):
    plot = listing_factory(
        kind=PropertyKind.PLOT,
        rooms=0,
        floor=0,
        floors=0,
        land_area=8,
        status=ListingStatus.DRAFT,
    )

    assert "rooms" not in missing_fields_for_publish(plot)
    assert "floor" not in missing_fields_for_publish(plot)


@pytest.mark.django_db
def test_plot_requires_land_area(listing_factory):
    plot = listing_factory(kind=PropertyKind.PLOT, land_area=None, status=ListingStatus.DRAFT)

    assert "land_area" in missing_fields_for_publish(plot)


@pytest.mark.django_db
def test_apartment_still_requires_rooms(listing_factory):
    flat = listing_factory(
        kind=PropertyKind.APARTMENT, rooms=0, floor=0, floors=0, status=ListingStatus.DRAFT
    )
    missing = missing_fields_for_publish(flat)

    assert "rooms" in missing
    assert "floor" in missing


@pytest.mark.django_db
def test_patch_drops_rooms_for_plot(listing_factory, authed_client: APIClient):
    plot = listing_factory(kind=PropertyKind.PLOT, rooms=0, status=ListingStatus.DRAFT)

    response = authed_client.patch(
        f"/api/v1/listings/{plot.slug}/",
        {"rooms": 3, "land_area": "8.00"},
        format="json",
    )

    assert response.status_code == 200
    plot.refresh_from_db()
    assert plot.rooms == 0
    assert str(plot.land_area) == "8.00"


@pytest.mark.django_db
def test_patch_saves_commercial_purpose(listing_factory, authed_client: APIClient):
    shop = listing_factory(kind=PropertyKind.COMMERCIAL, status=ListingStatus.DRAFT)

    response = authed_client.patch(
        f"/api/v1/listings/{shop.slug}/",
        {"commercial_purpose": CommercialPurpose.SHOP, "has_separate_entrance": True},
        format="json",
    )

    assert response.status_code == 200
    shop.refresh_from_db()
    assert shop.commercial_purpose == CommercialPurpose.SHOP
    assert shop.has_separate_entrance is True
```

Фикстуры `listing_factory` и `authed_client` берутся из существующего `backend/tests/conftest.py`; если их имена там другие — использовать те, что есть, не заводя дубликаты.

- [ ] **Step 2: Запустить и убедиться, что падает**

Run: `cd backend && pytest tests/test_kind_fields_api.py -v`
Expected: FAIL — участок требует `rooms`, PATCH сохраняет `rooms=3`.

- [ ] **Step 3: Переписать проверку публикации**

В `backend/apps/catalog/services.py` заменить блок `REQUIRED_FOR_PUBLISH` / `REQUIRED_FOR_BUILDINGS` и функцию `missing_fields_for_publish`:

```python
def missing_fields_for_publish(listing: Listing) -> list[str]:
    """Чего не хватает, чтобы объявление можно было опубликовать.

    Набор обязательных полей зависит от типа: у участка нет ни комнат, ни
    этажей, зато обязательна площадь участка (apps/catalog/field_rules.py).
    """
    required = REQUIRED_BY_KIND.get(listing.kind, ())
    missing = [name for name in required if _is_blank(listing, name)]

    if not listing.media.filter(kind=MediaKind.PHOTO).exists():
        missing.append("photos")

    return missing
```

Импорт добавить в начало файла: `from apps.catalog.field_rules import REQUIRED_BY_KIND`.

`_is_blank` должен считать пустым и числовой ноль — иначе `rooms=0` пройдёт как заполненное. Проверить его текущую реализацию и, если он проверяет только `None`/`""`, дополнить:

```python
def _is_blank(listing: Listing, field: str) -> bool:
    value = getattr(listing, field, None)
    if value is None or value == "":
        return True
    # Ноль в «комнатах» и «этаже» — это незаполненное поле, а не значение.
    return field in ZERO_MEANS_EMPTY and not value
```

с константой рядом:

```python
# Поля, где 0 — это «не заполнено»: модель хранит их как PositiveSmallInteger
# с default=0, отличить «ноль» от «пусто» больше нечем.
ZERO_MEANS_EMPTY = frozenset({"rooms", "floor", "floors"})
```

Старые `REQUIRED_FOR_PUBLISH` и `REQUIRED_FOR_BUILDINGS` удалить, предварительно убедившись `grep -rn "REQUIRED_FOR_" backend/`, что на них никто не ссылается.

- [ ] **Step 4: Очистка входных данных в сериализаторе**

В `backend/apps/catalog/serializers.py` в `ListingUpdateSerializer.Meta.fields` добавить пять новых полей после `"builder"`:

```python
            "plot_purpose",
            "commercial_purpose",
            "has_separate_entrance",
            "building_line",
            "ceiling_height",
```

и переписать `validate`:

```python
    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        # Город всегда согласован с районом: клиент присылает только район.
        district = attrs.get("district")
        if district is not None and "city" not in attrs:
            attrs["city"] = district.city

        # Тип берём из запроса, а если его там нет — из уже сохранённого
        # объявления: клиент шлёт форму по частям.
        kind = attrs.get("kind") or getattr(self.instance, "kind", "")
        # Неприменимое отбрасываем молча: 400 на остаточном `rooms` от
        # предыдущего выбора типа сломал бы обычное заполнение формы.
        return strip_inapplicable(kind, attrs)
```

Импорт: `from apps.catalog.field_rules import strip_inapplicable`.

- [ ] **Step 5: Запустить тесты**

Run: `cd backend && pytest tests/test_kind_fields_api.py tests/test_field_rules.py -v`
Expected: PASS

- [ ] **Step 6: Прогнать весь набор — не сломалась ли публикация**

Run: `cd backend && pytest tests/ -q -k "publish or draft or listing"`
Expected: PASS. Если падает тест, ожидавший `rooms` обязательным для участка, — это ожидаемое изменение поведения: обновить тест и отметить в сообщении коммита.

- [ ] **Step 7: Коммит**

```bash
git add backend/apps/catalog/services.py backend/apps/catalog/serializers.py backend/tests/test_kind_fields_api.py
git commit -m "feat(catalog): обязательные поля и очистка данных по типу недвижимости"
```

---

### Task 4: Отдача полей клиенту и фильтры

**Files:**
- Modify: `backend/apps/catalog/serializers.py:274-300, 356-390, 98-110`
- Modify: `backend/apps/catalog/services.py:128-144`
- Modify: `backend/apps/catalog/filters.py`
- Modify: `backend/apps/catalog/admin.py`
- Test: `backend/tests/test_kind_fields_api.py` (дополняется)

**Interfaces:**
- Consumes: поля модели из Task 1.
- Produces: `land_area` и новые поля в ответах `/listings/` и `/listings/{slug}/`; query-параметры `plot_purpose`, `commercial_purpose`, `building_line`, `has_separate_entrance`; ключи `plot_purposes`, `commercial_purposes`, `building_lines` в `/catalog/filter-options/`.

- [ ] **Step 1: Написать падающий тест**

Дописать в `backend/tests/test_kind_fields_api.py`:

```python
@pytest.mark.django_db
def test_list_response_exposes_land_area(listing_factory, client):
    listing_factory(kind=PropertyKind.PLOT, land_area=8, status=ListingStatus.ACTIVE)

    response = client.get("/api/v1/listings/")

    assert response.status_code == 200
    assert "land_area" in response.json()["results"][0]


@pytest.mark.django_db
def test_filter_by_commercial_purpose(listing_factory, client):
    listing_factory(
        kind=PropertyKind.COMMERCIAL,
        commercial_purpose=CommercialPurpose.SHOP,
        status=ListingStatus.ACTIVE,
    )
    listing_factory(
        kind=PropertyKind.COMMERCIAL,
        commercial_purpose=CommercialPurpose.OFFICE,
        status=ListingStatus.ACTIVE,
    )

    response = client.get("/api/v1/listings/?commercial_purpose=shop")

    results = response.json()["results"]
    assert len(results) == 1
    assert results[0]["commercial_purpose"] == "shop"


@pytest.mark.django_db
def test_filter_options_expose_new_dictionaries(client):
    response = client.get("/api/v1/catalog/filter-options/")

    payload = response.json()
    assert {item["value"] for item in payload["plot_purposes"]} == {
        "ihs",
        "garden",
        "agricultural",
        "commercial",
    }
    assert "commercial_purposes" in payload
    assert "building_lines" in payload
```

- [ ] **Step 2: Запустить и убедиться, что падает**

Run: `cd backend && pytest tests/test_kind_fields_api.py -v -k "land_area or commercial_purpose or filter_options"`
Expected: FAIL — `KeyError: 'land_area'`, `KeyError: 'plot_purposes'`

- [ ] **Step 3: Дополнить сериализаторы**

В `ListingListSerializer.Meta.fields` после `"area"` добавить `"land_area"` — без него карточка участка не может показать площадь участка.

В `ListingDetailSerializer.Meta.fields` после `"furniture"` добавить:

```python
            "plot_purpose",
            "commercial_purpose",
            "has_separate_entrance",
            "building_line",
            "ceiling_height",
```

В `FilterOptionsSerializer` после `series`:

```python
    plot_purposes = ChoiceOptionSerializer(many=True)
    commercial_purposes = ChoiceOptionSerializer(many=True)
    building_lines = ChoiceOptionSerializer(many=True)
```

- [ ] **Step 4: Дополнить опции фильтра**

В `backend/apps/catalog/services.py` в `build_filter_options` добавить в возвращаемый словарь после `"series"`:

```python
        "plot_purposes": _choices_payload(PlotPurpose.choices),
        "commercial_purposes": _choices_payload(CommercialPurpose.choices),
        "building_lines": _choices_payload(BuildingLine.choices),
```

Импорт enums дополнить: `from apps.catalog.enums import BuildingLine, CommercialPurpose, PlotPurpose` (к существующему импорту).

- [ ] **Step 5: Добавить фильтры**

В `backend/apps/catalog/filters.py` в `ListingFilterSet` после `builder`:

```python
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
```

Если у `ListingFilterSet.Meta` есть явный список `fields`, добавить туда те же четыре имени.

- [ ] **Step 6: Добавить поля в админку**

В `backend/apps/catalog/admin.py` найти `fieldsets` или `fields` у `ListingAdmin` и добавить новые поля в секцию с характеристиками. Если списка полей нет (админка показывает все) — шаг пропускается.

- [ ] **Step 7: Запустить тесты**

Run: `cd backend && pytest tests/test_kind_fields_api.py -v`
Expected: PASS

- [ ] **Step 8: Обновить снапшот схемы и проверить контракт**

Run: `cd backend && make schema-update && pytest tests/test_openapi_contract.py -v`
Expected: PASS. Изменения аддитивные — контрактный тест не должен считать их ломающими.

- [ ] **Step 9: Линт и полный прогон**

Run: `cd backend && ruff check apps/catalog && pytest tests/ -q`
Expected: `All checks passed!` и зелёный набор тестов.

- [ ] **Step 10: Коммит**

```bash
git add backend/apps/catalog backend/tests/test_kind_fields_api.py backend/tests/snapshots/openapi.json
git commit -m "feat(catalog): новые поля в ответах API и фильтрах каталога"
```

---

### Task 5: Зеркало таблицы правил в клиенте

**Files:**
- Create: `flutter_app/lib/data/kind_fields.dart`
- Modify: `flutter_app/lib/data/listings.dart`

**Interfaces:**
- Produces: `enum ListingField`, `const kindFields`, `bool showsField(PropertyKind, ListingField)`, `Set<ListingField> fieldsForKinds(Set<PropertyKind>)`; поля `Listing.landArea`, `Listing.plotPurpose`, `Listing.commercialPurpose`, `Listing.hasSeparateEntrance`, `Listing.buildingLine`, `Listing.ceilingHeight`.

- [ ] **Step 1: Написать модуль правил**

Создать `flutter_app/lib/data/kind_fields.dart`:

```dart
// Какие поля объявления применимы к какому типу недвижимости.
//
// Зеркало серверной таблицы `backend/apps/catalog/field_rules.py`: при правке
// здесь правьте и там. Клиент держит копию, чтобы форма и фильтр решали, что
// рисовать, без похода на сервер.
import 'listings.dart';

enum ListingField {
  rooms,
  floor,
  floors,
  series,
  isSecondary,
  builder,
  interior, // площади комнат и мебель — показываются одним блоком
  landArea,
  redBook,
  plotPurpose,
  commercialPurpose,
  separateEntrance,
  buildingLine,
  ceilingHeight,
}

const Map<PropertyKind, Set<ListingField>> kindFields = {
  PropertyKind.apartment: {
    ListingField.rooms,
    ListingField.floor,
    ListingField.floors,
    ListingField.series,
    ListingField.isSecondary,
    ListingField.interior,
  },
  PropertyKind.room: {
    ListingField.floor,
    ListingField.floors,
    ListingField.series,
    ListingField.isSecondary,
    ListingField.interior,
  },
  PropertyKind.house: {
    ListingField.rooms,
    ListingField.floors,
    ListingField.isSecondary,
    ListingField.interior,
    ListingField.landArea,
    ListingField.redBook,
  },
  PropertyKind.newBuilding: {
    ListingField.rooms,
    ListingField.floor,
    ListingField.floors,
    ListingField.builder,
    ListingField.interior,
  },
  PropertyKind.plot: {
    ListingField.landArea,
    ListingField.redBook,
    ListingField.plotPurpose,
  },
  PropertyKind.commercial: {
    ListingField.floor,
    ListingField.floors,
    ListingField.commercialPurpose,
    ListingField.separateEntrance,
    ListingField.buildingLine,
    ListingField.ceilingHeight,
  },
};

bool showsField(PropertyKind kind, ListingField field) =>
    kindFields[kind]?.contains(field) ?? false;

/// Объединение полей нескольких типов — для фильтра с мультивыбором.
///
/// Пустой набор типов означает «ищем везде», поэтому показываются все поля:
/// иначе экран фильтра при первом открытии оказался бы почти пустым.
Set<ListingField> fieldsForKinds(Set<PropertyKind> kinds) {
  if (kinds.isEmpty) return ListingField.values.toSet();
  return kinds.fold<Set<ListingField>>(
    <ListingField>{},
    (acc, kind) => acc..addAll(kindFields[kind] ?? const <ListingField>{}),
  );
}

/// Подписи назначений участка — значения совпадают с `PlotPurpose` на бэкенде.
const Map<String, String> plotPurposeLabels = {
  'ihs': 'ИЖС',
  'garden': 'Садовый',
  'agricultural': 'Сельхозназначение',
  'commercial': 'Коммерческий',
};

/// Подписи назначений помещения — значения совпадают с `CommercialPurpose`.
const Map<String, String> commercialPurposeLabels = {
  'office': 'Офис',
  'shop': 'Магазин',
  'warehouse': 'Склад',
  'production': 'Производство',
  'catering': 'Общепит',
  'free': 'Свободного назначения',
};

/// Подписи линий — значения совпадают с `BuildingLine`.
const Map<String, String> buildingLineLabels = {
  'first': 'Первая линия',
  'second': 'Вторая линия',
  'inside': 'Внутри квартала',
};
```

- [ ] **Step 2: Добавить поля в модель `Listing`**

В `flutter_app/lib/data/listings.dart` в класс `Listing` добавить именованные параметры конструктора и поля:

```dart
    this.landArea,
    this.plotPurpose = '',
    this.commercialPurpose = '',
    this.hasSeparateEntrance = false,
    this.buildingLine = '',
    this.ceilingHeight,
```

```dart
  final double? landArea;
  final String plotPurpose;
  final String commercialPurpose;
  final bool hasSeparateEntrance;
  final String buildingLine;
  final double? ceilingHeight;
```

В `Listing.fromJson` разобрать их рядом с существующим разбором `area`:

```dart
      landArea: _toDouble(json['land_area']),
      plotPurpose: json['plot_purpose'] as String? ?? '',
      commercialPurpose: json['commercial_purpose'] as String? ?? '',
      hasSeparateEntrance: json['has_separate_entrance'] as bool? ?? false,
      buildingLine: json['building_line'] as String? ?? '',
      ceilingHeight: _toDouble(json['ceiling_height']),
```

Если в файле нет хелпера `_toDouble`, добавить его рядом с существующими хелперами разбора:

```dart
double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
```

- [ ] **Step 3: Проверить анализатором**

Run: `cd flutter_app && dart analyze lib/data/kind_fields.dart lib/data/listings.dart`
Expected: без ошибок (warnings уровня `info` допустимы).

- [ ] **Step 4: Коммит**

```bash
git add flutter_app/lib/data/kind_fields.dart flutter_app/lib/data/listings.dart
git commit -m "feat(app): таблица применимости полей и новые поля модели объявления"
```

---

### Task 6: Форма подачи объявления

**Files:**
- Modify: `flutter_app/lib/ui/pages/ad_form_page.dart:403-700`
- Modify: `flutter_app/lib/app/app_state.dart:951-963, 993-1011`

**Interfaces:**
- Consumes: `showsField`, `ListingField`, словари подписей из Task 5.
- Produces: черновик отправляет `plot_purpose`, `commercial_purpose`, `has_separate_entrance`, `building_line`, `ceiling_height`; поля скрытых секций сбрасываются при смене типа.

- [ ] **Step 1: Добавить поля черновика в состояние**

В `flutter_app/lib/app/app_state.dart` рядом с `draftBuilder`:

```dart
  String draftPlotPurpose = '';
  String draftCommercialPurpose = '';
  bool draftSeparateEntrance = false;
  String draftBuildingLine = '';
  String draftCeilingHeight = '';
  String draftLandArea = '';
```

- [ ] **Step 2: Сбрасывать неприменимое при смене типа**

Там же добавить метод:

```dart
  /// Смена типа объявления: значения полей, неприменимых к новому типу,
  /// забываются — иначе на сервер уедет `rooms` от предыдущего выбора.
  void setDraftKind(PropertyKind kind) {
    draftKinds
      ..clear()
      ..add(kind);

    if (!showsField(kind, ListingField.rooms)) draftRooms = 0;
    if (!showsField(kind, ListingField.floor)) draftFloor = 0;
    if (!showsField(kind, ListingField.floors)) draftFloors = 0;
    if (!showsField(kind, ListingField.builder)) draftBuilder = '';
    if (!showsField(kind, ListingField.landArea)) draftLandArea = '';
    if (!showsField(kind, ListingField.plotPurpose)) draftPlotPurpose = '';
    if (!showsField(kind, ListingField.commercialPurpose)) {
      draftCommercialPurpose = '';
      draftSeparateEntrance = false;
      draftBuildingLine = '';
      draftCeilingHeight = '';
    }
    notifyListeners();
  }
```

Импорт в `app_state.dart`: `import '../data/kind_fields.dart';`.

- [ ] **Step 3: Отправлять новые поля на сервер**

В `ad_form_page.dart` в месте сборки payload (около строки 160, где формируются `'kind'` и `'seller_kind'`) добавить:

```dart
      if (state.draftPlotPurpose.isNotEmpty) 'plot_purpose': state.draftPlotPurpose,
      if (state.draftCommercialPurpose.isNotEmpty)
        'commercial_purpose': state.draftCommercialPurpose,
      if (showsField(kindEnum, ListingField.separateEntrance))
        'has_separate_entrance': state.draftSeparateEntrance,
      if (state.draftBuildingLine.isNotEmpty) 'building_line': state.draftBuildingLine,
      if (state.draftCeilingHeight.isNotEmpty) 'ceiling_height': state.draftCeilingHeight,
      if (state.draftLandArea.isNotEmpty) 'land_area': state.draftLandArea,
```

- [ ] **Step 4: Сделать существующие секции условными**

В `build` перед списком секций получить текущий тип:

```dart
    final kind = state.draftKinds.isNotEmpty ? state.draftKinds.first : PropertyKind.apartment;
```

Секции «Количество комнат» (строка ~454), «Этаж» (~509), «Кол-во этажей в здании» (~566), «Строительная компания» (~623) обернуть по образцу:

```dart
              if (showsField(kind, ListingField.rooms)) ...[
                _buildSectionTitle('Количество комнат'),
                const SizedBox(height: 10.0),
                // ...существующее содержимое секции без изменений...
                const SizedBox(height: 24.0),
              ],
```

Чип выбора типа переключить на новый метод: `onTap: () => state.setDraftKind(kind)` вместо ручной работы с `draftKinds`.

- [ ] **Step 5: Добавить новые секции**

После секции «Кол-во этажей в здании» добавить:

```dart
              if (showsField(kind, ListingField.landArea)) ...[
                _buildSectionTitle('Площадь участка, соток'),
                const SizedBox(height: 10.0),
                _buildInputField(
                  controller: landAreaCtrl,
                  hintText: 'Например, 8',
                  keyboardType: TextInputType.number,
                  onChanged: (val) => state.setDraft(() => state.draftLandArea = val),
                ),
                const SizedBox(height: 24.0),
              ],

              if (showsField(kind, ListingField.plotPurpose)) ...[
                _buildSectionTitle('Назначение участка'),
                const SizedBox(height: 10.0),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    for (final entry in plotPurposeLabels.entries)
                      _buildChip(
                        label: entry.value,
                        selected: state.draftPlotPurpose == entry.key,
                        onTap: () => state.setDraft(() => state.draftPlotPurpose = entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 24.0),
              ],

              if (showsField(kind, ListingField.commercialPurpose)) ...[
                _buildSectionTitle('Назначение помещения'),
                const SizedBox(height: 10.0),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    for (final entry in commercialPurposeLabels.entries)
                      _buildChip(
                        label: entry.value,
                        selected: state.draftCommercialPurpose == entry.key,
                        onTap: () =>
                            state.setDraft(() => state.draftCommercialPurpose = entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 24.0),
              ],

              if (showsField(kind, ListingField.buildingLine)) ...[
                _buildSectionTitle('Линия'),
                const SizedBox(height: 10.0),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    for (final entry in buildingLineLabels.entries)
                      _buildChip(
                        label: entry.value,
                        selected: state.draftBuildingLine == entry.key,
                        onTap: () => state.setDraft(() => state.draftBuildingLine = entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 24.0),
              ],

              if (showsField(kind, ListingField.separateEntrance)) ...[
                _buildSectionTitle('Отдельный вход'),
                const SizedBox(height: 10.0),
                Wrap(
                  spacing: 8.0,
                  children: [
                    _buildChip(
                      label: 'Есть',
                      selected: state.draftSeparateEntrance,
                      onTap: () => state.setDraft(() => state.draftSeparateEntrance = true),
                    ),
                    _buildChip(
                      label: 'Нет',
                      selected: !state.draftSeparateEntrance,
                      onTap: () => state.setDraft(() => state.draftSeparateEntrance = false),
                    ),
                  ],
                ),
                const SizedBox(height: 24.0),
              ],

              if (showsField(kind, ListingField.ceilingHeight)) ...[
                _buildSectionTitle('Высота потолков, м'),
                const SizedBox(height: 10.0),
                _buildInputField(
                  controller: ceilingCtrl,
                  hintText: 'Необязательно, например 3.2',
                  keyboardType: TextInputType.number,
                  onChanged: (val) => state.setDraft(() => state.draftCeilingHeight = val),
                ),
                const SizedBox(height: 24.0),
              ],
```

Контроллеры `landAreaCtrl` и `ceilingCtrl` завести рядом с существующими `roomsCtrl` / `areaCtrl` и освободить в `dispose`.

- [ ] **Step 6: Проверить анализатором**

Run: `cd flutter_app && dart analyze lib/ui/pages/ad_form_page.dart lib/app/app_state.dart`
Expected: без ошибок.

- [ ] **Step 7: Ручная проверка**

Открыть форму, пройти все шесть типов подряд. Ожидается: у «Участка» нет секций комнат, этажа, этажности, серии, застройщика, но есть площадь участка и назначение; у «Коммерции» нет комнат и серии, но есть назначение помещения, линия, отдельный вход, высота потолков; у «Комнаты» нет секции комнат.

- [ ] **Step 8: Коммит**

```bash
git add flutter_app/lib/ui/pages/ad_form_page.dart flutter_app/lib/app/app_state.dart
git commit -m "feat(app): секции формы объявления зависят от типа недвижимости"
```

---

### Task 7: Карточка, детальная страница и превью

**Files:**
- Modify: `flutter_app/lib/ui/object_card.dart:178-186`
- Modify: `flutter_app/lib/ui/pages/listing_page.dart:648-651, 934-959`
- Modify: `flutter_app/lib/ui/pages/ad_preview_page.dart:406, 422`

**Interfaces:**
- Consumes: `showsField`, `ListingField`, словари подписей из Task 5; `Listing.landArea` и новые поля.

- [ ] **Step 1: Характеристики в карточке**

В `flutter_app/lib/ui/object_card.dart` заменить блок на строках 178-186:

```dart
                        if (showsField(listing.kind, ListingField.rooms) &&
                            listing.rooms > 0) ...[
                          _spec7(listing.roomsLabel),
                          _dot7(),
                        ],
                        if (showsField(listing.kind, ListingField.landArea) &&
                            listing.landArea != null) ...[
                          _spec7('${listing.landArea!.toStringAsFixed(0)} сот.'),
                          _dot7(),
                        ],
                        if (showsField(listing.kind, ListingField.floor) &&
                            listing.floor > 0) ...[
                          _spec7(listing.floorLong.isNotEmpty
                              ? listing.floorLong
                              : '${listing.floor} этаж'),
                          _dot7(),
                        ],
```

Точную форму разделителей (`_dot7()` и порядок) взять из текущего кода — здесь показана только логика условий.

- [ ] **Step 2: Детальная страница**

В `flutter_app/lib/ui/pages/listing_page.dart` строку 651 заменить: вместо

```dart
                  _buildInfoRow('Этаж', '${listing.floor} из ${listing.floors > 0 ? listing.floors : 12}', isPlain: true),
```

написать

```dart
                  // Фолбэка «из 12» здесь быть не должно: у участка этажей нет
                  // вообще, а у дома их столько, сколько указал владелец.
                  if (showsField(listing.kind, ListingField.floor) && listing.floors > 0)
                    _buildInfoRow('Этаж', '${listing.floor} из ${listing.floors}', isPlain: true),
                  if (showsField(listing.kind, ListingField.landArea) &&
                      listing.landArea != null)
                    _buildInfoRow(
                      'Площадь участка',
                      '${listing.landArea!.toStringAsFixed(0)} соток',
                      isPlain: true,
                    ),
                  if (listing.plotPurpose.isNotEmpty)
                    _buildInfoRow(
                      'Назначение',
                      plotPurposeLabels[listing.plotPurpose] ?? listing.plotPurpose,
                      isPlain: true,
                    ),
                  if (listing.commercialPurpose.isNotEmpty)
                    _buildInfoRow(
                      'Назначение',
                      commercialPurposeLabels[listing.commercialPurpose] ??
                          listing.commercialPurpose,
                      isPlain: true,
                    ),
                  if (listing.buildingLine.isNotEmpty)
                    _buildInfoRow(
                      'Линия',
                      buildingLineLabels[listing.buildingLine] ?? listing.buildingLine,
                      isPlain: true,
                    ),
                  if (showsField(listing.kind, ListingField.separateEntrance))
                    _buildInfoRow(
                      'Отдельный вход',
                      listing.hasSeparateEntrance ? 'Есть' : 'Нет',
                      isPlain: true,
                    ),
                  if (listing.ceilingHeight != null)
                    _buildInfoRow(
                      'Высота потолков',
                      '${listing.ceilingHeight} м',
                      isPlain: true,
                    ),
```

В строках 934-939 заменить частный случай `!listing.isPlot` на `showsField(listing.kind, ListingField.rooms)` и `showsField(listing.kind, ListingField.floor)` соответственно — правило должно быть одно на всё приложение.

- [ ] **Step 3: Превью объявления**

В `flutter_app/lib/ui/pages/ad_preview_page.dart` строки 406 и 422 обернуть проверками:

```dart
                    if (showsField(item.kind, ListingField.rooms))
                      // ...существующий виджет с '${item.rooms}-комн.'
                    if (showsField(item.kind, ListingField.floor) && item.floors > 0)
                      // ...существующий виджет с '${item.floor}/${item.floors} эт.'
```

Точную структуру виджетов сохранить как есть — меняется только условие показа.

- [ ] **Step 4: Проверить анализатором**

Run: `cd flutter_app && dart analyze lib/ui/object_card.dart lib/ui/pages/listing_page.dart lib/ui/pages/ad_preview_page.dart`
Expected: без ошибок.

- [ ] **Step 5: Ручная проверка**

Открыть карточку участка и карточку коммерции. Ожидается: у участка нет «0 комнат» и «этаж из 12», есть площадь участка и назначение; у коммерции есть назначение, линия и отдельный вход, нет комнат.

- [ ] **Step 6: Коммит**

```bash
git add flutter_app/lib/ui/object_card.dart flutter_app/lib/ui/pages/listing_page.dart flutter_app/lib/ui/pages/ad_preview_page.dart
git commit -m "feat(app): характеристики объявления показываются по типу недвижимости"
```

---

### Task 8: Пересборка экрана фильтра

**Files:**
- Modify: `flutter_app/lib/ui/pages/filter_page.dart` (переписывается целиком)
- Modify: `flutter_app/lib/app/app_state.dart` (состояние новых фильтров)

**Interfaces:**
- Consumes: `fieldsForKinds`, `ListingField`, словари подписей из Task 5.
- Produces: `AppState.plotPurposes`, `AppState.commercialPurposes`, `AppState.buildingLines` (`Set<String>`) и методы `togglePlotPurpose`, `toggleCommercialPurpose`, `toggleBuildingLine`; query-параметры уходят в `/listings/`.

- [ ] **Step 1: Состояние новых фильтров**

В `flutter_app/lib/app/app_state.dart` рядом с `_series`:

```dart
  final Set<String> _plotPurposes = {};
  final Set<String> _commercialPurposes = {};
  final Set<String> _buildingLines = {};
```

Геттеры и переключатели по образцу существующего `toggleSeries`:

```dart
  Set<String> get plotPurposes => Set.unmodifiable(_plotPurposes);
  Set<String> get commercialPurposes => Set.unmodifiable(_commercialPurposes);
  Set<String> get buildingLines => Set.unmodifiable(_buildingLines);

  void togglePlotPurpose(String value) {
    _plotPurposes.contains(value) ? _plotPurposes.remove(value) : _plotPurposes.add(value);
    notifyListeners();
  }

  void toggleCommercialPurpose(String value) {
    _commercialPurposes.contains(value)
        ? _commercialPurposes.remove(value)
        : _commercialPurposes.add(value);
    notifyListeners();
  }

  void toggleBuildingLine(String value) {
    _buildingLines.contains(value) ? _buildingLines.remove(value) : _buildingLines.add(value);
    notifyListeners();
  }
```

В методе сборки query-параметров (около строки 583, где формируется `params['seller_kind']`) добавить:

```dart
    if (_plotPurposes.isNotEmpty) params['plot_purpose'] = _plotPurposes.join(',');
    if (_commercialPurposes.isNotEmpty) {
      params['commercial_purpose'] = _commercialPurposes.join(',');
    }
    if (_buildingLines.isNotEmpty) params['building_line'] = _buildingLines.join(',');
```

- [ ] **Step 2: Переписать экран фильтра**

`flutter_app/lib/ui/pages/filter_page.dart` переписывается как `Scaffold` с `ListView` секций. Требования к результату:

- те же виджеты `FigChip`, `FigChipInput`, `FigToggle`, `FigInputBox` из `ui/fig_controls.dart` — чипы, шрифты, цвета и высоты не меняются;
- заголовок «Фильтр» и кнопка «назад» сверху, кнопка «Показать результаты» закреплена снизу;
- секции в прежнем порядке: Тип недвижимости → Признаки (Вторичка, 103 серия) → Комнаты → Квадратура → Цена → параметры участка → параметры коммерции → Продавец;
- каждая секция, кроме «Тип недвижимости», «Квадратура», «Цена» и «Продавец», показывается по `fieldsForKinds(state.kinds).contains(...)`;
- чипы типов строятся из `PropertyKind.values` — это заодно чинит нынешнюю ошибку кадра, где чип «Квартиры» переключал `PropertyKind.room` (`_kindChips` в старом файле);
- горизонтальный скролл диапазонов площади сохраняется как сейчас.

Скелет:

```dart
    final visible = fieldsForKinds(state.kinds);

    return Scaffold(
      backgroundColor: const Color(0xfffefefe),
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(25, 8, 25, 16),
                children: [
                  _sectionTitle('Тип недвижимости'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final kind in PropertyKind.values)
                        FigChip(
                          label: kind.label,
                          selected: state.kinds.contains(kind),
                          onTap: () => state.toggleKind(kind),
                        ),
                    ],
                  ),
                  if (visible.contains(ListingField.isSecondary) ||
                      visible.contains(ListingField.series)) ...[
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (visible.contains(ListingField.isSecondary))
                          FigChip(
                            label: 'Вторичка',
                            selected: state.secondaryOnly,
                            onTap: () => state.setSecondaryOnly(!state.secondaryOnly),
                          ),
                        if (visible.contains(ListingField.series))
                          FigChip(
                            label: '103 серия',
                            selected: state.series103,
                            onTap: () => state.setSeries103(!state.series103),
                          ),
                      ],
                    ),
                  ],
                  if (visible.contains(ListingField.rooms)) ...[
                    const SizedBox(height: 20),
                    _sectionTitle('Количество комнат'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var count = 1; count <= 4; count++)
                          FigChip(
                            label: '$count ком.',
                            selected: state.rooms.contains(count),
                            onTap: () => state.toggleRooms(count),
                          ),
                      ],
                    ),
                  ],
                  // ...квадратура, цена — как сейчас, без условий...
                  if (visible.contains(ListingField.plotPurpose)) ...[
                    const SizedBox(height: 20),
                    _sectionTitle('Назначение участка'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in plotPurposeLabels.entries)
                          FigChip(
                            label: entry.value,
                            selected: state.plotPurposes.contains(entry.key),
                            onTap: () => state.togglePlotPurpose(entry.key),
                          ),
                      ],
                    ),
                  ],
                  if (visible.contains(ListingField.commercialPurpose)) ...[
                    const SizedBox(height: 20),
                    _sectionTitle('Назначение помещения'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in commercialPurposeLabels.entries)
                          FigChip(
                            label: entry.value,
                            selected: state.commercialPurposes.contains(entry.key),
                            onTap: () => state.toggleCommercialPurpose(entry.key),
                          ),
                      ],
                    ),
                  ],
                  if (visible.contains(ListingField.buildingLine)) ...[
                    const SizedBox(height: 20),
                    _sectionTitle('Линия'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in buildingLineLabels.entries)
                          FigChip(
                            label: entry.value,
                            selected: state.buildingLines.contains(entry.key),
                            onTap: () => state.toggleBuildingLine(entry.key),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  _sectionTitle('Продавец'),
                  for (final seller in SellerKind.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(seller.label),
                          FigToggle(
                            value: state.sellers.contains(seller),
                            onChanged: (_) => state.toggleSeller(seller),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _showResultsButton(context, state),
          ],
        ),
      ),
    );
```

Секции «Квадратура» и «Цена» переносятся из текущего файла как есть — меняются только координаты на позицию в списке.

- [ ] **Step 3: Проверить анализатором**

Run: `cd flutter_app && dart analyze lib/ui/pages/filter_page.dart lib/app/app_state.dart`
Expected: без ошибок.

- [ ] **Step 4: Ручная проверка**

Открыть фильтр. Ожидается: без выбранных типов видны все секции; при выборе «Участки» исчезают «Комнаты», «Вторичка» и «103 серия», появляется «Назначение участка»; при выборе «Коммерция» появляются «Назначение помещения» и «Линия»; экран прокручивается; кнопка «Показать результаты» остаётся на месте; выбранные значения уходят в запрос (проверить в логах бэкенда параметр `commercial_purpose`).

- [ ] **Step 5: Коммит**

```bash
git add flutter_app/lib/ui/pages/filter_page.dart flutter_app/lib/app/app_state.dart
git commit -m "feat(app): экран фильтра пересобран секциями и учитывает тип недвижимости"
```

---

### Task 9: Финальная проверка

**Files:**
- Modify: `CLAUDE.md` (при необходимости)

- [ ] **Step 1: Полный прогон бэкенда**

Run: `cd backend && make lint && make test`
Expected: линт чист по изменённым файлам, тесты зелёные. Предсуществующие ошибки `ruff` в файлах, которых задача не касалась, не чиним — но и не увеличиваем их число.

- [ ] **Step 2: Полный анализ клиента**

Run: `cd flutter_app && dart analyze lib`
Expected: ни одной строки уровня `error`.

- [ ] **Step 3: Проверить, что таблицы не разъехались**

Сверить глазами `backend/apps/catalog/field_rules.py` и `flutter_app/lib/data/kind_fields.dart`: набор полей для каждого из шести типов должен совпадать. Расхождение здесь — самый вероятный источник будущих багов.

- [ ] **Step 4: Коммит, если были правки**

```bash
git add -A
git commit -m "chore: финальная проверка полей по типу недвижимости"
```

## Самопроверка плана

**Покрытие спеки:** пять новых полей — Task 1; таблица правил — Task 2; три точки применения (сериализатор, публикация, фильтры) — Task 3 и 4; контракт API и `filter-options` — Task 4; миграция без чистки данных — Task 1; общий модуль клиента — Task 5; форма — Task 6; карточка, детальная, превью — Task 7; пересборка фильтра — Task 8; тесты — в каждой задаче плюс Task 9.

**Отклонение от спеки, найденное при планировании:** `land_area` не отдавалась в `ListingListSerializer`, поэтому карточка участка не смогла бы показать площадь участка. Добавление этого поля включено в Task 4, Step 3.

**Согласованность имён:** `showsField` / `fieldsForKinds` / `ListingField` объявлены в Task 5 и используются в Task 6, 7, 8 в том же виде; `strip_inapplicable` / `REQUIRED_BY_KIND` объявлены в Task 2 и используются в Task 3; `setDraftKind` объявлен в Task 6, Step 2 и используется там же в Step 4.
