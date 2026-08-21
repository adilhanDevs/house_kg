from typing import Any

from django.contrib import admin
from django.http import HttpRequest
from django.utils.html import format_html
from django.utils.safestring import SafeString

from apps.engagement.models import (
    Collection,
    CollectionItem,
    Favourite,
    SavedFilter,
    ViewHistory,
)


@admin.register(Favourite)
class FavouriteAdmin(admin.ModelAdmin):
    list_display = ["user", "listing", "created_at"]
    date_hierarchy = "created_at"
    search_fields = ["user__phone", "listing__slug"]
    list_select_related = ["user", "listing"]
    autocomplete_fields = ["user", "listing"]


@admin.register(ViewHistory)
class ViewHistoryAdmin(admin.ModelAdmin):
    list_display = ["user", "listing", "viewed_at"]
    date_hierarchy = "viewed_at"
    search_fields = ["user__phone", "listing__slug"]
    list_select_related = ["user", "listing"]
    autocomplete_fields = ["user", "listing"]


@admin.register(SavedFilter)
class SavedFilterAdmin(admin.ModelAdmin):
    list_display = ["name", "user", "notify_on_new", "matches_count", "last_notified_at"]
    list_filter = ["notify_on_new"]
    search_fields = ["name", "user__phone"]
    list_select_related = ["user"]
    autocomplete_fields = ["user"]
    # Параметры нормализованы каталогом — правка руками сломала бы фильтр.
    readonly_fields = ["params", "matches_count", "last_notified_at"]


class CollectionItemInline(admin.TabularInline):
    """Порядок объектов в подборке задаётся полем order."""

    model = CollectionItem
    extra = 1
    fields = ["order", "listing"]
    ordering = ["order", "id"]
    autocomplete_fields = ["listing"]


@admin.register(Collection)
class CollectionAdmin(admin.ModelAdmin):
    list_display = ["cover_preview", "order", "title", "slug", "mode", "is_active"]
    list_display_links = ["title"]
    list_editable = ["order", "is_active"]
    list_filter = ["mode", "is_active"]
    search_fields = ["title", "slug", "description"]
    ordering = ["order", "-created_at"]
    inlines = [CollectionItemInline]
    readonly_fields = ["cover_large"]
    fieldsets = (
        (None, {"fields": ("title", "subtitle", "slug", "is_active", "order")}),
        ("Оформление", {"fields": ("cover", "cover_large", "description")}),
        (
            "Наполнение",
            {
                "fields": ("mode", "params"),
                "description": (
                    "«По фильтру» — подборка собирается параметрами каталога; "
                    "«Ручной список» — объектами из блока ниже, в порядке поля order."
                ),
            },
        ),
    )

    @admin.display(description="Обложка")
    def cover_preview(self, obj: Collection) -> SafeString | str:
        if not obj.cover:
            return "—"
        return format_html('<img src="{}" style="height:40px;border-radius:6px" />', obj.cover.url)

    @admin.display(description="Обложка")
    def cover_large(self, obj: Collection) -> SafeString | str:
        if not obj.cover:
            return "—"
        return format_html(
            '<img src="{}" style="max-width:320px;border-radius:12px" />', obj.cover.url
        )

    def get_inlines(self, request: HttpRequest, obj: Any = None) -> list:
        """Ручной список нужен только подборкам соответствующего режима."""
        if obj is not None and not obj.is_manual:
            return []
        return super().get_inlines(request, obj)
