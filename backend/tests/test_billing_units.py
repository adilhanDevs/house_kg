"""Точечные тесты биллинга: ветки, до которых не доходят сценарные тесты.

Здесь проверяется то, что в обычном прогоне не срабатывает: заготовка
банковского провайдера, отказы подписи, действия админки, форматирование
сумм и защита неизменяемого леджера. Для биллинга это не педантизм —
непокрытая ветка там стоит дороже любой другой.
"""

import json
from decimal import Decimal
from unittest.mock import Mock, patch

import pytest
from django.core.exceptions import ImproperlyConfigured
from django.utils import timezone

from apps.billing.models import (
    Payment,
    PaymentStatus,
    Promotion,
    PromotionStatus,
    Subscription,
    SubscriptionStatus,
    Wallet,
    WalletTransaction,
    format_bricks,
)
from apps.billing.providers import WebhookSignatureError, get_payment_provider
from apps.billing.providers.bank import BankPaymentProvider
from apps.billing.providers.mock import MockPaymentProvider
from apps.billing.services import apply_transaction, get_wallet
from apps.common.enums import WalletEntryKind
from apps.common.exceptions import ConflictError
from tests.factories import (
    ListingFactory,
    PaymentFactory,
    PromotionFactory,
    SubscriptionFactory,
    TariffFactory,
    UserFactory,
    WalletTransactionFactory,
)

pytestmark = pytest.mark.django_db


# -- форматирование и свойства моделей ---------------------------------------


@pytest.mark.parametrize(
    ("amount", "expected"),
    [(0, "0"), (780, "780"), (16_700, "16.700"), (1_234_567, "1.234.567"), (-500, "-500")],
)
def test_format_bricks(amount: int, expected: str):
    """Разделитель разрядов — точка, как в макете экрана кошелька."""
    assert format_bricks(amount) == expected


def test_wallet_str_and_display(wallet_with_balance):
    wallet = wallet_with_balance(balance=16_700)

    assert wallet.balance_display == "16.700"
    assert "16.700" in str(wallet)


def test_transaction_amount_display(wallet_with_balance):
    wallet = wallet_with_balance(balance=1_000)
    credit = WalletTransactionFactory(wallet=wallet, amount=2_000)
    debit = WalletTransactionFactory(wallet=wallet, amount=-500, kind=WalletEntryKind.SPEND)

    assert credit.amount_display == "+2.000"
    assert debit.amount_display == "-500"
    assert str(credit).startswith("+2000")


def test_ledger_entries_are_immutable(wallet_with_balance):
    """Ошибочная операция компенсируется обратной, а не правкой."""
    wallet = wallet_with_balance(balance=1_000)
    operation = WalletTransaction.objects.filter(wallet=wallet).first()

    with pytest.raises(RuntimeError, match="неизменяемы"):
        operation.label = "подмена"
        operation.save()

    with pytest.raises(RuntimeError, match="не удаляются"):
        operation.delete()


def test_tariff_helpers():
    free = TariffFactory(code="free", price_bricks_per_month=0, listings_limit=3, features={})
    agency = TariffFactory(
        code="agency",
        price_bricks_per_month=14_900,
        listings_limit=0,
        features={"verified_badge": True},
    )

    assert free.is_free is True
    assert free.is_unlimited is False
    assert agency.is_free is False
    assert agency.is_unlimited is True
    assert agency.has_feature("verified_badge") is True
    assert agency.has_feature("nope") is False
    assert agency.cost_for(3) == 44_700
    assert str(agency) == "Агентство"


def test_promotion_helpers(promotion_package):
    promotion = PromotionFactory(package=promotion_package, days=3)

    assert promotion.cost_bricks == 2_340
    assert promotion.is_running is True
    assert str(promotion.listing_id) in str(promotion)

    Promotion.objects.filter(pk=promotion.pk).update(status=PromotionStatus.FINISHED)
    promotion.refresh_from_db()
    assert promotion.is_running is False


def test_subscription_helpers(tariff):
    subscription = SubscriptionFactory(tariff=tariff)

    assert subscription.is_current is True
    assert subscription.days_left == 29  # 30 суток минус доли текущего дня
    assert str(subscription.user_id) in str(subscription)

    Subscription.objects.filter(pk=subscription.pk).update(
        status=SubscriptionStatus.EXPIRED, ends_at=timezone.now() - timezone.timedelta(days=1)
    )
    subscription.refresh_from_db()
    assert subscription.is_current is False
    assert subscription.days_left == 0


