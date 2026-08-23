"""Выбор платёжного провайдера."""

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured

from apps.billing.providers.bank import BankPaymentProvider
from apps.billing.providers.base import PaymentProvider
from apps.billing.providers.mock import MockPaymentProvider

PROVIDERS: dict[str, type[PaymentProvider]] = {
    MockPaymentProvider.code: MockPaymentProvider,
    BankPaymentProvider.code: BankPaymentProvider,
}


def get_payment_provider(code: str | None = None) -> PaymentProvider:
    """Провайдер по коду; без кода — тот, что указан в настройках."""
    name = (code or settings.PAYMENT_PROVIDER or "").lower()

    provider_class = PROVIDERS.get(name)
    if provider_class is None:
        raise ImproperlyConfigured(
            f"Неизвестный платёжный провайдер: {name!r}. Доступны: {sorted(PROVIDERS)}."
        )

    return provider_class()
