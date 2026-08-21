"""Справочники: город и застройщик, район переезжает на FK города.

Разбито на три миграции: схема (эта) → перенос данных (0004) → финализация (0005).
Иначе существующие районы остались бы без города.
"""

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0002_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="City",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True, primary_key=True, serialize=False, verbose_name="ID"
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True, db_index=True, verbose_name="Создано")),
                ("updated_at", models.DateTimeField(auto_now=True, verbose_name="Обновлено")),
                ("is_active", models.BooleanField(default=True, verbose_name="Активен")),
                ("order", models.PositiveSmallIntegerField(db_index=True, default=0, verbose_name="Порядок")),
                ("name", models.CharField(max_length=100, verbose_name="Название")),
                ("slug", models.SlugField(max_length=120, unique=True, verbose_name="Слаг")),
                (
                    "is_default",
                    models.BooleanField(
                        default=False,
                        help_text="Подставляется клиенту, если город не выбран.",
                        verbose_name="Город по умолчанию",
                    ),
                ),
            ],
            options={
                "verbose_name": "Город",
                "verbose_name_plural": "Города",
                "ordering": ["order", "name"],
            },
        ),
        migrations.CreateModel(
            name="Builder",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True, primary_key=True, serialize=False, verbose_name="ID"
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True, db_index=True, verbose_name="Создано")),
                ("updated_at", models.DateTimeField(auto_now=True, verbose_name="Обновлено")),
                ("is_active", models.BooleanField(default=True, verbose_name="Активен")),
                ("order", models.PositiveSmallIntegerField(db_index=True, default=0, verbose_name="Порядок")),
                ("name", models.CharField(max_length=150, verbose_name="Название")),
                ("slug", models.SlugField(max_length=160, unique=True, verbose_name="Слаг")),
                (
                    "logo",
                    models.ImageField(
                        blank=True, null=True, upload_to="builders/%Y/%m/", verbose_name="Логотип"
                    ),
                ),
                ("description", models.TextField(blank=True, verbose_name="Описание")),
            ],
            options={
                "verbose_name": "Застройщик",
                "verbose_name_plural": "Застройщики",
                "ordering": ["order", "name"],
            },
        ),
        migrations.AddField(
            model_name="district",
            name="is_active",
            field=models.BooleanField(default=True, verbose_name="Активен"),
        ),
        migrations.AddField(
            model_name="district",
            name="order",
            field=models.PositiveSmallIntegerField(db_index=True, default=0, verbose_name="Порядок"),
        ),
        migrations.AddField(
            model_name="houseseries",
            name="is_active",
            field=models.BooleanField(default=True, verbose_name="Активен"),
        ),
        migrations.AddField(
            model_name="houseseries",
            name="order",
            field=models.PositiveSmallIntegerField(db_index=True, default=0, verbose_name="Порядок"),
        ),
        migrations.RemoveConstraint(
            model_name="district",
            name="district_unique_in_city",
        ),
        migrations.RenameField(
            model_name="district",
            old_name="city",
            new_name="city_legacy",
        ),
        migrations.AddField(
            model_name="district",
            name="city",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="districts",
                to="catalog.city",
                verbose_name="Город",
            ),
        ),
    ]
