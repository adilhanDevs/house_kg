from django.apps import AppConfig


class NotificationsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.notifications"
    label = "notifications"
    verbose_name = "Уведомления"

    def ready(self) -> None:
        # Настройки уведомлений создаются вместе с пользователем.
        from apps.notifications import signals  # noqa: F401
