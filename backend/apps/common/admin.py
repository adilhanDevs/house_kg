"""Админка конфигурации приложения и статического контента."""

from typing import Any

from django.contrib import admin
from django.db import models
from django.http import HttpRequest, HttpResponse
from django.urls import reverse
from django.utils.html import format_html
from django.utils.safestring import SafeString

from apps.common.models import (
    AppConfig,
    AuditLog,
    OnboardingSlide,
    StaticPage,
    SupportTicket,
)


@admin.register(AppConfig)
class AppConfigAdmin(admin.ModelAdmin):
    """Singleton: одна строка, создать вторую и удалить существующую нельзя."""

    fieldsets = (
        (
            "Версии",
            {
                "fields": ("min_supported_version", "recommended_version"),
                "description": "Клиент с версией ниже минимальной получает force_update.",
            },
        ),
        ("Ссылки на сторы", {"fields": ("android_store_url", "ios_store_url")}),
        ("Режим обслуживания", {"fields": ("maintenance_mode", "maintenance_message")}),
        ("Флаги и константы", {"fields": ("feature_flags", "constants")}),
    )
    # Django 6.0 сменит схему URLField по умолчанию — фиксируем https заранее.
    formfield_overrides = {models.URLField: {"assume_scheme": "https"}}

    def has_add_permission(self, request: HttpRequest) -> bool:
        return not AppConfig.objects.exists()

    def has_delete_permission(self, request: HttpRequest, obj: Any = None) -> bool:
        return False

    def changelist_view(
        self, request: HttpRequest, extra_context: dict[str, Any] | None = None
    ) -> HttpResponse:
        """Список из одной строки не нужен — сразу открываем форму редактирования."""
        from django.shortcuts import redirect

        config = AppConfig.get_solo()
        return redirect(reverse("admin:common_appconfig_change", args=[config.pk]))


@admin.register(OnboardingSlide)
class OnboardingSlideAdmin(admin.ModelAdmin):
    list_display = ["preview", "order", "title", "is_active"]
    list_display_links = ["title"]
    list_editable = ["order", "is_active"]
    ordering = ["order", "id"]
    readonly_fields = ["preview_large"]
    fields = ["order", "title", "text", "image", "preview_large", "is_active"]

    @admin.display(description="Превью")
    def preview(self, obj: OnboardingSlide) -> SafeString | str:
        if not obj.image:
            return "—"
        return format_html('<img src="{}" style="height:48px;border-radius:6px" />', obj.image.url)

    @admin.display(description="Изображение")
    def preview_large(self, obj: OnboardingSlide) -> SafeString | str:
        if not obj.image:
            return "—"
        return format_html(
            '<img src="{}" style="max-width:320px;border-radius:12px" />', obj.image.url
        )


@admin.register(StaticPage)
class StaticPageAdmin(admin.ModelAdmin):
    list_display = ["slug", "title", "version", "is_active", "updated_at"]
    list_filter = ["is_active"]
    search_fields = ["slug", "title", "content"]
    readonly_fields = ["created_at", "updated_at"]
    fieldsets = (
        (None, {"fields": ("slug", "title", "is_active")}),
        (
            "Содержимое",
            {
                "fields": ("content", "version"),
                "description": (
                    "Текст — markdown. <b>При изменении текста соглашения "
                    "(terms, privacy) обязательно увеличьте версию</b>: по ней "
                    "у пользователей запрашивается новое согласие."
                ),
            },
        ),
        ("Служебное", {"fields": ("created_at", "updated_at")}),
    )


@admin.register(SupportTicket)
class SupportTicketAdmin(admin.ModelAdmin):
    list_display = ["id", "subject", "user", "contact_phone", "platform", "status", "created_at"]
    list_filter = ["status", "platform"]
    search_fields = ["subject", "message", "contact_phone"]
    readonly_fields = [
        "user",
        "subject",
        "message",
        "contact_phone",
        "app_version",
        "platform",
        "created_at",
    ]
    list_select_related = ["user"]


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    """Журнал аудита только для чтения — записи не правятся и не удаляются."""

    list_display = ["created_at", "action", "actor", "target_user", "ip_address"]
    list_filter = ["action"]
    search_fields = ["actor__phone", "target_user__phone", "object_id"]
    list_select_related = ["actor", "target_user"]
    readonly_fields = [field.name for field in AuditLog._meta.fields]

    def has_add_permission(self, request: HttpRequest) -> bool:
        return False

    def has_change_permission(self, request: HttpRequest, obj: Any = None) -> bool:
        return False

    def has_delete_permission(self, request: HttpRequest, obj: Any = None) -> bool:
        return False
