"""Пять настоящих объявлений: живые тексты, адреса и характеристики.

Отличие от `seed_demo`: тот рисует картинки-заглушки на лету и наполняет базу
десятками случайных объектов. Здесь — ровно пять объявлений, которые не стыдно
показать: осмысленные описания, адреса и характеристики.

По умолчанию создаёт объявления без фото и видео.
Если требуется прикрепить медиафайлы из ассетов, используйте флаг `--with-media`:

    python manage.py seed_real
    python manage.py seed_real --with-media
    python manage.py seed_real --with-media --assets /srv/house_kgz/flutter_app/assets
    python manage.py seed_real --with-media --replace-media

Команда идемпотентна: повторный запуск обновляет те же пять объявлений по их
slug и не плодит копии.
"""

from decimal import Decimal
from pathlib import Path
from typing import Any

from django.contrib.auth import get_user_model
from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand, CommandError, CommandParser
from django.db import transaction
from django.utils import timezone

from apps.catalog.enums import (
    BuildingLine,
    CommercialPurpose,
    Currency,
    FurnitureKind,
    HeatingKind,
    ListingCondition,
    ListingStatus,
    MediaKind,
    MediaStatus,
    PropertyKind,
    SellerKind,
)
from apps.catalog.models import (
    Builder,
    City,
    District,
    HouseSeries,
    Listing,
    ListingMedia,
)
from apps.catalog.search import update_search_vectors

# Продавцы ------------------------------------------------------------------

# Телефоны из диапазона, зарезервированного под демо: настоящим людям такие
# номера не выдаются, и случайная отправка SMS никого не разбудит.
OWNERS: dict[str, dict[str, Any]] = {
    "owner": {
        "phone": "+996700990001",
        "name": "Айбек Осмонов",
        "seller_kind": SellerKind.OWNER,
    },
    "realtor": {
        "phone": "+996700990002",
        "name": "Динара Сатылганова",
        "seller_kind": SellerKind.REALTOR,
    },
    "agency": {
        "phone": "+996700990003",
        "name": "Агентство «Ак-Кеме Недвижимость»",
        "seller_kind": SellerKind.AGENCY,
    },
}

# Районы: название -> slug.
DISTRICTS: list[tuple[str, str]] = [
    ("Технопарк", "technopark"),
    ("Асанбай", "asanbay"),
    ("Джал", "djal"),
    ("Кок-Жар", "kok-jar"),
    ("Центр", "center"),
]

SERIES: list[tuple[str, str]] = [("103", "103 серия"), ("105", "105 серия")]

BUILDER = ("Авангард Стиль", "avangard-stil")

# Объявления ----------------------------------------------------------------
#
# Фотографии подобраны под каждый объект: интерьер к квартире, фасад и вид
# сверху к дому, бизнес-центр и план этажа к коммерции. Файл `plan` — это
# экспликация помещений из макета, она идёт последней в галерее.

