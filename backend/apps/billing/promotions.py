"""Платное продвижение объявлений — экран `ad_promo_page`.

Расчёт стоимости и покупка разделены намеренно: экран считает цену сколько
угодно раз без единой записи в БД, а покупка — одна атомарная операция, в
которой либо создаются и списание, и продвижение, либо не создаётся ничего.
"""

import logging
from datetime import timedelta
from typing import Any

from django.db import transaction
from django.utils import timezone

from apps.billing.models import (
    Promotion,
    PromotionOption,
    PromotionPackage,
    PromotionStatus,
)
from apps.billing.services import apply_transaction, get_wallet
from apps.common.enums import WalletEntryKind
from apps.common.exceptions import ApiValidationError, ConflictError

logger = logging.getLogger(__name__)

DEFAULT_PACKAGE_CODE = "standard"


def get_package(code: str | None = None) -> PromotionPackage:
    """Пакет по коду или базовый, если код не прислали."""
    wanted = code or DEFAULT_PACKAGE_CODE
    package = PromotionPackage.objects.filter(code=wanted, is_active=True).first()

    if package is None:
        raise ApiValidationError("Неизвестный пакет продвижения.", {"package": wanted})
    return package


def resolve_options(codes: list[str] | None) -> list[PromotionOption]:
    """Опции по кодам с проверкой, что все они существуют и включены."""
    wanted = [code for code in (codes or []) if code]
    if not wanted:
        return []

    options = list(PromotionOption.objects.filter(code__in=wanted, is_active=True))
    missing = sorted(set(wanted) - {option.code for option in options})

    if missing:
        raise ApiValidationError("Неизвестные опции продвижения.", {"options": missing})

    # Порядок как в справочнике, а не как прислал клиент: цена не зависит от
    # порядка, а ответ должен быть стабильным.
    return sorted(options, key=lambda option: (option.order, option.code))


def calculate_cost(
    days: int,
    package: PromotionPackage,
    options: list[PromotionOption],
) -> dict[str, Any]:
    """Разложение цены по составляющим — ровно то, что рисует экран."""
    base_cost = package.cost_for(days)
    option_rows = [
        {
            "code": option.code,
            "name": option.name,
            "price_per_day_bricks": option.price_per_day_bricks,
            "cost": option.cost_for(days),
        }
        for option in options
    ]
    options_cost = sum(row["cost"] for row in option_rows)

    return {
        "days": days,
        "package": package.code,
        "base_cost": base_cost,
        "options": option_rows,
        "options_cost": options_cost,
        "total_cost": base_cost + options_cost,
    }


def promoted_until_after(listing: Any, days: int) -> Any:
    """Докуда будет продвигаться объявление после покупки.

    Продление складывается с остатком: пользователь, купивший три дня поверх
    двух неистёкших, должен получить пять, а не три.
    """
    now = timezone.now()
    current = listing.promoted_until if listing and listing.promoted_until else now
    return max(now, current) + timedelta(days=days)


def build_pricing(user: Any, days: int, option_codes: list[str], listing: Any = None) -> dict:
    """Предрасчёт для экрана. Ничего не списывает и ничего не создаёт."""
    package = get_package()
    options = resolve_options(option_codes)
    breakdown = calculate_cost(days, package, options)

    balance = get_wallet(user).balance if user and user.is_authenticated else 0

    return {
        **breakdown,
        "balance": balance,
        "is_affordable": balance >= breakdown["total_cost"],
        "promoted_until_after": promoted_until_after(listing, days),
        "packages": list(PromotionPackage.objects.filter(is_active=True)),
        "available_options": list(PromotionOption.objects.filter(is_active=True)),
    }


@transaction.atomic
def promote_listing(
    listing: Any,
    days: int,
    package_code: str | None,
    option_codes: list[str],
    idempotency_key: str,
) -> Promotion:
    """Покупает продвижение: списание и запись — одной транзакцией.

    Нехватки средств достаточно, чтобы не появилось ничего: `apply_transaction`
    поднимает InsufficientFundsError внутри atomic-блока, и созданный до этого
    Promotion откатывается вместе со всем остальным.
    """
    from apps.catalog.enums import ListingStatus

    if listing.status != ListingStatus.ACTIVE:
        raise ConflictError(
            "Продвигать можно только опубликованное объявление. "
            "Дождитесь окончания модерации или верните объявление из архива."
        )

    existing = Promotion.objects.filter(transaction__idempotency_key=idempotency_key).first()
    if existing is not None:
        logger.info("Продвижение с ключом %s уже куплено", idempotency_key)
        return existing

    package = get_package(package_code)
    options = resolve_options(option_codes)
    breakdown = calculate_cost(days, package, options)
    cost = breakdown["total_cost"]

    now = timezone.now()
    ends_at = promoted_until_after(listing, days)

    promotion = Promotion.objects.create(
        listing=listing,
        package=package,
        days=days,
        options=[option.code for option in options],
        cost_bricks=cost,
        starts_at=now,
        ends_at=ends_at,
        status=PromotionStatus.ACTIVE,
    )

    operation = apply_transaction(
        wallet=get_wallet(listing.owner),
        amount=-cost,
        kind=WalletEntryKind.SPEND,
        label=f"-{cost} кирпичей",
        related=promotion,
        idempotency_key=idempotency_key,
    )

    promotion.transaction = operation
    promotion.save(update_fields=["transaction", "updated_at"])

    listing.promoted_until = ends_at
    listing.save(update_fields=["promoted_until", "updated_at"])

    logger.info(
        "Объявление %s продвигается до %s за %s кирпичей (продвижение %s)",
        listing.slug,
        ends_at,
        cost,
        promotion.pk,
    )
    return promotion


def listing_promotions(listing: Any) -> Any:
    """История продвижений объявления."""
    return Promotion.objects.filter(listing=listing).select_related("package", "transaction")


def refresh_promoted_until(listing_id: int) -> None:
    """Пересчитывает `promoted_until` по действующим продвижениям.

    Продвижений у объявления может быть несколько; снимать флаг можно, только
    когда не осталось ни одного действующего.
    """
    from apps.catalog.models import Listing

    now = timezone.now()
    latest = (
        Promotion.objects.filter(
            listing_id=listing_id,
            status=PromotionStatus.ACTIVE,
            ends_at__gt=now,
        )
        .order_by("-ends_at")
        .values_list("ends_at", flat=True)
        .first()
    )

    Listing.objects.filter(pk=listing_id).update(promoted_until=latest, updated_at=now)
