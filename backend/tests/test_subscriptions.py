"""Подписки и тарифы риелторов и агентств."""

from datetime import timedelta

import pytest
from django.urls import reverse
from django.utils import timezone
from freezegun import freeze_time
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.billing.models import Subscription, SubscriptionStatus, Tariff, WalletTransaction
from apps.billing.services import apply_transaction, get_wallet
from apps.billing.subscriptions import (
    MONTH_DAYS,
    current_subscription,
    get_listings_limit,
    subscribe,
)
from apps.billing.tasks import auto_bump_listings, process_subscriptions
from apps.catalog.enums import ListingStatus
from apps.catalog.models import Listing
from apps.common.enums import WalletEntryKind
from tests.factories import ListingFactory, ListingMediaFactory, UserFactory

pytestmark = pytest.mark.django_db

REALTOR_PRICE = 4900
AGENCY_PRICE = 14900

SUBSCRIBE_URL = "billing:subscriptions"
CURRENT_URL = "billing:subscription-current"
CANCEL_URL = "billing:subscription-cancel"


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


def buy(client, key: str, tariff_code: str = "realtor", months: int = 1):
    return client.post(
        reverse(SUBSCRIBE_URL),
        {"tariff_code": tariff_code, "months": months},
        format="json",
        HTTP_IDEMPOTENCY_KEY=key,
    )


@pytest.fixture
def rich_user():
    user = UserFactory()
    fund(user, 100_000)
    return user


# -- справочник --------------------------------------------------------------


def test_tariffs_are_seeded():
    tariffs = {tariff.code: tariff for tariff in Tariff.objects.all()}

    assert set(tariffs) == {"free", "realtor", "agency"}
    assert tariffs["free"].price_bricks_per_month == 0
    assert tariffs["free"].listings_limit == 3
    assert tariffs["realtor"].price_bricks_per_month == REALTOR_PRICE
    assert tariffs["agency"].listings_limit == 0  # без ограничений
    assert tariffs["agency"].features["verified_badge"] is True
    assert tariffs["free"].features["priority_in_search"] is False


def test_tariffs_endpoint_is_public_and_marks_current(api_client, rich_user):
    anonymous = api_client.get(reverse("billing:tariffs"))

    assert anonymous.status_code == 200
    assert [item["code"] for item in anonymous.data] == ["free", "realtor", "agency"]
    # Без подписки текущим считается бесплатный тариф.
    assert [item["code"] for item in anonymous.data if item["is_current"]] == ["free"]

    buy(client_for(rich_user), "tariff-current")
    subscribed = client_for(rich_user).get(reverse("billing:tariffs"))

    assert [item["code"] for item in subscribed.data if item["is_current"]] == ["realtor"]


# -- покупка -----------------------------------------------------------------


def test_purchase_charges_price_and_lifts_publication_limit(rich_user):
    client = client_for(rich_user)
    balance_before = get_wallet(rich_user).balance
    assert get_listings_limit(rich_user) == 3

    response = buy(client, "sub-1")

    assert response.status_code == 201, response.data
    assert response.data["tariff"]["code"] == "realtor"
    assert get_wallet(rich_user).balance == balance_before - REALTOR_PRICE
    assert get_listings_limit(rich_user) == 20

    operation = Subscription.objects.get().transaction
    assert operation.amount == -REALTOR_PRICE
    assert operation.kind == WalletEntryKind.SPEND
    assert operation.label == f"-{REALTOR_PRICE} кирпичей (подписка «Риелтор», 1 мес.)"


def test_subscription_allows_publishing_beyond_free_limit(
    rich_user, django_capture_on_commit_callbacks
):
    """Без подписки четвёртое объявление не публикуется, с подпиской — да."""
    client = client_for(rich_user)
    for _ in range(3):
        ListingFactory(owner=rich_user, status=ListingStatus.ACTIVE)

    draft = ListingFactory(owner=rich_user, status=ListingStatus.DRAFT)
    ListingMediaFactory(listing=draft, is_cover=True)
    publish_url = reverse("catalog:listing-publish", args=[draft.slug])

    blocked = client.post(publish_url)
    assert blocked.status_code == 409

    buy(client, "sub-limit")

    with django_capture_on_commit_callbacks(execute=True):
        allowed = client.post(publish_url)

    assert allowed.status_code == 200, allowed.data
    draft.refresh_from_db()
    assert draft.status in (ListingStatus.ACTIVE, ListingStatus.PENDING)


