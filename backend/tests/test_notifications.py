"""Тесты уведомлений, настроек, устройств и push."""

from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import patch

import pytest
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.notifications.models import (
    DeviceToken,
    Notification,
    NotificationSettings,
    NotificationType,
    PushOutbox,
)
from apps.notifications.push import send_to_user
from apps.notifications.services import notify, register_device
from apps.notifications.tasks import notify_price_drop, send_push
from tests.factories import CityFactory, DistrictFactory, ListingFactory, UserFactory

LIST_URL = "/api/v1/notifications/"
UNREAD_URL = "/api/v1/notifications/unread-count/"
READ_URL = "/api/v1/notifications/read/"
SETTINGS_URL = "/api/v1/notifications/settings/"
DEVICES_URL = "/api/v1/devices/"
DEVICE_URL = "/api/v1/devices/{token}/"
CANONICAL_DEVICES_URL = "/api/v1/notifications/devices/"
CURRENT_DEVICE_URL = "/api/v1/notifications/devices/current/"
FAVOURITE_URL = "/api/v1/listings/{slug}/favourite/"


def client_for(user) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
    return client


def fcm_response(*successes: bool, exception=None):
    """Ответ FCM в форме, которую отдаёт send_each_for_multicast."""
    responses = [
        SimpleNamespace(success=ok, exception=None if ok else exception) for ok in successes
    ]
    return SimpleNamespace(success_count=sum(successes), responses=responses)


@pytest.fixture
def user(db):
    return UserFactory()


@pytest.fixture
def auth(user):
    return client_for(user)


@pytest.fixture
def district(db):
    return DistrictFactory(city=CityFactory(slug="bishkek", is_default=True), name="Технопарк")


# -- сервис notify -----------------------------------------------------------


@pytest.mark.django_db
def test_settings_are_created_with_user() -> None:
    user = UserFactory()

    assert NotificationSettings.objects.filter(user=user).exists()


@pytest.mark.django_db
def test_notify_creates_one_record_and_one_outbox_row(user) -> None:
    """Доставка ставится строкой в базе, в той же транзакции, что и событие."""
    notification = notify(
        user,
        NotificationType.SYSTEM,
        title="Заголовок",
        body="Текст",
        payload={"kind": "test"},
    )

    assert Notification.objects.count() == 1
    assert notification.payload == {"kind": "test"}
    assert PushOutbox.objects.filter(notification=notification).count() == 1


@pytest.mark.django_db
def test_notify_event_key_is_idempotent_per_user(user) -> None:
    """Повторное доменное событие не создаёт ни второго уведомления, ни второй доставки."""
    first = notify(user, NotificationType.PRICE_DROP, "Цена", event_key="price-drop:7")
    second = notify(user, NotificationType.PRICE_DROP, "Цена", event_key="price-drop:7")

    assert first.pk == second.pk
    assert Notification.objects.filter(user=user, event_key="price-drop:7").count() == 1
    assert PushOutbox.objects.filter(notification=first).count() == 1


@pytest.mark.django_db
def test_notify_event_key_can_be_reused_for_another_recipient(
    user, django_capture_on_commit_callbacks
) -> None:
    other = UserFactory()

    with django_capture_on_commit_callbacks(execute=False):
        notify(user, NotificationType.PRICE_DROP, "Цена", event_key="price-drop:8")
        notify(other, NotificationType.PRICE_DROP, "Цена", event_key="price-drop:8")

    assert Notification.objects.filter(event_key="price-drop:8").count() == 2


@pytest.mark.django_db
def test_push_is_skipped_when_disabled(user) -> None:
    NotificationSettings.objects.filter(user=user).update(push_enabled=False)
    DeviceToken.objects.create(user=user, token="token-1", platform="android")
    notification = Notification.objects.create(
        user=user, type=NotificationType.PRICE_DROP, title="Цена"
    )

    with patch("firebase_admin.messaging.send_each_for_multicast") as fcm:
        assert send_push(notification.pk) == 0

    # Уведомление в базе есть, push не ушёл.
    assert Notification.objects.count() == 1
    fcm.assert_not_called()


