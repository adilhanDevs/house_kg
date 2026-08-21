from django.contrib import admin

from apps.notifications.models import DeviceToken, Notification, NotificationSettings


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ["created_at", "user", "type", "title", "is_read"]
    list_filter = ["type", "is_read"]
    search_fields = ["title", "body", "user__phone"]
    list_select_related = ["user"]
    autocomplete_fields = ["user", "listing"]


@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
    list_display = ["masked_token", "user", "platform", "app_version", "is_active", "last_seen_at"]
    list_filter = ["platform", "is_active"]
    search_fields = ["user__phone", "token"]
    list_select_related = ["user"]
    autocomplete_fields = ["user"]
    readonly_fields = ["last_seen_at"]

    @admin.display(description="Токен")
    def masked_token(self, obj: DeviceToken) -> str:
        # Токен целиком не показываем: по нему можно слать push.
        return f"…{obj.token[-8:]}"


@admin.register(NotificationSettings)
class NotificationSettingsAdmin(admin.ModelAdmin):
    list_display = ["user", "push_enabled", "price_drop_enabled", "saved_filter_enabled"]
    list_filter = ["push_enabled"]
    search_fields = ["user__phone"]
    list_select_related = ["user"]
    autocomplete_fields = ["user"]
