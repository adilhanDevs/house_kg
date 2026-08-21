"""Наполнение БД демо-данными, повторяющими прототип Flutter.

Источник правды по «якорным» объявлениям — `flutter_app/lib/data/listings.dart`
(константа `kListings`): те же районы, цены, площади, этажи и флаги, чтобы
клиент можно было переключить с моковых данных на API, не заметив разницы.

Команда идемпотентна: повторный запуск ничего не дублирует (get_or_create по
стабильным slug / phone / idempotency_key). Флаг --flush предварительно чистит
доменные таблицы.
"""

import random
import zlib
from datetime import timedelta
from decimal import Decimal
from io import BytesIO
from pathlib import Path
from typing import Any

from django.contrib.auth import get_user_model
from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand, CommandParser
from django.db import transaction
from django.utils import timezone
from PIL import Image, ImageDraw, ImageFont

from apps.billing.models import Wallet, WalletTransaction
from apps.billing.services import apply_transaction, get_wallet
from apps.catalog.enums import (
    Currency,
    ListingStatus,
    MediaKind,
    PropertyKind,
    SellerKind,
)
from apps.catalog.models import Builder, City, District, HouseSeries, Listing, ListingMedia
from apps.catalog.search import update_search_vectors
from apps.common.enums import WalletEntryKind

# Данные прототипа -----------------------------------------------------------

# Текст-рыба из макета — им подписан каждый объект прототипа.
FILLER_DESCRIPTION = (
    "Сату́рн — шестая планета по удалённости от Солнца и вторая по размерам "
    "планета в Солнечной системе после Юпитера."
)
DEFAULT_ADDRESS = "Бишкек, Октябрьский район,\nул.Бакаева 178/4"
DEFAULT_AGENT = "Садыр Жапаров"
DEMO_PASSWORD = "demo12345"

# Районы Бишкека: (название, slug).
DISTRICTS: list[tuple[str, str]] = [
    ("Технопарк", "technopark"),
    ("Асанбай", "asanbay"),
    ("Джал", "djal"),
    ("Восток-5", "vostok-5"),
    ("Кок-Жар", "kok-jar"),
    ("Юг-2", "yug-2"),
    ("Центр", "center"),
    ("Орто-Сай", "orto-say"),
    ("Байтик", "baytik"),
    ("Чуй-Манаса", "chui-manasa"),
    ("Аламедин-1", "alamedin-1"),
    ("Тунгуч", "tunguch"),
    ("Джал-23", "djal-23"),
    ("Кызыл-Аскер", "kyzyl-asker"),
    ("Верхний Джал", "verkhniy-djal"),
]

# Серии домов: (код, название). Код — то, что ищет чип «103 серия».
HOUSE_SERIES: list[tuple[str, str]] = [
    ("103", "103 серия"),
    ("104", "104 серия"),
    ("105", "105 серия"),
    ("106", "106 серия"),
    ("individual", "Индивидуальная"),
    ("elite", "Элитка"),
]

# Пользователи: (телефон, имя, is_pro, тип продавца).
DEMO_USERS: list[dict[str, Any]] = [
    {
        "phone": "+996700000001",
        "name": "Азамат Осмонов",
        "is_pro": False,
        "seller_kind": SellerKind.OWNER,
    },
    {
        "phone": "+996700000002",
        "name": DEFAULT_AGENT,
        "is_pro": True,
        "seller_kind": SellerKind.REALTOR,
        "iin": "20101199001234",
    },
    {
        "phone": "+996700000003",
        "name": "Агентство «Дом Плюс»",
        "is_pro": True,
        "seller_kind": SellerKind.AGENCY,
        "iin": "10203199505678",
    },
]

