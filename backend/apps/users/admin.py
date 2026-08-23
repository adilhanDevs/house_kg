from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.db.models import QuerySet
from django.http import HttpRequest

from apps.users.models import (
    ContactEvent,
    IdentityVerification,
    Review,
    ReviewStatus,
    SellerProfile,
    SellerVerification,
    User,
    VerificationStatus,
)
from apps.users.sellers import publish_review, reject_review, review_seller_verification


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ["-date_joined"]
    list_display = ["phone", "name", "is_pro", "is_trusted", "is_active", "date_joined"]
    list_filter = ["is_pro", "is_trusted", "is_active"]
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
                    "is_trusted",
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
    list_display = [
        "user",
        "company_name",
        "experience_years",
        "is_verified",
        "rating",
        "reviews_count",
    ]
    list_filter = ["is_verified"]
    search_fields = ["company_name", "user__phone", "user__name"]
    autocomplete_fields = ["user"]
    filter_horizontal = ["work_districts"]
    # Рейтинг — агрегат отзывов, значок ставит решение по заявке.
    readonly_fields = ["rating", "reviews_count", "verified_at"]


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


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    """Модерация отзывов. Те же решения доступны и в общей очереди."""

    list_display = ["id", "seller", "author", "rating", "short_text", "status", "created_at"]
    list_filter = ["status", "rating"]
    search_fields = ["seller__phone", "author__phone", "text"]
    list_select_related = ["seller", "author"]
    autocomplete_fields = ["seller", "author"]
    date_hierarchy = "created_at"
    actions = ["publish_selected", "reject_selected"]
    # Оценку и текст пишет автор — модератор только решает, публиковать ли.
    readonly_fields = ["seller", "author", "listing", "rating", "text", "status"]

    @admin.display(description="Текст")
    def short_text(self, obj: Review) -> str:
        text = (obj.text or "").replace("\n", " ")
        return f"{text[:60]}…" if len(text) > 60 else (text or "—")

    @admin.action(description="Опубликовать")
    def publish_selected(self, request: HttpRequest, queryset: QuerySet[Review]) -> None:
        done = 0
        for review in queryset.exclude(status=ReviewStatus.PUBLISHED):
            publish_review(review, request.user)
            done += 1
        self.message_user(request, f"Опубликовано отзывов: {done}")

    @admin.action(description="Отклонить")
    def reject_selected(self, request: HttpRequest, queryset: QuerySet[Review]) -> None:
        done = 0
        for review in queryset.exclude(status=ReviewStatus.REJECTED):
            reject_review(review, request.user)
            done += 1
        self.message_user(request, f"Отклонено отзывов: {done}")


@admin.register(SellerVerification)
class SellerVerificationAdmin(admin.ModelAdmin):
    list_display = ["id", "seller", "status", "documents_count", "created_at", "reviewed_at"]
    list_filter = ["status"]
    search_fields = ["seller__phone", "seller__name"]
    list_select_related = ["seller", "reviewed_by"]
    autocomplete_fields = ["seller"]
    date_hierarchy = "created_at"
    actions = ["approve_selected", "reject_selected"]
    readonly_fields = ["seller", "documents", "reviewed_by", "reviewed_at"]

    @admin.display(description="Документов")
    def documents_count(self, obj: SellerVerification) -> int:
        return len(obj.documents or [])

    @admin.action(description="Подтвердить продавца")
    def approve_selected(
        self, request: HttpRequest, queryset: QuerySet[SellerVerification]
    ) -> None:
        done = 0
        for verification in queryset.filter(status=VerificationStatus.PENDING):
            review_seller_verification(verification, request.user, approved=True)
            done += 1
        self.message_user(request, f"Подтверждено продавцов: {done}")

    @admin.action(description="Отклонить заявку")
    def reject_selected(self, request: HttpRequest, queryset: QuerySet[SellerVerification]) -> None:
        done = 0
        for verification in queryset.filter(status=VerificationStatus.PENDING):
            review_seller_verification(verification, request.user, approved=False)
            done += 1
        self.message_user(request, f"Отклонено заявок: {done}")


@admin.register(ContactEvent)
class ContactEventAdmin(admin.ModelAdmin):
    """Только чтение: журнал раскрытий для разбора подозрительной активности."""

    list_display = ["id", "user", "listing", "ip_address", "created_at"]
    search_fields = ["user__phone", "listing__slug", "ip_address"]
    list_select_related = ["user", "listing"]
    date_hierarchy = "created_at"

    def has_add_permission(self, request: HttpRequest) -> bool:
        return False

    def has_change_permission(self, request: HttpRequest, obj: object = None) -> bool:
        return False
