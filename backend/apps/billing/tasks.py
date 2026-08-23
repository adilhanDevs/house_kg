"""Фоновые задачи биллинга."""

import logging

from celery import shared_task

logger = logging.getLogger(__name__)


@shared_task(name="billing.expire_payments", ignore_result=True)
def expire_payments() -> int:
    """Каждые пять минут закрывает счета, которые так и не оплатили."""
    from apps.billing.payments import expire_payments as expire

    expired = expire()
    if expired:
        logger.info("Просроченных счетов на оплату: %s", expired)
    return expired


@shared_task(name="billing.expire_promotions", ignore_result=True)
def expire_promotions() -> dict[str, int]:
    """Закрывает истёкшие продвижения и предупреждает о скором окончании.

    Флаг `promoted_until` снимается только тогда, когда у объявления не
    осталось ни одного действующего продвижения: их может быть несколько.
    """
    from datetime import timedelta

    from django.utils import timezone

    from apps.billing.models import Promotion, PromotionStatus
    from apps.billing.promotions import refresh_promoted_until
    from apps.notifications.models import Notification, NotificationType
    from apps.notifications.services import notify_many

    now = timezone.now()

    stale = list(
        Promotion.objects.filter(status=PromotionStatus.ACTIVE, ends_at__lte=now).values_list(
            "pk", "listing_id"
        )
    )
    finished = Promotion.objects.filter(pk__in=[pk for pk, _ in stale]).update(
        status=PromotionStatus.FINISHED, updated_at=now
    )

    for listing_id in {listing_id for _, listing_id in stale}:
        refresh_promoted_until(listing_id)

    # Предупреждение ровно одно на продвижение: следующий час не должен
    # присылать то же самое снова.
    expiring = list(
        Promotion.objects.filter(
            status=PromotionStatus.ACTIVE,
            ends_at__gt=now,
            ends_at__lte=now + timedelta(hours=24),
            expiry_notified_at__isnull=True,
        ).select_related("listing", "listing__owner", "listing__district")
    )

    notify_many(
        [
            Notification(
                user=promotion.listing.owner,
                type=NotificationType.PROMOTION_EXPIRING,
                title="Продвижение заканчивается завтра",
                body=f"«{promotion.listing}» перестанет показываться выше остальных.",
                payload={
                    "promotion_id": promotion.pk,
                    "listing_slug": promotion.listing.slug,
                    "ends_at": promotion.ends_at.isoformat(),
                },
                listing=promotion.listing,
            )
            for promotion in expiring
        ]
    )
    Promotion.objects.filter(pk__in=[promotion.pk for promotion in expiring]).update(
        expiry_notified_at=now
    )

    logger.info("Продвижений завершено: %s, предупреждений: %s", finished, len(expiring))
    return {"finished": finished, "warned": len(expiring)}


@shared_task(name="billing.process_subscriptions", ignore_result=True)
def process_subscriptions() -> dict[str, int]:
    """Суточная обработка подписок: продление и истечение.

    Порядок важен: сначала пытаемся продлить те, что заканчиваются, и только
    потом закрываем действительно истёкшие — иначе успешно продлённая
    подписка тут же попала бы в «истёкшие».
    """
    renewed, failed = _renew_due_subscriptions()
    expired, archived = _expire_subscriptions()

    logger.info(
        "Подписки: продлено %s, неудач %s, истекло %s, объявлений в архив %s",
        renewed,
        failed,
        expired,
        archived,
    )
    return {"renewed": renewed, "failed": failed, "expired": expired, "archived": archived}


def _renew_due_subscriptions() -> tuple[int, int]:
    """Списывает следующий период за сутки до окончания.

    Нехватка средств — не ошибка, а обычный сценарий: пользователю уходит
    уведомление, а баланс остаётся нетронутым. В минус не уходим никогда.
    """
    from datetime import timedelta

    from django.utils import timezone

    from apps.billing.models import Subscription, SubscriptionStatus
    from apps.billing.services import apply_transaction, get_wallet
    from apps.billing.subscriptions import MONTH_DAYS
    from apps.common.enums import WalletEntryKind
    from apps.common.exceptions import InsufficientFundsError
    from apps.notifications.models import NotificationType
    from apps.notifications.services import notify

    now = timezone.now()
    renewed = 0
    failed = 0

    due = Subscription.objects.select_related("tariff", "user").filter(
        status=SubscriptionStatus.ACTIVE,
        is_auto_renew=True,
        starts_at__lte=now,
        ends_at__gt=now,
        ends_at__lte=now + timedelta(hours=24),
        # Повторная попытка в тот же день не нужна: задача суточная.
        renewal_attempted_at__isnull=True,
    )

    for subscription in due:
        cost = subscription.tariff.cost_for(1)
        # Ключ детерминированный: повторный запуск задачи не спишет дважды.
        key = f"subscription-renew-{subscription.pk}-{subscription.ends_at:%Y%m%d}"

        try:
            operation = apply_transaction(
                wallet=get_wallet(subscription.user),
                amount=-cost,
                kind=WalletEntryKind.SPEND,
                label=f"-{cost} кирпичей (продление подписки «{subscription.tariff.name}»)",
                related=subscription,
                idempotency_key=key,
            )
        except InsufficientFundsError:
            failed += 1
            subscription.renewal_attempted_at = now
            subscription.save(update_fields=["renewal_attempted_at", "updated_at"])
            notify(
                user=subscription.user,
                notification_type=NotificationType.SYSTEM,
                title="Не удалось продлить подписку",
                body=(
                    f"На балансе не хватает {cost} кирпичей для тарифа "
                    f"«{subscription.tariff.name}». Пополните баланс, "
                    "иначе подписка закончится."
                ),
                payload={"kind": "subscription_renew_failed", "required": cost},
            )
            continue

        subscription.ends_at = subscription.ends_at + timedelta(days=MONTH_DAYS)
        subscription.transaction = operation
        subscription.renewal_attempted_at = now
        subscription.save(
            update_fields=["ends_at", "transaction", "renewal_attempted_at", "updated_at"]
        )
        renewed += 1

        notify(
            user=subscription.user,
            notification_type=NotificationType.SYSTEM,
            title="Подписка продлена",
            body=(
                f"Тариф «{subscription.tariff.name}» продлён до "
                f"{subscription.ends_at:%d.%m.%Y}. Списано {cost} кирпичей."
            ),
            payload={"kind": "subscription_renewed", "cost": cost},
        )

    return renewed, failed


