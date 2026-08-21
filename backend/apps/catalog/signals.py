"""Инвалидация кэша опций фильтра."""

from typing import Any

from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from apps.catalog.models import City, District, HouseSeries, Listing
from apps.catalog.services import invalidate_filter_options_cache


@receiver([post_save, post_delete], sender=District)
@receiver([post_save, post_delete], sender=HouseSeries)
@receiver([post_save, post_delete], sender=Listing)
# Город в ответе появляется слагом внутри районов, поэтому его правки
# кэш тоже должны сбрасывать.
@receiver([post_save, post_delete], sender=City)
def on_catalog_changed(sender: type, instance: Any, **kwargs: Any) -> None:
    invalidate_filter_options_cache()
