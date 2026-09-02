"""Пересобирает снапшот OpenAPI. Запускается из `make schema-update`."""

import json
import os
from pathlib import Path

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()

from drf_spectacular.generators import SchemaGenerator  # noqa: E402

SNAPSHOT = Path(__file__).resolve().parent.parent / "tests" / "snapshots" / "openapi.json"


def main() -> None:
    schema = SchemaGenerator().get_schema(request=None, public=True)
    SNAPSHOT.parent.mkdir(parents=True, exist_ok=True)
    SNAPSHOT.write_text(
        json.dumps(schema, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"Снапшот обновлён: {SNAPSHOT}")
    print(f"  путей: {len(schema['paths'])}, схем: {len(schema['components']['schemas'])}")


if __name__ == "__main__":
    main()
