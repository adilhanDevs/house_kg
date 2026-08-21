from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.http import HttpRequest

from apps.users.models import IdentityVerification, SellerProfile, User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ["-date_joined"]
    list_display = ["phone", "name", "is_pro", "is_active", "date_joined"]
    list_filter = ["is_pro", "is_active"]
    search_fields = ["phone", "name"]
    # ИИН — персональные данные: показываем, но править из админки нельзя.
    readonly_fields = ["iin", "date_joined", "updated_at", "last_login"]
    fieldsets = (
        (None, {"fields": ("phone", "password")}),
        (
            "Профиль",
            {"fields": ("name", "avatar", "is_pro", "seller_kind", "iin", "whatsapp_phone")},
        ),
        (
            "Права",
            {
                "fields": (
                    "is_active",
                    "is_staff",
                    "is_superuser",
                    "groups",
                    "user_permissions",
                )
            },
        ),
        ("Даты", {"fields": ("last_login", "date_joined", "updated_at")}),
    )
    add_fieldsets = (
        (None, {"classes": ("wide",), "fields": ("phone", "name", "password1", "password2")}),
    )


@admin.register(SellerProfile)
class SellerProfileAdmin(admin.ModelAdmin):
    list_display = ["user", "company_name", "is_verified", "verified_at", "rating"]
    list_filter = ["is_verified"]
    search_fields = ["company_name", "user__phone", "user__name"]
    autocomplete_fields = ["user"]


@admin.register(IdentityVerification)
class IdentityVerificationAdmin(admin.ModelAdmin):
    """Заявки на верификацию.

    Сами файлы из админки не открываются: доступ к ним — только через
    очередь модерации, где каждая выдача ссылки пишется в журнал аудита.
    """

    list_display = ["id", "user", "status", "document_type", "created_at", "reviewed_by"]
    list_filter = ["status", "document_type"]
    search_fields = ["user__phone", "user__name"]
    autocomplete_fields = ["user", "reviewed_by"]
    readonly_fields = ["user", "document_type", "created_at", "files_state", "purge_after"]
    fields = [
        "user",
        "document_type",
        "files_state",
        "status",
        "reject_reason",
        "comment",
        "reviewed_by",
        "reviewed_at",
        "purge_after",
        "created_at",
    ]

    @admin.display(description="Файлы")
    def files_state(self, obj: IdentityVerification) -> str:
        loaded = [name for name, _ in obj.files()]
        return ", ".join(loaded) if loaded else "файлы удалены"

    def has_add_permission(self, request: HttpRequest) -> bool:
        return False
