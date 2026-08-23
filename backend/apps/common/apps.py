from django.apps import AppConfig
from django.conf import settings


class CommonConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.common"
    label = "common"
    verbose_name = "Общее"

    def ready(self) -> None:
        # Подключаем обработчики инвалидации кэша.
        from apps.common import signals  # noqa: F401
        from apps.common.logging import configure_structlog
        from apps.common.observability import init_sentry

        # Логирование настраивается здесь, а не в settings: настройки читает
        # и Celery, и management-команды — точка входа у всех одна.
        configure_structlog(
            json_logs=getattr(settings, "LOG_JSON", True),
            level=getattr(settings, "LOG_LEVEL", "INFO"),
        )
        init_sentry()
