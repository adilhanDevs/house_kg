"""Площади помещений переезжают из семи колонок в ListingRoom.

Фиксированный набор «гостиная / холл / кухня / спальная / спальная 2 / балкон /
сан.узел» не описывает реальные квартиры: у одной нет холла, у другой две
спальни и гардеробная. Набор помещений должен собирать владелец, а модель
ListingRoom для этого уже существовала — она просто не была доступна на запись.

Перенос идёт до удаления колонок: заполненные значения становятся строками
ListingRoom с тем же порядком, что был в форме.
"""

from django.db import migrations

# Порядок тот же, в каком поля шли в старой форме.
COLUMNS = [
    ("living_room_area", "Гостинная"),
    ("hall_area", "Холл"),
    ("kitchen_area", "Кухня"),
    ("bedroom_area", "Спальная"),
    ("bedroom_2_area", "Спальная 2"),
    ("balcony_area", "Балкон"),
    ("bathroom_area", "Сан.узел"),
]


def to_rooms(apps, schema_editor):  # noqa: ANN001, ANN201
    Listing = apps.get_model("catalog", "Listing")
    ListingRoom = apps.get_model("catalog", "ListingRoom")

    created = []
    for listing in Listing.objects.iterator():
        # Уже заполненная экспликация приоритетнее: её вводили руками.
        existing = {
            name.strip().lower()
            for name in listing.rooms_data.values_list("name", flat=True)
        }

        order = listing.rooms_data.count()
        for column, title in COLUMNS:
            value = getattr(listing, column, None)
            if value is None or title.lower() in existing:
                continue
            created.append(
                ListingRoom(listing=listing, name=title, area=value, order=order)
            )
            order += 1

    ListingRoom.objects.bulk_create(created, batch_size=500)


def to_columns(apps, schema_editor):  # noqa: ANN001, ANN201
    """Обратная миграция: известные названия возвращаются в колонки."""
    Listing = apps.get_model("catalog", "Listing")
    by_title = {title.lower(): column for column, title in COLUMNS}

    for listing in Listing.objects.iterator():
        changed = []
        for room in listing.rooms_data.all():
            column = by_title.get(room.name.strip().lower())
            if column:
                setattr(listing, column, room.area)
                changed.append(column)
        if changed:
            listing.save(update_fields=changed)


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0024_furniture_to_codes"),
    ]

    operations = [
        migrations.RunPython(to_rooms, to_columns),
        migrations.RemoveField(model_name="listing", name="living_room_area"),
        migrations.RemoveField(model_name="listing", name="hall_area"),
        migrations.RemoveField(model_name="listing", name="kitchen_area"),
        migrations.RemoveField(model_name="listing", name="bedroom_area"),
        migrations.RemoveField(model_name="listing", name="bedroom_2_area"),
        migrations.RemoveField(model_name="listing", name="balcony_area"),
        migrations.RemoveField(model_name="listing", name="bathroom_area"),
    ]
