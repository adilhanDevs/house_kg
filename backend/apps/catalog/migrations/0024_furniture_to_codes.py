"""Перевод `furniture` со свободного текста на коды.

Поле хранило русские подписи («Полностью»), а клиент присылал коды `full` /
`partial` / `none` — на детальной странице у части объявлений в графе «Мебель»
стояло `full`. Здесь старые значения приводятся к кодам; всё, что распознать
не удалось, обнуляется: показать «не указано» честнее, чем оставить строку,
которую интерфейс не умеет отобразить.
"""

from django.db import migrations

# Приводим к нижнему регистру и сравниваем по началу строки: в базе
# встречаются и «Полностью», и «Полностью меблирована».
TEXT_TO_CODE = {
    "полностью": "full",
    "частично": "partial",
    "без мебели": "none",
    "нет": "none",
}


def to_codes(apps, schema_editor):  # noqa: ANN001, ANN201
    Listing = apps.get_model("catalog", "Listing")
    valid = {"full", "partial", "none"}

    for listing in Listing.objects.exclude(furniture="").iterator():
        value = (listing.furniture or "").strip()
        if value in valid:
            continue

        lowered = value.lower()
        code = ""
        for prefix, mapped in TEXT_TO_CODE.items():
            if lowered.startswith(prefix):
                code = mapped
                break

        listing.furniture = code
        listing.save(update_fields=["furniture"])


def to_text(apps, schema_editor):  # noqa: ANN001, ANN201
    """Обратная миграция: коды обратно в подписи."""
    Listing = apps.get_model("catalog", "Listing")
    code_to_text = {
        "full": "Полностью",
        "partial": "Частично",
        "none": "Без мебели",
    }

    for listing in Listing.objects.exclude(furniture="").iterator():
        listing.furniture = code_to_text.get(listing.furniture, "")
        listing.save(update_fields=["furniture"])


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0023_listing_condition_and_furniture"),
    ]

    operations = [
        migrations.RunPython(to_codes, to_text),
    ]
