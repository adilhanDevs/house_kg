from django.contrib import admin

from apps.billing.models import Wallet, WalletTransaction


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
