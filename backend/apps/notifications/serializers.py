"""Сериализаторы уведомлений, настроек и устройств."""

from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

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

    new_listing_match_enabled = serializers.BooleanField(
        source="saved_filter_enabled",
        read_only=True,
    )

    class Meta:
        model = NotificationSettings
        fields = [
            "push_enabled",
            "new_message_enabled",
            "price_drop_enabled",
            "price_drop_viewed_enabled",
            "new_listing_match_enabled",
            "saved_filter_enabled",
            "listing_moderated_enabled",
            "promotion_expiring_enabled",
            "wallet_topup_enabled",
            "system_enabled",
        ]

    def to_internal_value(self, data: Any) -> dict[str, Any]:
        if hasattr(data, "copy"):
            data = data.copy()
        if isinstance(data, dict) and "new_listing_match_enabled" in data:
            canonical = data["new_listing_match_enabled"]
            legacy = data.get("saved_filter_enabled", canonical)
            if legacy != canonical:
                raise serializers.ValidationError(
                    {
                        "new_listing_match_enabled": (
                            "Не передавайте разные значения для canonical и legacy поля."
                        )
                    }
                )
            data["saved_filter_enabled"] = canonical
        return super().to_internal_value(data)


class DeviceTokenSerializer(serializers.ModelSerializer):
    """Регистрация устройства для push."""

    class Meta:
        model = DeviceToken
        fields = [
            "token",
            "platform",
            "device_id",
            "app_version",
            "locale",
            "timezone",
            "is_active",
            "last_seen_at",
        ]
        read_only_fields = ["is_active", "last_seen_at"]
        extra_kwargs = {
            "app_version": {"required": False, "allow_blank": True},
            "device_id": {"required": False, "allow_blank": True, "allow_null": True},
            # Уникальность токена — не ошибка ввода, а повод обновить запись.
            "token": {"validators": []},
        }

    def validate_device_id(self, value: str | None) -> str | None:
        value = (value or "").strip()
        return value or None

    def validate_timezone(self, value: str) -> str:
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError) as exc:
            raise serializers.ValidationError("Неизвестный часовой пояс.") from exc
        return value


class DeviceDeactivateSerializer(serializers.Serializer):
    device_id = serializers.CharField(required=False, allow_blank=False, max_length=64)
    token = serializers.CharField(required=False, allow_blank=False, max_length=512)

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        if not attrs.get("device_id") and not attrs.get("token"):
            raise serializers.ValidationError(
                {"device_id": "Передайте device_id или token текущего устройства."}
            )
        return attrs
