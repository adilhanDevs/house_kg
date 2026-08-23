"""UUID для путей в хранилище, статус обработки и варианты размеров медиа.

UUID добавляются в три шага (AddField без unique -> заполнение -> AlterField):
одно значение по умолчанию на все существующие строки нарушило бы уникальность.
"""

import uuid

import apps.catalog.media
from django.db import migrations, models


def fill_uuids(apps_registry, schema_editor):
    """Проставляет уникальные UUID существующим строкам."""
    for model_name in ("Listing", "ListingMedia"):
        model = apps_registry.get_model("catalog", model_name)
        rows = list(model.objects.all().only("pk"))
        for row in rows:
            row.uuid = uuid.uuid4()
        model.objects.bulk_update(rows, ["uuid"], batch_size=500)


def mark_existing_media_ready(apps_registry, schema_editor):
    """Ранее загруженные файлы уже показываются клиенту — они `ready`."""
    model = apps_registry.get_model("catalog", "ListingMedia")
    model.objects.update(status="ready")


def noop(apps_registry, schema_editor):
    """Откат: значения остаются, схему возвращает AlterField."""


class Migration(migrations.Migration):

    dependencies = [
        ("catalog", "0013_listing_lifecycle"),
    ]

    operations = [
        migrations.AddField(
            model_name="listing",
            name="uuid",
            field=models.UUIDField(default=uuid.uuid4, editable=False, verbose_name="UUID"),
        ),
        migrations.AddField(
            model_name="listingmedia",
            name="phash",
            field=models.CharField(
                blank=True,
                db_index=True,
                max_length=64,
                verbose_name="Перцептивный хеш",
            ),
        ),
        migrations.AddField(
            model_name="listingmedia",
            name="processing_error",
            field=models.CharField(
                blank=True, max_length=255, verbose_name="Ошибка обработки"
            ),
        ),
        migrations.AddField(
            model_name="listingmedia",
            name="status",
            field=models.CharField(
                choices=[
                    ("uploading", "Загружается"),
                    ("processing", "Обрабатывается"),
                    ("ready", "Готово"),
                    ("failed", "Ошибка обработки"),
                ],
                db_index=True,
                default="uploading",
                max_length=12,
                verbose_name="Статус обработки",
            ),
        ),
        migrations.AddField(
            model_name="listingmedia",
            name="url_medium",
            field=models.FileField(
                blank=True,
                upload_to=apps.catalog.media.media_upload_to,
                verbose_name="Средний 1080px",
            ),
        ),
        migrations.AddField(
            model_name="listingmedia",
            name="url_medium_jpeg",
            field=models.FileField(
                blank=True,
                upload_to=apps.catalog.media.media_upload_to,
                verbose_name="Средний JPEG",
            ),
        ),
        migrations.AddField(
            model_name="listingmedia",
            name="url_original",
            field=models.FileField(
                blank=True,
                upload_to=apps.catalog.media.media_upload_to,
                verbose_name="Оригинал ≤2560px",
            ),
        ),
        migrations.AddField(
            model_name="listingmedia",
            name="url_original_jpeg",
            field=models.FileField(
                blank=True,
                upload_to=apps.catalog.media.media_upload_to,
                verbose_name="Оригинал JPEG",
            ),
        ),
        migrations.AddField(
            model_name="listingmedia",
            name="url_thumb",
            field=models.FileField(
                blank=True,
                upload_to=apps.catalog.media.media_upload_to,
                verbose_name="Превью 400px",
            ),
        ),
        migrations.AddField(
            model_name="listingmedia",
            name="url_thumb_jpeg",
            field=models.FileField(
                blank=True,
                upload_to=apps.catalog.media.media_upload_to,
                verbose_name="Превью JPEG",
            ),
        ),
        migrations.AddField(
            model_name="listingmedia",
            name="uuid",
            field=models.UUIDField(default=uuid.uuid4, editable=False, verbose_name="UUID"),
        ),
        migrations.RunPython(fill_uuids, noop),
        migrations.AlterField(
            model_name="listing",
            name="uuid",
            field=models.UUIDField(
                default=uuid.uuid4, editable=False, unique=True, verbose_name="UUID"
            ),
        ),
        migrations.AlterField(
            model_name="listingmedia",
            name="uuid",
            field=models.UUIDField(
                default=uuid.uuid4, editable=False, unique=True, verbose_name="UUID"
            ),
        ),
        migrations.AlterField(
            model_name="listingmedia",
            name="file",
            field=models.FileField(
                upload_to=apps.catalog.media.media_upload_to, verbose_name="Оригинал"
            ),
        ),
        migrations.AlterField(
            model_name="listingmedia",
            name="thumbnail",
            field=models.ImageField(
                blank=True,
                null=True,
                upload_to=apps.catalog.media.media_upload_to,
                verbose_name="Превью",
            ),
        ),
        migrations.RunPython(mark_existing_media_ready, noop),
    ]
