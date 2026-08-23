"""Тесты пополнения кошелька и обработки вебхуков."""

import json
import uuid
from datetime import timedelta
from decimal import Decimal

import pytest
from django.test import override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.billing.models import (
    Payment,
    PaymentLog,
    PaymentProviderConfig,
    PaymentStatus,
    WalletTransaction,
)
from apps.billing.payments import expire_payments, mask_sensitive
from apps.billing.services import get_wallet
from apps.common.enums import WalletEntryKind
from apps.notifications.models import Notification, NotificationType
from tests.factories import UserFactory

TOPUP_URL = "/api/v1/wallet/topup/"
STATUS_URL = "/api/v1/wallet/topup/{payment_id}/"
CONFIRM_URL = "/api/v1/wallet/topup/{payment_id}/mock-confirm/"
WEBHOOK_URL = "/api/v1/webhooks/payments/mock/"

SECRET = "webhook-secret"
webhook_settings = override_settings(PAYMENT_WEBHOOK_SECRET=SECRET, PAYMENT_PROVIDER="mock")


def client_for(user) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
    return client


@pytest.fixture
def user(db):
    return UserFactory()


@pytest.fixture
def auth(user):
    return client_for(user)


@pytest.fixture
def providers(db):
    PaymentProviderConfig.objects.create(
        code="mbank",
        name="MBank",
        deeplink_template="mbank://pay?target={provider_ref}&amount={amount}",
        order=0,
    )
    PaymentProviderConfig.objects.create(code="odengi", name="О!Деньги", order=1)


def create_payment(auth: APIClient, amount: int = 12_000, key: str | None = None):
    return auth.post(
        TOPUP_URL,
        {"amount_kgs": amount, "provider": "mock"},
        format="json",
        HTTP_IDEMPOTENCY_KEY=key or uuid.uuid4().hex,
    )


def webhook(client: APIClient, provider_ref: str, status_value: str = "succeeded", **extra):
    payload = {"provider_ref": provider_ref, "status": status_value, **extra}
    return client.post(
        WEBHOOK_URL,
        data=json.dumps(payload),
        content_type="application/json",
        HTTP_X_SIGNATURE=extra.pop("signature", SECRET),
    )


# -- маскирование ------------------------------------------------------------


def test_sensitive_fields_are_masked() -> None:
    masked = mask_sensitive(
        {
            "card_number": "4444555566667777",
            "cvv": "123",
            "access_token": "secret-token",
            "signature": "abcdef",
            "amount": "12000",
            "payer": {"pan": "4444555566667777", "name": "Азамат"},
            "items": [{"card": "1234"}],
        }
    )

    assert masked == {
        "card_number": "***",
        "cvv": "***",
        "access_token": "***",
        "signature": "***",
        "amount": "12000",
        "payer": {"pan": "***", "name": "Азамат"},
        "items": [{"card": "***"}],
    }


# -- создание счёта ----------------------------------------------------------


@pytest.mark.django_db
@webhook_settings
def test_topup_creates_payment(auth: APIClient, user, providers) -> None:
    response = create_payment(auth)

    assert response.status_code == 201
    body = response.json()
    assert body["bricks"] == 12_000
    assert body["bonus_bricks"] == 1_200
    assert body["total_bricks"] == 13_200
    assert body["amount_kgs"] == "12000.00"
    assert body["payment_url"]
    assert body["qr_code_url"].endswith(".png")
    assert body["expires_at"]
    assert [item["code"] for item in body["providers"]] == ["mbank", "odengi"]
    assert body["providers"][0]["deeplink"].startswith("mbank://pay?target=mock-")

    payment = Payment.objects.get()
    assert payment.status == PaymentStatus.PENDING
    assert payment.user == user
    # Баланс до оплаты не меняется.
    assert get_wallet(user).balance == 0


@pytest.mark.django_db
@webhook_settings
def test_topup_requires_idempotency_key(auth: APIClient) -> None:
    response = auth.post(TOPUP_URL, {"amount_kgs": 12_000}, format="json")

    assert response.status_code == 400
    assert "Idempotency-Key" in response.json()["error"]["message"]
    assert Payment.objects.count() == 0


