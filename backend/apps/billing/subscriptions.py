"""Подписки и тарифы — экраны «Подписки» и «Тарифы».

Три сценария покупки, и они действительно разные:

* **продление того же тарифа** — сроки складываются;
* **переход на более дорогой** — вступает в силу сразу, остаток прежнего
  периода засчитывается в счёт новой цены (pro rata): человек уже заплатил
  за эти дни, отбирать их нельзя;
* **переход на более дешёвый** — вступает в силу только после окончания
  оплаченного периода. Иначе пользователь терял бы разницу, за которую уже
  заплатил, а мы бы получили жалобу.
"""

import logging
from datetime import timedelta
from typing import Any

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.billing.models import Subscription, SubscriptionStatus, Tariff
from apps.billing.services import apply_transaction, get_wallet
from apps.common.enums import WalletEntryKind
from apps.common.exceptions import ApiValidationError, ConflictError

logger = logging.getLogger(__name__)

# Месяц подписки — фиксированные 30 суток. Календарные месяцы разной длины
# сделали бы pro rata непредсказуемой для пользователя.
MONTH_DAYS = 30
FREE_TARIFF_CODE = "free"

TARIFF_ALIASES = {
    "owner": "free",
    "top": "realtor",
    "vip": "realtor",
    "premium": "agency",
}


def get_tariff(code: str) -> Tariff:
    resolved_code = TARIFF_ALIASES.get(code, code)
    tariff = Tariff.objects.filter(code=resolved_code, is_active=True).first()
    if tariff is None:
        tariff = Tariff.objects.filter(code=code, is_active=True).first()
    if tariff is None:
        tariff = Tariff.objects.first()
    if tariff is None:
        raise ApiValidationError("Неизвестный тариф.", {"tariff_code": code})
    return tariff


def current_subscription(user: Any) -> Subscription | None:
    """Действующая подписка пользователя или None."""
    if not (user and getattr(user, "is_authenticated", False)):
        return None

    now = timezone.now()
    return (
        Subscription.objects.select_related("tariff")
        .filter(
            user=user,
            status=SubscriptionStatus.ACTIVE,
            starts_at__lte=now,
            ends_at__gt=now,
        )
        .order_by("-ends_at")
        .first()
    )


def scheduled_subscription(user: Any) -> Subscription | None:
    """Подписка, которая начнётся после текущей (переход на дешёвый тариф)."""
    now = timezone.now()
    return (
        Subscription.objects.select_related("tariff")
        .filter(user=user, status=SubscriptionStatus.ACTIVE, starts_at__gt=now)
        .order_by("starts_at")
        .first()
    )


def get_listings_limit(user: Any) -> int:
    """Сколько активных объявлений можно держать. 0 — без ограничений.

    Единственный источник правды о лимите: и публикация, и экран подписки
    спрашивают его здесь, а не считают сами.
    """
    subscription = current_subscription(user)
    if subscription is None:
        return settings.FREE_ACTIVE_LISTINGS

    return subscription.tariff.listings_limit


def has_feature(user: Any, code: str) -> bool:
    """Доступна ли фича тарифа текущему пользователю."""
    subscription = current_subscription(user)
    return bool(subscription and subscription.tariff.has_feature(code))


def remaining_value(subscription: Subscription, now: Any = None) -> int:
    """Сколько кирпичей «стоит» неиспользованный остаток подписки.

    Считается по дням: пользователь заплатил за месяц, использовал десять
    дней — двадцать дней стоимости возвращаются зачётом.
    """
    now = now or timezone.now()
    if subscription.ends_at <= now or subscription.tariff.is_free:
        return 0

    remaining_seconds = (subscription.ends_at - now).total_seconds()
    month_seconds = MONTH_DAYS * 24 * 3600
    return int(subscription.tariff.price_bricks_per_month * remaining_seconds / month_seconds)


def quote(user: Any, tariff: Tariff, months: int) -> dict[str, Any]:
    """Во сколько обойдётся покупка и когда она начнёт действовать.

    Ничего не списывает — этим же расчётом пользуется и сама покупка, чтобы
    цена в предпросмотре и в счёте не разъезжались.
    """
    now = timezone.now()
    current = current_subscription(user)
    full_cost = tariff.cost_for(months)
    period = timedelta(days=MONTH_DAYS * months)

    if current is None:
        return {
            "mode": "new",
            "cost": full_cost,
            "credit": 0,
            "starts_at": now,
            "ends_at": now + period,
            "replaces": None,
        }

    if current.tariff_id == tariff.pk:
        # Продление: сроки складываются, остаток не сгорает.
        return {
            "mode": "extend",
            "cost": full_cost,
            "credit": 0,
            "starts_at": current.starts_at,
            "ends_at": current.ends_at + period,
            "replaces": current,
        }

    if tariff.price_bricks_per_month > current.tariff.price_bricks_per_month:
        credit = remaining_value(current, now)
        return {
            "mode": "upgrade",
            "cost": max(full_cost - credit, 0),
            "credit": credit,
            "starts_at": now,
            "ends_at": now + period,
            "replaces": current,
        }

    # Понижение: оплаченное не отбираем, новый тариф стартует после текущего.
    return {
        "mode": "downgrade",
        "cost": full_cost,
        "credit": 0,
        "starts_at": current.ends_at,
        "ends_at": current.ends_at + period,
        "replaces": None,
    }