def test_months_multiply_the_price(rich_user):
    balance_before = get_wallet(rich_user).balance

    response = buy(client_for(rich_user), "sub-3m", months=3)

    assert response.status_code == 201, response.data
    assert get_wallet(rich_user).balance == balance_before - 3 * REALTOR_PRICE
    subscription = Subscription.objects.get()
    assert (subscription.ends_at - subscription.starts_at).days == 3 * MONTH_DAYS


def test_insufficient_funds_creates_nothing():
    poor = UserFactory()
    fund(poor, 100)

    response = buy(client_for(poor), "sub-poor")

    assert response.status_code == 402
    details = response.data["error"]["details"]
    assert details["required"] == REALTOR_PRICE
    assert details["available"] == 100
    assert details["shortfall"] == REALTOR_PRICE - 100
    assert Subscription.objects.count() == 0
    assert get_wallet(poor).balance == 100
    assert WalletTransaction.objects.filter(kind=WalletEntryKind.SPEND).count() == 0


def test_free_tariff_cannot_be_purchased(rich_user):
    response = buy(client_for(rich_user), "sub-free", tariff_code="free")

    assert response.status_code == 400
    assert Subscription.objects.count() == 0


def test_unknown_tariff_is_rejected(rich_user):
    response = buy(client_for(rich_user), "sub-unknown", tariff_code="platinum")

    assert response.status_code == 400
    assert response.data["error"]["details"]["tariff_code"] == "platinum"


def test_missing_idempotency_key_is_rejected(rich_user):
    response = client_for(rich_user).post(
        reverse(SUBSCRIBE_URL), {"tariff_code": "realtor", "months": 1}, format="json"
    )

    assert response.status_code == 400
    assert Subscription.objects.count() == 0


def test_repeated_idempotency_key_does_not_charge_twice(rich_user):
    client = client_for(rich_user)
    balance_before = get_wallet(rich_user).balance

    first = buy(client, "sub-same")
    second = buy(client, "sub-same")

    assert first.data["id"] == second.data["id"]
    assert get_wallet(rich_user).balance == balance_before - REALTOR_PRICE
    assert Subscription.objects.count() == 1


# -- продление и смена тарифа ------------------------------------------------


def test_extension_of_same_tariff_adds_periods(rich_user):
    # Проверки внутри замороженного окна: снаружи «сейчас» уже другое, и
    # подписка, начавшаяся в 10:00 UTC, ещё не считалась бы действующей.
    with freeze_time("2026-08-22 10:00:00"):
        first = subscribe(rich_user, "realtor", 1, "ext-1")
        first_end = first.ends_at

        second = subscribe(rich_user, "realtor", 1, "ext-2")

        assert second.ends_at == first_end + timedelta(days=MONTH_DAYS)
        assert second.starts_at == first.starts_at
        # Действующая подписка одна: прежняя закрыта продлением.
        first.refresh_from_db()
        assert first.status == SubscriptionStatus.CANCELLED
        assert current_subscription(rich_user).pk == second.pk


def test_upgrade_credits_the_remaining_period(rich_user):
    """Остаток дорогого-в-будущем тарифа не сгорает: он идёт зачётом."""
    with freeze_time("2026-08-22 10:00:00") as frozen:
        subscribe(rich_user, "realtor", 1, "up-1")
        balance_after_first = get_wallet(rich_user).balance

        # Половина месяца прошла — зачёту подлежит примерно половина цены.
        frozen.move_to("2026-09-06 10:00:00")
        subscribe(rich_user, "agency", 1, "up-2")

        charged = balance_after_first - get_wallet(rich_user).balance
        expected_credit = REALTOR_PRICE // 2

        assert charged == pytest.approx(AGENCY_PRICE - expected_credit, abs=50)
        assert current_subscription(rich_user).tariff.code == "agency"
        assert get_listings_limit(rich_user) == 0  # без ограничений


