"""Переносит название города из строки в справочник."""

from django.db import migrations
from django.utils.text import slugify

DEFAULT_CITY = "Бишкек"
DEFAULT_SLUG = "bishkek"

# Города, для которых нужен латинский слаг: slugify кириллицу выбрасывает.
CITY_SLUGS = {
    "Бишкек": "bishkek",
    "Ош": "osh",
    "Джалал-Абад": "jalal-abad",
    "Каракол": "karakol",
    "Токмок": "tokmok",
}


def forwards(apps, schema_editor):
    City = apps.get_model("catalog", "City")
    District = apps.get_model("catalog", "District")

    names = set(District.objects.values_list("city_legacy", flat=True))
    names.discard("")
    names.discard(None)
    names.add(DEFAULT_CITY)

    cities = {}
    for index, name in enumerate(sorted(names)):
        slug = CITY_SLUGS.get(name) or slugify(name) or f"city-{index + 1}"
        city, _ = City.objects.get_or_create(
            slug=slug,
            defaults={"name": name, "is_default": name == DEFAULT_CITY, "order": index},
        )
        cities[name] = city

    for name, city in cities.items():
        District.objects.filter(city_legacy=name).update(city=city)

    District.objects.filter(city__isnull=True).update(city=cities[DEFAULT_CITY])


def backwards(apps, schema_editor):
    District = apps.get_model("catalog", "District")
    for district in District.objects.select_related("city"):
        district.city_legacy = district.city.name if district.city_id else DEFAULT_CITY
        district.save(update_fields=["city_legacy"])


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0003_city_builder_and_district_city_fk"),
    ]

    operations = [
        migrations.RunPython(forwards, backwards),
    ]
