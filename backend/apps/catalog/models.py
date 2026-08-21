"""Каталог: справочники, объявления и медиа.

Набор полей повторяет §1.6 ТЗ и прототип Flutter (`lib/data/listings.dart`),
чтобы клиент мог переключиться с моковых данных на API без изменений в UI.
"""

import uuid

from django.conf import settings
from django.contrib.postgres.indexes import GinIndex
from django.contrib.postgres.search import SearchVectorField
from django.core.exceptions import ValidationError
from django.db import models
from django.db.models import Q
from django.utils import timezone

from apps.catalog.constants import (
    MAX_PHOTOS_PER_LISTING,
    MAX_VIDEOS_PER_LISTING,
    SLUG_MAX_LENGTH,
    SLUG_SUFFIX_LENGTH,
)
from apps.catalog.enums import (
    Currency,
    ListingStatus,
    MediaKind,
    PropertyKind,
    SellerKind,
)
from apps.common.models import TimeStampedModel


class DictionaryModel(TimeStampedModel):
    """Общее для справочников: показывать ли и в каком порядке."""

    is_active = models.BooleanField("Активен", default=True)
    order = models.PositiveSmallIntegerField("Порядок", default=0, db_index=True)

    class Meta:
        abstract = True


class City(DictionaryModel):
    """Город (Бишкек, Ош, ...)."""

    name = models.CharField("Название", max_length=100)
    slug = models.SlugField("Слаг", max_length=120, unique=True)
    is_default = models.BooleanField(
        "Город по умолчанию",
        default=False,
        help_text="Подставляется клиенту, если город не выбран.",
    )

    class Meta:
        verbose_name = "Город"
        verbose_name_plural = "Города"
        ordering = ["order", "name"]

    def __str__(self) -> str:
        return self.name


class District(DictionaryModel):
    """Район города (Технопарк, Асанбай, ...)."""

    city = models.ForeignKey(
        City,
        verbose_name="Город",
        on_delete=models.CASCADE,
        related_name="districts",
    )
    name = models.CharField("Название", max_length=100)
    slug = models.SlugField("Слаг", max_length=120)
    latitude = models.DecimalField("Широта", max_digits=9, decimal_places=6, blank=True, null=True)
    longitude = models.DecimalField(
        "Долгота", max_digits=9, decimal_places=6, blank=True, null=True
    )

    class Meta:
        verbose_name = "Район"
        verbose_name_plural = "Районы"
        ordering = ["order", "name"]
        unique_together = [("city", "slug")]

    def __str__(self) -> str:
        return self.name


class HouseSeries(DictionaryModel):
    """Серия дома: 103, 105, Элитка и т.п."""

    code = models.CharField("Код", max_length=32, unique=True)
    name = models.CharField("Название", max_length=100)

    class Meta:
        verbose_name = "Серия дома"
        verbose_name_plural = "Серии домов"
        ordering = ["order", "code"]

    def __str__(self) -> str:
        return self.name


class Builder(DictionaryModel):
    """Застройщик."""

    name = models.CharField("Название", max_length=150)
    slug = models.SlugField("Слаг", max_length=160, unique=True)
    logo = models.ImageField("Логотип", upload_to="builders/%Y/%m/", blank=True, null=True)
    description = models.TextField("Описание", blank=True)

    class Meta:
        verbose_name = "Застройщик"
        verbose_name_plural = "Застройщики"
        ordering = ["order", "name"]

    def __str__(self) -> str:
        return self.name


def listing_media_path(instance: "ListingMedia", filename: str) -> str:
    """Историческая схема путей.

    Функция больше не используется (медиа складываются в `listings/%Y/%m/`),
    но на неё ссылается миграция 0001 — удалять нельзя.
    """
    return f"listings/{instance.listing.slug}/{filename}"


def build_listing_slug(district_slug: str, rooms: int) -> str:
    """«technopark-3k-9f1c2a4b» — читаемо и уникально.

    Слаг генерируется один раз при создании и дальше не меняется: он попадает
    в ссылки, которыми делятся пользователи.
    """
    suffix = uuid.uuid4().hex[:SLUG_SUFFIX_LENGTH]
    tail = f"-{rooms}k-{suffix}"
    head = (district_slug or "listing")[: SLUG_MAX_LENGTH - len(tail)]
    return f"{head}{tail}"


