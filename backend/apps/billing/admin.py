from django.contrib import admin

from apps.billing.models import (
    Payment,
    PaymentLog,
    PaymentProviderConfig,
    Promotion,
    PromotionOption,
    PromotionPackage,
    Subscription,
    Tariff,
    Wallet,
    WalletTransaction,
)
from apps.catalog.models import ListingDailyStat


@admin.register(Wallet)
class WalletAdmin(admin.ModelAdmin):
    list_display = ["user", "balance_display"]
    search_fields = ["user__phone", "user__name"]
    autocomplete_fields = ["user"]
    # Баланс меняется только операциями через apply_transaction.
    readonly_fields = ["user", "balance"]

    def has_add_permission(self, request) -> bool:
        return False


@admin.register(WalletTransaction)
class WalletTransactionAdmin(admin.ModelAdmin):
    """Леджер только для чтения: операции не правятся и не удаляются."""

    list_display = ["created_at", "wallet", "amount_display", "kind", "label", "balance_after"]
    list_filter = ["kind"]
    search_fields = ["label", "wallet__user__phone", "idempotency_key"]
    list_select_related = ["wallet__user"]
    date_hierarchy = "created_at"
    readonly_fields = [field.name for field in WalletTransaction._meta.fields]

    def has_add_permission(self, request) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return False


@admin.register(PaymentProviderConfig)
class PaymentProviderConfigAdmin(admin.ModelAdmin):
    list_display = ["order", "name", "code", "is_active"]
    list_display_links = ["name"]
    list_editable = ["order", "is_active"]
    list_filter = ["is_active"]
    search_fields = ["code", "name"]
    ordering = ["order", "name"]


class PaymentLogInline(admin.TabularInline):
    model = PaymentLog
    extra = 0
    can_delete = False
    fields = ["created_at", "direction", "endpoint", "status_code", "payload"]
    readonly_fields = fields

    def has_add_permission(self, request, obj=None) -> bool:
        return False


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    """Счета только для чтения: статус меняют вебхуки, а не руки."""

    list_display = ["created_at", "user", "amount_kgs", "bricks", "bonus_bricks", "status"]
    list_filter = ["status", "provider"]
    search_fields = ["user__phone", "provider_ref", "idempotency_key"]
    list_select_related = ["user"]
    date_hierarchy = "created_at"
    readonly_fields = [field.name for field in Payment._meta.fields]
    inlines = [PaymentLogInline]

    def has_add_permission(self, request) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False


@admin.register(PaymentLog)
class PaymentLogAdmin(admin.ModelAdmin):
    list_display = ["created_at", "direction", "endpoint", "status_code", "payment"]
    list_filter = ["direction", "status_code"]
    search_fields = ["endpoint", "payment__provider_ref"]
    readonly_fields = [field.name for field in PaymentLog._meta.fields]

    def has_add_permission(self, request) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False


@admin.register(PromotionPackage)
class PromotionPackageAdmin(admin.ModelAdmin):
    list_display = ["code", "name", "price_per_day_bricks", "is_active", "order"]
    list_editable = ["price_per_day_bricks", "is_active", "order"]
    search_fields = ["code", "name"]
    ordering = ["order", "code"]


@admin.register(PromotionOption)
class PromotionOptionAdmin(admin.ModelAdmin):
    list_display = ["code", "name", "price_per_day_bricks", "is_active", "order"]
    list_editable = ["price_per_day_bricks", "is_active", "order"]
    search_fields = ["code", "name"]
    ordering = ["order", "code"]


@admin.register(Promotion)
class PromotionAdmin(admin.ModelAdmin):
    list_display = [
        "id",
        "listing",
        "package",
        "days",
        "cost_bricks",
        "starts_at",
        "ends_at",
        "status",
    ]
    list_filter = ["status", "package"]
    search_fields = ["listing__slug"]
    list_select_related = ["listing", "package"]
    autocomplete_fields = ["listing"]
    date_hierarchy = "created_at"
    # Цена и срок зафиксированы покупкой: правка руками разошлась бы с леджером.
    readonly_fields = [
        "listing",
        "package",
        "days",
        "options",
        "cost_bricks",
        "starts_at",
        "ends_at",
        "transaction",
        "expiry_notified_at",
    ]


@admin.register(ListingDailyStat)
class ListingDailyStatAdmin(admin.ModelAdmin):
    list_display = ["listing", "date", "impressions", "views", "favourites", "phone_reveals"]
    list_filter = ["date"]
    search_fields = ["listing__slug"]
    list_select_related = ["listing"]
    date_hierarchy = "date"
    # Счётчики пишутся сервисами F-выражениями — руками не правим.
    readonly_fields = ["listing", "date", "impressions", "views", "favourites", "phone_reveals"]


@admin.register(Tariff)
class TariffAdmin(admin.ModelAdmin):
    list_display = [
        "code",
        "name",
        "price_bricks_per_month",
        "listings_limit",
        "is_active",
        "order",
    ]
    list_editable = ["price_bricks_per_month", "listings_limit", "is_active", "order"]
    search_fields = ["code", "name"]
    ordering = ["order", "code"]


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = [
        "id",
        "user",
        "tariff",
        "starts_at",
        "ends_at",
        "is_auto_renew",
        "status",
    ]
    list_filter = ["status", "tariff", "is_auto_renew"]
    search_fields = ["user__phone", "user__name"]
    list_select_related = ["user", "tariff"]
    autocomplete_fields = ["user"]
    date_hierarchy = "created_at"
    # Срок и оплата зафиксированы покупкой: правка руками разошлась бы с леджером.
    readonly_fields = [
        "user",
        "tariff",
        "starts_at",
        "transaction",
        "renewal_attempted_at",
        "auto_bumped_at",
    ]
