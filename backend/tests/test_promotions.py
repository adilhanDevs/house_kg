"""Платное продвижение объявлений и статистика."""

from datetime import timedelta

import pytest
from django.urls import reverse
from django.utils import timezone
from freezegun import freeze_time
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.billing.models import (
    Promotion,
    PromotionOption,
    PromotionPackage,
    PromotionStatus,
    WalletTransaction,
)
from apps.billing.services import apply_transaction, get_wallet
from apps.billing.tasks import expire_promotions
from apps.catalog.enums import ListingStatus
from apps.common.enums import WalletEntryKind
from tests.factories import ListingFactory, UserFactory

pytestmark = pytest.mark.django_db

DAY_PRICE = 780


def client_for(user) -> APIClient:
    client = APIClient()
    token = RefreshToken.for_user(user)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {token.access_token}")
    return client


def fund(user, amount: int) -> None:
    apply_transaction(
        wallet=get_wallet(user),
        amount=amount,
        kind=WalletEntryKind.TOPUP,
        label=f"+{amount} кирпичей",
    )


@pytest.fixture
def seller():
    user = UserFactory()
    fund(user, 20_000)
    return user


@pytest.fixture
def listing(seller):
    return ListingFactory(owner=seller, status=ListingStatus.ACTIVE)


def promote(client, listing, key: str, **body):
    payload = {"days": 3, **body}
    return client.post(
        reverse("billing:listing-promote", args=[listing.slug]),
        payload,
        format="json",
        HTTP_IDEMPOTENCY_KEY=key,
    )


# -- справочники -------------------------------------------------------------


def test_promotion_catalog_is_seeded():
    package = PromotionPackage.objects.get(code="standard")

    assert package.price_per_day_bricks == DAY_PRICE
    assert set(PromotionOption.objects.values_list("code", flat=True)) == {
        "exact_targeting",
        "client_base",
        "whatsapp_base",
    }


# -- предрасчёт --------------------------------------------------------------


def test_pricing_returns_breakdown_without_charging(seller, listing):
    client = client_for(seller)
    balance_before = get_wallet(seller).balance

    response = client.get(
        reverse("billing:promotions-pricing"),
        {"days": 3, "options": "exact_targeting,whatsapp_base", "listing": listing.slug},
    )

    assert response.status_code == 200, response.data
    body = response.data
    assert body["days"] == 3
    assert body["base_cost"] == 3 * DAY_PRICE
    assert body["options_cost"] == 3 * (300 + 250)
    assert body["total_cost"] == body["base_cost"] + body["options_cost"]
    assert body["balance"] == balance_before
    assert body["is_affordable"] is True
    assert [option["code"] for option in body["options"]] == ["exact_targeting", "whatsapp_base"]
    # Экран рисует пакеты и опции из этого же ответа.
    assert body["packages"][0]["code"] == "standard"
    assert len(body["available_options"]) == 3

    assert get_wallet(seller).balance == balance_before
    assert Promotion.objects.count() == 0


def test_pricing_marks_unaffordable():
    poor = UserFactory()
    get_wallet(poor)  # кошелёк пуст

    response = client_for(poor).get(reverse("billing:promotions-pricing"), {"days": 3})

    assert response.data["is_affordable"] is False
    assert response.data["balance"] == 0


def test_pricing_rejects_unknown_option(seller):
    response = client_for(seller).get(
        reverse("billing:promotions-pricing"), {"days": 1, "options": "magic"}
    )

    assert response.status_code == 400
    assert response.data["error"]["details"]["options"] == ["magic"]


# -- покупка -----------------------------------------------------------------


def test_three_days_cost_exactly_three_day_prices(seller, listing):
    balance_before = get_wallet(seller).balance

    response = promote(client_for(seller), listing, "promo-1")

    assert response.status_code == 201, response.data
    assert response.data["cost_bricks"] == 3 * DAY_PRICE
    assert response.data["balance_after"] == balance_before - 3 * DAY_PRICE
    assert get_wallet(seller).balance == balance_before - 3 * DAY_PRICE

    promotion = Promotion.objects.get(pk=response.data["promotion_id"])
    assert promotion.days == 3
    assert promotion.cost_bricks == 3 * DAY_PRICE
    assert promotion.status == PromotionStatus.ACTIVE

    operation = promotion.transaction
    assert operation.amount == -3 * DAY_PRICE
    assert operation.kind == WalletEntryKind.SPEND
    assert operation.label == f"-{3 * DAY_PRICE} кирпичей"
    assert operation.related == promotion


def test_options_add_to_the_cost(seller, listing):
    balance_before = get_wallet(seller).balance
    expected = 3 * DAY_PRICE + 3 * 300 + 3 * 250

    response = promote(
        client_for(seller),
        listing,
        "promo-options",
        options=["exact_targeting", "client_base"],
    )

    assert response.status_code == 201, response.data
    assert response.data["cost_bricks"] == expected
    assert get_wallet(seller).balance == balance_before - expected

    promotion = Promotion.objects.get(pk=response.data["promotion_id"])
    assert promotion.options == ["exact_targeting", "client_base"]


