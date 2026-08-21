from django.apps import AppConfig


class CatalogConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.catalog"
    label = "catalog"
    verbose_name = "Каталог"

    def ready(self) -> None:
        # Подключаем инвалидацию кэша опций фильтра.
        from apps.catalog import signals  # noqa: F401
