"""Операции с кошельком.

`apply_transaction` — единственный способ изменить баланс. Прямых записей в
`Wallet.balance` в коде быть не должно: только здесь есть блокировка строки,
проверка на овердрафт и запись в леджер.
"""

import logging
from typing import Any

from django.contrib.contenttypes.models import ContentType
from django.db import transaction
from django.db.models import Model

from apps.billing.models import Wallet, WalletTransaction
from apps.common.enums import WalletEntryKind
from apps.common.exceptions import InsufficientFundsError

logger = logging.getLogger(__name__)


def get_wallet(user: Any) -> Wallet:
    """Кошелёк пользователя (создаётся сигналом, get_or_create — страховка)."""
    wallet, _ = Wallet.objects.get_or_create(user=user)
    return wallet


@transaction.atomic
def apply_transaction(
    *,
    wallet: Wallet,
    amount: int,
    kind: str = WalletEntryKind.SPEND,
    label: str = "",
    related: Model | None = None,
    idempotency_key: str | None = None,
) -> WalletTransaction:
    """Меняет баланс и пишет операцию в леджер.

    Идемпотентно по `idempotency_key`: повторный вызов возвращает уже созданную
    операцию, не трогая баланс.
    """
    if idempotency_key:
        existing = WalletTransaction.objects.filter(idempotency_key=idempotency_key).first()
        if existing is not None:
            logger.info("Операция с ключом %s уже проведена", idempotency_key)
            return existing

    # Блокируем строку кошелька: параллельные списания должны выстроиться в очередь.
    locked = Wallet.objects.select_for_update().get(pk=wallet.pk)

    if amount < 0 and locked.balance + amount < 0:
        raise InsufficientFundsError(required=abs(amount), available=locked.balance)

    locked.balance += amount
    locked.save(update_fields=["balance", "updated_at"])

    related_type = ContentType.objects.get_for_model(related) if related is not None else None

    operation = WalletTransaction.objects.create(
        wallet=locked,
        amount=amount,
        kind=kind,
        label=label,
        balance_after=locked.balance,
        related_content_type=related_type,
        related_object_id=getattr(related, "pk", None),
        idempotency_key=idempotency_key or None,
    )

    # Объект, переданный вызывающим кодом, тоже должен знать новый баланс.
    wallet.balance = locked.balance

    logger.info(
        "Кошелёк %s: %+d кирпичей (%s), баланс %s",
        locked.pk,
        amount,
        kind,
        locked.balance,
    )
    return operation
