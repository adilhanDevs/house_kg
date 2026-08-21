"""Админка каталога: справочники и объявления."""

from django.contrib import admin
from django.db.models import QuerySet
from django.http import HttpRequest
from django.utils import timezone

from apps.catalog.enums import ListingStatus
from apps.catalog.models import (
    Builder,
    City,
    District,
    ExchangeRate,
    HouseSeries,
    Listing,
    ListingMedia,
)
from apps.catalog.search import update_search_vectors


@admin.register(City)
class CityAdmin(admin.ModelAdmin):
    list_display = ["name", "slug", "is_default", "is_active", "order"]
    list_editable = ["is_active", "order"]
    list_filter = ["is_active", "is_default"]
    search_fields = ["name", "slug"]
    ordering = ["order", "name"]


@admin.register(District)
class DistrictAdmin(admin.ModelAdmin):
    list_display = ["name", "city", "slug", "is_active", "order"]
    list_editable = ["is_active", "order"]
    list_filter = ["city", "is_active"]
    search_fields = ["name", "slug"]
    autocomplete_fields = ["city"]
    list_select_related = ["city"]
    ordering = ["city", "order", "name"]


@admin.register(HouseSeries)
class HouseSeriesAdmin(admin.ModelAdmin):
    list_display = ["code", "name", "is_active", "order"]
    list_editable = ["is_active", "order"]
    list_filter = ["is_active"]
    search_fields = ["code", "name"]
    ordering = ["order", "code"]


@admin.register(Builder)
class BuilderAdmin(admin.ModelAdmin):
    list_display = ["name", "slug", "is_active", "order"]
    list_editable = ["is_active", "order"]
    list_filter = ["is_active"]
    search_fields = ["name", "slug"]
    ordering = ["order", "name"]


class ListingMediaInline(admin.TabularInline):
    model = ListingMedia
    extra = 0
    fields = ["file", "kind", "order", "is_cover", "thumbnail", "width", "height"]


@admin.register(Listing)
class ListingAdmin(admin.ModelAdmin):
    list_display = ["slug", "district", "kind", "price", "status", "published_at", "views_count"]
    list_filter = ["status", "kind", "seller_kind", "city", "district", "is_secondary"]
    search_fields = ["slug", "address", "description"]
    autocomplete_fields = ["city", "district", "builder", "series", "owner"]
    list_select_related = ["district", "city"]
    # Счётчики денормализованы и меняются только сервисами — руками не правим.
    readonly_fields = ["slug", "views_count", "favourites_count", "search_vector"]
    inlines = [ListingMediaInline]
    actions = ["publish", "reject", "archive"]
    date_hierarchy = "created_at"

    @admin.action(description="Опубликовать")
    def publish(self, request: HttpRequest, queryset: QuerySet[Listing]) -> None:
        updated = queryset.update(
            status=ListingStatus.ACTIVE,
            published_at=timezone.now(),
            rejection_reason="",
        )
        # Поисковый индекс пересчитываем одним запросом на всю пачку.
        update_search_vectors(Listing.objects.filter(pk__in=queryset.values("pk")))
        self.message_user(request, f"Опубликовано объявлений: {updated}")

    @admin.action(description="Отклонить")
    def reject(self, request: HttpRequest, queryset: QuerySet[Listing]) -> None:
        updated = queryset.update(status=ListingStatus.REJECTED)
        self.message_user(
            request,
            f"Отклонено объявлений: {updated}. Причину укажите в карточке объявления.",
        )

    @admin.action(description="Архивировать")
    def archive(self, request: HttpRequest, queryset: QuerySet[Listing]) -> None:
        updated = queryset.update(status=ListingStatus.ARCHIVED)
        self.message_user(request, f"В архив отправлено объявлений: {updated}")


@admin.register(ExchangeRate)
class ExchangeRateAdmin(admin.ModelAdmin):
    """История курсов только для чтения — её пишет задача НБКР."""

    list_display = ["currency_from", "currency_to", "rate", "fetched_at"]
    list_filter = ["currency_from", "currency_to"]
    readonly_fields = ["currency_from", "currency_to", "rate", "fetched_at"]

    def has_add_permission(self, request: HttpRequest) -> bool:
        return False
