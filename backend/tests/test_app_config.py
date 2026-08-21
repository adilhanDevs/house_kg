"""Тесты конфигурации приложения, онбординга, страниц и поддержки."""

import pytest
from django.core import mail
from django.core.cache import cache
from django.test import override_settings
from rest_framework.test import APIClient

from apps.common.models import AppConfig, OnboardingSlide, StaticPage, SupportTicket

CONFIG_URL = "/api/v1/app/config/"
ONBOARDING_URL = "/api/v1/app/onboarding/"
PAGES_URL = "/api/v1/app/pages/{slug}/"
TICKETS_URL = "/api/v1/support/tickets/"


@pytest.fixture
def app_config(db) -> AppConfig:
    config = AppConfig.get_solo()
    config.min_supported_version = "1.0.10"
    config.recommended_version = "1.2.0"
    config.android_store_url = "https://play.google.com/store/apps/details?id=kg.house"
    config.save()
    return config


# -- force_update ------------------------------------------------------------


@pytest.mark.django_db
@pytest.mark.parametrize(
    ("client_version", "expected"),
    [
        ("1.0.0", True),  # строковое сравнение тоже сказало бы True
        ("1.0.9", True),  # а вот тут строки врут: "1.0.9" > "1.0.10"
        ("1.0.10", False),
        ("1.2.0", False),
        ("2.0.0", False),
        ("", False),  # версию не прислали — не выгоняем на обновление
    ],
)
def test_force_update_is_calculated_by_semver(
    api_client: APIClient, app_config: AppConfig, client_version: str, expected: bool
) -> None:
    response = api_client.get(CONFIG_URL, {"platform": "android", "version": client_version})

    assert response.status_code == 200
    assert response.json()["force_update"] is expected


@pytest.mark.django_db
def test_config_returns_store_url_and_constants(
    api_client: APIClient, app_config: AppConfig
) -> None:
    body = api_client.get(CONFIG_URL, {"platform": "android"}).json()

    assert body["min_supported_version"] == "1.0.10"
    assert body["recommended_version"] == "1.2.0"
    assert body["store_url"] == app_config.android_store_url
    assert body["constants"] == {
        "topup_bonus_rate": 0.1,
        "promotion_price_per_day": 780,
        "max_photos": 20,
        "max_videos": 20,
        "free_active_listings": 3,
    }
    assert body["feature_flags"] == {"mortgage_calculator": False, "natural_search": False}


@pytest.mark.django_db
def test_config_documents_point_to_static_pages(
    api_client: APIClient, app_config: AppConfig
) -> None:
    StaticPage.objects.create(
        slug=StaticPage.Slug.TERMS,
        title="Пользовательское соглашение",
        content="# Соглашение",
        version="2026-08-01",
    )

    documents = api_client.get(CONFIG_URL).json()["documents"]

    assert documents["terms"]["version"] == "2026-08-01"
    assert documents["terms"]["url"].endswith("/api/v1/app/pages/terms/")


# -- режим обслуживания ------------------------------------------------------


@pytest.mark.django_db
def test_maintenance_mode_is_exposed(api_client: APIClient, app_config: AppConfig) -> None:
    app_config.maintenance_mode = True
    app_config.maintenance_message = "Обновляем базу, вернёмся через час."
    app_config.save()

    maintenance = api_client.get(CONFIG_URL).json()["maintenance"]

    assert maintenance == {
        "enabled": True,
        "message": "Обновляем базу, вернёмся через час.",
    }


# -- ETag / 304 --------------------------------------------------------------


@pytest.mark.django_db
def test_if_none_match_returns_304(api_client: APIClient, app_config: AppConfig) -> None:
    first = api_client.get(CONFIG_URL, {"platform": "android"})
    etag = first.headers["ETag"]
    assert first.status_code == 200
    assert etag

    second = api_client.get(CONFIG_URL, {"platform": "android"}, HTTP_IF_NONE_MATCH=etag)

    assert second.status_code == 304
    assert second.content == b""
    assert second.headers["ETag"] == etag


