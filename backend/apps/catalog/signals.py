"""Инвалидация кэша опций фильтра и подборок главного экрана."""

from typing import Any

from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from apps.catalog.models import Builder, City, District, HouseSeries, Listing, ListingMedia
from apps.catalog.services import invalidate_filter_options_cache


# Застройщики отдаются в опциях фильтра наравне с районами и сериями:
# без этого приёмника переименованный застройщик до десяти минут виден
# в фильтре под старым именем.
@receiver([post_save, post_delete], sender=Builder)
@receiver([post_save, post_delete], sender=District)
@receiver([post_save, post_delete], sender=HouseSeries)
@receiver([post_save, post_delete], sender=Listing)
# Город в ответе появляется слагом внутри районов, поэтому его правки
# кэш тоже должны сбрасывать.
@receiver([post_save, post_delete], sender=City)
def on_catalog_changed(sender: type, instance: Any, **kwargs: Any) -> None:
    invalidate_filter_options_cache()


# Ответ /listings/featured/ кэшируется на пять минут вместе с готовыми
# cover_url (см. FEATURED_CACHE_KEY), а ключ включает тот же счётчик версии.
# Правка медиа объявление не трогает, поэтому без этого приёмника главный
# экран до пяти минут показывал прежнюю обложку.
#
# Массовые обновления (`bulk_update` в reorder_listing_media) сигналов не
# шлют — там инвалидация вызывается сервисом напрямую.
@receiver([post_save, post_delete], sender=ListingMedia)
def on_listing_media_changed(sender: type, instance: Any, **kwargs: Any) -> None:
    invalidate_filter_options_cache()
