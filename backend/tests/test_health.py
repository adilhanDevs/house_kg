"""Smoke-тест health-check эндпоинта."""

from unittest.mock import patch

import pytest
from rest_framework.test import APIClient

HEALTH_URL = "/api/v1/health/"


@pytest.mark.django_db
def test_health_returns_ok(api_client: APIClient) -> None:
    """Все зависимости на месте — 200 и все флаги true."""
    response = api_client.get(HEALTH_URL)

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "db": True, "redis": True}


@pytest.mark.django_db
def test_health_returns_503_when_db_is_down(api_client: APIClient) -> None:
    """Если БД недоступна — 503 и db=false."""
    with patch("apps.common.views.check_database", return_value=False):
        response = api_client.get(HEALTH_URL)

    assert response.status_code == 503
    assert response.json() == {"status": "error", "db": False, "redis": True}
