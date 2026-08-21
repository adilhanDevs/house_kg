"""Город становится обязательным, текстовое поле застройщика уходит."""

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0009_move_listing_city_and_builder"),
    ]

    operations = [
        migrations.AlterField(
            model_name="listing",
            name="city",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.PROTECT,
                related_name="listings",
                to="catalog.city",
                verbose_name="Город",
            ),
        ),
        migrations.RemoveField(
            model_name="listing",
            name="builder_legacy",
        ),
    ]