def test_downgrade_starts_after_the_paid_period(rich_user):
    """Оплаченное не отбираем: дешёвый тариф ждёт конца текущего периода."""
    with freeze_time("2026-08-22 10:00:00"):
        expensive = subscribe(rich_user, "agency", 1, "down-1")
        cheap = subscribe(rich_user, "realtor", 1, "down-2")

        assert cheap.starts_at == expensive.ends_at
        assert cheap.ends_at == expensive.ends_at + timedelta(days=MONTH_DAYS)
        # Пока действует прежний тариф — его лимиты и его фичи.
        assert current_subscription(rich_user).tariff.code == "agency"
        assert get_listings_limit(rich_user) == 0

    expensive.refresh_from_db()
    assert expensive.status == SubscriptionStatus.ACTIVE


def test_second_downgrade_is_conflict(rich_user):
    with freeze_time("2026-08-22 10:00:00"):
        subscribe(rich_user, "agency", 1, "down2-1")
        subscribe(rich_user, "realtor", 1, "down2-2")

        with pytest.raises(Exception) as exc:
            subscribe(rich_user, "realtor", 1, "down2-3")

    assert exc.value.status_code == 409


# -- текущая подписка и отмена -----------------------------------------------


def test_current_endpoint_reports_free_slots(rich_user):
    client = client_for(rich_user)
    buy(client, "state-1")
    for _ in range(4):
        ListingFactory(owner=rich_user, status=ListingStatus.ACTIVE)

    response = client.get(reverse(CURRENT_URL))

    assert response.status_code == 200, response.data
    assert response.data["tariff"]["code"] == "realtor"
    assert response.data["listings_limit"] == 20
    assert response.data["listings_used"] == 4
    assert response.data["listings_free"] == 16
    assert response.data["subscription"]["is_current"] is True


def test_current_endpoint_without_subscription(rich_user):
    response = client_for(rich_user).get(reverse(CURRENT_URL))

    assert response.data["subscription"] is None
    assert response.data["tariff"]["code"] == "free"
    assert response.data["listings_limit"] == 3
    assert response.data["listings_free"] == 3


def test_unlimited_tariff_reports_null_free_slots(rich_user):
    client = client_for(rich_user)
    buy(client, "state-agency", tariff_code="agency")

    response = client.get(reverse(CURRENT_URL))

    assert response.data["listings_limit"] == 0
    assert response.data["listings_free"] is None


def test_cancel_keeps_the_paid_period(rich_user):
    client = client_for(rich_user)
    bought = buy(client, "cancel-1")
    ends_at = bought.data["ends_at"]

    response = client.post(reverse(CANCEL_URL))

    assert response.status_code == 200, response.data
    assert response.data["is_auto_renew"] is False
    # Ничего не отобрали: статус прежний, срок прежний, лимит прежний.
    assert response.data["status"] == SubscriptionStatus.ACTIVE
    assert response.data["ends_at"] == ends_at
    assert response.data["is_current"] is True
    assert get_listings_limit(rich_user) == 20


def test_cancel_without_subscription_is_conflict(rich_user):
    assert client_for(rich_user).post(reverse(CANCEL_URL)).status_code == 409


def test_double_cancel_is_conflict(rich_user):
    client = client_for(rich_user)
    buy(client, "cancel-2")

    assert client.post(reverse(CANCEL_URL)).status_code == 200
    assert client.post(reverse(CANCEL_URL)).status_code == 409


def test_anonymous_cannot_subscribe(api_client):
    response = api_client.post(
        reverse(SUBSCRIBE_URL),
        {"tariff_code": "realtor", "months": 1},
        format="json",
        HTTP_IDEMPOTENCY_KEY="anon",
    )

    assert response.status_code == 401


# -- автопродление и истечение -----------------------------------------------


