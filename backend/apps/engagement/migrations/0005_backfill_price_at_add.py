"""Проставляет цену на момент добавления у уже существующего избранного."""

from django.db import migrations
from django.db.models import OuterRef, Subquery


def forwards(apps, schema_editor):
    Favourite = apps.get_model("engagement", "Favourite")
    Listing = apps.get_model("catalog", "Listing")

    price = Listing.objects.filter(pk=OuterRef("listing_id")).values("price_usd")[:1]
    Favourite.objects.filter(price_at_add__isnull=True).update(price_at_add=Subquery(price))


def backwards(apps, schema_editor):
    Favourite = apps.get_model("engagement", "Favourite")
    Favourite.objects.update(price_at_add=None)


class Migration(migrations.Migration):
    dependencies = [
        ("engagement", "0004_favourite_price_at_add"),
        ("catalog", "0012_backfill_price_usd"),
    ]

    operations = [
        migrations.RunPython(forwards, backwards),
    ]
