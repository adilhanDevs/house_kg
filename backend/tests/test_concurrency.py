"""Гонки на деньгах и счётчиках.

Тесты поднимают НАСТОЯЩИЕ параллельные соединения к БД (потоки +
`django_db(transaction=True)`), а не мокают блокировки: смысл проверки
именно в том, что `SELECT ... FOR UPDATE` и уникальные ограничения работают
на реальном движке.

Поэтому они идут только на PostgreSQL. SQLite сериализует запись на уровне
файла и игнорирует `select_for_update`, так что «зелёный» результат там
ничего не доказывал бы — честнее пропустить.
"""

import threading

import pytest
from django.db import connection, connections, transaction

from apps.billing.models import Payment, PaymentStatus, Wallet, WalletTransaction
from apps.billing.services import apply_transaction, get_wallet
from apps.catalog.models import Listing
from apps.common.enums import WalletEntryKind
from apps.common.exceptions import InsufficientFundsError

requires_postgres = pytest.mark.skipif(
    connection.vendor != "postgresql",
    reason="Нужна PostgreSQL: SQLite не поддерживает select_for_update и реальную параллельность",
)


def run_in_parallel(target, count: int = 2) -> list:
    """Запускает `target()` в нескольких потоках и собирает результаты.

    Каждый поток закрывает своё соединение сам: иначе тестовая БД не
    дождётся их и уборка транзакции повиснет.
    """
    results: list = [None] * count
    barrier = threading.Barrier(count)

    def worker(index: int) -> None:
        try:
            # Все потоки стартуют одновременно — иначе гонки не будет.
            barrier.wait(timeout=10)
            results[index] = ("ok", target())
        except Exception as exc:  # noqa: BLE001 - исключение и есть результат
            results[index] = ("error", exc)
        finally:
            connections.close_all()

    threads = [threading.Thread(target=worker, args=(index,)) for index in range(count)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=30)

    assert all(not thread.is_alive() for thread in threads), "поток не завершился"
    return results


@pytest.mark.django_db(transaction=True)
@requires_postgres
def test_parallel_spend_lets_exactly_one_through(django_user_model):
    """Баланса хватает на одно списание — второе обязано упасть, а не уйти в минус."""
    user = django_user_model.objects.create_user(phone="+996700900001", name="Гонка")
    wallet = get_wallet(user)
    apply_transaction(wallet=wallet, amount=780, kind=WalletEntryKind.TOPUP, label="+780 кирпичей")

    def spend():  # noqa: ANN202
        with transaction.atomic():
            return apply_transaction(
                wallet=Wallet.objects.get(pk=wallet.pk),
                amount=-780,
                kind=WalletEntryKind.SPEND,
                label="-780 кирпичей",
            )

    results = run_in_parallel(spend, count=2)

    outcomes = [status for status, _ in results]
    assert outcomes.count("ok") == 1, f"прошло не одно списание: {results}"

    failure = next(payload for status, payload in results if status == "error")
    assert isinstance(failure, InsufficientFundsError)

    wallet.refresh_from_db()
    assert wallet.balance == 0
    assert WalletTransaction.objects.filter(kind=WalletEntryKind.SPEND).count() == 1


@pytest.mark.django_db(transaction=True)
@requires_postgres
def test_parallel_webhooks_credit_payment_once(django_user_model):
    """Провайдер умеет прислать вебхук дважды — кирпичи начисляются один раз."""
    from apps.billing.payments import credit_payment

    user = django_user_model.objects.create_user(phone="+996700900002", name="Вебхук")
    get_wallet(user)
    payment = Payment.objects.create(
        user=user,
        amount_kgs="12000.00",
        bricks=12_000,
        bonus_bricks=1_200,
        provider="mock",
        status=PaymentStatus.PENDING,
        idempotency_key="concurrent-webhook",
    )

    def credit():  # noqa: ANN202
        return credit_payment(Payment.objects.get(pk=payment.pk))

    results = run_in_parallel(credit, count=2)

    errors = [payload for status, payload in results if status == "error"]
    assert not errors, f"вебхук упал: {errors}"

    payment.refresh_from_db()
    assert payment.status == PaymentStatus.SUCCEEDED
    assert get_wallet(user).balance == 13_200
    # Ровно одно начисление: повтор обязан быть идемпотентным.
    assert WalletTransaction.objects.filter(wallet__user=user).count() == 2


@pytest.mark.django_db(transaction=True)
@requires_postgres
def test_parallel_favourites_keep_counter_correct(django_user_model):
    """Двойной тап по «сердечку» не должен посчитать объявление дважды."""
    from apps.engagement.models import Favourite
    from apps.engagement.services import add_favourite
    from tests.factories import ListingFactory

    user = django_user_model.objects.create_user(phone="+996700900003", name="Избранное")
    listing = ListingFactory()

    def like():  # noqa: ANN202
        return add_favourite(user, Listing.objects.get(pk=listing.pk))

    results = run_in_parallel(like, count=2)

    errors = [payload for status, payload in results if status == "error"]
    assert not errors, f"добавление в избранное упало: {errors}"

    listing.refresh_from_db()
    assert Favourite.objects.filter(user=user, listing=listing).count() == 1
    assert listing.favourites_count == 1


# -- детерминированные проверки тех же инвариантов ---------------------------
#
# Идут на любом движке: они не про параллельность, а про то, что повторный
# вызов не меняет результат. Гонку они не поймают, но регрессию в логике —
# поймают и на SQLite.


@pytest.mark.django_db
def test_spend_beyond_balance_is_rejected(wallet_with_balance):
    wallet = wallet_with_balance(balance=780)

    with pytest.raises(InsufficientFundsError):
        apply_transaction(wallet=wallet, amount=-1560, kind=WalletEntryKind.SPEND, label="-1560")

    wallet.refresh_from_db()
    assert wallet.balance == 780
    assert not WalletTransaction.objects.filter(kind=WalletEntryKind.SPEND).exists()


@pytest.mark.django_db
def test_repeated_credit_is_idempotent(user):
    from apps.billing.payments import credit_payment

    get_wallet(user)
    payment = Payment.objects.create(
        user=user,
        amount_kgs="5000.00",
        bricks=5_000,
        bonus_bricks=500,
        provider="mock",
        status=PaymentStatus.PENDING,
        idempotency_key="repeat-credit",
    )

    credit_payment(payment)
    credit_payment(Payment.objects.get(pk=payment.pk))

    assert get_wallet(user).balance == 5_500
    # Две операции — само пополнение и бонус; повторный вызов не добавил третьей.
    assert WalletTransaction.objects.filter(wallet__user=user).count() == 2


@pytest.mark.django_db
def test_repeated_favourite_does_not_double_the_counter(user, listing):
    from apps.engagement.services import add_favourite

    add_favourite(user, listing)
    add_favourite(user, listing)

    listing.refresh_from_db()
    assert listing.favourites_count == 1
