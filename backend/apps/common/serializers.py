"""Сериализаторы общего назначения (нужны в основном для схемы OpenAPI)."""

from rest_framework import serializers

from apps.common.models import SupportTicket


class HealthSerializer(serializers.Serializer):
    """Ответ health-check."""

    status = serializers.ChoiceField(choices=["ok", "error"])
    db = serializers.BooleanField()
    redis = serializers.BooleanField()


class ErrorDetailSerializer(serializers.Serializer):
    code = serializers.CharField()
    message = serializers.CharField()
    details = serializers.DictField(required=False)


class ErrorSerializer(serializers.Serializer):
    """Единый формат ошибок API."""

    error = ErrorDetailSerializer()


class MaintenanceSerializer(serializers.Serializer):
    """Режим обслуживания."""

    enabled = serializers.BooleanField()
    message = serializers.CharField(allow_blank=True)


class DocumentLinkSerializer(serializers.Serializer):
    """Ссылка на документ и его версия (на неё ссылаются согласия)."""

    url = serializers.CharField()
    version = serializers.CharField()


class AppConfigResponseSerializer(serializers.Serializer):
    """Ответ GET /app/config/."""

    min_supported_version = serializers.CharField()
    recommended_version = serializers.CharField()
    force_update = serializers.BooleanField()
    store_url = serializers.CharField(allow_blank=True)
    maintenance = MaintenanceSerializer()
    feature_flags = serializers.DictField()
    constants = serializers.DictField()
    documents = serializers.DictField(child=DocumentLinkSerializer())


class OnboardingSlideSerializer(serializers.Serializer):
    """Слайд онбординга."""

    id = serializers.IntegerField()
    title = serializers.CharField()
    text = serializers.CharField(allow_blank=True)
    image = serializers.CharField(allow_null=True)
    order = serializers.IntegerField()


class StaticPageSerializer(serializers.Serializer):
    """Статическая страница."""

    slug = serializers.CharField()
    title = serializers.CharField()
    content = serializers.CharField(allow_blank=True)
    version = serializers.CharField()
    updated_at = serializers.DateTimeField()


class SupportTicketSerializer(serializers.ModelSerializer):
    """Обращение в поддержку из приложения."""

    class Meta:
        model = SupportTicket
        fields = [
            "id",
            "subject",
            "message",
            "contact_phone",
            "app_version",
            "platform",
            "status",
            "created_at",
        ]
        read_only_fields = ["id", "status", "created_at"]
        extra_kwargs = {
            "contact_phone": {"required": False, "allow_blank": True},
            "app_version": {"required": False, "allow_blank": True},
            "platform": {"required": False, "allow_blank": True},
        }
