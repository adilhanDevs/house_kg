from django.apps import AppConfig


class CommonConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.common"
    label = "common"
    verbose_name = "Общее"

    def ready(self) -> None:
        # Подключаем обработчики инвалидации кэша.
        from apps.common import signals  # noqa: F401
