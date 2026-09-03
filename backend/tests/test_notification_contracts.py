"""Канонический контракт уведомлений: типы, payload и данные для маршрутизации.

Проверяем то, на что завязан клиент: значение `type`, набор полей payload и
компактность data-части push. Разрастание payload здесь ловится тестом, а не
на телефоне, где FCM просто отбросит сообщение больше 4 КБ.
"""

from uuid import uuid4

import pytest

from apps.notifications.models import Notification, NotificationSettings, NotificationType
from apps.notifications.push import _data_payload
from tests.factories import ConversationFactory, ListingFactory, UserFactory

# Значения, на которые завязаны клиент и уже лежащие в базе строки.
# Менять их нельзя без миграции данных.
CANONICAL_TYPES = {
    "new_message",
    "price_drop",
    "saved_filter_match",
    "listing_moderated",
    "promotion_expiring",
    "wallet_topup",
    "system",
}


def test_type_values_are_canonical_and_stable() -> None:
    assert {choice.value for choice in NotificationType} == CANONICAL_TYPES


def test_every_type_maps_to_a_preference_field() -> None:
    """Тип без настройки означал бы push, который нельзя отключить."""
    for choice in NotificationType:
        field = NotificationSettings.TYPE_FIELDS.get(choice.value)
        assert field, f"у типа {choice.value} нет поля настроек"
        assert hasattr(NotificationSettings(), field)


@pytest.mark.django_db
def test_new_message_payload_carries_routing_contract() -> None:
    """Сообщение должно открывать конкретный диалог, а не список."""
    from apps.messaging.services import send_message

    conversation = ConversationFactory()
    buyer = conversation.buyer
    buyer.name = "Айбек"
    buyer.save(update_fields=["name"])

    send_message(
        user=buyer,
        conversation=conversation,
        text="Здравствуйте, актуально?",
        client_message_id=uuid4(),
    )

    notification = Notification.objects.get(
        user=conversation.seller, type=NotificationType.NEW_MESSAGE
    )
    payload = notification.payload
    assert payload["conversation_id"] == str(conversation.id)
    assert payload["listing_slug"] == conversation.listing_slug
    assert payload["sender_id"] == buyer.pk
    assert payload["sender_name"] == "Айбек"
    assert payload["preview"].startswith("Здравствуйте")
    # Получатель — только собеседник, себе уведомление не приходит.
    assert not Notification.objects.filter(user=buyer).exists()


@pytest.mark.django_db
def test_push_data_is_limited_to_the_routing_contract() -> None:
    """В data уходит то, что нужно для перехода, а не весь payload карточки."""
    user = UserFactory()
    listing = ListingFactory()
    notification = Notification.objects.create(
        user=user,
        type=NotificationType.PRICE_DROP,
        listing=listing,
        title="Цена снизилась",
        body="текст",
        payload={
            "listing_slug": listing.slug,
            "old_price": "107000.00",
            "new_price": "102000.00",
            "currency": "USD",
            "drop_amount": "5000.00",
            "drop_percent": "4.67",
            "reason": "favorite",
            # Поля карточки: в push им делать нечего.
            "address": "улица, дом",
            "district": "Технопарк",
            "area": "92.00",
            "floor": 8,
            "floors": 12,
            "event_at": "2026-09-03T00:00:00+00:00",
        },
    )

    data = _data_payload(notification)

    assert data["type"] == "price_drop"
    assert data["notification_id"] == str(notification.pk)
    assert data["listing_slug"] == listing.slug
    assert data["drop_percent"] == "4.67"
    assert data["reason"] == "favorite"
    for leaked in ("address", "district", "area", "floor", "floors", "event_at"):
        assert leaked not in data, f"{leaked} не должно уезжать в push"


@pytest.mark.django_db
def test_push_data_values_are_all_strings() -> None:
    """FCM принимает только строки: число в data роняет отправку целиком."""
    user = UserFactory()
    listing = ListingFactory()
    notification = Notification.objects.create(
        user=user,
        type=NotificationType.NEW_MESSAGE,
        listing=listing,
        payload={"conversation_id": "c-1", "sender_id": 42, "preview": "привет"},
    )

    data = _data_payload(notification)

    assert all(isinstance(value, str) for value in data.values())
    assert data["sender_id"] == "42"


@pytest.mark.django_db
def test_unknown_payload_keys_do_not_reach_push() -> None:
    """Новое поле в payload не должно молча просачиваться в push."""
    user = UserFactory()
    notification = Notification.objects.create(
        user=user,
        type=NotificationType.SYSTEM,
        payload={"kind": "test", "internal_debug": "секрет"},
    )

    data = _data_payload(notification)
    assert "internal_debug" not in data


@pytest.mark.django_db
def test_price_drop_reason_maps_to_the_right_preference() -> None:
    """«По избранному» и «по просмотренному» отключаются независимо."""
    settings_row = NotificationSettings(
        push_enabled=True, price_drop_enabled=True, price_drop_viewed_enabled=False
    )
    assert settings_row.allows(NotificationType.PRICE_DROP) is True
    assert settings_row.allows_reason(NotificationType.PRICE_DROP, "viewed") is False
    assert settings_row.allows_reason(NotificationType.PRICE_DROP, "favorite") is True
    assert settings_row.allows_reason(NotificationType.NEW_MESSAGE, None) is True