class Listing(TimeStampedModel):
    """Объявление о продаже объекта — центральная сущность каталога."""

    slug = models.SlugField("Слаг", max_length=SLUG_MAX_LENGTH, unique=True, blank=True)
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="Владелец",
        on_delete=models.CASCADE,
        related_name="listings",
    )
    kind = models.CharField("Тип объекта", max_length=16, choices=PropertyKind.choices)
    seller_kind = models.CharField(
        "Кто продаёт",
        max_length=16,
        choices=SellerKind.choices,
        default=SellerKind.OWNER,
    )

    # Город продублирован рядом с районом осознанно: фильтр по городу —
    # самый частый запрос каталога, и джойн ради него делать не хочется.
    city = models.ForeignKey(
        City,
        verbose_name="Город",
        on_delete=models.PROTECT,
        related_name="listings",
    )
    district = models.ForeignKey(
        District,
        verbose_name="Район",
        on_delete=models.PROTECT,
        related_name="listings",
    )
    address = models.CharField("Адрес", max_length=255, blank=True)
    latitude = models.DecimalField("Широта", max_digits=9, decimal_places=6, blank=True, null=True)
    longitude = models.DecimalField(
        "Долгота", max_digits=9, decimal_places=6, blank=True, null=True
    )

    price = models.DecimalField("Цена", max_digits=12, decimal_places=2)
    currency = models.CharField(
        "Валюта", max_length=3, choices=Currency.choices, default=Currency.USD
    )
    # Цена, приведённая к долларам: по ней идут все фильтры и сортировки,
    # иначе объявления в сомах выпадали бы из ценового диапазона.
    price_usd = models.DecimalField(
        "Цена в USD",
        max_digits=12,
        decimal_places=2,
        db_index=True,
        blank=True,
        null=True,
        editable=False,
    )
    old_price = models.DecimalField(
        "Старая цена",
        max_digits=12,
        decimal_places=2,
        blank=True,
        null=True,
        help_text="Зачёркнутая цена в карточке.",
    )

    rooms = models.PositiveSmallIntegerField("Комнат", default=0)
    area = models.DecimalField("Площадь, м²", max_digits=8, decimal_places=2)
    land_area = models.DecimalField(
        "Площадь участка, соток", max_digits=8, decimal_places=2, blank=True, null=True
    )
    floor = models.PositiveSmallIntegerField("Этаж", default=0)
    floors = models.PositiveSmallIntegerField("Этажность", default=0)

    series = models.ForeignKey(
        HouseSeries,
        verbose_name="Серия дома",
        on_delete=models.SET_NULL,
        related_name="listings",
        blank=True,
        null=True,
    )
    builder = models.ForeignKey(
        Builder,
        verbose_name="Застройщик",
        on_delete=models.SET_NULL,
        related_name="listings",
        blank=True,
        null=True,
    )

    is_secondary = models.BooleanField("Вторичка", default=False)
    below_market = models.BooleanField("Ниже рынка", default=False)
    red_book = models.BooleanField("Красная книга", default=False)

    description = models.TextField("Описание", blank=True)

    status = models.CharField(
        "Статус",
        max_length=16,
        choices=ListingStatus.choices,
        default=ListingStatus.DRAFT,
        db_index=True,
    )
    rejection_reason = models.TextField("Причина отклонения", blank=True)
    published_at = models.DateTimeField("Опубликовано", blank=True, null=True)
    expires_at = models.DateTimeField("Снять с публикации", blank=True, null=True)
    promoted_until = models.DateTimeField("Продвигается до", blank=True, null=True, db_index=True)

    # Денормализованные счётчики: меняются только через сервисы, F-выражениями.
    views_count = models.PositiveIntegerField("Просмотров", default=0)
    favourites_count = models.PositiveIntegerField("В избранном", default=0)

    allow_media_download = models.BooleanField("Разрешить скачивание фото", default=True)
    contact_name = models.CharField("Контактное лицо", max_length=150, blank=True)
    contact_phone = models.CharField("Контактный телефон", max_length=16, blank=True)

    search_vector = SearchVectorField("Поисковый вектор", blank=True, null=True, editable=False)

    class Meta:
        verbose_name = "Объявление"
        verbose_name_plural = "Объявления"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status", "-published_at"], name="listing_status_pub_idx"),
            models.Index(fields=["status", "district", "kind"], name="listing_status_geo_idx"),
            models.Index(fields=["status", "price"], name="listing_status_price_idx"),
            GinIndex(fields=["search_vector"], name="listing_search_vector_idx"),
            GinIndex(
                fields=["address"],
                name="listing_address_trgm_idx",
                opclasses=["gin_trgm_ops"],
            ),
        ]

    def __str__(self) -> str:
        return f"{self.district.name} · {self.price:.0f} {self.currency}"

    def save(self, *args: object, **kwargs: object) -> None:
        from apps.catalog.rates import to_usd

        if not self.slug:
            self.slug = build_listing_slug(self.district.slug, self.rooms)

        self.price_usd = to_usd(self.price, self.currency)
        update_fields = kwargs.get("update_fields")
        if update_fields is not None and "price" in update_fields:
            kwargs["update_fields"] = [*update_fields, "price_usd"]

        super().save(*args, **kwargs)

    @property
    def is_plot(self) -> bool:
        """У участка нет комнат и этажей — строка характеристик короче."""
        return self.kind == PropertyKind.PLOT

    @property
    def is_promoted(self) -> bool:
        return bool(self.promoted_until and self.promoted_until > timezone.now())

    @property
    def price_display(self) -> str:
        """«102 000$» — как в макете: тысячи через неразрывный пробел."""
        amount = f"{int(self.price):,}".replace(",", "\u00a0")
        return f"{amount}$" if self.currency == Currency.USD else f"{amount}\u00a0сом"

    @property
    def discount_percent(self) -> int | None:
        """На сколько процентов цена ниже прежней."""
        if not self.old_price or self.old_price <= self.price:
            return None
        return round((self.old_price - self.price) / self.old_price * 100)