@pytest.mark.django_db
def test_push_is_skipped_for_disabled_type(user) -> None:
    NotificationSettings.objects.filter(user=user).update(price_drop_enabled=False)
    DeviceToken.objects.create(user=user, token="token-1", platform="android")
    notification = Notification.objects.create(
        user=user, type=NotificationType.PRICE_DROP, title="Цена"
    )

    with patch("firebase_admin.messaging.send_each_for_multicast") as fcm:
        assert send_to_user(user, notification) == 0

    fcm.assert_not_called()


# -- отправка push -----------------------------------------------------------


@pytest.mark.django_db
def test_push_is_sent_to_active_devices(user) -> None:
    DeviceToken.objects.create(user=user, token="alive", platform="android")
    DeviceToken.objects.create(user=user, token="disabled", platform="ios", is_active=False)
    notification = Notification.objects.create(
        user=user, type=NotificationType.SYSTEM, title="Привет", body="Текст"
    )

    with (
        patch("apps.notifications.push.get_fcm_app", return_value=object()),
        patch(
            "firebase_admin.messaging.send_each_for_multicast",
            return_value=fcm_response(True),
        ) as fcm,
    ):
        assert send_to_user(user, notification) == 1

    message = fcm.call_args.args[0]
    assert message.tokens == ["alive"]
    assert message.data["notification_id"] == str(notification.pk)


@pytest.mark.django_db
def test_unregistered_token_is_deactivated(user) -> None:
    DeviceToken.objects.create(user=user, token="dead", platform="android")
    DeviceToken.objects.create(user=user, token="alive", platform="android")
    notification = Notification.objects.create(
        user=user, type=NotificationType.SYSTEM, title="Привет"
    )

    unregistered = SimpleNamespace(code="UNREGISTERED")
    response = fcm_response(False, True, exception=unregistered)
    response.responses[0].exception = unregistered

    with (
        patch("apps.notifications.push.get_fcm_app", return_value=object()),
        patch("firebase_admin.messaging.send_each_for_multicast", return_value=response),
    ):
        assert send_to_user(user, notification) == 1

    assert DeviceToken.objects.get(token="dead").is_active is False
    assert DeviceToken.objects.get(token="alive").is_active is True


@pytest.mark.django_db
def test_push_without_fcm_credentials_is_noop(user) -> None:
    DeviceToken.objects.create(user=user, token="alive", platform="android")
    notification = Notification.objects.create(
        user=user, type=NotificationType.SYSTEM, title="Привет"
    )

    with patch("apps.notifications.push.get_fcm_app", return_value=None):
        assert send_to_user(user, notification) == 0


# -- лента -------------------------------------------------------------------


@pytest.mark.django_db
def test_unread_count_matches_reality(auth: APIClient, user) -> None:
    for index in range(5):
        Notification.objects.create(user=user, title=f"№{index}", type=NotificationType.SYSTEM)
    Notification.objects.filter(title="№0").update(is_read=True)
    Notification.objects.create(user=UserFactory(), title="чужое", type=NotificationType.SYSTEM)

    assert auth.get(UNREAD_URL).json() == {"count": 4}


@pytest.mark.django_db
def test_mark_all_read_resets_counter(auth: APIClient, user) -> None:
    for index in range(3):
        Notification.objects.create(user=user, title=f"№{index}", type=NotificationType.SYSTEM)
    stranger_notification = Notification.objects.create(
        user=UserFactory(), title="чужое", type=NotificationType.SYSTEM
    )

    response = auth.post(READ_URL, {"all": True}, format="json")

    assert response.status_code == 200
    assert response.json() == {"updated": 3, "unread_count": 0}
    assert auth.get(UNREAD_URL).json() == {"count": 0}
    # Чужие уведомления не тронуты.
    stranger_notification.refresh_from_db()
    assert stranger_notification.is_read is False


@pytest.mark.django_db
def test_mark_read_by_ids(auth: APIClient, user) -> None:
    first = Notification.objects.create(user=user, title="1", type=NotificationType.SYSTEM)
    Notification.objects.create(user=user, title="2", type=NotificationType.SYSTEM)

    response = auth.post(READ_URL, {"ids": [first.pk]}, format="json")

    assert response.json() == {"updated": 1, "unread_count": 1}


@pytest.mark.django_db
def test_mark_read_requires_ids_or_all(auth: APIClient) -> None:
    assert auth.post(READ_URL, {}, format="json").status_code == 400


