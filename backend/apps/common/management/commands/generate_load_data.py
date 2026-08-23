"""Наполнение БД объявлениями для нагрузочного теста.

От `seed_demo` отличается назначением: тому важна достоверность данных
(он воспроизводит прототип Flutter), этому — объём и скорость. Медиа не
генерируются, всё пишется пачками через `bulk_create`.
"""

import random
from datetime import timedelta
from decimal import Decimal
from typing import Any

from django.core.management.base import BaseCommand, CommandParser
from django.db import transaction
from django.utils import timezone

from apps.catalog.enums import Currency, ListingStatus, PropertyKind, SellerKind
from apps.catalog.models import Builder, City, District, HouseSeries, Listing

BATCH_SIZE = 1_000

DISTRICT_NAMES = [
    "Технопарк",
    "Асанбай",
    "Джал",
    "Восток-5",
    "Аламедин-1",
    "Кок-Жар",
    "Тунгуч",
    "Учкун",
    "Мадина",
    "Ак-Орго",
    "Арча-Бешик",
    "Кара-Жыгач",
    "Верхний Джал",
    "Нижний Джал",
    "Кызыл-Аскер",
]

DESCRIPTION_PARTS = [
    "Светлая квартира с ремонтом",
    "Рядом школа и детский сад",
    "Тихий двор, парковка",
    "Элитка, автономное отопление",
    "Панорамные окна, вид на горы",
    "Развитая инфраструктура",
    "Новостройка, сдача в этом году",
    "Документы готовы, красная книга",
]


class Command(BaseCommand):
    help = "Создаёт объявления для нагрузочного теста (по умолчанию 50 000)."

    def add_arguments(self, parser: CommandParser) -> None:
        parser.add_argument("--count", type=int, default=50_000, help="Сколько объявлений создать.")
        parser.add_argument(
            "--flush",
            action="store_true",
            help="Сначала удалить объявления, созданные этой командой.",
        )

    def handle(self, *args: Any, **options: Any) -> None:
        count = options["count"]

        if options["flush"]:
            removed, _ = Listing.all_objects.filter(slug__startswith="load-").delete()
            self.stdout.write(f"Удалено объявлений: {removed}")

        city, districts, series, builders = self._dictionaries()
        owner = self._owner()

        created = 0
        now = timezone.now()

        while created < count:
            chunk = min(BATCH_SIZE, count - created)
            batch = [
                self._make_listing(created + index, owner, city, districts, series, builders, now)
                for index in range(chunk)
            ]
            with transaction.atomic():
                Listing.objects.bulk_create(batch, batch_size=BATCH_SIZE)
            created += chunk
            self.stdout.write(f"  создано {created} / {count}", ending="\r")

        self.stdout.write("")
        self.stdout.write(self.style.SUCCESS(f"Готово: объявлений {created}"))
        self.stdout.write(
            "Дальше: `make loadtest HOST=http://localhost:8000` (цель — p95 < 300 мс при 100 RPS)."
        )

    # -- справочники ---------------------------------------------------------

    def _dictionaries(self) -> tuple[City, list[District], list[HouseSeries], list[Builder]]:
        city, _ = City.objects.get_or_create(
            slug="bishkek", defaults={"name": "Бишкек", "is_default": True}
        )

        districts = []
        for order, name in enumerate(DISTRICT_NAMES):
            district, _ = District.objects.get_or_create(
                city=city,
                slug=f"load-{order}",
                defaults={"name": name, "order": order},
            )
            districts.append(district)

        series = [
            HouseSeries.objects.get_or_create(code=code, defaults={"name": f"{code} серия"})[0]
            for code in ("103", "104", "105", "106")
        ]
        builders = [
            Builder.objects.get_or_create(
                slug=f"load-builder-{index}", defaults={"name": f"Застройщик {index}"}
            )[0]
            for index in range(5)
        ]
        return city, districts, series, builders

    def _owner(self) -> Any:
        from django.contrib.auth import get_user_model

        user_model = get_user_model()
        owner, _ = user_model.objects.get_or_create(
            phone="+996700000900",
            defaults={"name": "Нагрузочный продавец", "is_pro": True},
        )
        return owner

    # -- генерация -----------------------------------------------------------

    def _make_listing(
        self,
        index: int,
        owner: Any,
        city: City,
        districts: list[District],
        series: list[HouseSeries],
        builders: list[Builder],
        now: Any,
    ) -> Listing:
        district = random.choice(districts)
        rooms = random.randint(1, 5)
        area = Decimal(random.randint(30, 200))
        price = Decimal(random.randint(25_000, 400_000))
        kind = random.choice(PropertyKind.values)

        return Listing(
            # Префикс `load-` позволяет удалить ровно эти записи флагом --flush.
            slug=f"load-{index}-{random.getrandbits(24):06x}",
            owner=owner,
            kind=kind,
            seller_kind=random.choice(SellerKind.values),
            city=city,
            district=district,
            address=f"{district.name}, дом {random.randint(1, 200)}",
            price=price,
            price_usd=price,
            currency=Currency.USD,
            rooms=rooms,
            area=area,
            floor=random.randint(1, 16),
            floors=random.randint(2, 16),
            series=random.choice(series) if kind == PropertyKind.APARTMENT else None,
            builder=random.choice(builders) if kind == PropertyKind.NEW_BUILDING else None,
            is_secondary=random.random() < 0.5,
            below_market=random.random() < 0.1,
            description=" ".join(random.sample(DESCRIPTION_PARTS, k=3)),
            status=ListingStatus.ACTIVE,
            published_at=now - timedelta(minutes=random.randint(0, 60 * 24 * 90)),
            expires_at=now + timedelta(days=30),
            views_count=random.randint(0, 5_000),
            favourites_count=random.randint(0, 200),
            # Каждое двадцатое продвинуто: сортировка каталога должна работать
            # на реалистичной доле продвинутых, а не на нуле.
            promoted_until=now + timedelta(days=3) if random.random() < 0.05 else None,
            contact_phone=owner.phone,
        )