LISTINGS: list[dict[str, Any]] = [
    {
        "slug": "technopark-3k-92-ahunbaeva",
        "owner": "owner",
        "kind": PropertyKind.APARTMENT,
        "seller_kind": SellerKind.OWNER,
        "district": "technopark",
        "address": "Бишкек, Свердловский район, ул. Ахунбаева 97/1",
        "price": Decimal("102000"),
        "old_price": Decimal("107000"),
        "rooms": 3,
        "area": Decimal("92"),
        "floor": 8,
        "floors": 12,
        "series": "103",
        "is_secondary": True,
        "below_market": True,
        "red_book": True,
        "condition": ListingCondition.EURO,
        "heating": HeatingKind.CENTRAL,
        "furniture": FurnitureKind.PARTIAL,
        "has_gas": True,
        "ceiling_height": Decimal("2.90"),
        "landmarks": ["ТЦ «Технопарк»", "Школа №70", "Парк Ататюрка"],
        "description": (
            "Трёхкомнатная квартира 92 м² в кирпичном доме рядом с Технопарком. "
            "Свежий евроремонт: заменены проводка и трубы, поставлены новые "
            "стеклопакеты, санузел раздельный, кухня-гостиная объединена с "
            "лоджией. Остаётся встроенная кухня со всей техникой и шкафы-купе "
            "в двух комнатах.\n\n"
            "Дом сдан в 2016 году, во дворе закрытая парковка и детская "
            "площадка. До школы №70 семь минут пешком, рядом супермаркет и "
            "остановка. Документы в порядке, красная книга на руках, "
            "собственник один, обременений нет — сделка за неделю."
        ),
        "photos": [
            ("74ca11e3a68b83c9.jpg", "Гостиная-кухня"),
            ("b9c2288b4b961f66.jpg", "Холл и вход в комнаты"),
            ("ccc665cff0c465a4.jpg", "Спальня"),
            ("53416eb5d259dfdf.jpg", "Планировка"),
        ],
        "video": ("video_1.mp4", "Обзор квартиры"),
        "views_count": 1840,
    },
    {
        "slug": "asanbay-3k-92-baytik-baatyra",
        "owner": "realtor",
        "kind": PropertyKind.APARTMENT,
        "seller_kind": SellerKind.REALTOR,
        "district": "asanbay",
        "address": "Бишкек, Ленинский район, ул. Байтик Баатыра 61",
        "price": Decimal("92850"),
        "rooms": 3,
        "area": Decimal("92"),
        "floor": 8,
        "floors": 12,
        "series": "105",
        "is_secondary": True,
        "condition": ListingCondition.GOOD,
        "heating": HeatingKind.CENTRAL,
        "furniture": FurnitureKind.FULL,
        "has_gas": True,
        "exchange_possible": True,
        "ceiling_height": Decimal("2.75"),
        "landmarks": ["Парк «Ынтымак»", "Гимназия №6", "Ошский рынок"],
        "description": (
            "Просторная квартира 105-й серии в Асанбае: три изолированные "
            "комнаты, большая кухня с выходом на застеклённую лоджию, окна на "
            "две стороны — утром солнце в спальне, вечером в гостиной.\n\n"
            "Мебель и техника остаются полностью, заезжать можно с чемоданом. "
            "Дом тихий, соседи спокойные, во дворе места под парковку хватает. "
            "Рассмотрим обмен на двухкомнатную в этом же районе с доплатой в "
            "нашу сторону."
        ),
        "photos": [
            ("b76192aa900c610a.jpg", "Гостиная с террасой"),
            ("92b0d143df96c511.jpg", "Столовая зона"),
            ("ca28464fe1355ade.jpg", "Планировка"),
        ],
        "video": ("video_2.mp4", "Обзор квартиры"),
        "views_count": 967,
    },
    {
        "slug": "djal-2k-70-novostroyka",
        "owner": "agency",
        "kind": PropertyKind.NEW_BUILDING,
        "seller_kind": SellerKind.AGENCY,
        "district": "djal",
        "address": "Бишкек, Джал-23, ул. Токомбаева 21/3",
        "price": Decimal("78400"),
        "rooms": 2,
        "area": Decimal("70"),
        "floor": 5,
        "floors": 9,
        "builder": True,
        "below_market": True,
        "condition": ListingCondition.EURO,
        "heating": HeatingKind.AUTONOMOUS,
        "furniture": FurnitureKind.NONE,
        "ceiling_height": Decimal("3.00"),
        "landmarks": ["ЖК «Джал Парк»", "Детский сад «Бал Бакча»", "Южная магистраль"],
        "description": (
            "Двухкомнатная квартира 70 м² в сданном доме на Джале. Дом "
            "монолит-каркас, автономная котельная на подъезд — отопление "
            "включаете сами и платите только за своё.\n\n"
            "Квартира с ремонтом от застройщика: стяжка, штукатурка, разводка "
            "электрики и сантехники, установлены двери и стеклопакеты. "
            "Планировка с кухней-гостиной 24 м² и отдельной спальней. Цена "
            "ниже рынка — застройщик закрывает остаток по объекту, поэтому "
            "квартира последняя в этой очереди."
        ),
        "photos": [
            ("2e62acec850fa8b9.jpg", "Гостиная"),
            ("0d0941963f5141a8.png", "Планировка"),
            ("626b1fdeaa97d9f9.jpg", "План этажа"),
        ],
        "video": ("video_3.mp4", "Обзор квартиры"),
        "views_count": 2310,
    },
    {
        "slug": "kok-jar-dom-210-sadovaya",
        "owner": "owner",
        "kind": PropertyKind.HOUSE,
        "seller_kind": SellerKind.OWNER,
        "district": "kok-jar",
        "address": "Бишкек, жилмассив Кок-Жар, ул. Садовая 12",
        "price": Decimal("189000"),
        "rooms": 5,
        "area": Decimal("210"),
        "land_area": Decimal("8"),
        "floor": 2,
        "floors": 2,
        "condition": ListingCondition.EURO,
        "heating": HeatingKind.GAS,
        "furniture": FurnitureKind.PARTIAL,
        "has_gas": True,
        "red_book": True,
        "ceiling_height": Decimal("3.20"),
        "landmarks": ["Школа-гимназия №38", "Кок-Жарский рынок", "Выезд на Южную магистраль"],
        "description": (
            "Двухэтажный дом 210 м² на восьми сотках в Кок-Жаре. Первый этаж — "
            "кухня-гостиная, гостевая комната и санузел; второй — четыре "
            "спальни и две ванные. Дом тёплый: газовый котёл, тёплый пол на "
            "первом этаже, стены в два кирпича.\n\n"
            "Участок ухоженный: плодовый сад, летняя кухня с тандыром, гараж "
            "на две машины и отдельный въезд для техники. Все коммуникации "
            "городские, счётчики свои. Красная книга готова, дом не в залоге."
        ),
        "photos": [
            ("fb9bf9cc77816ef6.jpg", "Фасад"),
            ("231c034e3954a705.jpg", "Двор вечером"),
            ("e267d094d7f9a8fc.jpg", "Вид сверху"),
            ("ccc665cff0c465a4.jpg", "Спальня на втором этаже"),
        ],
        "video": ("video_4.mp4", "Обзор дома и участка"),
        "views_count": 1425,
    },
    {
        "slug": "center-commercial-120-chuy",
        "owner": "agency",
        "kind": PropertyKind.COMMERCIAL,
        "seller_kind": SellerKind.AGENCY,
        "district": "center",
        "address": "Бишкек, Первомайский район, пр. Чуй 164",
        "price": Decimal("210000"),
        "rooms": 0,
        "area": Decimal("120"),
        "floor": 1,
        "floors": 9,
        "commercial_purpose": CommercialPurpose.OFFICE,
        "building_line": BuildingLine.FIRST,
        "has_separate_entrance": True,
        "condition": ListingCondition.EURO,
        "heating": HeatingKind.CENTRAL,
        "ceiling_height": Decimal("3.50"),
        "landmarks": ["пр. Чуй", "Филармония", "Остановка «Молодая гвардия»"],
        "description": (
            "Помещение 120 м² на первой линии проспекта Чуй: отдельный вход с "
            "улицы, витринные окна, своё крыльцо и место под вывеску. Сейчас "
            "открытое пространство с двумя кабинетами и санузлом, перегородки "
            "можно снять — несущих стен внутри нет.\n\n"
            "Электричество 15 кВт, вентиляция и кондиционирование выведены, "
            "интернет от двух провайдеров. Подходит под офис, клинику, салон "
            "или магазин. Помещение свободно, договор аренды не обременяет — "
            "заезжать можно сразу после сделки."
        ),
        "photos": [
            ("6b47403283623706.jpg", "Фасад здания"),
            ("6c0d66ecdce7df22.jpg", "План этажа"),
            ("f36bc748a320b1d4.jpg", "Расположение на карте"),
        ],
        "video": ("video_5.mp4", "Обзор помещения"),
        "views_count": 512,
    },
]


