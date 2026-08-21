"""Заполняет price_usd у существующих объявлений."""

from decimal import Decimal

from django.conf import settings
from django.db import migrations
from django.db.models import F


def forwards(apps, schema_editor):
    Listing = apps.get_model("catalog", "Listing")
    ExchangeRate = apps.get_model("catalog", "ExchangeRate")

    Listing.objects.filter(currency="USD").update(price_usd=F("price"))

    latest = (
        ExchangeRate.objects.filter(currency_from="USD", currency_to="KGS")
        .order_by("-fetched_at")
        .values_list("rate", flat=True)
        .first()
    )
    rate = Decimal(latest) if latest else Decimal(str(settings.FALLBACK_USD_KGS_RATE))

    Listing.objects.filter(currency="KGS").update(price_usd=F("price") / rate)


def backwards(apps, schema_editor):
    Listing = apps.get_model("catalog", "Listing")
    Listing.objects.update(price_usd=None)


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0011_listing_price_usd_and_exchange_rate"),
    ]

    operations = [
        migrations.RunPython(forwards, backwards),
    ]