def test_auto_renew_charges_and_extends(rich_user):
    subscription = subscribe(rich_user, "realtor", 1, "renew-ok")
    Subscription.objects.filter(pk=subscription.pk).update(
        ends_at=timezone.now() + timedelta(hours=10)
    )
    balance_before = get_wallet(rich_user).balance

    result = process_subscriptions()

    subscription.refresh_from_db()
    assert result["renewed"] == 1
    assert result["failed"] == 0
    assert get_wallet(rich_user).balance == balance_before - REALTOR_PRICE
    assert subscription.status == SubscriptionStatus.ACTIVE
    assert subscription.ends_at > timezone.now() + timedelta(days=MONTH_DAYS)


def test_auto_renew_without_money_does_not_go_negative(rich_user):
    from apps.notifications.models import Notification

    subscription = subscribe(rich_user, "realtor", 1, "renew-poor")
    # Тратим остаток, чтобы на продление не хватило.
    wallet = get_wallet(rich_user)
    apply_transaction(
        wallet=wallet,
        amount=-wallet.balance,
        kind=WalletEntryKind.SPEND,
        label="-всё",
    )
    Subscription.objects.filter(pk=subscription.pk).update(
        ends_at=timezone.now() + timedelta(hours=10)
    )

    result = process_subscriptions()

    assert result["failed"] == 1
    assert result["renewed"] == 0
    assert get_wallet(rich_user).balance == 0
    subscription.refresh_from_db()
    assert subscription.ends_at < timezone.now() + timedelta(days=1)

    notification = Notification.objects.filter(user=rich_user).latest("created_at")
    assert notification.title == "Не удалось продлить подписку"
    assert notification.payload["kind"] == "subscription_renew_failed"


def test_cancelled_subscription_is_not_renewed(rich_user):
    from apps.billing.subscriptions import cancel_subscription

    subscription = subscribe(rich_user, "realtor", 1, "renew-cancelled")
    cancel_subscription(rich_user)
    Subscription.objects.filter(pk=subscription.pk).update(
        ends_at=timezone.now() + timedelta(hours=10)
    )
    balance_before = get_wallet(rich_user).balance

    result = process_subscriptions()

    assert result["renewed"] == 0
    assert get_wallet(rich_user).balance == balance_before


def test_expiry_archives_oldest_listings_over_the_limit(rich_user):
    from apps.notifications.models import Notification

    subscription = subscribe(rich_user, "realtor", 1, "expire-1")
    now = timezone.now()

    listings = []
    for index in range(6):
        listing = ListingFactory(owner=rich_user, status=ListingStatus.ACTIVE)
        Listing.objects.filter(pk=listing.pk).update(published_at=now - timedelta(days=10 - index))
        listings.append(listing)

    Subscription.objects.filter(pk=subscription.pk).update(
        ends_at=now - timedelta(minutes=1), is_auto_renew=False
    )

    result = process_subscriptions()

    subscription.refresh_from_db()
    assert subscription.status == SubscriptionStatus.EXPIRED
    assert result["archived"] == 3  # 6 активных, бесплатный лимит — 3

    statuses = {listing.slug: Listing.objects.get(pk=listing.pk).status for listing in listings}
    # В архив ушли три самых старых, три свежих остались активными.
    assert [statuses[listing.slug] for listing in listings[:3]] == [ListingStatus.ARCHIVED] * 3
    assert [statuses[listing.slug] for listing in listings[3:]] == [ListingStatus.ACTIVE] * 3

    notification = Notification.objects.filter(user=rich_user).latest("created_at")
    assert notification.payload["kind"] == "subscription_expired"
    assert notification.payload["archived"] == 3


def test_expiry_without_surplus_archives_nothing(rich_user):
    subscription = subscribe(rich_user, "realtor", 1, "expire-2")
    ListingFactory(owner=rich_user, status=ListingStatus.ACTIVE)
    Subscription.objects.filter(pk=subscription.pk).update(
        ends_at=timezone.now() - timedelta(minutes=1), is_auto_renew=False
    )

    result = process_subscriptions()

    assert result["expired"] == 1
    assert result["archived"] == 0
    assert Listing.objects.filter(owner=rich_user, status=ListingStatus.ACTIVE).count() == 1