# Ровно kListings из flutter_app/lib/data/listings.dart.
ANCHOR_LISTINGS: list[dict[str, Any]] = [
    {
        "slug": "technopark",
        "district": "Технопарк",
        "price": 102_000,
        "old_price": 107_000,
        "rooms": 3,
        "area": 92,
        "floor": 8,
        "floors": 12,
        "kind": PropertyKind.APARTMENT,
        "seller_kind": SellerKind.OWNER,
        "is_secondary": True,
        "series": "103",
        "below_market": True,
        "red_book": True,
        "photos": 4,
    },
    {
        "slug": "asanbay",
        "district": "Асанбай",
        "price": 92_850,
        "rooms": 3,
        "area": 92,
        "floor": 8,
        "floors": 12,
        "kind": PropertyKind.APARTMENT,
        "seller_kind": SellerKind.OWNER,
        "is_secondary": True,
        "series": "105",
        "photos": 3,
    },
    {
        "slug": "djal",
        "district": "Джал",
        "price": 78_400,
        "rooms": 2,
        "area": 70,
        "floor": 5,
        "floors": 9,
        "kind": PropertyKind.NEW_BUILDING,
        "seller_kind": SellerKind.OWNER,
        "below_market": True,
        "photos": 3,
    },
    {
        "slug": "vostok",
        "district": "Восток-5",
        "price": 54_300,
        "rooms": 1,
        "area": 45,
        "floor": 3,
        "floors": 5,
        "kind": PropertyKind.ROOM,
        "seller_kind": SellerKind.REALTOR,
        "is_secondary": True,
        "series": "103",
        "photos": 3,
    },
    {
        "slug": "kok-jar",
        "district": "Кок-Жар",
        "price": 189_000,
        "rooms": 5,
        "area": 210,
        "floor": 2,
        "floors": 2,
        "kind": PropertyKind.HOUSE,
        "seller_kind": SellerKind.OWNER,
        "is_secondary": True,
        "red_book": True,
        "photos": 3,
    },
    {
        "slug": "yug-2",
        "district": "Юг-2",
        "price": 96_500,
        "rooms": 3,
        "area": 80,
        "floor": 6,
        "floors": 10,
        "kind": PropertyKind.NEW_BUILDING,
        "seller_kind": SellerKind.OWNER,
        "photos": 3,
    },
    {
        "slug": "center",
        "district": "Центр",
        "price": 143_000,
        "rooms": 4,
        "area": 118,
        "floor": 9,
        "floors": 14,
        "kind": PropertyKind.APARTMENT,
        "seller_kind": SellerKind.AGENCY,
        "is_secondary": True,
        "red_book": True,
        "photos": 3,
    },
    {
        "slug": "orto-say",
        "district": "Орто-Сай",
        "price": 45_000,
        "rooms": 0,
        "area": 600,
        "floor": 0,
        "floors": 0,
        "kind": PropertyKind.PLOT,
        "seller_kind": SellerKind.OWNER,
        "photos": 3,
    },
    {
        "slug": "baytik",
        "district": "Байтик",
        "price": 120_000,
        "rooms": 0,
        "area": 1200,
        "floor": 0,
        "floors": 0,
        "kind": PropertyKind.PLOT,
        "seller_kind": SellerKind.OWNER,
        "red_book": True,
        "photos": 3,
    },
    {
        "slug": "chui",
        "district": "Чуй-Манаса",
        "price": 61_200,
        "rooms": 2,
        "area": 52,
        "floor": 4,
        "floors": 9,
        "kind": PropertyKind.COMMERCIAL,
        "seller_kind": SellerKind.AGENCY,
        "is_secondary": True,
        "below_market": True,
        "photos": 3,
    },
]

