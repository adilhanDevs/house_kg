"""Пополнение кошелька: создание счёта и обработка вебхуков.

Кирпичи начисляются исключительно через `apply_transaction` с ключами
идемпотентности — повторный вебхук не может начислить их дважды.
"""

import logging
from datetime import timedelta
from decimal import Decimal
from typing import Any

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.billing.models import (
    Payment,
    PaymentLog,
    PaymentLogDirection,
    PaymentStatus,
    format_bricks,
)
from apps.billing.providers import get_payment_provider
from apps.billing.services import apply_transaction, get_wallet
from apps.common.audit import audit
from apps.common.enums import WalletEntryKind
from apps.common.exceptions import ConflictError
from apps.common.metrics import observe_payment_failed, observe_topup, safe
from apps.common.models import AuditLog

logger = logging.getLogger(__name__)

# Ключи, значения которых нельзя писать в лог ни при каких обстоятельствах.
SENSITIVE_KEYS = ("card", "pan", "cvv", "cvc", "token", "signature", "secret", "password")
MASK = "***"


def mask_sensitive(value: Any) -> Any:
    """Вырезает платёжные данные из тела перед записью в лог."""
    if isinstance(value, dict):
        return {
            key: MASK if _is_sensitive(str(key)) else mask_sensitive(item)
            for key, item in value.items()
        }
    if isinstance(value, list | tuple):
        return [mask_sensitive(item) for item in value]
    return value


def _is_sensitive(key: str) -> bool:
    lowered = key.lower()
    return any(marker in lowered for marker in SENSITIVE_KEYS)


def log_payment(
    *,
    payment: Payment | None,
    direction: str,
    endpoint: str = "",
    payload: Any = None,
    status_code: int | None = None,
) -> PaymentLog:
    """Пишет обмен с провайдером в журнал — уже без чувствительных полей."""
    return PaymentLog.objects.create(
        payment=payment,
        direction=direction,
        endpoint=endpoint[:255],
        payload=mask_sensitive(payload or {}),
        status_code=status_code,
    )


# -- создание счёта ----------------------------------------------------------


def calculate_bricks(amount_kgs: Decimal) -> tuple[int, int]:
    """1 сом = 1 кирпич, сверху бонус TOPUP_BONUS_RATE."""
    bricks = int(amount_kgs)
    bonus = round(bricks * settings.TOPUP_BONUS_RATE)
    return bricks, int(bonus)


def find_reusable_payment(user: Any, idempotency_key: str) -> Payment | None:
    """Счёт по тому же ключу идемпотентности, если он ещё «свежий»."""
    payment = Payment.objects.filter(idempotency_key=idempotency_key).first()
    if payment is None:
        return None

    if payment.user_id != user.pk:
        # Чужой ключ: отдавать чужой платёж нельзя.
        raise ConflictError("Этот ключ идемпотентности уже использован.")

    ttl = timedelta(hours=settings.PAYMENT_IDEMPOTENCY_TTL_HOURS)
    if timezone.now() - payment.created_at > ttl:
        raise ConflictError("Ключ идемпотентности уже использован ранее — сформируйте новый.")

    return payment


@transaction.atomic
def create_topup(
    *,
    user: Any,
    amount_kgs: Decimal,
    provider_code: str,
    idempotency_key: str,
    return_url: str = "",
) -> Payment:
    """Создаёт счёт на пополнение и получает ссылку у провайдера."""
    existing = find_reusable_payment(user, idempotency_key)
    if existing is not None:
        logger.info("Пополнение по ключу %s уже создано", idempotency_key)
        return existing

    bricks, bonus = calculate_bricks(amount_kgs)

    payment = Payment.objects.create(
        user=user,
        amount_kgs=amount_kgs,
        bricks=bricks,
        bonus_bricks=bonus,
        provider=provider_code,
        idempotency_key=idempotency_key,
        expires_at=timezone.now() + timedelta(minutes=settings.PAYMENT_EXPIRY_MINUTES),
    )

    provider = get_payment_provider(provider_code)
    intent = provider.create_payment(
        payment=payment,
        return_url=return_url or settings.PAYMENT_RETURN_URL,
    )

    payment.provider_ref = intent.provider_ref or None
    # Ответ провайдера храним целиком: по нему восстанавливается тот же ответ
    # на повторный запрос с тем же ключом идемпотентности.
    payment.raw_response = {
        "intent": {
            "payment_url": intent.payment_url,
            "qr_code_url": intent.qr_code_url,
            "qr_data": intent.qr_data,
            "provider_ref": intent.provider_ref,
            "extra": intent.extra,
        }
    }
    payment.save(update_fields=["provider_ref", "raw_response", "updated_at"])

    log_payment(
        payment=payment,
        direction=PaymentLogDirection.OUT,
        endpoint=f"{provider_code}:create_payment",
        payload={"amount_kgs": str(amount_kgs), "provider_ref": intent.provider_ref},
        status_code=201,
    )
    return payment


def payment_intent(payment: Payment) -> dict[str, Any]:
    """Сохранённый ответ провайдера."""
    return (payment.raw_response or {}).get("intent", {})


# -- начисление --------------------------------------------------------------


