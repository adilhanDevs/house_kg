"""Новые связи объявления: город и застройщик — пока nullable.

Заполняются в 0009, обязательными становятся в 0010.
"""

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0006_pg_trgm_and_listing_renames"),
    ]

    operations = [
        migrations.AddField(
            model_name="listing",
            name="city",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name="listings",
                to="catalog.city",
                verbose_name="Город",
            ),
        ),
        migrations.AddField(
            model_name="listing",
            name="builder",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="listings",
                to="catalog.builder",
                verbose_name="Застройщик",
            ),
        ),
    ]