class ListingMedia(TimeStampedModel):
    """Фото или видео объявления. Первый файл (order=0) — обложка."""

    listing = models.ForeignKey(
        Listing,
        verbose_name="Объявление",
        on_delete=models.CASCADE,
        related_name="media",
    )
    file = models.FileField("Файл", upload_to="listings/%Y/%m/")
    kind = models.CharField("Тип", max_length=8, choices=MediaKind.choices, default=MediaKind.PHOTO)
    order = models.PositiveSmallIntegerField("Порядок", default=0)
    is_cover = models.BooleanField("Обложка", default=False)

    width = models.PositiveIntegerField("Ширина", blank=True, null=True)
    height = models.PositiveIntegerField("Высота", blank=True, null=True)
    duration_seconds = models.PositiveIntegerField("Длительность, с", blank=True, null=True)
    size_bytes = models.PositiveBigIntegerField("Размер, байт", blank=True, null=True)
    thumbnail = models.ImageField(
        "Превью", upload_to="listings/thumbnails/%Y/%m/", blank=True, null=True
    )

    class Meta:
        verbose_name = "Медиа объявления"
        verbose_name_plural = "Медиа объявлений"
        ordering = ("order", "id")
        constraints = [
            models.UniqueConstraint(fields=["listing", "order"], name="listing_media_unique_order"),
            models.UniqueConstraint(
                fields=["listing"],
                condition=Q(is_cover=True),
                name="listing_media_single_cover",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.listing.slug} #{self.order}"

    @property
    def limit(self) -> int:
        return MAX_PHOTOS_PER_LISTING if self.kind == MediaKind.PHOTO else MAX_VIDEOS_PER_LISTING

    def clean(self) -> None:
        """Не даём превысить лимит файлов — то же ограничение, что в форме Flutter."""
        super().clean()
        if not self.listing_id:
            return

        siblings = ListingMedia.objects.filter(listing_id=self.listing_id, kind=self.kind)
        if self.pk:
            siblings = siblings.exclude(pk=self.pk)

        if siblings.count() >= self.limit:
            word = "фотографий" if self.kind == MediaKind.PHOTO else "видео"
            raise ValidationError(
                {"file": f"К объявлению можно приложить не больше {self.limit} {word}."},
                code="validation_error",
            )


class ExchangeRate(TimeStampedModel):
    """Курс валюты на момент загрузки.

    Источник — НБКР. История хранится целиком: цена в сомах, пересчитанная
    вчерашним курсом, должна воспроизводиться.
    """

    currency_from = models.CharField("Из валюты", max_length=3, choices=Currency.choices)
    currency_to = models.CharField("В валюту", max_length=3, choices=Currency.choices)
    rate = models.DecimalField("Курс", max_digits=12, decimal_places=6)
    fetched_at = models.DateTimeField("Загружен", default=timezone.now, db_index=True)

    class Meta:
        verbose_name = "Курс валюты"
        verbose_name_plural = "Курсы валют"
        ordering = ["-fetched_at"]
        get_latest_by = "fetched_at"
        indexes = [
            models.Index(
                fields=["currency_from", "currency_to", "-fetched_at"],
                name="rate_pair_recent_idx",
            ),
        ]

    def __str__(self) -> str:
        return f"1 {self.currency_from} = {self.rate} {self.currency_to}"