def test_package_and_option_str(promotion_package, promotion_option):
    assert "780" in str(promotion_package)
    assert str(promotion_option).startswith(promotion_option.name)


# -- провайдеры --------------------------------------------------------------


def test_unknown_provider_is_configuration_error():
    with pytest.raises(ImproperlyConfigured, match="Неизвестный платёжный провайдер"):
        get_payment_provider("visa-gold")


def test_mock_provider_rejects_bad_signature(settings):
    settings.PAYMENT_WEBHOOK_SECRET = "shared-secret"
    provider = MockPaymentProvider()

    request = Mock(headers={"X-Signature": "wrong"}, data={})

    with pytest.raises(WebhookSignatureError):
        provider.verify_webhook(request)


def test_mock_provider_parses_payload_from_body(settings):
    """Вебхук может прийти сырым телом, а не разобранным словарём."""
    settings.PAYMENT_WEBHOOK_SECRET = "shared-secret"
    provider = MockPaymentProvider()

    request = Mock(
        headers={"X-Signature": "shared-secret"},
        data=None,
        body=json.dumps({"provider_ref": "ref-1", "status": "succeeded", "amount": "100"}).encode(),
    )
    result = provider.verify_webhook(request)

    assert result.provider_ref == "ref-1"
    assert result.status == "succeeded"
    assert result.amount == Decimal("100")


def test_mock_provider_survives_broken_amount_and_body(settings):
    settings.PAYMENT_WEBHOOK_SECRET = "shared-secret"
    provider = MockPaymentProvider()

    broken_amount = provider.verify_webhook(
        Mock(headers={"X-Signature": "shared-secret"}, data={"amount": "не число"})
    )
    broken_body = provider.verify_webhook(
        Mock(headers={"X-Signature": "shared-secret"}, data=None, body=b"{not json")
    )

    assert broken_amount.amount is None
    assert broken_body.raw == {}


# -- заготовка банковского шлюза ---------------------------------------------
#
# Реального банка в тестах нет, поэтому HTTP замокан. Проверяется то, что
# сломается первым при подключении: подпись, обработка ответа и разбор вебхука.


@pytest.fixture
def bank(settings) -> BankPaymentProvider:
    settings.BANK_PAYMENT_API_URL = "https://bank.example/api/invoices"
    settings.BANK_PAYMENT_MERCHANT_ID = "merchant-1"
    settings.BANK_PAYMENT_SECRET = "bank-secret"
    settings.BANK_PAYMENT_TIMEOUT = 5
    return BankPaymentProvider()


def test_bank_signature_is_stable_and_depends_on_payload(bank: BankPaymentProvider):
    payload = {"b": 2, "a": 1}

    # Порядок ключей не должен влиять: подпись считается от канонического вида.
    assert bank.sign(payload) == bank.sign({"a": 1, "b": 2})
    assert bank.sign(payload) != bank.sign({"a": 1, "b": 3})


def test_bank_refuses_to_work_unconfigured(settings):
    settings.BANK_PAYMENT_API_URL = ""
    settings.BANK_PAYMENT_SECRET = ""

    with pytest.raises(RuntimeError, match="не настроен"):
        BankPaymentProvider().create_payment(payment=PaymentFactory(), return_url="")


def test_bank_creates_payment_intent(bank: BankPaymentProvider):
    payment = PaymentFactory()
    response = Mock()
    response.json.return_value = {
        "payment_url": "https://bank.example/pay/1",
        "qr_url": "https://bank.example/qr/1",
        "payment_id": "bank-ref-1",
    }
    response.raise_for_status.return_value = None

    with patch("apps.billing.providers.bank.requests.post", return_value=response) as post:
        intent = bank.create_payment(payment=payment, return_url="app://back")

    assert intent.payment_url == "https://bank.example/pay/1"
    assert intent.provider_ref == "bank-ref-1"

    _, kwargs = post.call_args
    assert kwargs["json"]["order_id"] == str(payment.pk)
    assert kwargs["headers"]["X-Signature"] == bank.sign(kwargs["json"])


def test_bank_webhook_requires_matching_signature(bank: BankPaymentProvider):
    payload = {"payment_id": "bank-ref-1", "status": "paid", "amount": "12000"}

    good = bank.verify_webhook(Mock(headers={"X-Signature": bank.sign(payload)}, data=payload))

    assert good.provider_ref == "bank-ref-1"
    assert good.status == "succeeded"
    assert good.amount == Decimal("12000")

    # Не-ASCII в заголовке — тоже отказ подписи, а не падение сравнения.
    with pytest.raises(WebhookSignatureError):
        bank.verify_webhook(Mock(headers={"X-Signature": "подделка"}, data=payload))

    with pytest.raises(WebhookSignatureError):
        bank.verify_webhook(Mock(headers={}, data=payload))


