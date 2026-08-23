"""Фабрики должны строить валидные объекты для всех моделей проекта.

Смысл теста не в покрытии, а в страховке: поле, добавленное в модель без
значения по умолчанию, ломает здесь все тесты сразу, а не в одном случайном.
"""

import pytest
from django.apps import apps as django_apps

from tests import factories

pytestmark = pytest.mark.django_db

# Модели, которые фабриками не создаются намеренно.
NO_FACTORY = {
    # Создаются только сервисами: у ModerationTask должна быть цель,
    # а у ListingDailyStat — событие.
}

FACTORY_NAMES = sorted(
    name
    for name in dir(factories)
    if name.endswith("Factory")
    # Импортированный DjangoModelFactory — абстрактный предок, не фабрика.
    and getattr(getattr(factories, name), "_meta", None) is not None
    and not getattr(factories, name)._meta.abstract
)


@pytest.mark.parametrize("name", FACTORY_NAMES)
def test_factory_creates_valid_object(name: str):
    factory_class = getattr(factories, name)
    instance = factory_class()

    assert instance.pk is not None
    # Объект должен читаться обратно из БД тем же менеджером.
    model = factory_class._meta.model
    assert model._base_manager.filter(pk=instance.pk).exists()


def test_every_model_has_a_factory():
    """У каждой модели проекта есть фабрика — иначе тест на неё писать неудобно."""
    covered = {getattr(factories, name)._meta.model for name in FACTORY_NAMES}

    missing = []
    for label in ("common", "users", "catalog", "engagement", "billing", "notifications"):
        for model in django_apps.get_app_config(label).get_models():
            if model not in covered and model not in NO_FACTORY:
                missing.append(f"{label}.{model.__name__}")

    assert not missing, f"Нет фабрик для моделей: {', '.join(sorted(missing))}"
