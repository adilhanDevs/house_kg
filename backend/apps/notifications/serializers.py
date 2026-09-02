"""Сериализаторы уведомлений, настроек и устройств."""

from typing import Any

from rest_framework import serializers

from apps.notifications.models import DeviceToken, Notification, NotificationSettings


class NotificationSerializer(serializers.ModelSerializer):
    """Уведомление в ленте."""

    listing_slug = serializers.SlugField(source="listing.slug", default=None, read_only=True)

    class Meta:
        model = Notification
        fields = [
            "id",
            "type",
            "title",
            "body",
            "payload",
            "listing_slug",
            "is_read",
            "created_at",
        ]
        read_only_fields = fields


class UnreadCountSerializer(serializers.Serializer):
    count = serializers.IntegerField()


class MarkReadSerializer(serializers.Serializer):
    """Что отметить прочитанным: перечисленные уведомления или все."""

    ids = serializers.ListField(child=serializers.IntegerField(), required=False, allow_empty=True)
    all = serializers.BooleanField(required=False, default=False)

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        if not attrs.get("all") and not attrs.get("ids"):
            raise serializers.ValidationError(
                {"ids": "Укажите список идентификаторов или передайте all=true."}
            )
        return attrs


class MarkReadResponseSerializer(serializers.Serializer):
    updated = serializers.IntegerField()
    unread_count = serializers.IntegerField()


class NotificationSettingsSerializer(serializers.ModelSerializer):
    """Настройки push-уведомлений пользователя."""

    class Meta:
        model = NotificationSettings
        fields = [
            "push_enabled",
            "new_message_enabled",
            "price_drop_enabled",
            "saved_filter_enabled",
            "listing_moderated_enabled",
            "promotion_expiring_enabled",
            "wallet_topup_enabled",
            "system_enabled",
        ]


class DeviceTokenSerializer(serializers.ModelSerializer):
    """Регистрация устройства для push."""

    class Meta:
        model = DeviceToken
        fields = ["token", "platform", "app_version", "is_active", "last_seen_at"]
        read_only_fields = ["is_active", "last_seen_at"]
        extra_kwargs = {
            "app_version": {"required": False, "allow_blank": True},
            # Уникальность токена — не ошибка ввода, а повод обновить запись.
            "token": {"validators": []},
        }