@pytest.mark.parametrize(
    ("bank_status", "expected"),
    [("paid", "succeeded"), ("declined", "failed"), ("expired", "expired"), ("????", "failed")],
)
def test_bank_status_map(bank: BankPaymentProvider, bank_status: str, expected: str):
    """Незнакомый статус трактуется как отказ, а не как успех."""
    payload = {"payment_id": "ref", "status": bank_status, "amount": "1"}
    result = bank.verify_webhook(Mock(headers={"X-Signature": bank.sign(payload)}, data=payload))

    assert result.status == expected


def test_bank_parses_body_and_broken_amount(bank: BankPaymentProvider):
    payload = {"payment_id": "ref", "status": "paid", "amount": "не число"}
    request = Mock(
        headers={"X-Signature": bank.sign(payload)},
        data=None,
        body=json.dumps(payload).encode(),
    )

    result = bank.verify_webhook(request)

    assert result.amount is None


def test_bank_handles_unreadable_body(bank: BankPaymentProvider):
    empty_signature = bank.sign({})
    request = Mock(headers={"X-Signature": empty_signature}, data=None, body=None)

    result = bank.verify_webhook(request)

    assert result.raw == {}


# -- идемпотентность платежей ------------------------------------------------


def test_foreign_idempotency_key_is_conflict(user):
    from apps.billing.payments import create_topup

    PaymentFactory(user=UserFactory(), idempotency_key="shared-key")

    with pytest.raises(ConflictError, match="уже использован"):
        create_topup(
            user=user,
            amount_kgs=Decimal("1000"),
            provider_code="mock",
            idempotency_key="shared-key",
        )


def test_expired_idempotency_key_is_conflict(user, settings):
    from apps.billing.payments import create_topup

    settings.PAYMENT_IDEMPOTENCY_TTL_HOURS = 24
    payment = PaymentFactory(user=user, idempotency_key="old-key")
    Payment.objects.filter(pk=payment.pk).update(
        created_at=timezone.now() - timezone.timedelta(days=2)
    )

    with pytest.raises(ConflictError, match="сформируйте новый"):
        create_topup(
            user=user,
            amount_kgs=Decimal("1000"),
            provider_code="mock",
            idempotency_key="old-key",
        )


def test_expire_payments_task_closes_stale_invoices(user, settings):
    from apps.billing.tasks import expire_payments

    settings.PAYMENT_EXPIRY_MINUTES = 5
    payment = PaymentFactory(user=user, status=PaymentStatus.PENDING)
    Payment.objects.filter(pk=payment.pk).update(
        expires_at=timezone.now() - timezone.timedelta(minutes=1)
    )

    assert expire_payments() == 1
    payment.refresh_from_db()
    assert payment.status == PaymentStatus.EXPIRED


# -- продвижение и подписки: краевые ветки -----------------------------------


def test_unknown_promotion_package_is_validation_error():
    from apps.billing.promotions import get_package
    from apps.common.exceptions import ApiValidationError

    with pytest.raises(ApiValidationError):
        get_package("platinum")


def test_has_feature_without_subscription(user, tariff):
    from apps.billing.subscriptions import has_feature

    assert has_feature(user, "priority_in_search") is False

    SubscriptionFactory(user=user, tariff=tariff)
    assert has_feature(user, "priority_in_search") is True
    assert has_feature(user, "support_priority") is False


def test_remaining_value_is_zero_for_free_and_expired(user):
    from apps.billing.subscriptions import remaining_value

    free = TariffFactory(code="free", price_bricks_per_month=0, listings_limit=3)
    free_subscription = SubscriptionFactory(user=user, tariff=free)
    assert remaining_value(free_subscription) == 0

    paid = SubscriptionFactory(user=UserFactory(), tariff=TariffFactory(code="realtor"))
    Subscription.objects.filter(pk=paid.pk).update(
        ends_at=timezone.now() - timezone.timedelta(days=1)
    )
    paid.refresh_from_db()
    assert remaining_value(paid) == 0


def test_archive_over_limit_does_nothing_for_unlimited_tariff(user):
    from apps.billing.tasks import _archive_over_limit

    ListingFactory(owner=user)

    assert _archive_over_limit(user, 0) == 0