# История кошелька — экран «История пополнения и трат».
# Баланс складывается из самих операций: 3 700 + 12 000 + 1 200 + 300 − 500 = 16 700.
WALLET_ENTRIES: list[dict[str, Any]] = [
    # Ключи стабильны по смыслу операции: список может пополняться, а
    # идемпотентность сидера не должна от этого ломаться.
    {
        "key": "initial-topup",
        "amount": 3_700,
        "kind": WalletEntryKind.TOPUP,
        "label": "+3 700 сом (3 700 кирпичей)",
        "days": 10,
    },
    {
        "key": "topup",
        "amount": 12_000,
        "kind": WalletEntryKind.TOPUP,
        "label": "+12 000 сом (12 000 кирпичей)",
        "days": 3,
    },
    {
        "key": "topup-bonus",
        "amount": 1_200,
        "kind": WalletEntryKind.BONUS,
        "label": "+1 200 кирпичей (бонус за пополнение)",
        "days": 3,
    },
    {
        "key": "quest-bonus",
        "amount": 300,
        "kind": WalletEntryKind.BONUS,
        "label": "+300 кирпичей (бонус за квест)",
        "days": 1,
    },
    {
        "key": "promotion",
        "amount": -500,
        "kind": WalletEntryKind.SPEND,
        "label": "-500 кирпичей",
        "days": 1,
    },
]

# Генерация ------------------------------------------------------------------

GENERATED_COUNT = 40
PRICE_MIN, PRICE_MAX = 30_000, 350_000
RANDOM_SEED = 20260820  # фиксируем, чтобы повторный запуск давал те же данные

# Застройщики: (название, слаг). Пустая строка — «застройщик не указан».
BUILDER_SPECS: list[tuple[str, str]] = [
    ("Авангард Стиль", "avangard-style"),
    ("Ихлас, ООО", "ihlas"),
    ("Элит Хаус", "elit-house"),
    ("Мурас Строй", "muras-stroy"),
]
BUILDERS = [name for name, _ in BUILDER_SPECS] + [""]

# Город прототипа.
DEMO_CITY = ("Бишкек", "bishkek")
STREETS = [
    "ул. Байтик Баатыра",
    "ул. Ахунбаева",
    "пр. Чуй",
    "ул. Токтогула",
    "ул. Медерова",
    "ул. Жукеева-Пудовкина",
]

# Палитра для программно нарисованных обложек.
PALETTE = [
    (36, 84, 120),
    (52, 108, 92),
    (120, 72, 48),
    (88, 60, 116),
    (140, 96, 40),
    (44, 96, 132),
    (100, 52, 68),
]


def _find_font(size: int) -> tuple[Any, bool]:
    """Ищет системный шрифт с кириллицей.

    Возвращает (шрифт, поддерживает_кириллицу). В slim-образе шрифтов может не
    быть — тогда откатываемся на встроенный и подписываем картинку латиницей.
    """
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
        "/Library/Fonts/Arial Unicode.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size), True
    return ImageFont.load_default(size=size), False


