"""Тесты уведомлений о снижении цены (price_drop)."""

from decimal import Decimal

import pytest

from apps.catalog.enums import Currency, ListingStatus
from apps.catalog.services import update_listing
from apps.engagement.models import Favourite
from apps.notifications.models import Notification, NotificationType
from apps.notifications.services import notify_listing_price_drop
from tests.factories import CityFactory, DistrictFactory, ListingFactory, UserFactory


@pytest.mark.django_db
def test_price_drop_triggers_on_price_decrease(django_capture_on_commit_callbacks):
    """Снижение цены активного объявления создаёт price_drop для подписчика."""
    city = CityFactory()
    district = DistrictFactory(city=city, name="Технопарк")
    owner = UserFactory(phone="+996555111111")
    follower = UserFactory(phone="+996555222222")

    listing = ListingFactory(
        owner=owner,
        status=ListingStatus.ACTIVE,
        price=Decimal("107000.00"),
        currency=Currency.USD,
        district=district,
        rooms=3,
        area=Decimal("92.00"),
        floor=8,
        floors=12,
    )
    Favourite.objects.create(user=follower, listing=listing, price_at_add=listing.price_usd)

    with django_capture_on_commit_callbacks(execute=True):
        update_listing(listing, {"price": Decimal("102000.00")})

    listing.refresh_from_db()
    assert listing.price == Decimal("102000.00")
    assert listing.old_price == Decimal("107000.00")

    notifications = Notification.objects.filter(user=follower, type=NotificationType.PRICE_DROP)
    assert notifications.count() == 1
    n = notifications.first()
    assert n.title == "Цена снизилась"
    assert "Технопарк" in n.body
    assert n.listing == listing
    assert n.payload["old_price"] == "107000.00"
    assert n.payload["new_price"] == "102000.00"
    assert n.payload["district"] == "Технопарк"
    assert n.payload["rooms"] == 3
    assert n.payload["area"] == "92.00"
    assert n.payload["floor"] == 8


@pytest.mark.django_db
def test_no_price_drop_on_price_increase(django_capture_on_commit_callbacks):
    """Повышение цены не создаёт уведомлений."""
    owner = UserFactory()
    follower = UserFactory()

    listing = ListingFactory(
        owner=owner,
        status=ListingStatus.ACTIVE,
        price=Decimal("102000.00"),
        currency=Currency.USD,
    )
    Favourite.objects.create(user=follower, listing=listing)

    with django_capture_on_commit_callbacks(execute=True):
        update_listing(listing, {"price": Decimal("107000.00")})

    assert Notification.objects.filter(type=NotificationType.PRICE_DROP).count() == 0


@pytest.mark.django_db
def test_no_price_drop_on_same_price(django_capture_on_commit_callbacks):
    """Сохранение объявления без изменения цены не создаёт уведомлений."""
    owner = UserFactory()
    follower = UserFactory()

    listing = ListingFactory(
        owner=owner,
        status=ListingStatus.ACTIVE,
        price=Decimal("102000.00"),
        currency=Currency.USD,
    )
    Favourite.objects.create(user=follower, listing=listing)

    with django_capture_on_commit_callbacks(execute=True):
        update_listing(listing, {"price": Decimal("102000.00")})

    assert Notification.objects.filter(type=NotificationType.PRICE_DROP).count() == 0


@pytest.mark.django_db
def test_owner_does_not_receive_own_price_drop(django_capture_on_commit_callbacks):
    """Владелец не получает уведомление о собственном изменении цены."""
    owner = UserFactory()
    listing = ListingFactory(
        owner=owner,
        status=ListingStatus.ACTIVE,
        price=Decimal("107000.00"),
    )
    # Даже если владелец добавил свой объект в избранное
    Favourite.objects.create(user=owner, listing=listing)

    with django_capture_on_commit_callbacks(execute=True):
        update_listing(listing, {"price": Decimal("102000.00")})

    assert Notification.objects.filter(user=owner, type=NotificationType.PRICE_DROP).count() == 0


@pytest.mark.django_db
def test_multiple_followers_receive_one_notification_each(django_capture_on_commit_callbacks):
    """Каждый подписчик получает ровно одно уведомление."""
    owner = UserFactory()
    followers = [UserFactory() for _ in range(3)]

    listing = ListingFactory(
        owner=owner,
        status=ListingStatus.ACTIVE,
        price=Decimal("107000.00"),
    )
    for follower in followers:
        Favourite.objects.create(user=follower, listing=listing)

    with django_capture_on_commit_callbacks(execute=True):
        update_listing(listing, {"price": Decimal("102000.00")})

    assert Notification.objects.filter(type=NotificationType.PRICE_DROP).count() == 3
    for follower in followers:
        assert (
            Notification.objects.filter(user=follower, type=NotificationType.PRICE_DROP).count()
            == 1
        )


