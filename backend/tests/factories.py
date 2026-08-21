"""Фабрики для тестов."""

from decimal import Decimal

import factory
from django.contrib.auth import get_user_model
from factory.django import DjangoModelFactory

from apps.catalog.enums import ListingStatus, MediaKind, PropertyKind, SellerKind
from apps.catalog.models import (
    Builder,
    City,
    District,
    HouseSeries,
    Listing,
    ListingMedia,
)
from apps.engagement.models import Favourite

DEFAULT_PASSWORD = "test12345"


class UserFactory(DjangoModelFactory):
    """Пользователь с валидным кыргызским номером."""

    class Meta:
        model = get_user_model()
        skip_postgeneration_save = True

    phone = factory.Sequence(lambda n: f"+99670012{n:04d}")
    name = factory.Sequence(lambda n: f"Пользователь {n}")
    is_pro = False

    class Params:
        # UserFactory(pro=True) — исполнитель с заполненным ИИН.
        pro = factory.Trait(
            is_pro=True,
            iin="20101199001234",
            seller_kind=SellerKind.REALTOR,
        )

    @factory.post_generation
    def password(obj, create: bool, extracted: str | None, **kwargs: object) -> None:  # noqa: N805
        if not create:
            return
        obj.set_password(extracted or DEFAULT_PASSWORD)
        obj.save(update_fields=["password"])


class CityFactory(DjangoModelFactory):
    class Meta:
        model = City
        django_get_or_create = ("slug",)

    name = factory.Sequence(lambda n: f"Город {n}")
    slug = factory.Sequence(lambda n: f"city-{n}")


class DistrictFactory(DjangoModelFactory):
    class Meta:
        model = District
        django_get_or_create = ("city", "slug")

    city = factory.SubFactory(CityFactory)
    name = factory.Sequence(lambda n: f"Район {n}")
    slug = factory.Sequence(lambda n: f"district-{n}")


class BuilderFactory(DjangoModelFactory):
    class Meta:
        model = Builder
        django_get_or_create = ("slug",)

    name = factory.Sequence(lambda n: f"Застройщик {n}")
    slug = factory.Sequence(lambda n: f"builder-{n}")


class HouseSeriesFactory(DjangoModelFactory):
    class Meta:
        model = HouseSeries
        django_get_or_create = ("code",)

    code = factory.Sequence(lambda n: f"1{n:02d}")
    name = factory.LazyAttribute(lambda obj: f"{obj.code} серия")


class ListingFactory(DjangoModelFactory):
    class Meta:
        model = Listing

    owner = factory.SubFactory(UserFactory)
    district = factory.SubFactory(DistrictFactory)
    # Город всегда тот же, что у района.
    city = factory.SelfAttribute("district.city")
    kind = PropertyKind.APARTMENT
    seller_kind = SellerKind.OWNER
    price = Decimal("100000.00")
    area = Decimal("80.00")
    rooms = 3
    floor = 5
    floors = 9
    status = ListingStatus.ACTIVE


class ListingMediaFactory(DjangoModelFactory):
    class Meta:
        model = ListingMedia

    listing = factory.SubFactory(ListingFactory)
    kind = MediaKind.PHOTO
    order = factory.Sequence(lambda n: n)
    is_cover = False
    file = factory.django.FileField(filename="photo.jpg", data=b"fake-photo-bytes")


class FavouriteFactory(DjangoModelFactory):
    class Meta:
        model = Favourite
        django_get_or_create = ("user", "listing")

    user = factory.SubFactory(UserFactory)
    listing = factory.SubFactory(ListingFactory)
