"""Ключи, которые шлёт клиент, должны существовать в API.

DRF молча игнорирует неизвестные ключи: запрос возвращает 200, а данные
исчезают. Именно так форма редактирования годами отправляла `floors_total`
вместо `floors` — этажность не сохранялась, и никто этого не видел.

Тест разбирает `flutter_app/lib/data/listing_payload.dart` — единственное
место, где клиент собирает тело запроса, — и сверяет имена ключей со списком
полей `ListingUpdateSerializer`.
"""

import re
from pathlib import Path

import pytest

from apps.catalog.serializers import ListingUpdateSerializer

PAYLOAD_DART = (
    Path(__file__).resolve().parents[2] / "flutter_app" / "lib" / "data" / "listing_payload.dart"
)

# Ключи площадей комнат объявлены отдельной константой-словарём.
KEY_RE = re.compile(r"""(?:put|putIf)\([^)]*?['"]([a-z_0-9]+)['"]""")
DATA_KEY_RE = re.compile(r"""data\[['"]([a-z_0-9]+)['"]\]\s*=""")
ROOM_AREA_RE = re.compile(r"""^\s*'([a-z_0-9]+)':\s*'[^']+',\s*$""", re.M)
# Начальный литерал карты: <String, dynamic>{'kind': ...}
LITERAL_KEY_RE = re.compile(r"""<String, dynamic>\{['"]([a-z_0-9]+)['"]:""")


def _client_keys() -> set[str]:
    source = PAYLOAD_DART.read_text(encoding="utf-8")

    keys = (
        set(KEY_RE.findall(source))
        | set(DATA_KEY_RE.findall(source))
        | set(LITERAL_KEY_RE.findall(source))
    )

    # roomAreaLabels — ключи площадей уходят в payload как есть.
    block = source[source.index("const Map<String, String> roomAreaLabels") :]
    block = block[: block.index("};")]
    keys |= set(ROOM_AREA_RE.findall(block))

    return keys


@pytest.mark.skipif(not PAYLOAD_DART.exists(), reason="Flutter-клиент рядом не лежит")
def test_every_client_key_exists_in_api():
    api_fields = set(ListingUpdateSerializer().fields)
    unknown = sorted(_client_keys() - api_fields)

    assert not unknown, (
        "Клиент отправляет поля, которых нет в ListingUpdateSerializer — "
        f"сервер их молча отбросит: {unknown}"
    )


@pytest.mark.skipif(not PAYLOAD_DART.exists(), reason="Flutter-клиент рядом не лежит")
def test_payload_module_covers_the_fields_we_expect():
    """Защита от обратной ошибки: ключи перестали собираться регуляркой."""
    keys = _client_keys()

    assert {"kind", "district", "price", "area", "floors", "landmarks"} <= keys
    assert "floors_total" not in keys