def test_insufficient_funds_changes_nothing():
    poor = UserFactory()
    fund(poor, 300)
    listing = ListingFactory(owner=poor, status=ListingStatus.ACTIVE)

    response = promote(client_for(poor), listing, "promo-poor")

    assert response.status_code == 402
    error = response.data["error"]
    assert error["code"] == "insufficient_funds"
    assert error["details"]["required"] == 3 * DAY_PRICE
    assert error["details"]["available"] == 300
    assert error["details"]["shortfall"] == 3 * DAY_PRICE - 300

    # Ни продвижения, ни операции, ни изменения баланса.
    assert Promotion.objects.count() == 0
    assert get_wallet(poor).balance == 300
    assert WalletTransaction.objects.filter(kind=WalletEntryKind.SPEND).count() == 0
    listing.refresh_from_db()
    assert listing.promoted_until is None
    # Бонусом: пополнение не тронуто, в леджере только оно.
    assert WalletTransaction.objects.count() == 1


def test_repeated_idempotency_key_does_not_charge_twice(seller, listing):
    client = client_for(seller)
    balance_before = get_wallet(seller).balance

    first = promote(client, listing, "promo-same")
    second = promote(client, listing, "promo-same")

    assert first.status_code == 201
    assert second.status_code == 201
    assert first.data["promotion_id"] == second.data["promotion_id"]
    assert get_wallet(seller).balance == balance_before - 3 * DAY_PRICE
    assert Promotion.objects.count() == 1
    assert WalletTransaction.objects.filter(kind=WalletEntryKind.SPEND).count() == 1


def test_missing_idempotency_key_is_rejected(seller, listing):
    response = client_for(seller).post(
        reverse("billing:listing-promote", args=[listing.slug]),
        {"days": 3},
        format="json",
    )

    assert response.status_code == 400
    assert "Idempotency-Key" in response.data["error"]["message"]
    assert Promotion.objects.count() == 0


def test_extension_adds_days_instead_of_replacing(seller, listing):
    """Три дня поверх неистёкших двух должны дать пять, а не три."""
    # Клиенты создаются внутри замороженного времени: токен, выписанный
    # снаружи, внутри окна невалиден.
    with freeze_time("2026-08-22 10:00:00") as frozen:
        first = promote(client_for(seller), listing, "promo-first", days=2)
        assert first.status_code == 201, first.data

        listing.refresh_from_db()
        first_end = listing.promoted_until
        assert (first_end - timezone.now()).days == 2

        # Через сутки покупаем ещё три дня: остаток — один день.
        frozen.move_to("2026-08-23 10:00:00")
        second = promote(client_for(seller), listing, "promo-second", days=3)

        assert second.status_code == 201, second.data
        listing.refresh_from_db()
        assert listing.promoted_until == first_end + timedelta(days=3)
        # Итого от «сейчас» — четыре дня: один остаточный плюс три купленных.
        assert (listing.promoted_until - timezone.now()).days == 4


def test_promoting_inactive_listing_is_conflict(seller):
    draft = ListingFactory(owner=seller, status=ListingStatus.PENDING)

    response = promote(client_for(seller), draft, "promo-pending")

    assert response.status_code == 409
    assert response.data["error"]["code"] == "conflict"
    assert Promotion.objects.count() == 0


def test_foreign_listing_cannot_be_promoted(seller):
    stranger_listing = ListingFactory(status=ListingStatus.ACTIVE)

    response = promote(client_for(seller), stranger_listing, "promo-foreign")

    assert response.status_code == 403
    assert Promotion.objects.count() == 0


def test_promotion_history_is_owner_only(seller, listing):
    promote(client_for(seller), listing, "promo-history")
    url = reverse("billing:listing-promotions", args=[listing.slug])

    own = client_for(seller).get(url)
    foreign = client_for(UserFactory()).get(url)

    assert own.status_code == 200
    assert len(own.data["results"]) == 1
    assert own.data["results"][0]["cost_display"] == "-2.340"
    assert foreign.status_code == 403


# -- истечение ---------------------------------------------------------------


def test_expired_promotion_clears_promoted_until(seller, listing):
    promote(client_for(seller), listing, "promo-expire", days=1)
    listing.refresh_from_db()
    assert listing.promoted_until is not None

    Promotion.objects.update(ends_at=timezone.now() - timedelta(minutes=1))
    result = expire_promotions()

    listing.refresh_from_db()
    assert result["finished"] == 1
    assert listing.promoted_until is None
    assert Promotion.objects.get().status == PromotionStatus.FINISHED