def _expire_subscriptions() -> tuple[int, int]:
    """Закрывает истёкшие подписки и приводит объявления к бесплатному лимиту.

    Лишние объявления уходят в архив, а не удаляются: пользователь вернётся
    на тариф и достанет их обратно одной кнопкой.
    """
    from django.utils import timezone

    from apps.billing.models import Subscription, SubscriptionStatus
    from apps.billing.subscriptions import get_listings_limit

    now = timezone.now()
    stale = list(
        Subscription.objects.select_related("user").filter(
            status=SubscriptionStatus.ACTIVE, ends_at__lte=now
        )
    )
    expired = Subscription.objects.filter(pk__in=[item.pk for item in stale]).update(
        status=SubscriptionStatus.EXPIRED, updated_at=now
    )

    archived = 0
    for subscription in stale:
        # Лимит спрашиваем заново: после истечения мог начаться запланированный
        # переход на другой тариф, и тогда он будет не бесплатным.
        archived += _archive_over_limit(subscription.user, get_listings_limit(subscription.user))

    return expired, archived


def _archive_over_limit(user: object, limit: int) -> int:
    """Архивирует самые старые активные объявления сверх лимита."""
    from django.utils import timezone

    from apps.catalog.enums import ListingStatus
    from apps.catalog.models import Listing
    from apps.notifications.models import NotificationType
    from apps.notifications.services import notify

    if limit == 0:
        return 0

    active = list(
        Listing.objects.filter(owner=user, status=ListingStatus.ACTIVE)
        # Самые старые уходят первыми: свежие объявления актуальнее.
        .order_by("published_at", "id")
        .values_list("pk", flat=True)
    )
    surplus = active[: max(len(active) - limit, 0)]
    if not surplus:
        return 0

    Listing.objects.filter(pk__in=surplus).update(
        status=ListingStatus.ARCHIVED, updated_at=timezone.now()
    )
    notify(
        user=user,
        notification_type=NotificationType.SYSTEM,
        title="Подписка закончилась",
        body=(
            f"Объявлений сверх лимита ({limit}) перенесено в архив: "
            f"{len(surplus)}. Их можно вернуть из «Моих объявлений» "
            "или оформить тариф."
        ),
        payload={"kind": "subscription_expired", "archived": len(surplus)},
    )
    return len(surplus)


@shared_task(name="billing.auto_bump_listings", ignore_result=True)
def auto_bump_listings() -> int:
    """Ежедневный автоподъём объявлений для тарифов с `auto_bump_daily`.

    Подъём — это обновление `published_at`: при сортировке по свежести
    объявление снова оказывается наверху, не занимая места продвинутых.
    """
    from datetime import timedelta

    from django.utils import timezone

    from apps.billing.models import Subscription, SubscriptionStatus
    from apps.catalog.enums import ListingStatus
    from apps.catalog.models import Listing

    now = timezone.now()
    subscriptions = Subscription.objects.select_related("tariff").filter(
        status=SubscriptionStatus.ACTIVE,
        starts_at__lte=now,
        ends_at__gt=now,
        tariff__features__auto_bump_daily=True,
    )

    bumped = 0
    for subscription in subscriptions:
        if subscription.auto_bumped_at and now - subscription.auto_bumped_at < timedelta(hours=23):
            continue

        updated = Listing.objects.filter(
            owner_id=subscription.user_id, status=ListingStatus.ACTIVE
        ).update(published_at=now, bumped_at=now, updated_at=now)

        Subscription.objects.filter(pk=subscription.pk).update(auto_bumped_at=now)
        bumped += updated

    logger.info("Автоподъём по тарифу: объявлений %s", bumped)
    return bumped