def credit_payment(payment: Payment) -> Payment:
    """Проводит успешную оплату: статус, кирпичи, бонус, уведомление.

    Идемпотентно на двух уровнях: проверка статуса и ключи идемпотентности
    у обеих операций леджера.
    """
    from apps.notifications.models import NotificationType
    from apps.notifications.services import notify

    with transaction.atomic():
        locked = Payment.objects.select_for_update().get(pk=payment.pk)

        if locked.status == PaymentStatus.SUCCEEDED:
            logger.info("Платёж %s уже начислен", locked.pk)
            return locked

        wallet = get_wallet(locked.user)
        amount_label = format_bricks(locked.bricks)

        apply_transaction(
            wallet=wallet,
            amount=locked.bricks,
            kind=WalletEntryKind.TOPUP,
            label=f"+{amount_label} сом ({amount_label} кирпичей)",
            related=locked,
            idempotency_key=f"payment-{locked.pk}-main",
        )

        if locked.bonus_bricks:
            bonus_label = format_bricks(locked.bonus_bricks)
            apply_transaction(
                wallet=wallet,
                amount=locked.bonus_bricks,
                kind=WalletEntryKind.BONUS,
                label=f"+{bonus_label} кирпичей (бонус за пополнение)",
                related=locked,
                idempotency_key=f"payment-{locked.pk}-bonus",
            )

        locked.status = PaymentStatus.SUCCEEDED
        locked.paid_at = timezone.now()
        locked.save(update_fields=["status", "paid_at", "updated_at"])

    notify(
        user=locked.user,
        notification_type=NotificationType.WALLET_TOPUP,
        title="Кошелёк пополнен",
        body=(f"+{format_bricks(locked.total_bricks)} кирпичей за {locked.amount_kgs:.0f} сом"),
        payload={"payment_id": str(locked.pk), "total_bricks": locked.total_bricks},
    )

    safe(observe_topup, locked.total_bricks)
    audit(
        actor=locked.user,
        action=AuditLog.Action.PAYMENT_CREDITED,
        target=locked,
        target_user=locked.user,
        extra={
            "amount_kgs": str(locked.amount_kgs),
            "bricks": locked.bricks,
            "bonus_bricks": locked.bonus_bricks,
            "provider": locked.provider,
        },
    )

    logger.info("Платёж %s начислен: %s кирпичей", locked.pk, locked.total_bricks)
    return locked


# -- вебхук ------------------------------------------------------------------


def process_webhook_result(provider_code: str, result: Any, endpoint: str) -> tuple[int, dict]:
    """Обрабатывает уже проверенный вебхук. Возвращает (код ответа, тело)."""
    payment = Payment.objects.filter(provider_ref=result.provider_ref).first()

    if payment is None and result.raw:
        # Fallback: поиск по paymentId внутри fields (Finik Callback format) или по PK
        raw_fields = (result.raw or {}).get("fields") or {}
        raw_id = (
            raw_fields.get("paymentId")
            or raw_fields.get("payment_id")
            or (result.raw or {}).get("payment_id")
            or result.provider_ref
        )
        if raw_id:
            try:
                payment = Payment.objects.filter(pk=raw_id).first()
            except Exception:
                pass

    if payment is None:
        log_payment(
            payment=None,
            direction=PaymentLogDirection.IN,
            endpoint=endpoint,
            payload=result.raw,
            status_code=404,
        )
        logger.warning(
            "Вебхук %s: платёж по ссылке %s не найден", provider_code, result.provider_ref
        )
        return 404, {"detail": "Платёж не найден"}

    log_payment(
        payment=payment,
        direction=PaymentLogDirection.IN,
        endpoint=endpoint,
        payload=result.raw,
        status_code=200,
    )

    if payment.status == PaymentStatus.SUCCEEDED:
        # Провайдеры ретраят вебхуки — второй раз начислять нечего.
        return 200, {"status": payment.status, "detail": "Платёж уже обработан"}

    if payment.status == PaymentStatus.EXPIRED or payment.is_expired:
        logger.info("Вебхук по просроченному платежу %s — начисления нет", payment.pk)
        log_payment(
            payment=payment,
            direction=PaymentLogDirection.IN,
            endpoint=endpoint,
            payload={"note": "Платёж просрочен, начисление не производится"},
            status_code=200,
        )
        return 200, {"status": PaymentStatus.EXPIRED, "detail": "Платёж просрочен"}

    if result.status != PaymentStatus.SUCCEEDED:
        payment.status = PaymentStatus.FAILED
        payment.raw_response = {**(payment.raw_response or {}), "webhook": result.raw}
        payment.save(update_fields=["status", "raw_response", "updated_at"])
        safe(observe_payment_failed, payment.provider, result.status or "unknown")
        return 200, {"status": payment.status}

    if result.amount is not None and Decimal(result.amount) != payment.amount_kgs:
        # Сумма в вебхуке не совпала с выставленным счётом — не начисляем.
        logger.error(
            "Вебхук по платежу %s: сумма %s не совпадает с ожидаемой %s",
            payment.pk,
            result.amount,
            payment.amount_kgs,
        )
        log_payment(
            payment=payment,
            direction=PaymentLogDirection.IN,
            endpoint=endpoint,
            payload={"note": "Сумма вебхука не совпала со счётом"},
            status_code=200,
        )
        safe(observe_payment_failed, payment.provider, "amount_mismatch")
        return 200, {"status": payment.status, "detail": "Сумма не совпадает"}

    payment.raw_response = {**(payment.raw_response or {}), "webhook": result.raw}
    payment.save(update_fields=["raw_response", "updated_at"])
    credited = credit_payment(payment)

    return 200, {"status": credited.status, "credited_bricks": credited.total_bricks}


def expire_payments() -> int:
    """Переводит просроченные счета в expired."""
    stale = Payment.objects.filter(status=PaymentStatus.PENDING, expires_at__lt=timezone.now())
    return stale.update(status=PaymentStatus.EXPIRED, updated_at=timezone.now())