class Command(BaseCommand):
    help = "Пять объявлений с настоящими текстами и характеристиками (по умолчанию без фото и видео)"

    def add_arguments(self, parser: CommandParser) -> None:
        parser.add_argument(
            "--with-media",
            action="store_true",
            help="Загрузить и прикрепить фото и видео из каталога ассетов.",
        )
        parser.add_argument(
            "--assets",
            type=Path,
            default=None,
            help=(
                "Каталог ассетов Flutter (по умолчанию ../flutter_app/assets). "
                "Внутри ожидаются папки figma/ и videos_obzor/."
            ),
        )
        parser.add_argument(
            "--replace-media",
            action="store_true",
            help="Перезалить фото и видео у объявлений, где они уже есть.",
        )

    def handle(self, *args: Any, **options: Any) -> None:
        self.with_media = bool(options.get("with_media"))
        self.replace_media = bool(options.get("replace_media"))
        if self.with_media or self.replace_media or options.get("assets"):
            self.with_media = True
            self.assets = self._resolve_assets(options.get("assets"))
        else:
            self.assets = None

        with transaction.atomic():
            owners = self._seed_owners()
            city = self._seed_city()
            districts = self._seed_districts(city)
            series = self._seed_series()
            builder = self._seed_builder()

            listings = []
            for spec in LISTINGS:
                listing = self._seed_listing(spec, owners, city, districts, series, builder)
                listings.append(listing)

        # Поисковый вектор считается вне транзакции: он не должен держать
        # блокировки, а при сбое объявления всё равно уже на месте.
        update_search_vectors(Listing.objects.filter(pk__in=[item.pk for item in listings]))

        self.stdout.write(self.style.SUCCESS(f"Готово: {len(listings)} объявлений"))
        for listing in listings:
            photos = listing.media.filter(kind=MediaKind.PHOTO).count()
            videos = listing.media.filter(kind=MediaKind.VIDEO).count()
            self.stdout.write(f"  {listing.slug}: фото {photos}, видео {videos}")

    # -- ассеты ---------------------------------------------------------------

    def _resolve_assets(self, given: Path | None) -> Path:
        from django.conf import settings

        root = given or Path(settings.BASE_DIR).parent / "flutter_app" / "assets"
        root = root.expanduser().resolve()

        missing = [name for name in ("figma", "videos_obzor") if not (root / name).is_dir()]
        if missing:
            raise CommandError(
                f"В каталоге {root} нет папок: {', '.join(missing)}. "
                "Укажите путь к ассетам Flutter флагом --assets "
                "(например: --assets /srv/house_kgz/flutter_app/assets)."
            )
        return root

    def _asset(self, folder: str, name: str) -> Path:
        path = self.assets / folder / name
        if not path.is_file():
            raise CommandError(f"Нет файла {path}")
        return path

    # -- справочники ----------------------------------------------------------

    def _seed_owners(self) -> dict[str, Any]:
        user_model = get_user_model()
        owners: dict[str, Any] = {}

        for key, data in OWNERS.items():
            user, created = user_model.objects.get_or_create(
                phone=data["phone"],
                defaults={
                    "name": data["name"],
                    "is_pro": True,
                    "seller_kind": data["seller_kind"],
                    "is_active": True,
                },
            )
            if not created:
                user.name = data["name"]
                user.is_pro = True
                user.seller_kind = data["seller_kind"]
                user.save(update_fields=["name", "is_pro", "seller_kind", "updated_at"])
            owners[key] = user

        self.stdout.write(f"  продавцов: {len(owners)}")
        return owners

    def _seed_city(self) -> City:
        city, _ = City.objects.get_or_create(slug="bishkek", defaults={"name": "Бишкек"})
        return city

    def _seed_districts(self, city: City) -> dict[str, District]:
        districts: dict[str, District] = {}
        for name, slug in DISTRICTS:
            district, _ = District.objects.get_or_create(
                slug=slug,
                defaults={"name": name, "city": city},
            )
            districts[slug] = district
        self.stdout.write(f"  районов: {len(districts)}")
        return districts

    def _seed_series(self) -> dict[str, HouseSeries]:
        series: dict[str, HouseSeries] = {}
        for code, name in SERIES:
            item, _ = HouseSeries.objects.get_or_create(code=code, defaults={"name": name})
            series[code] = item
        return series

    def _seed_builder(self) -> Builder:
        name, slug = BUILDER
        builder, _ = Builder.objects.get_or_create(slug=slug, defaults={"name": name})
        return builder

    # -- объявления -----------------------------------------------------------

    def _seed_listing(
        self,
        spec: dict[str, Any],
        owners: dict[str, Any],
        city: City,
        districts: dict[str, District],
        series: dict[str, HouseSeries],
        builder: Builder,
    ) -> Listing:
        owner = owners[spec["owner"]]
        now = timezone.now()

        fields: dict[str, Any] = {
            "owner": owner,
            "kind": spec["kind"],
            "seller_kind": spec["seller_kind"],
            "city": city,
            "district": districts[spec["district"]],
            "address": spec["address"],
            "price": spec["price"],
            "currency": Currency.USD,
            "old_price": spec.get("old_price"),
            "rooms": spec.get("rooms", 0),
            "area": spec.get("area"),
            "land_area": spec.get("land_area"),
            "floor": spec.get("floor", 0),
            "floors": spec.get("floors", 0),
            "series": series.get(spec["series"]) if spec.get("series") else None,
            "builder": builder if spec.get("builder") else None,
            "is_secondary": spec.get("is_secondary", False),
            "below_market": spec.get("below_market", False),
            "red_book": spec.get("red_book", False),
            "exchange_possible": spec.get("exchange_possible", False),
            "has_gas": spec.get("has_gas", False),
            "condition": spec.get("condition", ""),
            "heating": spec.get("heating", ""),
            "furniture": spec.get("furniture", ""),
            "commercial_purpose": spec.get("commercial_purpose", ""),
            "building_line": spec.get("building_line", ""),
            "has_separate_entrance": spec.get("has_separate_entrance", False),
            "ceiling_height": spec.get("ceiling_height"),
            "landmarks": spec.get("landmarks", []),
            "description": spec["description"],
            "contact_name": owner.name,
            "contact_phone": owner.phone,
            "status": ListingStatus.ACTIVE,
            "views_count": spec.get("views_count", 0),
        }

        listing, created = Listing.objects.update_or_create(slug=spec["slug"], defaults=fields)
        if created or listing.published_at is None:
            listing.published_at = now
            listing.save(update_fields=["published_at", "updated_at"])

        if self.with_media and self.assets:
            order = 0
            for name, title in spec.get("photos", []):
                self._attach(
                    listing=listing,
                    order=order,
                    source=self._asset("figma", name),
                    kind=MediaKind.PHOTO,
                    title=title,
                    is_cover=order == 0,
                )
                order += 1

            if "video" in spec and spec["video"]:
                video_name, video_title = spec["video"]
                self._attach(
                    listing=listing,
                    order=order,
                    source=self._asset("videos_obzor", video_name),
                    kind=MediaKind.VIDEO,
                    title=video_title,
                    is_cover=False,
                )
        return listing

    # -- медиа ----------------------------------------------------------------

    def _attach(
        self,
        *,
        listing: Listing,
        order: int,
        source: Path,
        kind: str,
        title: str,
        is_cover: bool,
    ) -> ListingMedia:
        media, created = ListingMedia.objects.get_or_create(
            listing=listing,
            order=order,
            defaults={"kind": kind, "is_cover": is_cover, "title": title},
        )

        if not created:
            media.kind = kind
            media.is_cover = is_cover
            media.title = title
            media.save(update_fields=["kind", "is_cover", "title", "updated_at"])
            if media.file and not self.replace_media:
                return media

        media.file.save(
            f"{listing.slug}-{order}{source.suffix.lower()}",
            ContentFile(source.read_bytes()),
            save=True,
        )

        if kind == MediaKind.PHOTO:
            self._process_photo(media)
        else:
            self._process_video(media, listing)
        return media

    def _process_photo(self, media: ListingMedia) -> None:
        """Гоняет фото через тот же конвейер, что и загрузку из приложения."""
        from apps.catalog.tasks import _process_photo

        try:
            _process_photo(media)
        except Exception as exc:  # noqa: BLE001 - сид не должен падать из-за одного файла
            self.stderr.write(f"    превью для {media.pk} не собрались: {exc}")
            media.status = MediaStatus.READY
            media.size_bytes = media.file.size
            media.save(update_fields=["status", "size_bytes", "updated_at"])

    def _process_video(self, media: ListingMedia, listing: Listing) -> None:
        """Метаданные и кадр-превью. Без ffmpeg постером станет обложка объекта."""
        from apps.catalog.tasks import _process_video

        try:
            _process_video(media)
            if media.thumbnail:
                return
        except Exception as exc:  # noqa: BLE001 - ffmpeg есть не на каждом сервере
            self.stderr.write(f"    кадр из видео не достали ({exc}); ставим обложку объекта")

        cover = (
            listing.media.filter(kind=MediaKind.PHOTO)
            .exclude(pk=media.pk)
            .order_by("order")
            .first()
        )
        if cover is not None and cover.file:
            cover.file.open("rb")
            try:
                data = cover.file.read()
            finally:
                cover.file.close()
            media.thumbnail.save(f"{listing.slug}-poster.jpg", ContentFile(data), save=False)

        media.size_bytes = media.size_bytes or media.file.size
        media.status = MediaStatus.READY
        media.processing_error = ""
        media.save(
            update_fields=["thumbnail", "size_bytes", "status", "processing_error", "updated_at"]
        )