def test_auto_bump_updates_published_at(rich_user):
    subscribe(rich_user, "realtor", 1, "bump-1")
    listing = ListingFactory(owner=rich_user, status=ListingStatus.ACTIVE)
    Listing.objects.filter(pk=listing.pk).update(published_at=timezone.now() - timedelta(days=5))

    bumped = auto_bump_listings()

    listing.refresh_from_db()
    assert bumped == 1
    assert listing.published_at > timezone.now() - timedelta(minutes=1)

    # Второй запуск в те же сутки ничего не делает.
    assert auto_bump_listings() == 0


def test_auto_bump_skips_tariffs_without_the_feature(rich_user):
    Tariff.objects.filter(code="realtor").update(
        features={"priority_in_search": True, "auto_bump_daily": False}
    )
    subscribe(rich_user, "realtor", 1, "bump-2")
    ListingFactory(owner=rich_user, status=ListingStatus.ACTIVE)

    assert auto_bump_listings() == 0


# -- приоритет в выдаче ------------------------------------------------------


def test_priority_in_search_lifts_listings_below_promoted(api_client, rich_user):
    """Купленное продвижение всегда выше тарифного приоритета."""
    plain_owner = UserFactory()
    plain = ListingFactory(owner=plain_owner, status=ListingStatus.ACTIVE)

    promoted_owner = UserFactory()
    promoted = ListingFactory(owner=promoted_owner, status=ListingStatus.ACTIVE)
    Listing.objects.filter(pk=promoted.pk).update(promoted_until=timezone.now() + timedelta(days=1))

    subscriber_listing = ListingFactory(owner=rich_user, status=ListingStatus.ACTIVE)
    subscribe(rich_user, "realtor", 1, "priority-1")

    response = api_client.get(reverse("catalog:listings"))
    slugs = [item["slug"] for item in response.data["results"]]

    assert slugs.index(promoted.slug) < slugs.index(subscriber_listing.slug)
    assert slugs.index(subscriber_listing.slug) < slugs.index(plain.slug)


def test_priority_disappears_when_subscription_expires(api_client, rich_user):
    mine = ListingFactory(owner=rich_user, status=ListingStatus.ACTIVE)
    # Чужое объявление свежее: без приоритета оно обязано идти первым.
    plain = ListingFactory(owner=UserFactory(), status=ListingStatus.ACTIVE)
    Listing.objects.filter(pk=plain.pk).update(published_at=timezone.now())
    Listing.objects.filter(pk=mine.pk).update(published_at=timezone.now() - timedelta(days=1))

    subscription = subscribe(rich_user, "realtor", 1, "priority-2")

    ahead = api_client.get(reverse("catalog:listings")).data["results"]
    assert [item["slug"] for item in ahead].index(mine.slug) == 0

    Subscription.objects.filter(pk=subscription.pk).update(
        ends_at=timezone.now() - timedelta(minutes=1)
    )
    after = api_client.get(reverse("catalog:listings")).data["results"]

    slugs = [item["slug"] for item in after]
    assert slugs.index(plain.slug) < slugs.index(mine.slug)


def test_catalog_query_count_is_stable_with_priority(api_client, rich_user):
    """Приоритет считается одним подзапросом, а не запросом на карточку."""
    from django.db import connection
    from django.test.utils import CaptureQueriesContext

    subscribe(rich_user, "realtor", 1, "priority-queries")
    for _ in range(6):
        ListingFactory(owner=rich_user, status=ListingStatus.ACTIVE)

    url = reverse("catalog:listings")
    with CaptureQueriesContext(connection) as small:
        assert api_client.get(url, {"page_size": 2}).status_code == 200
    with CaptureQueriesContext(connection) as large:
        assert api_client.get(url, {"page_size": 6}).status_code == 200

    assert len(large.captured_queries) == len(small.captured_queries)