def test_expiry_keeps_promoted_until_while_another_promotion_runs(seller, listing):
    """Продвижений может быть несколько — флаг снимается только с последним."""
    client = client_for(seller)
    promote(client, listing, "promo-a", days=1)
    promote(client, listing, "promo-b", days=5)

    stale = Promotion.objects.order_by("pk").first()
    Promotion.objects.filter(pk=stale.pk).update(ends_at=timezone.now() - timedelta(minutes=1))

    expire_promotions()

    listing.refresh_from_db()
    assert listing.promoted_until is not None
    assert Promotion.objects.filter(status=PromotionStatus.ACTIVE).count() == 1


def test_expiring_promotion_notifies_owner_once(seller, listing):
    from apps.notifications.models import Notification, NotificationType

    promote(client_for(seller), listing, "promo-warn", days=5)
    Promotion.objects.update(ends_at=timezone.now() + timedelta(hours=10))

    first = expire_promotions()
    second = expire_promotions()

    assert first["warned"] == 1
    assert second["warned"] == 0
    notifications = Notification.objects.filter(
        user=seller, type=NotificationType.PROMOTION_EXPIRING
    )
    assert notifications.count() == 1
    assert "заканчивается завтра" in notifications.get().title


def test_promoted_listing_goes_first_in_catalog(seller, listing, api_client):
    ListingFactory(status=ListingStatus.ACTIVE)
    promote(client_for(seller), listing, "promo-order")

    response = api_client.get(reverse("catalog:listings"))

    assert response.data["results"][0]["slug"] == listing.slug


# -- статистика --------------------------------------------------------------


def test_impressions_are_buffered_and_flushed(seller, listing, api_client):
    from apps.catalog.models import ListingDailyStat
    from apps.catalog.tasks import flush_impressions

    api_client.get(reverse("catalog:listings"))
    api_client.get(reverse("catalog:listings"))

    # До сброса записей в БД нет — показы лежат в буфере.
    assert ListingDailyStat.objects.count() == 0

    flushed = flush_impressions()

    assert flushed >= 1
    stat = ListingDailyStat.objects.get(listing=listing, date=timezone.localdate())
    assert stat.impressions == 2


def test_stats_endpoint_returns_series_and_totals(seller, listing, api_client):
    from apps.catalog.stats import bump_stat
    from apps.catalog.tasks import flush_impressions

    api_client.get(reverse("catalog:listings"))
    flush_impressions()
    bump_stat(listing.pk, "views", 3)
    bump_stat(listing.pk, "favourites")
    bump_stat(listing.pk, "phone_reveals", 2)

    response = client_for(seller).get(reverse("billing:listing-stats", args=[listing.slug]))

    assert response.status_code == 200, response.data
    assert response.data["days"] == 30
    assert len(response.data["series"]) == 30
    assert response.data["totals"]["views"] == 3
    assert response.data["totals"]["favourites"] == 1
    assert response.data["totals"]["phone_reveals"] == 2
    assert response.data["totals"]["impressions"] == 1
    # Продвижений не было — сравнивать не с чем.
    assert response.data["promotion_effect"] is None


def test_stats_include_promotion_effect(seller, listing):
    from apps.catalog.stats import bump_stat

    today = timezone.localdate()
    # День до продвижения и день во время него.
    bump_stat(listing.pk, "views", 2, day=today - timedelta(days=5))
    bump_stat(listing.pk, "views", 20, day=today)

    promote(client_for(seller), listing, "promo-stats", days=1)

    response = client_for(seller).get(reverse("billing:listing-stats", args=[listing.slug]))
    effect = response.data["promotion_effect"]

    assert effect is not None
    assert effect["promoted_days"] >= 1
    assert effect["during"]["views"] > effect["before"]["views"]


def test_phone_reveal_is_counted(listing, api_client):
    from apps.catalog.models import ListingDailyStat

    viewer = UserFactory()
    response = client_for(viewer).post(reverse("users:listing-contact", args=[listing.slug]))

    assert response.status_code == 200
    assert response.data["phone"] == listing.owner.phone
    stat = ListingDailyStat.objects.get(listing=listing, date=timezone.localdate())
    assert stat.phone_reveals == 1


def test_owner_phone_reveal_does_not_inflate_stats(seller, listing):
    from apps.catalog.models import ListingDailyStat

    client_for(seller).post(reverse("users:listing-contact", args=[listing.slug]))

    assert not ListingDailyStat.objects.filter(listing=listing).exists()


def test_stats_are_owner_only(listing):
    response = client_for(UserFactory()).get(reverse("billing:listing-stats", args=[listing.slug]))

    assert response.status_code == 403


def test_view_and_favourite_increment_daily_stats(listing, api_client):
    from apps.catalog.models import ListingDailyStat

    viewer = UserFactory()
    client = client_for(viewer)
    client.post(reverse("catalog:listing-view", args=[listing.slug]))
    client.post(reverse("engagement:listing-favourite", args=[listing.slug]))

    stat = ListingDailyStat.objects.get(listing=listing, date=timezone.localdate())
    assert stat.views == 1
    assert stat.favourites == 1
