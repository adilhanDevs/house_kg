"""Общие фикстуры для тестов."""

import pytest
from django.core.cache import cache
from rest_framework.test import APIClient


@pytest.fixture(autouse=True)
def clear_cache():
    """Кэш конфига и счётчики троттлинга не должны протекать между тестами."""
    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def api_client() -> APIClient:
    """Незалогиненный API-клиент."""
    return APIClient()


@pytest.fixture
def user(db):  # noqa: ANN001, ANN201 - фикстуры Django типизировать нечем
    from tests.factories import UserFactory

    return UserFactory()


@pytest.fixture
def auth_client(api_client: APIClient, user) -> APIClient:  # noqa: ANN001
    """API-клиент с JWT-токеном пользователя."""
    from rest_framework_simplejwt.tokens import RefreshToken

    token = RefreshToken.for_user(user)
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token.access_token}")
    return api_client