@pytest.mark.django_db
def test_list_filters_by_read_and_type(auth: APIClient, user) -> None:
    Notification.objects.create(user=user, title="цена", type=NotificationType.PRICE_DROP)
    Notification.objects.create(
        user=user, title="фильтр", type=NotificationType.SAVED_FILTER_MATCH, is_read=True
    )

    unread = auth.get(LIST_URL, {"is_read": "false"}).json()
    by_type = auth.get(LIST_URL, {"type": "price_drop"}).json()

    assert [item["title"] for item in unread["results"]] == ["цена"]
    assert [item["title"] for item in by_type["results"]] == ["цена"]


@pytest.mark.django_db
def test_delete_own_notification_only(auth: APIClient, user) -> None:
    mine = Notification.objects.create(user=user, title="моё", type=NotificationType.SYSTEM)
    stranger = Notification.objects.create(
        user=UserFactory(), title="чужое", type=NotificationType.SYSTEM
    )

    assert auth.delete(f"{LIST_URL}{mine.pk}/").status_code == 204
    assert auth.delete(f"{LIST_URL}{stranger.pk}/").status_code == 404
    assert Notification.objects.filter(pk=stranger.pk).exists()


# -- настройки и устройства --------------------------------------------------


@pytest.mark.django_db
def test_settings_read_and_update(auth: APIClient, user) -> None:
    body = auth.get(SETTINGS_URL).json()
    assert body["push_enabled"] is True
    assert body["new_message_enabled"] is True
    assert body["price_drop_viewed_enabled"] is True
    assert body["new_listing_match_enabled"] is True

    response = auth.patch(
        SETTINGS_URL,
        {"price_drop_enabled": False, "new_message_enabled": False},
        format="json",
    )

    assert response.status_code == 200
    assert response.json()["price_drop_enabled"] is False
    assert response.json()["new_message_enabled"] is False
    assert NotificationSettings.objects.get(user=user).price_drop_enabled is False
    assert NotificationSettings.objects.get(user=user).new_message_enabled is False


@pytest.mark.django_db
def test_new_listing_match_setting_keeps_legacy_alias(auth: APIClient, user) -> None:
    response = auth.patch(
        SETTINGS_URL,
        {"new_listing_match_enabled": False},
        format="json",
    )

    assert response.status_code == 200
    assert response.json()["new_listing_match_enabled"] is False
    assert response.json()["saved_filter_enabled"] is False
    assert NotificationSettings.objects.get(user=user).saved_filter_enabled is False


@pytest.mark.django_db
def test_device_registration_is_upsert(auth: APIClient, user) -> None:
    first = auth.post(
        DEVICES_URL,
        {"token": "device-token", "platform": "android", "app_version": "1.0.0"},
        format="json",
    )
    second = auth.post(
        DEVICES_URL,
        {"token": "device-token", "platform": "android", "app_version": "1.1.0"},
        format="json",
    )

    assert first.status_code == second.status_code == 200
    assert DeviceToken.objects.count() == 1
    assert DeviceToken.objects.get().app_version == "1.1.0"


@pytest.mark.django_db
def test_device_token_moves_to_current_user(user) -> None:
    previous_owner = UserFactory()
    register_device(previous_owner, "shared-token", "android")

    device = register_device(user, "shared-token", "android", "1.2.0")

    assert DeviceToken.objects.count() == 1
    assert device.user == user
    assert device.is_active is True


@pytest.mark.django_db
def test_device_id_refresh_replaces_token_without_leaving_old_active(user) -> None:
    original = register_device(
        user,
        "old-token",
        "android",
        device_id="installation-1",
        locale="ru",
    )

    refreshed = register_device(
        user,
        "new-token",
        "android",
        device_id="installation-1",
        locale="ky",
        timezone_name="Asia/Bishkek",
    )

    assert refreshed.pk == original.pk
    assert DeviceToken.objects.count() == 1
    assert refreshed.token == "new-token"
    assert refreshed.locale == "ky"
    assert refreshed.is_active is True


@pytest.mark.django_db
def test_device_id_account_switch_reassigns_the_installation(user) -> None:
    previous_owner = UserFactory()
    original = register_device(
        previous_owner,
        "old-account-token",
        "ios",
        device_id="installation-2",
    )

    moved = register_device(
        user,
        "new-account-token",
        "ios",
        device_id="installation-2",
    )

    assert moved.pk == original.pk
    assert moved.user == user
    assert moved.token == "new-account-token"
    assert DeviceToken.objects.filter(user=previous_owner, is_active=True).count() == 0