# -- админка -----------------------------------------------------------------


def test_wallet_admin_is_read_only(admin_user):
    from django.contrib.admin.sites import AdminSite

    from apps.billing.admin import PaymentAdmin, WalletAdmin, WalletTransactionAdmin

    site = AdminSite()
    request = Mock(user=admin_user)

    wallet_admin = WalletAdmin(Wallet, site)
    tx_admin = WalletTransactionAdmin(WalletTransaction, site)
    payment_admin = PaymentAdmin(Payment, site)

    # Баланс меняется только через apply_transaction, леджер append-only,
    # платежи создаёт провайдер — руками в админке ничего не заводится.
    assert wallet_admin.has_add_permission(request) is False
    assert tx_admin.has_add_permission(request) is False
    assert tx_admin.has_change_permission(request) is False
    assert tx_admin.has_delete_permission(request) is False
    assert payment_admin.has_add_permission(request) is False


def test_promotion_and_subscription_admin_columns(admin_user, promotion_package, tariff):
    from django.contrib.admin.sites import AdminSite

    from apps.billing.admin import PromotionAdmin, SubscriptionAdmin

    site = AdminSite()
    promotion = PromotionFactory(package=promotion_package)
    subscription = SubscriptionFactory(tariff=tariff)

    promotion_admin = PromotionAdmin(Promotion, site)
    subscription_admin = SubscriptionAdmin(Subscription, site)

    assert "cost_bricks" in promotion_admin.list_display
    assert promotion.pk is not None
    assert "tariff" in subscription_admin.list_display
    assert subscription.pk is not None


def test_spend_label_and_balance_after_are_consistent(wallet_with_balance):
    """balance_after в леджере обязан совпадать с балансом кошелька."""
    wallet = wallet_with_balance(balance=5_000)

    operation = apply_transaction(
        wallet=wallet,
        amount=-780,
        kind=WalletEntryKind.SPEND,
        label="-780 кирпичей",
    )

    wallet.refresh_from_db()
    assert operation.balance_after == wallet.balance == 4_220
    assert get_wallet(wallet.user).balance == 4_220


def test_finik_provider_signature_and_webhook(settings):
    from apps.billing.providers.finik import FinikPaymentProvider

    settings.FINIK_SECRET_KEY = "test-finik-secret"
    provider = FinikPaymentProvider()

    payload = {"payment_id": "fnk_999", "status": "paid", "amount": "12000"}
    signature = provider.sign(payload)

    # Валидная подпись
    request = Mock(headers={"X-Signature": signature}, data=payload)
    result = provider.verify_webhook(request)

    assert result.provider_ref == "fnk_999"
    assert result.status == "succeeded"
    assert result.amount == Decimal("12000")

    # Невалидная подпись
    bad_request = Mock(headers={"X-Signature": "invalid-signature"}, data=payload)
    with pytest.raises(WebhookSignatureError):
        provider.verify_webhook(bad_request)


def _finik_callback_payload(**overrides):
    payload = {
        "status": "SUCCEEDED",
        "accountId": "finik-account-123",
        "amount": "12000.00",
        "transactionId": "trx-123",
        "item": {"id": "item-123"},
        "fields": {
            "paymentId": "550e8400-e29b-41d4-a716-446655440000",
            "finikRequestId": "550e8400-e29b-41d4-a716-446655440000",
            "paymentKind": "wallet_topup",
        },
    }
    payload.update(overrides)
    return payload


def _finik_item(payment_id="550e8400-e29b-41d4-a716-446655440000", amount=12000):
    return {
        "id": "item-123",
        "fixedAmount": amount,
        "paymentCount": 1,
        "transactionId": "trx-123",
        "requiredFields": [{"fieldId": "paymentId", "value": payment_id}],
    }


def test_finik_unsigned_callback_is_accepted_after_verification(settings):
    """Колбэк без подписи проходит, если Finik подтвердил транзакцию."""
    from apps.billing.providers.finik import FinikPaymentProvider

    settings.FINIK_ACCOUNT_ID = "finik-account-123"
    settings.FINIK_API_KEY = "test-key"
    settings.FINIK_SECRET_KEY = ""
    settings.PAYMENT_WEBHOOK_SECRET = ""
    provider = FinikPaymentProvider()

    request = Mock(headers={}, data=_finik_callback_payload())
    with patch.object(provider, "verify_finik_transaction", return_value=_finik_item()):
        result = provider.verify_webhook(request)

    assert result.provider_ref == "item-123"
    assert result.status == "succeeded"
    # Сумма взята из ответа Finik, а не из тела колбэка.
    assert result.amount == Decimal("12000")
    assert result.raw["fields"]["paymentId"] == "550e8400-e29b-41d4-a716-446655440000"