@pytest.mark.django_db
@webhook_settings
def test_repeated_idempotency_key_returns_same_payment(auth: APIClient) -> None:
    key = "topup-key-1"

    first = create_payment(auth, key=key)
    second = create_payment(auth, key=key)

    assert first.status_code == second.status_code == 201
    assert first.json() == second.json()
    assert Payment.objects.count() == 1


@pytest.mark.django_db
@webhook_settings
def test_someone_elses_key_is_rejected(auth: APIClient) -> None:
    key = "shared-key"
    create_payment(auth, key=key)

    stranger = client_for(UserFactory())
    response = create_payment(stranger, key=key)

    assert response.status_code == 409
    assert Payment.objects.count() == 1


@pytest.mark.django_db
@webhook_settings
def test_amount_below_minimum_is_rejected(auth: APIClient) -> None:
    response = create_payment(auth, amount=50)

    assert response.status_code == 400
    assert "amount_kgs" in response.json()["error"]["details"]
    assert Payment.objects.count() == 0


@pytest.mark.django_db
@webhook_settings
def test_amount_above_maximum_is_rejected(auth: APIClient) -> None:
    assert create_payment(auth, amount=500_001).status_code == 400


@pytest.mark.django_db
@webhook_settings
def test_status_polling(auth: APIClient, user) -> None:
    payment_id = create_payment(auth).json()["payment_id"]

    body = auth.get(STATUS_URL.format(payment_id=payment_id)).json()

    assert body == {"status": "pending", "balance": 0, "credited_bricks": 0}


@pytest.mark.django_db
@webhook_settings
def test_other_users_payment_is_hidden(auth: APIClient) -> None:
    payment_id = create_payment(auth).json()["payment_id"]
    stranger = client_for(UserFactory())

    assert stranger.get(STATUS_URL.format(payment_id=payment_id)).status_code == 404


# -- вебхук ------------------------------------------------------------------


@pytest.mark.django_db
@webhook_settings
def test_webhook_credits_bricks_once(auth: APIClient, user, api_client: APIClient) -> None:
    create_payment(auth)
    payment = Payment.objects.get()

    first = webhook(api_client, payment.provider_ref)
    second = webhook(api_client, payment.provider_ref)

    assert first.status_code == second.status_code == 200

    payment.refresh_from_db()
    assert payment.status == PaymentStatus.SUCCEEDED
    assert payment.paid_at is not None

    wallet = get_wallet(user)
    assert wallet.balance == 13_200

    operations = WalletTransaction.objects.filter(wallet=wallet).order_by("created_at")
    assert operations.count() == 2
    assert [item.kind for item in operations] == [
        WalletEntryKind.TOPUP,
        WalletEntryKind.BONUS,
    ]
    assert operations[0].label == "+12.000 сом (12.000 кирпичей)"
    assert operations[1].label == "+1.200 кирпичей (бонус за пополнение)"
    assert operations[1].balance_after == 13_200
    assert operations[0].related == payment

    notification = Notification.objects.get()
    assert notification.type == NotificationType.WALLET_TOPUP


@pytest.mark.django_db
@webhook_settings
def test_webhook_with_bad_signature(auth: APIClient, user, api_client: APIClient) -> None:
    create_payment(auth)
    payment = Payment.objects.get()

    response = api_client.post(
        WEBHOOK_URL,
        data=json.dumps({"provider_ref": payment.provider_ref, "status": "succeeded"}),
        content_type="application/json",
        HTTP_X_SIGNATURE="wrong-secret",
    )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "permission_denied"

    payment.refresh_from_db()
    assert payment.status == PaymentStatus.PENDING
    assert get_wallet(user).balance == 0
    assert PaymentLog.objects.filter(status_code=403).exists()


@pytest.mark.django_db
@webhook_settings
def test_webhook_on_expired_payment_does_not_credit(
    auth: APIClient, user, api_client: APIClient
) -> None:
    create_payment(auth)
    payment = Payment.objects.get()
    Payment.objects.filter(pk=payment.pk).update(
        status=PaymentStatus.EXPIRED, expires_at=timezone.now() - timedelta(minutes=1)
    )

    response = webhook(api_client, payment.provider_ref)

    assert response.status_code == 200
    assert response.json()["status"] == PaymentStatus.EXPIRED
    assert get_wallet(user).balance == 0
    assert WalletTransaction.objects.count() == 0