@pytest.mark.django_db
def test_canonical_device_api_and_current_deactivation(auth: APIClient, user) -> None:
    registered = auth.post(
        CANONICAL_DEVICES_URL,
        {
            "token": "canonical-token",
            "platform": "android",
            "device_id": "installation-3",
            "locale": "ru",
            "timezone": "Asia/Bishkek",
        },
        format="json",
    )
    deactivated = auth.delete(
        CURRENT_DEVICE_URL,
        {"device_id": "installation-3"},
        format="json",
    )

    assert registered.status_code == 200
    assert registered.json()["device_id"] == "installation-3"
    assert deactivated.status_code == 204
    assert DeviceToken.objects.get(user=user, device_id="installation-3").is_active is False


@pytest.mark.django_db
def test_current_device_deactivation_cannot_touch_another_user(auth: APIClient) -> None:
    stranger_device = register_device(
        UserFactory(),
        "stranger-token",
        "android",
        device_id="stranger-installation",
    )

    response = auth.delete(
        CURRENT_DEVICE_URL,
        {"device_id": "stranger-installation"},
        format="json",
    )

    assert response.status_code == 404
    stranger_device.refresh_from_db()
    assert stranger_device.is_active is True


@pytest.mark.django_db
def test_device_registration_rejects_unknown_timezone(auth: APIClient) -> None:
    response = auth.post(
        CANONICAL_DEVICES_URL,
        {
            "token": "bad-timezone-token",
            "platform": "android",
            "device_id": "installation-4",
            "locale": "ru",
            "timezone": "Moon/Sea_of_Tranquility",
        },
        format="json",
    )

    assert response.status_code == 400


@pytest.mark.django_db
def test_device_deactivation(auth: APIClient, user) -> None:
    register_device(user, "device-token", "ios")

    assert auth.delete(DEVICE_URL.format(token="device-token")).status_code == 204
    assert DeviceToken.objects.get().is_active is False
    assert auth.delete(DEVICE_URL.format(token="unknown")).status_code == 404


@pytest.mark.django_db
def test_notifications_require_authentication(api_client: APIClient) -> None:
    assert api_client.get(LIST_URL).status_code == 401
    assert api_client.get(UNREAD_URL).status_code == 401
    assert api_client.post(DEVICES_URL, {}, format="json").status_code == 401


# -- снижение цены -----------------------------------------------------------


def _favourite_with_drop(user, district, old: str, new: str):
    from apps.engagement.models import Favourite

    listing = ListingFactory(district=district, rooms=3, price=Decimal(new))
    return Favourite.objects.create(user=user, listing=listing, price_at_add=Decimal(old)), listing


@pytest.mark.django_db
def test_two_percent_drop_is_ignored(user, district) -> None:
    _favourite_with_drop(user, district, "100000", "98000")

    assert notify_price_drop() == 0
    assert Notification.objects.count() == 0


@pytest.mark.django_db
def test_five_percent_drop_creates_single_notification(user, district) -> None:
    favourite, listing = _favourite_with_drop(user, district, "102000", "97000")

    assert notify_price_drop() == 1

    notification = Notification.objects.get()
    assert notification.type == NotificationType.PRICE_DROP
    assert notification.listing == listing
    expected = f"Цена снизилась на 5%: Технопарк, 3-комн. — {listing.price_display}"
    assert notification.body == expected
    assert notification.body.startswith("Цена снизилась на 5%: Технопарк, 3-комн. — 97")
    assert notification.payload["listing_slug"] == listing.slug

    # Отметка цены обновлена — повторно о том же снижении не напишем.
    favourite.refresh_from_db()
    assert favourite.price_at_add == Decimal("97000.00")
    assert notify_price_drop() == 0
    assert Notification.objects.count() == 1


@pytest.mark.django_db
def test_price_growth_is_ignored(user, district) -> None:
    _favourite_with_drop(user, district, "90000", "100000")

    assert notify_price_drop() == 0


@pytest.mark.django_db
def test_favourite_remembers_price_at_add(auth: APIClient, user, district) -> None:
    from apps.engagement.models import Favourite

    listing = ListingFactory(district=district, price=Decimal("120000"))

    auth.post(FAVOURITE_URL.format(slug=listing.slug))

    assert Favourite.objects.get().price_at_add == Decimal("120000.00")
