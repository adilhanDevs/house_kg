"""Админка каталога: справочники, объявления и очередь модерации."""

import json

from django.contrib import admin, messages
from django.db.models import Prefetch, QuerySet
from django.http import HttpRequest
from django.utils import timezone
from django.utils.html import format_html, format_html_join

from apps.catalog.enums import ListingStatus, ModerationStatus
from apps.catalog.models import (
    Builder,
    City,
    District,
    ExchangeRate,
    HouseSeries,
    Listing,
    ListingMedia,
    ListingReport,
    ListingRoom,
    ModerationTask,
    RejectReason,
)
from apps.catalog.moderation.services import approve_task, reject_task
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


class ListingRoomInline(admin.TabularInline):
    model = ListingRoom
    extra = 1
    fields = ["name", "area", "order"]
    verbose_name = "Комната (помещение)"
    verbose_name_plural = "Комнаты (экспликация помещений)"


class ListingMediaInline(admin.TabularInline):
    model = ListingMedia
    extra = 0
    fields = ["file", "kind", "title", "thumbnail", "status", "order", "is_cover", "width", "height"]
    readonly_fields = ["status", "width", "height"]


@admin.register(ListingMedia)
class ListingMediaAdmin(admin.ModelAdmin):
    """Отдельный раздел нужен ради phash: по нему ищутся переклеенные фото."""

    list_display = ["id", "listing", "kind", "status", "order", "is_cover", "phash"]
    list_filter = ["kind", "status", "is_cover"]
    # Поиск по phash: одинаковый хеш в разных объявлениях — один и тот же снимок.
    search_fields = ["phash", "listing__slug"]
    list_select_related = ["listing"]
    autocomplete_fields = ["listing"]
    readonly_fields = [
        "uuid",
        "status",
        "phash",
        "width",
        "height",
        "duration_seconds",
        "size_bytes",
        "processing_error",
        "url_thumb",
        "url_medium",
        "url_original",
        "url_thumb_jpeg",
        "url_medium_jpeg",
        "url_original_jpeg",
    ]


@admin.register(Listing)
class ListingAdmin(admin.ModelAdmin):
    list_display = ["slug", "district", "kind", "price", "status", "published_at", "views_count"]
    list_filter = [
        "status",
        "kind",
        "seller_kind",
        "city",
        "district",
        "is_secondary",
        "is_deleted",
    ]
    search_fields = ["slug", "address", "description"]
    autocomplete_fields = ["city", "district", "builder", "series", "owner"]
    list_select_related = ["district", "city"]
    readonly_fields = ["slug", "views_count", "favourites_count", "search_vector", "bumped_at"]

    fieldsets = [
        (
            "Основная информация",
            {
                "fields": [
                    "slug",
                    "owner",
                    "status",
                    "kind",
                    "seller_kind",
                    "city",
                    "district",
                    "address",
                    ("latitude", "longitude"),
                    ("price", "currency"),
                    "old_price",
                    "description",
                ]
            },
        ),
        (
            "Общая информация",
            {
                "fields": [
                    "area",
                    "rooms",
                    ("floor", "floors"),
                    "furniture",
                ]
            },
        ),
        (
            "Ключевые места и покупка",
            {
                "fields": [
                    "landmarks",
                    ("has_direct_sale", "has_mortgage"),
                ]
            },
        ),
        (
            "Дополнительные параметры",
            {
                "fields": [
                    "series",
                    "builder",
                    "land_area",
                    ("is_secondary", "below_market", "red_book"),
                    ("contact_name", "contact_phone"),
                    "allow_media_download",
                    "rejection_reason",
                ],
                "classes": ["collapse"],
            },
        ),
        (
            "Системные поля",
            {
                "fields": [
                    "views_count",
                    "favourites_count",
                    "bumped_at",
                    "published_at",
                    "expires_at",
                    "promoted_until",
                    "is_deleted",
                ],
                "classes": ["collapse"],
            },
        ),
    ]

    def get_queryset(self, request):
        # В админке видны и мягко удалённые объявления.
        return Listing.all_objects.get_queryset().select_related("district", "city")

    inlines = [ListingRoomInline, ListingMediaInline]
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


@admin.register(RejectReason)
class RejectReasonAdmin(admin.ModelAdmin):
    list_display = ["code", "title", "is_active", "order"]
    list_editable = ["is_active", "order"]
    search_fields = ["code", "title"]
    ordering = ["order", "code"]


@admin.register(ListingReport)
class ListingReportAdmin(admin.ModelAdmin):
    list_display = ["id", "listing", "reason", "reporter", "is_resolved", "created_at"]
    list_filter = ["reason", "is_resolved"]
    search_fields = ["listing__slug", "comment"]
    list_select_related = ["listing", "reporter"]
    autocomplete_fields = ["listing", "reporter"]
    date_hierarchy = "created_at"