@pytest.mark.django_db
@webhook_settings
def test_webhook_with_unknown_ref(api_client: APIClient) -> None:
    response = webhook(api_client, "mock-unknown")

    assert response.status_code == 404
    assert PaymentLog.objects.filter(status_code=404).exists()


@pytest.mark.django_db
@webhook_settings
def test_failed_webhook_marks_payment(auth: APIClient, user, api_client: APIClient) -> None:
    create_payment(auth)
    payment = Payment.objects.get()

    response = webhook(api_client, payment.provider_ref, status_value="failed")

    assert response.status_code == 200
    payment.refresh_from_db()
    assert payment.status == PaymentStatus.FAILED
    assert get_wallet(user).balance == 0


@pytest.mark.django_db
@webhook_settings
def test_amount_mismatch_is_not_credited(auth: APIClient, user, api_client: APIClient) -> None:
    create_payment(auth)
    payment = Payment.objects.get()

    response = webhook(api_client, payment.provider_ref, amount="1")

    assert response.status_code == 200
    payment.refresh_from_db()
    assert payment.status == PaymentStatus.PENDING
    assert get_wallet(user).balance == 0


@pytest.mark.django_db
@webhook_settings
def test_webhook_payload_is_logged_without_secrets(auth: APIClient, api_client: APIClient) -> None:
    create_payment(auth)
    payment = Payment.objects.get()

    webhook(api_client, payment.provider_ref, card="4444555566667777", cvv="123")

    logged = PaymentLog.objects.filter(payment=payment, direction="in").first()
    assert logged.payload["card"] == "***"
    assert logged.payload["cvv"] == "***"
    assert "4444555566667777" not in json.dumps(logged.payload)


# -- mock-confirm ------------------------------------------------------------


@pytest.mark.django_db
@override_settings(DEBUG=True, PAYMENT_PROVIDER="mock", PAYMENT_WEBHOOK_SECRET=SECRET)
def test_mock_confirm_credits_in_debug(auth: APIClient, user) -> None:
    payment_id = create_payment(auth).json()["payment_id"]

    response = auth.post(CONFIRM_URL.format(payment_id=payment_id))

    assert response.status_code == 200
    assert response.json() == {
        "status": PaymentStatus.SUCCEEDED,
        "balance": 13_200,
        "credited_bricks": 13_200,
    }


@pytest.mark.django_db
@override_settings(DEBUG=False, PAYMENT_PROVIDER="mock", PAYMENT_WEBHOOK_SECRET=SECRET)
def test_mock_confirm_is_hidden_in_production(auth: APIClient) -> None:
    payment_id = create_payment(auth).json()["payment_id"]

    assert auth.post(CONFIRM_URL.format(payment_id=payment_id)).status_code == 404
    assert get_wallet(Payment.objects.get().user).balance == 0


# -- истечение счёта ---------------------------------------------------------


@pytest.mark.django_db
@webhook_settings
def test_expire_payments(auth: APIClient) -> None:
    create_payment(auth)
    fresh = create_payment(auth)
    stale = Payment.objects.exclude(pk=fresh.json()["payment_id"]).first()
    Payment.objects.filter(pk=stale.pk).update(expires_at=timezone.now() - timedelta(minutes=1))

    assert expire_payments() == 1

    stale.refresh_from_db()
    assert stale.status == PaymentStatus.EXPIRED
    assert Payment.objects.filter(status=PaymentStatus.PENDING).count() == 1


@pytest.mark.django_db
@webhook_settings
def test_bonus_matches_configured_rate(auth: APIClient) -> None:
    with override_settings(TOPUP_BONUS_RATE=0.10):
        body = create_payment(auth, amount=100).json()

    assert body["bricks"] == 100
    assert body["bonus_bricks"] == 10
    assert Decimal(body["amount_kgs"]) == Decimal("100.00")
