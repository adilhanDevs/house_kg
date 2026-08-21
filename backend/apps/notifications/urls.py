"""URL-маршруты уведомлений."""

from django.urls import path

from apps.notifications.views import (
    DeviceDeactivateView,
    DeviceRegisterView,
    MarkReadView,
    NotificationDeleteView,
    NotificationListView,
    NotificationSettingsView,
    UnreadCountView,
)

app_name = "notifications"

urlpatterns = [
    path("notifications/", NotificationListView.as_view(), name="notifications"),
    path(
        "notifications/unread-count/",
        UnreadCountView.as_view(),
        name="notifications-unread-count",
    ),
    path("notifications/read/", MarkReadView.as_view(), name="notifications-read"),
    path(
        "notifications/settings/",
        NotificationSettingsView.as_view(),
        name="notifications-settings",
    ),
    path("notifications/<int:pk>/", NotificationDeleteView.as_view(), name="notification"),
    path("devices/", DeviceRegisterView.as_view(), name="devices"),
    path("devices/<str:token>/", DeviceDeactivateView.as_view(), name="device"),
]
