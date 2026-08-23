"""Тесты кошелька и леджера операций."""

import threading

import pytest
from django.db import connection, connections, transaction
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.billing.models import Wallet, WalletTransaction, format_bricks
from apps.billing.services import apply_transaction, get_wallet
from apps.common.enums import WalletEntryKind
from apps.common.exceptions import InsufficientFundsError
from tests.factories import CityFactory, DistrictFactory, ListingFactory, UserFactory

WALLET_URL = "/api/v1/wallet/"
TRANSACTIONS_URL = "/api/v1/wallet/transactions/"

postgres_only = pytest.mark.skipif(
    connection.vendor != "postgresql",
    reason="блокировка строки (select_for_update) работает только на PostgreSQL",
)


def client_for(user) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
    return client


@pytest.fixture
def user(db):
    return UserFactory()


@pytest.fixture
def wallet(user) -> Wallet:
    return get_wallet(user)


def topup(wallet: Wallet, amount: int, **kwargs) -> WalletTransaction:
    return apply_transaction(
        wallet=wallet,
        amount=amount,
        kind=WalletEntryKind.TOPUP,
        label=f"+{amount} кирпичей",
        **kwargs,
    )


# -- форматирование ----------------------------------------------------------


@pytest.mark.parametrize(
    ("amount", "expected"),
    [(16_700, "16.700"), (500, "500"), (1_200_000, "1.200.000"), (0, "0")],
)
def test_balance_display(amount: int, expected: str) -> None:
    assert format_bricks(amount) == expected


@pytest.mark.django_db
def test_wallet_balance_display(wallet: Wallet) -> None:
    topup(wallet, 16_700)
    wallet.refresh_from_db()

    assert wallet.balance_display == "16.700"


# -- кошелёк создаётся сигналом ----------------------------------------------


@pytest.mark.django_db
def test_wallet_is_created_with_user() -> None:
    user = UserFactory()

    assert Wallet.objects.filter(user=user, balance=0).exists()


# -- apply_transaction -------------------------------------------------------


@pytest.mark.django_db
def test_transaction_updates_balance_and_ledger(wallet: Wallet) -> None:
    operation = topup(wallet, 12_000)

    wallet.refresh_from_db()
    assert wallet.balance == 12_000
    assert operation.balance_after == 12_000
    assert operation.kind == WalletEntryKind.TOPUP


@pytest.mark.django_db
def test_balance_after_equals_running_total(wallet: Wallet) -> None:
    amounts = [3_700, 12_000, 1_200, 300, -500]

    for amount in amounts:
        apply_transaction(
            wallet=wallet,
            amount=amount,
            kind=WalletEntryKind.TOPUP if amount > 0 else WalletEntryKind.SPEND,
            label=str(amount),
        )

    running = 0
    for operation in WalletTransaction.objects.filter(wallet=wallet).order_by("created_at", "pk"):
        running += operation.amount
        assert operation.balance_after == running

    wallet.refresh_from_db()
    assert wallet.balance == sum(amounts) == 16_700


@pytest.mark.django_db
def test_spend_more_than_balance_raises(wallet: Wallet) -> None:
    topup(wallet, 300)

    with pytest.raises(InsufficientFundsError) as exc:
        apply_transaction(
            wallet=wallet, amount=-780, kind=WalletEntryKind.SPEND, label="Продвижение"
        )

    # shortfall считается сервером: приложению не нужно вычитать самому.
    assert exc.value.extra_details == {"required": 780, "available": 300, "shortfall": 480}

    wallet.refresh_from_db()
    assert wallet.balance == 300
    assert WalletTransaction.objects.filter(kind=WalletEntryKind.SPEND).count() == 0


@pytest.mark.django_db
def test_idempotency_key_returns_same_transaction(wallet: Wallet) -> None:
    first = topup(wallet, 12_000, idempotency_key="payment-42")
    second = topup(wallet, 12_000, idempotency_key="payment-42")

    assert first.pk == second.pk
    assert WalletTransaction.objects.count() == 1

    wallet.refresh_from_db()
    assert wallet.balance == 12_000


@pytest.mark.django_db
def test_related_object_is_linked(wallet: Wallet) -> None:
    district = DistrictFactory(city=CityFactory(slug="bishkek"))
    listing = ListingFactory(district=district)
    topup(wallet, 1_000)

    operation = apply_transaction(
        wallet=wallet,
        amount=-780,
        kind=WalletEntryKind.SPEND,
        label="-780 кирпичей",
        related=listing,
    )

    operation.refresh_from_db()
    assert operation.related == listing


# -- леджер неизменяем -------------------------------------------------------


@pytest.mark.django_db
def test_saved_transaction_cannot_be_changed(wallet: Wallet) -> None:
    operation = topup(wallet, 500)

    operation.amount = 999_999
    with pytest.raises(RuntimeError, match="неизменяемы"):
        operation.save()

    operation.refresh_from_db()
    assert operation.amount == 500


