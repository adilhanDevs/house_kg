"""Эндпоинты ленты уведомлений, настроек и устройств."""

from typing import Any

from django.db.models import QuerySet
from django_filters import rest_framework as filters
from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import status
from rest_framework.generics import (
    DestroyAPIView,
    GenericAPIView,
    ListAPIView,
    RetrieveUpdateAPIView,
)
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.pagination import DefaultCursorPagination
from apps.common.serializers import ErrorSerializer
from apps.notifications.models import Notification, NotificationSettings
from apps.notifications.serializers import (
    DeviceTokenSerializer,
    MarkReadResponseSerializer,
    MarkReadSerializer,
    NotificationSerializer,
    NotificationSettingsSerializer,
    UnreadCountSerializer,
)
from apps.notifications.services import (
    deactivate_device,
    mark_read,
    register_device,
    unread_count,
)


class NotificationFilterSet(filters.FilterSet):
    """Фильтры ленты: непрочитанные и конкретный тип."""

    class Meta:
        model = Notification
        fields = ["is_read", "type"]


class NotificationListView(ListAPIView):
    """GET /api/v1/notifications/ — лента уведомлений."""

    permission_classes = [IsAuthenticated]
    serializer_class = NotificationSerializer
    pagination_class = DefaultCursorPagination
    filterset_class = NotificationFilterSet
    queryset = Notification.objects.none()  # для генератора схемы

    def get_queryset(self) -> QuerySet[Notification]:
        if not self.request.user.is_authenticated:  # pragma: no cover - генерация схемы
            return Notification.objects.none()
        return Notification.objects.filter(user=self.request.user).select_related("listing")

    @extend_schema(
        operation_id="notifications_list",
        summary="Лента уведомлений",
        responses={status.HTTP_200_OK: NotificationSerializer(many=True)},
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().get(request, *args, **kwargs)


class NotificationDeleteView(DestroyAPIView):
    """DELETE /api/v1/notifications/{id}/"""

    permission_classes = [IsAuthenticated]
    serializer_class = NotificationSerializer
    queryset = Notification.objects.none()  # для генератора схемы

    def get_queryset(self) -> QuerySet[Notification]:
        if not self.request.user.is_authenticated:  # pragma: no cover - генерация схемы
            return Notification.objects.none()
        return Notification.objects.filter(user=self.request.user)

    @extend_schema(
        operation_id="notifications_delete",
        summary="Удалить уведомление",
        responses={
            status.HTTP_204_NO_CONTENT: None,
            status.HTTP_404_NOT_FOUND: ErrorSerializer,
        },
    )
    def delete(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().delete(request, *args, **kwargs)


class UnreadCountView(APIView):
    """GET /api/v1/notifications/unread-count/ — бейдж на иконке."""

    permission_classes = [IsAuthenticated]

    @extend_schema(
        operation_id="notifications_unread_count",
        summary="Число непрочитанных уведомлений",
        responses={status.HTTP_200_OK: UnreadCountSerializer},
    )
    def get(self, request: Request) -> Response:
        return Response({"count": unread_count(request.user)})


class MarkReadView(GenericAPIView):
    """POST /api/v1/notifications/read/ — отметить прочитанными."""

    permission_classes = [IsAuthenticated]
    serializer_class = MarkReadSerializer

    @extend_schema(
        operation_id="notifications_mark_read",
        summary="Отметить уведомления прочитанными",
        description='Тело `{"ids": [1, 2]}` или `{"all": true}`.',
        responses={
            status.HTTP_200_OK: MarkReadResponseSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
        },
    )
    def post(self, request: Request) -> Response:
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        updated = mark_read(
            request.user,
            ids=serializer.validated_data.get("ids"),
            mark_all=serializer.validated_data.get("all", False),
        )

        return Response({"updated": updated, "unread_count": unread_count(request.user)})


@extend_schema_view(
    get=extend_schema(
        operation_id="notifications_settings_retrieve",
        summary="Настройки уведомлений",
        responses={status.HTTP_200_OK: NotificationSettingsSerializer},
    ),
    patch=extend_schema(
        operation_id="notifications_settings_update",
        summary="Изменить настройки уведомлений",
        responses={status.HTTP_200_OK: NotificationSettingsSerializer},
    ),
)
class NotificationSettingsView(RetrieveUpdateAPIView):
    """GET / PATCH /api/v1/notifications/settings/"""

    permission_classes = [IsAuthenticated]
    serializer_class = NotificationSettingsSerializer
    http_method_names = ["get", "patch", "head", "options"]

    def get_object(self) -> NotificationSettings:
        # Настройки создаёт сигнал при регистрации; get_or_create — страховка
        # для аккаунтов, созданных до появления этой модели.
        settings_obj, _ = NotificationSettings.objects.get_or_create(user=self.request.user)
        return settings_obj


class DeviceRegisterView(GenericAPIView):
    """POST /api/v1/devices/ — зарегистрировать устройство."""

    permission_classes = [IsAuthenticated]
    serializer_class = DeviceTokenSerializer

    @extend_schema(
        operation_id="devices_register",
        summary="Зарегистрировать устройство для push",
        description=(
            "Upsert по токену. Если токен был привязан к другому аккаунту "
            "(на телефоне сменился пользователь) — переезжает к текущему."
        ),
        responses={
            status.HTTP_200_OK: DeviceTokenSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
        },
    )
    def post(self, request: Request) -> Response:
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        device = register_device(
            user=request.user,
            token=serializer.validated_data["token"],
            platform=serializer.validated_data["platform"],
            app_version=serializer.validated_data.get("app_version", ""),
        )

        return Response(DeviceTokenSerializer(device).data)


class DeviceDeactivateView(APIView):
    """DELETE /api/v1/devices/{token}/ — выключить устройство при выходе."""

    permission_classes = [IsAuthenticated]

    @extend_schema(
        operation_id="devices_deactivate",
        summary="Деактивировать устройство",
        responses={
            status.HTTP_204_NO_CONTENT: None,
            status.HTTP_404_NOT_FOUND: ErrorSerializer,
        },
    )
    def delete(self, request: Request, token: str) -> Response:
        if not deactivate_device(request.user, token):
            from rest_framework.exceptions import NotFound

            raise NotFound("Устройство не найдено.")

        return Response(status=status.HTTP_204_NO_CONTENT)