@admin.register(ModerationTask)
class ModerationTaskAdmin(admin.ModelAdmin):
    """Очередь модерации с превью объявления и решениями прямо из списка."""

    list_display = [
        "id",
        "preview",
        "listing_title",
        "priority",
        "triggers",
        "status",
        "assigned_to",
        "created_at",
    ]
    list_filter = ["status", "priority", "reject_reason"]
    search_fields = ["listing__slug", "listing__description", "comment"]
    list_select_related = ["listing", "listing__district", "assigned_to", "reject_reason"]
    autocomplete_fields = ["listing", "assigned_to", "resolved_by"]
    readonly_fields = ["checks_table", "preview_large", "listing_text", "resolved_at"]
    date_hierarchy = "created_at"
    actions = ["approve_selected", "reject_selected"]
    fields = [
        "listing",
        "status",
        "priority",
        "assigned_to",
        "preview_large",
        "listing_text",
        "checks_table",
        "reject_reason",
        "comment",
        "resolved_by",
        "resolved_at",
    ]

    def get_queryset(self, request: HttpRequest) -> QuerySet[ModerationTask]:
        cover = ListingMedia.objects.filter(is_cover=True)
        return (
            super()
            .get_queryset(request)
            .prefetch_related(Prefetch("listing__media", queryset=cover, to_attr="cover_media"))
        )

    @staticmethod
    def _cover_url(task: ModerationTask) -> str:
        cover = getattr(task.listing, "cover_media", None) or []
        if not cover:
            return ""
        media = cover[0]
        file_field = media.url_thumb or media.file
        return file_field.url if file_field else ""

    @admin.display(description="Фото")
    def preview(self, obj: ModerationTask) -> str:
        url = self._cover_url(obj)
        if not url:
            return "—"
        return format_html('<img src="{}" style="height:48px;border-radius:4px">', url)

    @admin.display(description="Обложка")
    def preview_large(self, obj: ModerationTask) -> str:
        url = self._cover_url(obj)
        if not url:
            return "Фотографий нет"
        return format_html('<img src="{}" style="max-height:320px;border-radius:8px">', url)

    @admin.display(description="Объект")
    def listing_title(self, obj: ModerationTask) -> str:
        listing = obj.listing
        return f"{listing.district} · {listing.price_display} · {listing.area or '—'} м²"

    @admin.display(description="Текст объявления")
    def listing_text(self, obj: ModerationTask) -> str:
        listing = obj.listing
        return format_html(
            "<b>{}</b><br><br>{}",
            listing.address or "адрес не указан",
            (listing.description or "описание не заполнено").replace("\n", " "),
        )

    @admin.display(description="Сработало")
    def triggers(self, obj: ModerationTask) -> str:
        names = obj.triggered_checks
        return ", ".join(names) if names else "—"

    @admin.display(description="Автопроверки")
    def checks_table(self, obj: ModerationTask) -> str:
        """Результаты автопроверок как есть — модератор должен видеть детали."""
        if not obj.checks:
            return "Проверки ещё не отработали"

        rows = []
        for name, result in obj.checks.items():
            triggered = result.get("triggered") if isinstance(result, dict) else False
            details = result.get("details") if isinstance(result, dict) else result
            rows.append(
                format_html(
                    "<tr><td><b>{}</b></td><td>{}</td><td><pre "
                    'style="white-space:pre-wrap;margin:0">{}</pre></td></tr>',
                    name,
                    "сработала" if triggered else "чисто",
                    json.dumps(details, ensure_ascii=False, indent=2),
                )
            )
        body = format_html_join("", "{}", ((row,) for row in rows))
        return format_html("<table>{}</table>", body)

    @admin.action(description="Одобрить")
    def approve_selected(self, request: HttpRequest, queryset: QuerySet[ModerationTask]) -> None:
        done = 0
        for task in queryset.filter(status=ModerationStatus.OPEN):
            approve_task(task, request.user)
            done += 1
        self.message_user(request, f"Одобрено задач: {done}")

    @admin.action(description="Отклонить (первая активная причина)")
    def reject_selected(self, request: HttpRequest, queryset: QuerySet[ModerationTask]) -> None:
        """Массовое отклонение берёт первую активную причину справочника.

        Точную причину и комментарий проставляют в карточке задачи — здесь
        только быстрый разбор очевидного потока.
        """
        reason = RejectReason.objects.filter(is_active=True).order_by("order").first()
        if reason is None:
            self.message_user(request, "Справочник причин пуст", level=messages.ERROR)
            return

        done = 0
        for task in queryset.filter(status=ModerationStatus.OPEN):
            reject_task(task, request.user, reason.code)
            done += 1
        self.message_user(request, f"Отклонено задач: {done} (причина «{reason.title}»)")
