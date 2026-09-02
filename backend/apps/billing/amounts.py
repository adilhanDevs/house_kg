"""Утилиты безопасного расчёта сумм и тестовых оверрайдов для Finik."""

import logging
from decimal import Decimal, InvalidOperation
from typing import Any

from django.conf import settings

logger = logging.getLogger("billing.finik")


def get_finik_test_amount_override(user: Any, nominal_amount: Decimal) -> tuple[Decimal, bool]:
    """Возвращает (итоговая_сумма_для_Finik, is_test_override).

    Fail-closed:
    Override применяется ТОЛЬКО если:
    1. Задана настройка FINIK_TEST_AMOUNT_KGS с валидным положительным числом (> 0);
    2. Задан непустой список FINIK_TEST_USER_IDS (список ID или телефонов);
    3. Текущий пользователь (по id или phone) входит в этот список.

    Во всех остальных случаях возвращается nominal_amount и is_test_override=False.
    """
    raw_test_amount = getattr(settings, "FINIK_TEST_AMOUNT_KGS", "")
    if not raw_test_amount:
        return nominal_amount, False

    try:
        test_amount = Decimal(str(raw_test_amount).strip())
        if test_amount <= Decimal("0"):
            logger.warning("FINIK_TEST_AMOUNT_KGS must be positive, got: %s", raw_test_amount)
            return nominal_amount, False
    except (InvalidOperation, TypeError, ValueError):
        logger.warning("Invalid FINIK_TEST_AMOUNT_KGS: %s", raw_test_amount)
        return nominal_amount, False

    allowlist = [
        str(item).strip()
        for item in (getattr(settings, "FINIK_TEST_USER_IDS", []) or [])
        if str(item).strip()
    ]
    if not allowlist:
        # Fail-closed: missing allowlist means test override is disabled globally
        return nominal_amount, False

    user_id = str(getattr(user, "pk", "") or getattr(user, "id", "") or "").strip()
    user_phone = str(getattr(user, "phone", "") or "").strip()

    is_allowed = False
    if user_id and user_id in allowlist:
        is_allowed = True
    elif user_phone and user_phone in allowlist:
        is_allowed = True

    if is_allowed:
        logger.info(
            "Finik test amount override active: user=%s (%s), nominal=%s -> provider_test=%s KGS",
            user_id,
            user_phone,
            nominal_amount,
            test_amount,
        )
        return test_amount, True

    return nominal_amount, False
