"""Контракт OpenAPI: схема генерируется чисто и не ломает клиентов.

Снапшот `tests/snapshots/openapi.json` — это обещание, данное мобильному
приложению. Ломающими считаются три вещи:

* пропал эндпоинт — старая сборка получит 404;
* пропало поле ответа — клиент упадёт на разборе;
* тип поля ужесточился (стал не-nullable, сменил тип, потерял вариант enum) —
  значение, которое клиент раньше присылал или получал, перестанет проходить.

Добавлять эндпоинты, поля и варианты enum можно свободно: это совместимо.
Снапшот обновляется осознанно — `make schema-update`.
"""

import json
import logging
from pathlib import Path
from typing import Any

import pytest
from drf_spectacular.generators import SchemaGenerator

SNAPSHOT = Path(__file__).parent / "snapshots" / "openapi.json"


def generate_schema() -> dict[str, Any]:
    return SchemaGenerator().get_schema(request=None, public=True)


@pytest.fixture(scope="module")
def schema() -> dict[str, Any]:
    return generate_schema()


@pytest.fixture(scope="module")
def snapshot() -> dict[str, Any]:
    if not SNAPSHOT.exists():  # pragma: no cover - снапшот в репозитории
        pytest.skip("Снапшот схемы отсутствует: создайте его через `make schema-update`")
    return json.loads(SNAPSHOT.read_text(encoding="utf-8"))


# -- генерация ---------------------------------------------------------------


def test_schema_generates_without_warnings(caplog: pytest.LogCaptureFixture):
    """drf-spectacular не должен ругаться: его предупреждения — это дыры в схеме."""
    with caplog.at_level(logging.WARNING, logger="drf_spectacular"):
        generate_schema()

    problems = [record.getMessage() for record in caplog.records]
    assert not problems, "drf-spectacular предупреждает:\n" + "\n".join(problems)


def test_schema_has_expected_shape(schema: dict[str, Any]):
    assert schema["openapi"].startswith("3.")
    assert schema["paths"], "в схеме нет ни одного пути"
    # Все пути живут под /api/v1/ — это соглашение §1.5 ТЗ.
    stray = [path for path in schema["paths"] if not path.startswith("/api/v1/")]
    assert not stray, f"пути вне /api/v1/: {stray}"


def test_every_operation_has_an_operation_id(schema: dict[str, Any]):
    """operationId — имя метода в сгенерированном клиенте."""
    missing = [
        f"{method.upper()} {path}"
        for path, methods in schema["paths"].items()
        for method, operation in methods.items()
        if method in {"get", "post", "patch", "put", "delete"} and not operation.get("operationId")
    ]
    assert not missing, f"без operationId: {missing}"


def test_operation_ids_are_unique(schema: dict[str, Any]):
    seen: dict[str, str] = {}
    duplicates = []
    for path, methods in schema["paths"].items():
        for method, operation in methods.items():
            if method not in {"get", "post", "patch", "put", "delete"}:
                continue
            name = operation.get("operationId")
            if name in seen:
                duplicates.append(f"{name}: {seen[name]} и {method.upper()} {path}")
            seen[name] = f"{method.upper()} {path}"

    assert not duplicates, f"повторяющиеся operationId: {duplicates}"


# -- обратная совместимость --------------------------------------------------

HTTP_METHODS = {"get", "post", "patch", "put", "delete"}


def operations(document: dict[str, Any]) -> set[str]:
    return {
        f"{method.upper()} {path}"
        for path, methods in document.get("paths", {}).items()
        for method in methods
        if method in HTTP_METHODS
    }


def response_properties(document: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Поля успешных ответов: {"ИмяСхемы.поле": описание типа}."""
    result: dict[str, dict[str, Any]] = {}
    schemas = document.get("components", {}).get("schemas", {})

    for name, definition in schemas.items():
        for field, spec in (definition.get("properties") or {}).items():
            result[f"{name}.{field}"] = spec

    return result


def test_no_endpoint_disappeared(schema: dict[str, Any], snapshot: dict[str, Any]):
    """Пропавший эндпоинт — 404 у всех, кто не обновил приложение."""
    removed = sorted(operations(snapshot) - operations(schema))

    assert not removed, (
        "Из схемы пропали эндпоинты:\n  "
        + "\n  ".join(removed)
        + "\nЕсли это осознанно — обновите снапшот: make schema-update"
    )


def test_no_response_field_disappeared(schema: dict[str, Any], snapshot: dict[str, Any]):
    """Пропавшее поле — падение клиента на разборе ответа."""
    current = response_properties(schema)
    previous = response_properties(snapshot)

    # Схемы, которых больше нет целиком, разбирает предыдущий тест.
    live_schemas = set(schema.get("components", {}).get("schemas", {}))
    removed = sorted(
        key for key in previous if key not in current and key.split(".", 1)[0] in live_schemas
    )

    assert not removed, (
        "Из ответов пропали поля:\n  "
        + "\n  ".join(removed)
        + "\nЕсли это осознанно — обновите снапшот: make schema-update"
    )


def _narrowed(before: dict[str, Any], after: dict[str, Any]) -> str | None:
    """Что именно ужесточилось в описании поля. None — совместимо."""
    if before.get("type") and after.get("type") and before["type"] != after["type"]:
        return f"тип {before['type']} -> {after['type']}"

    if before.get("nullable") and not after.get("nullable"):
        return "поле перестало быть nullable"

    if before.get("format") and after.get("format") and before["format"] != after["format"]:
        return f"формат {before['format']} -> {after['format']}"

    lost = set(before.get("enum") or []) - set(after.get("enum") or [])
    if lost:
        return f"из enum пропали значения: {sorted(lost)}"

    return None


def test_no_response_field_type_narrowed(schema: dict[str, Any], snapshot: dict[str, Any]):
    """Ужесточение типа ломает уже отправленные сборки так же, как удаление."""
    current = response_properties(schema)
    previous = response_properties(snapshot)

    problems = []
    for key, before in previous.items():
        after = current.get(key)
        if after is None:
            continue
        reason = _narrowed(before, after)
        if reason:
            problems.append(f"{key}: {reason}")

    assert not problems, (
        "Типы полей ужесточились:\n  "
        + "\n  ".join(sorted(problems))
        + "\nЕсли это осознанно — обновите снапшот: make schema-update"
    )


def test_no_required_request_field_added(schema: dict[str, Any], snapshot: dict[str, Any]):
    """Новое обязательное поле запроса ломает старых клиентов так же жёстко."""
    current = schema.get("components", {}).get("schemas", {})
    previous = snapshot.get("components", {}).get("schemas", {})

    problems = []
    for name, before in previous.items():
        after = current.get(name)
        if after is None:
            continue
        added = set(after.get("required") or []) - set(before.get("required") or [])
        if added:
            problems.append(f"{name}: стали обязательными {sorted(added)}")

    assert not problems, (
        "Появились новые обязательные поля:\n  "
        + "\n  ".join(sorted(problems))
        + "\nЕсли это осознанно — обновите снапшот: make schema-update"
    )