@pytest.mark.django_db
def test_duplicate_protection_on_re_execution():
    """Повторный вызов notify_listing_price_drop для той же цены не дублирует уведомления."""
    owner = UserFactory()
    follower = UserFactory()

    listing = ListingFactory(
        owner=owner,
        status=ListingStatus.ACTIVE,
        price=Decimal("102000.00"),
    )
    Favourite.objects.create(user=follower, listing=listing)

    first = notify_listing_price_drop(listing, Decimal("107000.00"), Decimal("102000.00"))
    assert len(first) == 1

    second = notify_listing_price_drop(listing, Decimal("107000.00"), Decimal("102000.00"))
    assert len(second) == 0

    assert Notification.objects.filter(user=follower, type=NotificationType.PRICE_DROP).count() == 1


@pytest.mark.django_db
def test_price_drop_after_price_recovered_notifies_again(django_capture_on_commit_callbacks):
    """Цена упала, поднялась и упала снова — это два разных снижения.

    Раньше защита от повтора смотрела только на конечную цену, поэтому второе
    падение до той же отметки не доходило до подписчика уже никогда.
    """
    from django.utils import timezone

    from apps.notifications.services import PRICE_DROP_DUPLICATE_WINDOW

    owner = UserFactory()
    follower = UserFactory()
    listing = ListingFactory(
        owner=owner,
        status=ListingStatus.ACTIVE,
        price=Decimal("107000.00"),
        currency=Currency.USD,
    )
    Favourite.objects.create(user=follower, listing=listing, price_at_add=listing.price_usd)

    def drops():
        return Notification.objects.filter(user=follower, type=NotificationType.PRICE_DROP)

    with django_capture_on_commit_callbacks(execute=True):
        update_listing(listing, {"price": Decimal("102000.00")})
    assert drops().count() == 1

    # Первое снижение уходит за окно защиты: событие завершилось.
    drops().update(created_at=timezone.now() - PRICE_DROP_DUPLICATE_WINDOW * 2)

    with django_capture_on_commit_callbacks(execute=True):
        update_listing(listing, {"price": Decimal("107000.00")})
    assert drops().count() == 1, "подорожание не создаёт уведомления"

    with django_capture_on_commit_callbacks(execute=True):
        update_listing(listing, {"price": Decimal("102000.00")})
    assert drops().count() == 2, "повторное снижение должно дойти до подписчика"


@pytest.mark.django_db
def test_repeated_call_inside_window_is_still_deduplicated():
    """Тот же переход, вызванный повторно сразу же, остаётся одним уведомлением."""
    owner = UserFactory()
    follower = UserFactory()
    listing = ListingFactory(owner=owner, status=ListingStatus.ACTIVE, price=Decimal("102000.00"))
    Favourite.objects.create(user=follower, listing=listing)

    assert len(notify_listing_price_drop(listing, Decimal("107000"), Decimal("102000"))) == 1
    assert len(notify_listing_price_drop(listing, Decimal("107000"), Decimal("102000"))) == 0
    assert Notification.objects.filter(type=NotificationType.PRICE_DROP).count() == 1


@pytest.mark.django_db
def test_no_price_drop_for_non_public_listing(django_capture_on_commit_callbacks):
    """Черновик и архив не рассылают уведомления: объявления никто не видит."""
    owner = UserFactory()
    follower = UserFactory()

    for status in (ListingStatus.DRAFT, ListingStatus.ARCHIVED):
        listing = ListingFactory(owner=owner, status=status, price=Decimal("107000.00"))
        Favourite.objects.create(user=follower, listing=listing)

        with django_capture_on_commit_callbacks(execute=True):
            update_listing(listing, {"price": Decimal("102000.00")})

    assert Notification.objects.filter(type=NotificationType.PRICE_DROP).count() == 0


@pytest.mark.django_db
def test_user_without_favourite_gets_nothing(django_capture_on_commit_callbacks):
    """Уведомление получает только тот, кто добавил объявление в избранное."""
    owner = UserFactory()
    stranger = UserFactory()
    listing = ListingFactory(owner=owner, status=ListingStatus.ACTIVE, price=Decimal("107000.00"))

    with django_capture_on_commit_callbacks(execute=True):
        update_listing(listing, {"price": Decimal("102000.00")})

    assert Notification.objects.filter(user=stranger).count() == 0
    assert Notification.objects.filter(type=NotificationType.PRICE_DROP).count() == 0