class Command(BaseCommand):
    help = "Наполняет БД демо-данными по прототипу Flutter (идемпотентно)."

    def add_arguments(self, parser: CommandParser) -> None:
        parser.add_argument(
            "--flush",
            action="store_true",
            help="Очистить доменные таблицы (районы, серии, объявления, медиа, кошельки) "
            "и демо-пользователей перед наполнением.",
        )

    @transaction.atomic
    def handle(self, *args: Any, **options: Any) -> None:
        self.rng = random.Random(RANDOM_SEED)
        self.font_title, self.cyrillic_ok = _find_font(64)
        self.font_body, _ = _find_font(40)

        if options["flush"]:
            self._flush()

        users = self._seed_users()
        districts = self._seed_districts()
        series = self._seed_series()
        builders = self._seed_builders()
        listings = self._seed_anchor_listings(users, districts, series)
        listings += self._seed_generated_listings(users, districts, series)
        media_count = self._seed_media(listings)
        self._seed_wallets(users)

        # На PostgreSQL сразу наполняем поисковый индекс, на SQLite — no-op.
        indexed = update_search_vectors(Listing.objects.all())

        self.stdout.write("")
        self.stdout.write(self.style.SUCCESS("Готово:"))
        self.stdout.write(f"  пользователей   {len(users)} (пароль {DEMO_PASSWORD})")
        self.stdout.write(f"  районов         {len(districts)}")
        self.stdout.write(f"  серий домов     {len(series)}")
        self.stdout.write(f"  застройщиков    {builders}")
        self.stdout.write(
            f"  объявлений      {len(listings)} "
            f"({len(ANCHOR_LISTINGS)} из прототипа + {GENERATED_COUNT} сгенерированных)"
        )
        self.stdout.write(f"  медиафайлов     {media_count}")
        self.stdout.write(f"  в поисковом индексе {indexed}")
        self.stdout.write(f"  кошельков       {Wallet.objects.count()}")

    # -- очистка ------------------------------------------------------------

    def _flush(self) -> None:
        self.stdout.write(self.style.WARNING("Чищу доменные таблицы…"))
        for media in ListingMedia.objects.all():
            media.file.delete(save=False)
        ListingMedia.objects.all().delete()
        Listing.objects.all().delete()
        District.objects.all().delete()
        City.objects.all().delete()
        HouseSeries.objects.all().delete()
        Builder.objects.all().delete()
        WalletTransaction.objects.all().delete()
        Wallet.objects.all().delete()
        get_user_model().objects.filter(phone__in=[u["phone"] for u in DEMO_USERS]).delete()

    # -- справочники и пользователи -----------------------------------------

    def _seed_users(self) -> dict[str, Any]:
        user_model = get_user_model()
        users: dict[str, Any] = {}
        for spec in DEMO_USERS:
            user, created = user_model.objects.get_or_create(
                phone=spec["phone"],
                defaults={
                    "name": spec["name"],
                    "is_pro": spec["is_pro"],
                    "seller_kind": spec["seller_kind"],
                    "iin": spec.get("iin", ""),
                },
            )
            if created:
                user.set_password(DEMO_PASSWORD)
                user.save(update_fields=["password"])
            users[str(spec["seller_kind"])] = user
            self.stdout.write(f"  {'+' if created else '='} пользователь {user.phone} {user.name}")
        return users

    def _seed_districts(self) -> dict[str, District]:
        name, slug = DEMO_CITY
        city, _ = City.objects.get_or_create(
            slug=slug,
            defaults={"name": name, "is_default": True},
        )
        districts: dict[str, District] = {}
        for order, (district_name, district_slug) in enumerate(DISTRICTS):
            district, _ = District.objects.get_or_create(
                city=city,
                slug=district_slug,
                defaults={"name": district_name, "order": order},
            )
            districts[district_name] = district
        self.stdout.write(f"  районов: {len(districts)}")
        return districts

    def _seed_series(self) -> dict[str, HouseSeries]:
        series: dict[str, HouseSeries] = {}
        for order, (code, name) in enumerate(HOUSE_SERIES):
            item, _ = HouseSeries.objects.get_or_create(
                code=code,
                defaults={"name": name, "order": order},
            )
            series[code] = item
        self.stdout.write(f"  серий домов: {len(series)}")
        return series

    def _seed_builders(self) -> int:
        for order, (name, slug) in enumerate(BUILDER_SPECS):
            Builder.objects.get_or_create(slug=slug, defaults={"name": name, "order": order})
        self.stdout.write(f"  застройщиков: {len(BUILDER_SPECS)}")
        return len(BUILDER_SPECS)

    # -- объявления ---------------------------------------------------------

    def _seed_anchor_listings(
        self,
        users: dict[str, Any],
        districts: dict[str, District],
        series: dict[str, HouseSeries],
    ) -> list[Listing]:
        now = timezone.now()
        listings: list[Listing] = []
        for index, spec in enumerate(ANCHOR_LISTINGS):
            listing, created = Listing.objects.get_or_create(
                slug=spec["slug"],
                defaults={
                    "owner": users[str(spec["seller_kind"])],
                    "kind": spec["kind"],
                    "seller_kind": spec["seller_kind"],
                    "district": districts[spec["district"]],
                    "address": DEFAULT_ADDRESS,
                    "price": Decimal(spec["price"]),
                    "currency": Currency.USD,
                    "old_price": (Decimal(spec["old_price"]) if spec.get("old_price") else None),
                    "rooms": spec["rooms"],
                    "area": Decimal(spec["area"]),
                    "floor": spec["floor"],
                    "floors": spec["floors"],
                    "series": series.get(spec.get("series", "")),
                    "is_secondary": spec.get("is_secondary", False),
                    "below_market": spec.get("below_market", False),
                    "red_book": spec.get("red_book", False),
                    "description": FILLER_DESCRIPTION,
                    "city": districts[spec["district"]].city,
                    "contact_name": DEFAULT_AGENT,
                    "contact_phone": DEMO_USERS[0]["phone"],
                    "status": ListingStatus.ACTIVE,
                    "published_at": now - timedelta(days=index),
                    "views_count": 120 + index * 37,
                },
            )
            listing.photos_wanted = spec["photos"]
            listings.append(listing)
            if created:
                self.stdout.write(f"  + объявление {listing.slug}")
        return listings

    def _seed_generated_listings(
        self,
        users: dict[str, Any],
        districts: dict[str, District],
        series: dict[str, HouseSeries],
    ) -> list[Listing]:
        now = timezone.now()
        district_list = list(districts.values())
        builder_objects = list(Builder.objects.order_by("order", "name"))
        kinds = [
            PropertyKind.APARTMENT,
            PropertyKind.APARTMENT,
            PropertyKind.NEW_BUILDING,
            PropertyKind.HOUSE,
            PropertyKind.PLOT,
            PropertyKind.ROOM,
            PropertyKind.COMMERCIAL,
        ]
        seller_kinds = [SellerKind.OWNER, SellerKind.OWNER, SellerKind.REALTOR, SellerKind.AGENCY]

        listings: list[Listing] = []
        created_count = 0
        for number in range(1, GENERATED_COUNT + 1):
            rng = self.rng
            kind = rng.choice(kinds)
            seller_kind = rng.choice(seller_kinds)
            is_plot = kind == PropertyKind.PLOT

            if is_plot:
                rooms, floor, floors = 0, 0, 0
                area = rng.randrange(300, 2000, 50)
                house_series = None
            else:
                rooms = rng.randint(1, 5)
                floors = rng.randint(2, 16)
                floor = rng.randint(1, floors)
                area = rng.randrange(28, 60) + rooms * rng.randrange(12, 22)
                house_series = (
                    series[rng.choice(["103", "104", "105", "106", "individual", "elite"])]
                    if kind in (PropertyKind.APARTMENT, PropertyKind.ROOM)
                    else None
                )

            district = rng.choice(district_list)
            price = rng.randrange(PRICE_MIN, PRICE_MAX, 100)
            below_market = rng.random() < 0.25
            old_price = price + rng.randrange(2_000, 12_000, 500) if below_market else None

            listing, created = Listing.objects.get_or_create(
                slug=f"demo-{number:03d}",
                defaults={
                    "owner": users[str(seller_kind)],
                    "kind": kind,
                    "seller_kind": seller_kind,
                    "district": district,
                    "city": district.city,
                    "address": f"Бишкек, {rng.choice(STREETS)} {rng.randint(1, 240)}",
                    "price": Decimal(price),
                    "currency": Currency.USD,
                    "old_price": Decimal(old_price) if old_price else None,
                    "rooms": rooms,
                    "area": Decimal(area),
                    "floor": floor,
                    "floors": floors,
                    "series": house_series,
                    "is_secondary": kind != PropertyKind.NEW_BUILDING and rng.random() < 0.7,
                    "below_market": below_market,
                    "red_book": rng.random() < 0.3,
                    "description": FILLER_DESCRIPTION,
                    "builder": (
                        rng.choice(builder_objects) if kind == PropertyKind.NEW_BUILDING else None
                    ),
                    "contact_name": users[str(seller_kind)].name,
                    "contact_phone": users[str(seller_kind)].phone,
                    "status": ListingStatus.ACTIVE,
                    "published_at": now
                    - timedelta(days=rng.randint(0, 45), hours=rng.randint(0, 23)),
                    "views_count": rng.randint(10, 2500),
                },
            )
            listing.photos_wanted = rng.randint(3, 5)
            listings.append(listing)
            created_count += int(created)
        self.stdout.write(f"  сгенерированных объявлений: {len(listings)} (новых {created_count})")
        return listings

    # -- медиа --------------------------------------------------------------

    def _seed_media(self, listings: list[Listing]) -> int:
        total = 0
        for listing in listings:
            wanted = getattr(listing, "photos_wanted", 3)
            for order in range(wanted):
                media, created = ListingMedia.objects.get_or_create(
                    listing=listing,
                    order=order,
                    defaults={
                        "kind": MediaKind.PHOTO,
                        "is_cover": order == 0,
                    },
                )
                if created or not media.file:
                    media.file.save(
                        f"{listing.slug}-{order}.jpg",
                        ContentFile(self._render_photo(listing, order)),
                        save=True,
                    )
                total += 1
        self.stdout.write(f"  медиафайлов: {total}")
        return total

    def _render_photo(self, listing: Listing, order: int) -> bytes:
        """Рисует обложку «район / цена» — картинки из сети не тянем."""
        width, height = 1200, 800
        digest = zlib.crc32(listing.district.slug.encode())
        base = PALETTE[(digest + order) % len(PALETTE)]
        shade = 1 - order * 0.12
        background = tuple(max(0, min(255, int(channel * shade))) for channel in base)

        image = Image.new("RGB", (width, height), background)
        draw = ImageDraw.Draw(image)
        draw.rectangle([40, 40, width - 40, height - 40], outline=(255, 255, 255), width=4)

        district = listing.district.name if self.cyrillic_ok else listing.district.slug
        price = f"{int(listing.price):,}".replace(",", " ")
        title = district
        subtitle = f"{price} {listing.currency}"
        footer = f"{listing.slug} · {order + 1}"

        draw.text((80, height / 2 - 120), title, font=self.font_title, fill=(255, 255, 255))
        draw.text((80, height / 2), subtitle, font=self.font_title, fill=(255, 255, 255))
        draw.text((80, height - 120), footer, font=self.font_body, fill=(230, 230, 230))

        buffer = BytesIO()
        image.save(buffer, format="JPEG", quality=82)
        return buffer.getvalue()

    # -- кошельки -----------------------------------------------------------

    def _seed_wallets(self, users: dict[str, Any]) -> None:
        # Полдень по UTC: дата операции одинакова и в UTC, и в Asia/Bishkek,
        # поэтому «два разных дня» на экране истории выглядят как два дня.
        noon = timezone.now().replace(hour=9, minute=0, second=0, microsecond=0)

        for user in users.values():
            if not user.is_pro:
                continue

            wallet = get_wallet(user)

            for index, entry in enumerate(WALLET_ENTRIES):
                # Ключ по смыслу операции, а не по порядку: список может расти.
                key = f"seed-demo:{user.phone}:{entry['key']}"
                before = WalletTransaction.objects.filter(idempotency_key=key).exists()

                # Баланс меняется только через сервис — прямых записей нет.
                operation = apply_transaction(
                    wallet=wallet,
                    amount=entry["amount"],
                    kind=entry["kind"],
                    label=entry["label"],
                    idempotency_key=key,
                )

                if not before:
                    # created_at — auto_now_add, поэтому дату проставляем апдейтом.
                    moment = noon - timedelta(days=entry["days"]) + timedelta(minutes=index * 7)
                    WalletTransaction.objects.filter(pk=operation.pk).update(created_at=moment)

            wallet.refresh_from_db()
            self.stdout.write(f"  кошелёк {user.phone}: {wallet.balance} кирпичей")