def test_finik_unsigned_callback_rejected_when_finik_denies(settings):
    """Finik не знает такой транзакции — начислять нельзя."""
    from apps.billing.providers.finik import FinikPaymentProvider

    settings.FINIK_ACCOUNT_ID = "finik-account-123"
    settings.FINIK_API_KEY = "test-key"
    settings.FINIK_SECRET_KEY = ""
    settings.PAYMENT_WEBHOOK_SECRET = ""
    provider = FinikPaymentProvider()

    request = Mock(headers={}, data=_finik_callback_payload())
    with patch.object(provider, "verify_finik_transaction", return_value=None):
        with pytest.raises(WebhookSignatureError):
            provider.verify_webhook(request)


def test_finik_unsigned_callback_rejected_when_gateway_unavailable(settings):
    """Сверка не удалась — отказ, а не начисление на веру."""
    from apps.billing.providers.finik import (
        FinikPaymentProvider,
        FinikVerificationUnavailable,
    )

    settings.FINIK_ACCOUNT_ID = "finik-account-123"
    settings.FINIK_API_KEY = "test-key"
    settings.FINIK_SECRET_KEY = ""
    settings.PAYMENT_WEBHOOK_SECRET = ""
    provider = FinikPaymentProvider()

    request = Mock(headers={}, data=_finik_callback_payload())
    with patch.object(
        provider,
        "verify_finik_transaction",
        side_effect=FinikVerificationUnavailable("finik_timeout"),
    ):
        with pytest.raises(WebhookSignatureError):
            provider.verify_webhook(request)


def test_finik_unsigned_callback_rejected_without_transaction_id(settings):
    """Раньше transactionId вида test-* пропускал сверку. Теперь — нет."""
    from apps.billing.providers.finik import FinikPaymentProvider

    settings.FINIK_ACCOUNT_ID = "finik-account-123"
    settings.FINIK_API_KEY = "test-key"
    settings.FINIK_SECRET_KEY = ""
    settings.PAYMENT_WEBHOOK_SECRET = ""
    provider = FinikPaymentProvider()

    request = Mock(headers={}, data=_finik_callback_payload(transactionId=""))
    with pytest.raises(WebhookSignatureError):
        provider.verify_webhook(request)


def test_finik_callback_payment_id_must_match_finik(settings):
    """Подменённый paymentId в теле колбэка не проходит сверку."""
    from apps.billing.providers.finik import FinikPaymentProvider

    settings.FINIK_ACCOUNT_ID = "finik-account-123"
    settings.FINIK_API_KEY = "test-key"
    settings.FINIK_SECRET_KEY = ""
    settings.PAYMENT_WEBHOOK_SECRET = ""
    provider = FinikPaymentProvider()

    payload = _finik_callback_payload()
    payload["fields"] = {**payload["fields"], "paymentId": "00000000-0000-0000-0000-000000000000"}
    request = Mock(headers={}, data=payload)

    with patch.object(provider, "verify_finik_transaction", return_value=_finik_item()):
        with pytest.raises(WebhookSignatureError):
            provider.verify_webhook(request)


def test_finik_callback_account_mismatch(settings):
    """Чужой accountId — чужой платёж."""
    from apps.billing.providers.finik import FinikPaymentProvider

    settings.FINIK_ACCOUNT_ID = "finik-account-123"
    settings.FINIK_API_KEY = "test-key"
    provider = FinikPaymentProvider()

    request = Mock(headers={}, data=_finik_callback_payload(accountId="wrong-account"))
    with pytest.raises(WebhookSignatureError):
        provider.verify_webhook(request)


def test_finik_create_payment_requires_configuration(settings):
    """Без ключей Finik счёт не выставляется — раньше отдавался фиктивный."""
    from apps.billing.providers.finik import FinikPaymentProvider

    settings.FINIK_API_KEY = ""
    settings.FINIK_ACCOUNT_ID = ""
    provider = FinikPaymentProvider()

    with pytest.raises(ImproperlyConfigured):
        provider.create_payment(payment=Mock(pk="x", amount_kgs=Decimal("100")), return_url="")