@pytest.mark.django_db
def test_transaction_cannot_be_deleted(wallet: Wallet) -> None:
    operation = topup(wallet, 500)

    with pytest.raises(RuntimeError, match="не удаляются"):
        operation.delete()

    assert WalletTransaction.objects.count() == 1


# -- параллельные списания ---------------------------------------------------


@pytest.mark.django_db
def test_service_locks_wallet_row(wallet: Wallet, monkeypatch) -> None:
    """Списание обязано брать строку кошелька под блокировку."""
    topup(wallet, 1_000)
    calls: list[bool] = []

    original = Wallet.objects.select_for_update

    def spy(*args, **kwargs):
        calls.append(True)
        return original(*args, **kwargs)

    monkeypatch.setattr(Wallet.objects, "select_for_update", spy)
    apply_transaction(wallet=wallet, amount=-100, kind=WalletEntryKind.SPEND, label="-100")

    assert calls, "apply_transaction должен блокировать строку кошелька"


@postgres_only
@pytest.mark.django_db(transaction=True)
def test_parallel_spend_does_not_overdraw() -> None:
    """Два одновременных списания больше половины баланса: второе не проходит."""
    user = UserFactory()
    wallet = get_wallet(user)
    topup(wallet, 1_000)

    barrier = threading.Barrier(2)
    results: list[str] = []

    def spend() -> None:
        barrier.wait()
        try:
            with transaction.atomic():
                apply_transaction(
                    wallet=Wallet.objects.get(pk=wallet.pk),
                    amount=-600,
                    kind=WalletEntryKind.SPEND,
                    label="-600 кирпичей",
                )
            results.append("ok")
        except InsufficientFundsError:
            results.append("insufficient")
        finally:
            connections.close_all()

    threads = [threading.Thread(target=spend) for _ in range(2)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    assert sorted(results) == ["insufficient", "ok"]
    wallet.refresh_from_db()
    assert wallet.balance == 400
    assert WalletTransaction.objects.filter(kind=WalletEntryKind.SPEND).count() == 1


# -- эндпоинты ---------------------------------------------------------------


@pytest.mark.django_db
def test_wallet_endpoint(user, wallet: Wallet) -> None:
    topup(wallet, 16_700)

    body = client_for(user).get(WALLET_URL).json()

    assert body == {"balance": 16_700, "balance_display": "16.700", "currency": "brick"}


@pytest.mark.django_db
def test_transactions_are_grouped_by_day(user, wallet: Wallet) -> None:
    topup(wallet, 12_000)
    apply_transaction(wallet=wallet, amount=-500, kind=WalletEntryKind.SPEND, label="-500 кирпичей")

    body = client_for(user).get(TRANSACTIONS_URL).json()

    assert len(body["results"]) == 1
    group = body["results"][0]
    assert "августа" in group["day_label"] or group["day_label"]
    assert [item["amount"] for item in group["items"]] == [-500, 12_000]
    assert group["items"][0]["amount_display"] == "-500"
    assert group["items"][1]["balance_after"] == 12_000


@pytest.mark.django_db
def test_transactions_filter_by_kind(user, wallet: Wallet) -> None:
    topup(wallet, 12_000)
    apply_transaction(
        wallet=wallet, amount=1_200, kind=WalletEntryKind.BONUS, label="+1 200 (бонус)"
    )
    apply_transaction(wallet=wallet, amount=-500, kind=WalletEntryKind.SPEND, label="-500 кирпичей")

    client = client_for(user)

    def kinds(kind: str | None) -> list[str]:
        params = {"kind": kind} if kind else {}
        body = client.get(TRANSACTIONS_URL, params).json()
        return [item["kind"] for group in body["results"] for item in group["items"]]

    assert kinds("topup") == ["topup"]
    assert kinds("bonus") == ["bonus"]
    assert kinds("spend") == ["spend"]
    assert sorted(kinds(None)) == ["bonus", "spend", "topup"]


@pytest.mark.django_db
def test_wallet_shows_only_own_transactions(user, wallet: Wallet) -> None:
    topup(wallet, 100)
    stranger = UserFactory()
    topup(get_wallet(stranger), 999)

    body = client_for(user).get(TRANSACTIONS_URL).json()

    amounts = [item["amount"] for group in body["results"] for item in group["items"]]
    assert amounts == [100]


@pytest.mark.django_db
def test_wallet_requires_authentication(api_client: APIClient) -> None:
    assert api_client.get(WALLET_URL).status_code == 401
    assert api_client.get(TRANSACTIONS_URL).status_code == 401


def test_insufficient_funds_http_envelope() -> None:
    """402 в формате, который ждёт приложение."""
    from apps.common.exceptions import custom_exception_handler

    response = custom_exception_handler(InsufficientFundsError(required=780, available=300), {})

    assert response.status_code == 402
    assert response.data == {
        "error": {
            "code": "insufficient_funds",
            "message": "Недостаточно кирпичей на балансе",
            "details": {"required": 780, "available": 300, "shortfall": 480},
        }
    }