@pytest.mark.django_db
def test_etag_changes_when_config_changes(api_client: APIClient, app_config: AppConfig) -> None:
    etag = api_client.get(CONFIG_URL).headers["ETag"]

    app_config.recommended_version = "1.3.0"
    app_config.save()

    response = api_client.get(CONFIG_URL, HTTP_IF_NONE_MATCH=etag)

    assert response.status_code == 200
    assert response.json()["recommended_version"] == "1.3.0"


# -- онбординг и инвалидация кэша -------------------------------------------


@pytest.mark.django_db
def test_onboarding_returns_active_slides_in_order(api_client: APIClient) -> None:
    OnboardingSlide.objects.create(title="Третий", order=3)
    OnboardingSlide.objects.create(title="Первый", order=1)
    OnboardingSlide.objects.create(title="Скрытый", order=2, is_active=False)

    body = api_client.get(ONBOARDING_URL).json()

    assert [slide["title"] for slide in body] == ["Первый", "Третий"]


@pytest.mark.django_db
def test_slide_change_invalidates_cache(api_client: APIClient) -> None:
    slide = OnboardingSlide.objects.create(title="Ищите жильё", order=1)
    assert api_client.get(ONBOARDING_URL).json()[0]["title"] == "Ищите жильё"

    slide.title = "Ищите жильё по всему Бишкеку"
    slide.save()

    body = api_client.get(ONBOARDING_URL).json()
    assert body[0]["title"] == "Ищите жильё по всему Бишкеку"


# -- статические страницы ----------------------------------------------------


@pytest.mark.django_db
def test_static_page_is_returned(api_client: APIClient) -> None:
    StaticPage.objects.create(
        slug=StaticPage.Slug.PRIVACY,
        title="Политика конфиденциальности",
        content="# Политика",
        version="3",
    )

    response = api_client.get(PAGES_URL.format(slug="privacy"))

    assert response.status_code == 200
    assert response.json()["version"] == "3"
    assert response.json()["content"] == "# Политика"


@pytest.mark.django_db
def test_unknown_static_page_returns_404(api_client: APIClient) -> None:
    response = api_client.get(PAGES_URL.format(slug="about"))

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


# -- поддержка ---------------------------------------------------------------


TICKET_PAYLOAD = {
    "subject": "Не приходит код",
    "message": "Жду SMS пять минут, кода нет.",
    "contact_phone": "+996700123456",
    "app_version": "1.0.3",
    "platform": "android",
}


@pytest.mark.django_db
def test_sixth_support_ticket_within_an_hour_is_throttled(api_client: APIClient) -> None:
    for _ in range(5):
        assert api_client.post(TICKETS_URL, TICKET_PAYLOAD).status_code == 201

    response = api_client.post(TICKETS_URL, TICKET_PAYLOAD)

    assert response.status_code == 429
    assert response.json()["error"]["code"] == "throttled"
    assert SupportTicket.objects.count() == 5


@pytest.mark.django_db
@override_settings(SUPPORT_NOTIFY_EMAILS=["support@house.kg"])
def test_support_ticket_notifies_staff(
    api_client: APIClient, django_capture_on_commit_callbacks
) -> None:
    with django_capture_on_commit_callbacks(execute=True):
        response = api_client.post(TICKETS_URL, TICKET_PAYLOAD)

    assert response.status_code == 201
    ticket = SupportTicket.objects.get()
    assert ticket.subject == TICKET_PAYLOAD["subject"]
    assert ticket.user is None
    assert len(mail.outbox) == 1
    assert mail.outbox[0].to == ["support@house.kg"]
    assert str(ticket.pk) in mail.outbox[0].subject


@pytest.mark.django_db
def test_support_ticket_binds_authenticated_user(auth_client: APIClient, user) -> None:
    response = auth_client.post(TICKETS_URL, TICKET_PAYLOAD)

    assert response.status_code == 201
    assert SupportTicket.objects.get().user == user


@pytest.mark.django_db
def test_cache_is_isolated_between_tests() -> None:
    """Страховка: автофикстура conftest чистит кэш между тестами."""
    assert cache.get("app:onboarding") is None