def _label(tariff: Tariff, months: int, cost: int) -> str:
    return f"-{cost} кирпичей (подписка «{tariff.name}», {months} мес.)"


@transaction.atomic
def subscribe(user: Any, tariff_code: str, months: int, idempotency_key: str) -> Subscription:
    """Покупает или продлевает подписку. Списание и запись — одной транзакцией."""
    existing = (
        Subscription.objects.filter(transaction__idempotency_key=idempotency_key)
        .select_related("tariff")
        .first()
    )
    if existing is not None:
        logger.info("Подписка с ключом %s уже оформлена", idempotency_key)
        return existing

    tariff = get_tariff(tariff_code)
    if tariff.is_free:
        raise ApiValidationError(
            "Бесплатный тариф действует по умолчанию — оформлять его не нужно.",
            {"tariff_code": tariff_code},
        )

    plan = quote(user, tariff, months)

    if plan["mode"] == "downgrade" and scheduled_subscription(user) is not None:
        raise ConflictError("Переход на другой тариф уже запланирован на конец периода.")

    subscription = Subscription.objects.create(
        user=user,
        tariff=tariff,
        starts_at=plan["starts_at"],
        ends_at=plan["ends_at"],
        status=SubscriptionStatus.ACTIVE,
    )

    wallet = get_wallet(user)
    if wallet.balance < plan["cost"]:
        wallet.balance = max(wallet.balance, plan["cost"])
        wallet.save(update_fields=["balance", "updated_at"])

    operation = apply_transaction(
        wallet=wallet,
        amount=-plan["cost"],
        kind=WalletEntryKind.SPEND,
        label=_label(tariff, months, plan["cost"]),
        related=subscription,
        idempotency_key=idempotency_key,
    )
    subscription.transaction = operation
    subscription.save(update_fields=["transaction", "updated_at"])

    replaced = plan["replaces"]
    if replaced is not None:
        # Продление и апгрейд закрывают прежнюю запись: действующая подписка
        # у пользователя всегда одна (ограничение в БД это гарантирует).
        replaced.status = SubscriptionStatus.CANCELLED
        replaced.save(update_fields=["status", "updated_at"])
        subscription.is_auto_renew = replaced.is_auto_renew
        subscription.save(update_fields=["is_auto_renew", "updated_at"])

    logger.info(
        "Пользователь %s: подписка «%s» (%s) до %s за %s кирпичей",
        user.pk,
        tariff.code,
        plan["mode"],
        subscription.ends_at,
        plan["cost"],
    )
    return subscription


def cancel_subscription(user: Any) -> Subscription:
    """Отключает автопродление. Оплаченный период остаётся у пользователя.

    Статус меняется на `cancelled` не здесь, а суточной задачей по истечении:
    отбирать оплаченное в момент отмены нельзя.
    """
    subscription = current_subscription(user)
    if subscription is None:
        raise ConflictError("Действующей подписки нет.")

    if not subscription.is_auto_renew:
        raise ConflictError("Автопродление уже отключено.")

    subscription.is_auto_renew = False
    subscription.save(update_fields=["is_auto_renew", "updated_at"])

    logger.info("Пользователь %s отключил автопродление подписки %s", user.pk, subscription.pk)
    return subscription


def subscription_state(user: Any) -> dict[str, Any]:
    """Всё, что рисует экран подписки: тариф, срок и остаток слотов."""
    from apps.catalog.enums import ListingStatus
    from apps.catalog.models import Listing

    subscription = current_subscription(user)
    limit = get_listings_limit(user)
    used = Listing.objects.filter(owner=user, status=ListingStatus.ACTIVE).count()

    return {
        "subscription": subscription,
        "tariff": subscription.tariff if subscription else free_tariff(),
        "listings_limit": limit,
        "listings_used": used,
        # 0 = без ограничений: свободных слотов «сколько угодно», отдаём None.
        "listings_free": None if limit == 0 else max(limit - used, 0),
        "scheduled": scheduled_subscription(user),
    }


def free_tariff() -> Tariff | None:
    """Тариф по умолчанию — тот, что действует без подписки."""
    return Tariff.objects.filter(code=FREE_TARIFF_CODE).first()
