"""Общие фикстуры.

Фикстуры собирают типовое окружение теста: клиента с нужными правами и
минимальный набор объектов. Всё специфическое тест строит сам через фабрики.
"""

from decimal import Decimal

import pytest
from django.core.cache import cache
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken


@pytest.fixture(autouse=True)
def clear_cache():
    """Кэш конфига и счётчики троттлинга не должны протекать между тестами."""
    cache.clear()
    yield
    cache.clear()


def authenticate(client: APIClient, user) -> APIClient:  # noqa: ANN001
    """Кладёт JWT пользователя в заголовок клиента."""
    token = RefreshToken.for_user(user)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {token.access_token}")
    return client


@pytest.fixture
def throttle_rates(monkeypatch):  # noqa: ANN001, ANN201
    """Подменяет лимиты на время теста.

    Через `settings` их не поменять: DRF читает
    `DEFAULT_THROTTLE_RATES` один раз при импорте и кладёт в атрибут класса
    `SimpleRateThrottle.THROTTLE_RATES`.
    """
    from rest_framework.throttling import SimpleRateThrottle

    def _set(**rates: str) -> None:
        merged = {**SimpleRateThrottle.THROTTLE_RATES, **rates}
        monkeypatch.setattr(SimpleRateThrottle, "THROTTLE_RATES", merged)
        cache.clear()

    return _set


@pytest.fixture
def api_client() -> APIClient:
    """Незалогиненный API-клиент."""
    return APIClient()


@pytest.fixture
def client_for():
    """Фабрика клиентов: `client_for(user)` — отдельный клиент на пользователя.

    Именно отдельный: переиспользование общего `api_client` незаметно
    перелогинивало бы уже настроенного клиента в другого пользователя.
    """

    def _client_for(user):  # noqa: ANN001, ANN202
        return authenticate(APIClient(), user)

    return _client_for


@pytest.fixture
def user(db):  # noqa: ANN001, ANN201
    from tests.factories import UserFactory

    return UserFactory()


@pytest.fixture
def auth_client(api_client: APIClient, user) -> APIClient:  # noqa: ANN001
    """API-клиент обычного пользователя."""
    return authenticate(api_client, user)


@pytest.fixture
def pro_user(db):  # noqa: ANN001, ANN201
    """Исполнитель с заведённым кошельком."""
    from apps.billing.services import get_wallet
    from tests.factories import UserFactory

    seller = UserFactory(pro=True)
    get_wallet(seller)
    return seller


@pytest.fixture
def pro_client(pro_user) -> APIClient:  # noqa: ANN001
    """API-клиент исполнителя."""
    return authenticate(APIClient(), pro_user)


@pytest.fixture
def admin_user(db):  # noqa: ANN001, ANN201
    from tests.factories import UserFactory

    return UserFactory(is_staff=True)


@pytest.fixture
def admin_client(admin_user) -> APIClient:  # noqa: ANN001
    """API-клиент сотрудника: очередь модерации, решения по заявкам."""
    return authenticate(APIClient(), admin_user)


@pytest.fixture
def city(db):  # noqa: ANN001, ANN201
    from tests.factories import CityFactory

    return CityFactory(name="Бишкек", slug="bishkek", is_default=True)


@pytest.fixture
def district(city):  # noqa: ANN001, ANN201
    from tests.factories import DistrictFactory

    return DistrictFactory(city=city, name="Технопарк", slug="technopark")


@pytest.fixture
def listing(district, pro_user):  # noqa: ANN001, ANN201
    """Активное объявление с тремя фотографиями, первая — обложка."""
    from django.utils import timezone

    from apps.catalog.enums import ListingStatus
    from tests.factories import ListingFactory, ListingMediaFactory

    item = ListingFactory(
        owner=pro_user,
        district=district,
        city=district.city,
        status=ListingStatus.ACTIVE,
        published_at=timezone.now(),
    )
    for order in range(3):
        ListingMediaFactory(listing=item, order=order, is_cover=(order == 0))
    return item


@pytest.fixture
def wallet_with_balance(db):  # noqa: ANN001, ANN201
    """Фабрика кошелька с балансом: `wallet_with_balance(user, 50000)`.

    Баланс наливается настоящей операцией, а не записью в поле: леджер и
    баланс обязаны сходиться даже в фикстурах.
    """
    from apps.billing.services import apply_transaction, get_wallet
    from apps.common.enums import WalletEntryKind
    from tests.factories import UserFactory

    def _wallet(user=None, balance: int = 50_000):  # noqa: ANN001, ANN202
        owner = user or UserFactory()
        wallet = get_wallet(owner)
        if balance:
            apply_transaction(
                wallet=wallet,
                amount=balance,
                kind=WalletEntryKind.TOPUP,
                label=f"+{balance} кирпичей",
            )
        wallet.refresh_from_db()
        return wallet

    return _wallet


@pytest.fixture
def tariff(db):  # noqa: ANN001, ANN201
    """Платный тариф «Риелтор» — он же лежит в миграции 0010."""
    from apps.billing.models import Tariff

    return Tariff.objects.get(code="realtor")


@pytest.fixture
def promotion_package(db):  # noqa: ANN001, ANN201
    """Базовый пакет продвижения: 780 кирпичей за день."""
    from apps.billing.models import PromotionPackage

    return PromotionPackage.objects.get(code="standard")


@pytest.fixture
def promotion_option(db):  # noqa: ANN001, ANN201
    from apps.billing.models import PromotionOption

    return PromotionOption.objects.get(code="exact_targeting")


@pytest.fixture
def exchange_rate(db):  # noqa: ANN001, ANN201
    """Курс USD/KGS: без него цены в сомах не пересчитываются."""
    from tests.factories import ExchangeRateFactory

    return ExchangeRateFactory(rate=Decimal("87.500000"))
