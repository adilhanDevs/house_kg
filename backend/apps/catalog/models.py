"""Каталог: справочники, объявления и медиа.

Набор полей повторяет §1.6 ТЗ и прототип Flutter (`lib/data/listings.dart`),
чтобы клиент мог переключиться с моковых данных на API без изменений в UI.
"""

import logging
import uuid
from typing import Any

logger = logging.getLogger(__name__)

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
    MediaStatus,
    ModerationStatus,
    PropertyKind,
    ReportReason,
    SellerKind,
)
from apps.catalog.media import media_upload_to
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


class ListingQuerySet(models.QuerySet):
    """Общие выборки объявлений."""

    def alive(self) -> "ListingQuerySet":
        return self.filter(is_deleted=False)


class ListingManager(models.Manager.from_queryset(ListingQuerySet)):
    """Менеджер по умолчанию: удалённые объявления не видны нигде."""

    def get_queryset(self) -> ListingQuerySet:
        return super().get_queryset().filter(is_deleted=False)


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
    # Ключи файлов в хранилище строятся из uuid, а не из slug или pk: slug
    # виден в ссылках, а по последовательному pk можно перебрать чужие файлы.
    uuid = models.UUIDField("UUID", default=uuid.uuid4, editable=False, unique=True)
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
    # Город и район заполняются в форме, поэтому у черновика их может не быть.
    city = models.ForeignKey(
        City,
        verbose_name="Город",
        on_delete=models.PROTECT,
        related_name="listings",
        blank=True,
        null=True,
    )
    district = models.ForeignKey(
        District,
        verbose_name="Район",
        on_delete=models.PROTECT,
        related_name="listings",
        blank=True,
        null=True,
    )
    address = models.CharField("Адрес", max_length=255, blank=True)
    latitude = models.DecimalField("Широта", max_digits=9, decimal_places=6, blank=True, null=True)
    longitude = models.DecimalField(
        "Долгота", max_digits=9, decimal_places=6, blank=True, null=True
    )

    price = models.DecimalField("Цена", max_digits=12, decimal_places=2, blank=True, null=True)
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
    area = models.DecimalField("Площадь, м²", max_digits=8, decimal_places=2, blank=True, null=True)
    living_room_area = models.DecimalField("Гостинная, м²", max_digits=6, decimal_places=2, blank=True, null=True)
    hall_area = models.DecimalField("Холл, м²", max_digits=6, decimal_places=2, blank=True, null=True)
    kitchen_area = models.DecimalField("Кухня, м²", max_digits=6, decimal_places=2, blank=True, null=True)
    bedroom_area = models.DecimalField("Спальная, м²", max_digits=6, decimal_places=2, blank=True, null=True)
    bedroom_2_area = models.DecimalField("Спальная 2, м²", max_digits=6, decimal_places=2, blank=True, null=True)
    balcony_area = models.DecimalField("Балкон, м²", max_digits=6, decimal_places=2, blank=True, null=True)
    bathroom_area = models.DecimalField("Сан.узел, м²", max_digits=6, decimal_places=2, blank=True, null=True)
    furniture = models.CharField("Мебель", max_length=50, blank=True, default="Полностью")

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
    has_direct_sale = models.BooleanField("Прямая покупка", default=True)
    has_mortgage = models.BooleanField("Ипотека", default=True)

    landmarks = models.JSONField("Ключевые места", default=list, blank=True)

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
    bumped_at = models.DateTimeField("Последний подъём", blank=True, null=True)
    # Мягкое удаление: объявление исчезает из выдачи, но остаётся в истории
    # просмотров, избранном и леджере операций.
    is_deleted = models.BooleanField("Удалено", default=False, db_index=True)

    # Денормализованные счётчики: меняются только через сервисы, F-выражениями.
    views_count = models.PositiveIntegerField("Просмотров", default=0)
    favourites_count = models.PositiveIntegerField("В избранном", default=0)

    allow_media_download = models.BooleanField("Разрешить скачивание фото", default=True)
    contact_name = models.CharField("Контактное лицо", max_length=150, blank=True)
    contact_phone = models.CharField("Контактный телефон", max_length=16, blank=True)

    search_vector = SearchVectorField("Поисковый вектор", blank=True, null=True, editable=False)

    objects = ListingManager()
    # Полный набор, включая удалённые: нужен админке и разбору инцидентов.
    all_objects = models.Manager()

    class Meta:
        verbose_name = "Объявление"
        verbose_name_plural = "Объявления"
        ordering = ["-created_at"]
        # Связанные объекты должны находиться даже у удалённого объявления.
        base_manager_name = "all_objects"
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
        district = self.district.name if self.district_id else "Черновик"
        price = f"{self.price:.0f} {self.currency}" if self.price is not None else "без цены"
        return f"{district} · {price}"

    def save(self, *args: object, **kwargs: object) -> None:
        from apps.catalog.rates import to_usd

        if not self.slug:
            district_slug = self.district.slug if self.district_id else ""
            self.slug = build_listing_slug(district_slug, self.rooms)

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
        if self.price is None:
            return ""
        amount = f"{int(self.price):,}".replace(",", "\u00a0")
        return f"{amount}$" if self.currency == Currency.USD else f"{amount}\u00a0сом"

    @property
    def discount_percent(self) -> int | None:
        """На сколько процентов цена ниже прежней."""
        if self.price is None or not self.old_price or self.old_price <= self.price:
            return None
class ListingRoom(models.Model):
    """Комната или помещение в объявлении с указанием квадратуры."""

    listing = models.ForeignKey(
        Listing,
        verbose_name="Объявление",
        on_delete=models.CASCADE,
        related_name="rooms_data",
    )
    name = models.CharField(
        "Название комнаты",
        max_length=100,
        help_text="Например: Гостинная, Холл, Кухня, Спальная, Гардеробная, Терраса, Сан.узел",
    )
    area = models.DecimalField(
        "Площадь, м²",
        max_digits=6,
        decimal_places=2,
    )
    order = models.PositiveIntegerField("Порядок", default=0)

    class Meta:
        verbose_name = "Комната"
        verbose_name_plural = "Комнаты (экспликация помещений)"
        ordering = ["order", "id"]

    def __str__(self) -> str:
        return f"{self.name}: {self.area} м²"


class ListingMedia(TimeStampedModel):
    """Фото или видео объявления. Первый файл (order=0) — обложка."""

    listing = models.ForeignKey(
        Listing,
        verbose_name="Объявление",
        on_delete=models.CASCADE,
        related_name="media",
    )
    uuid = models.UUIDField("UUID", default=uuid.uuid4, editable=False, unique=True)
    file = models.FileField("Оригинал", upload_to=media_upload_to)
    kind = models.CharField("Тип", max_length=8, choices=MediaKind.choices, default=MediaKind.PHOTO)
    status = models.CharField(
        "Статус обработки",
        max_length=12,
        choices=MediaStatus.choices,
        default=MediaStatus.UPLOADING,
        db_index=True,
    )
    order = models.PositiveSmallIntegerField("Порядок", default=0)
    is_cover = models.BooleanField("Обложка", default=False)

    title = models.CharField("Заголовок", max_length=100, blank=True)
    description = models.TextField("Описание", blank=True)

    width = models.PositiveIntegerField("Ширина", blank=True, null=True)
    height = models.PositiveIntegerField("Высота", blank=True, null=True)
    duration_seconds = models.PositiveIntegerField("Длительность, с", blank=True, null=True)
    size_bytes = models.PositiveBigIntegerField("Размер, байт", blank=True, null=True)
    thumbnail = models.ImageField("Превью", upload_to=media_upload_to, blank=True, null=True)

    # Перцептивный хеш: одинаковые снимки в разных объявлениях дают одно
    # значение, и модератор видит переклейку чужих фото.
    phash = models.CharField("Перцептивный хеш", max_length=64, blank=True, db_index=True)

    # Варианты размеров. Имена полей повторяют имена в ответе API.
    url_thumb = models.FileField("Превью 400px", upload_to=media_upload_to, blank=True)
    url_medium = models.FileField("Средний 1080px", upload_to=media_upload_to, blank=True)
    url_original = models.FileField("Оригинал ≤2560px", upload_to=media_upload_to, blank=True)
    # JPEG-фолбэк для клиентов, которые не умеют WebP.
    url_thumb_jpeg = models.FileField("Превью JPEG", upload_to=media_upload_to, blank=True)
    url_medium_jpeg = models.FileField("Средний JPEG", upload_to=media_upload_to, blank=True)
    url_original_jpeg = models.FileField("Оригинал JPEG", upload_to=media_upload_to, blank=True)

    processing_error = models.CharField("Ошибка обработки", max_length=255, blank=True)

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

    # Поля, в которых лежат файлы. Порядок важен: по нему удаляются варианты.
    FILE_FIELDS = (
        "url_thumb",
        "url_medium",
        "url_original",
        "url_thumb_jpeg",
        "url_medium_jpeg",
        "url_original_jpeg",
        "thumbnail",
        "file",
    )

    @property
    def is_ready(self) -> bool:
        return self.status == MediaStatus.READY

    def save(self, *args: Any, **kwargs: Any) -> None:
        super().save(*args, **kwargs)
        if self.kind == MediaKind.VIDEO and not self.thumbnail and self.file:
            try:
                from apps.catalog.tasks import _process_video
                _process_video(self)
            except Exception as e:
                logger.warning("Не удалось автоматически извлечь кадр-обложку видео: %s", e)

    def display_file(self) -> Any:
        """Что показывать клиенту сейчас.

        Пока обработка не закончилась, отдаётся оригинал: экран не должен
        ждать конвертации, чтобы показать только что снятую фотографию.
        """
        return self.url_medium if self.url_medium else self.file

    def delete_files(self) -> None:
        """Убирает из хранилища сам файл и все варианты размеров."""
        for name in self.FILE_FIELDS:
            file_field = getattr(self, name, None)
            if file_field:
                file_field.delete(save=False)

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


class ListingDailyStat(models.Model):
    """Показатели объявления за сутки — график на экране статистики.

    Отдельная таблица, а не счётчики на объявлении: владельцу нужна динамика
    по дням, чтобы сравнить период до продвижения и во время него.
    """

    listing = models.ForeignKey(
        Listing,
        verbose_name="Объявление",
        on_delete=models.CASCADE,
        related_name="daily_stats",
    )
    date = models.DateField("Дата", db_index=True)
    # Показ в выдаче — самое частое событие, пишется пачкой из Celery.
    impressions = models.PositiveIntegerField("Показы в выдаче", default=0)
    views = models.PositiveIntegerField("Открытия карточки", default=0)
    favourites = models.PositiveIntegerField("Добавления в избранное", default=0)
    phone_reveals = models.PositiveIntegerField("Показы телефона", default=0)

    class Meta:
        verbose_name = "Статистика объявления за день"
        verbose_name_plural = "Статистика объявлений по дням"
        ordering = ["-date"]
        constraints = [
            models.UniqueConstraint(fields=["listing", "date"], name="listing_daily_stat_unique"),
        ]
        indexes = [
            models.Index(fields=["listing", "-date"], name="listing_stat_recent_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.listing_id} · {self.date}"


class RejectReason(DictionaryModel):
    """Справочник причин отклонения — редактируется в админке.

    Причина — отдельная сущность, а не строка в задаче: текст формулировки
    правится редактором один раз и подтягивается во все прошлые отклонения,
    а по коду собирается статистика «за что чаще всего отклоняем».
    """

    code = models.SlugField("Код", max_length=32, unique=True)
    title = models.CharField("Заголовок", max_length=150)
    description = models.TextField(
        "Пояснение",
        blank=True,
        help_text="Текст, который увидит владелец объявления.",
    )

    class Meta:
        verbose_name = "Причина отклонения"
        verbose_name_plural = "Причины отклонения"
        ordering = ["order", "code"]

    def __str__(self) -> str:
        return self.title


class ModerationTask(TimeStampedModel):
    """Одна проверка объявления модератором.

    На объявление их может быть несколько: после исправления и повторной
    подачи заводится новая, а прошлые остаются историей — по ним видно, кто
    и сколько раз уже приходил с одним и тем же нарушением.
    """

    # Задача может быть либо об объявлении, либо об отзыве: очередь одна,
    # чтобы модератор не переключался между двумя списками.
    listing = models.ForeignKey(
        Listing,
        verbose_name="Объявление",
        on_delete=models.CASCADE,
        related_name="moderation_tasks",
        blank=True,
        null=True,
    )
    review = models.ForeignKey(
        "users.Review",
        verbose_name="Отзыв",
        on_delete=models.CASCADE,
        related_name="moderation_tasks",
        blank=True,
        null=True,
    )
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="Модератор",
        on_delete=models.SET_NULL,
        related_name="moderation_tasks",
        limit_choices_to={"is_staff": True},
        blank=True,
        null=True,
    )
    status = models.CharField(
        "Статус",
        max_length=16,
        choices=ModerationStatus.choices,
        default=ModerationStatus.OPEN,
        db_index=True,
    )
    # Результаты автопроверок: {"contacts_in_text": {"triggered": true, "details": {...}}}
    checks = models.JSONField("Автопроверки", default=dict, blank=True)
    priority = models.PositiveSmallIntegerField(
        "Приоритет",
        default=0,
        db_index=True,
        help_text="Количество сработавших автопроверок; жалобы дают 10.",
    )

    reject_reason = models.ForeignKey(
        RejectReason,
        verbose_name="Причина отклонения",
        on_delete=models.SET_NULL,
        related_name="moderation_tasks",
        blank=True,
        null=True,
    )
    comment = models.TextField("Комментарий модератора", blank=True)

    resolved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="Кто решил",
        on_delete=models.SET_NULL,
        related_name="resolved_moderation_tasks",
        blank=True,
        null=True,
    )
    resolved_at = models.DateTimeField("Когда решено", blank=True, null=True)

    class Meta:
        verbose_name = "Задача модерации"
        verbose_name_plural = "Очередь модерации"
        # Порядок очереди: сначала подозрительные, внутри — по времени подачи.
        ordering = ["-priority", "created_at"]
        indexes = [
            models.Index(fields=["status", "-priority", "created_at"], name="moderation_queue_idx"),
        ]
        constraints = [
            # Один объект не может стоять в очереди дважды. NULL в частичном
            # индексе не конфликтует, поэтому задачи об отзывах не мешают
            # задачам об объявлениях.
            models.UniqueConstraint(
                fields=["listing"],
                condition=Q(status=ModerationStatus.OPEN),
                name="moderation_single_open_task",
            ),
            models.UniqueConstraint(
                fields=["review"],
                condition=Q(status=ModerationStatus.OPEN),
                name="moderation_single_open_review",
            ),
            models.CheckConstraint(
                condition=Q(listing__isnull=False) | Q(review__isnull=False),
                name="moderation_task_has_target",
            ),
        ]

    def __str__(self) -> str:
        target = f"объявление {self.listing_id}" if self.listing_id else f"отзыв {self.review_id}"
        return f"Модерация: {target} ({self.get_status_display()})"

    @property
    def target_kind(self) -> str:
        return "listing" if self.listing_id else "review"

    @property
    def triggered_checks(self) -> list[str]:
        """Имена сработавших проверок."""
        return [
            name
            for name, result in (self.checks or {}).items()
            if isinstance(result, dict) and result.get("triggered")
        ]

    @property
    def is_open(self) -> bool:
        return self.status == ModerationStatus.OPEN


class ListingReport(TimeStampedModel):
    """Жалоба пользователя на объявление.

    Три неразрешённые жалобы снимают активное объявление с публикации
    автоматически: ждать модератора, пока люди видят мошенническое
    объявление, нельзя.
    """

    listing = models.ForeignKey(
        Listing,
        verbose_name="Объявление",
        on_delete=models.CASCADE,
        related_name="reports",
    )
    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="Кто пожаловался",
        on_delete=models.CASCADE,
        related_name="listing_reports",
    )
    reason = models.CharField("Причина", max_length=16, choices=ReportReason.choices)
    comment = models.TextField("Комментарий", blank=True)
    is_resolved = models.BooleanField("Разобрано", default=False, db_index=True)

    class Meta:
        verbose_name = "Жалоба на объявление"
        verbose_name_plural = "Жалобы на объявления"
        ordering = ["-created_at"]
        constraints = [
            # Один пользователь — одна жалоба на объявление: иначе порог
            # автоснятия накручивается одним человеком.
            models.UniqueConstraint(
                fields=["listing", "reporter"],
                name="listing_report_unique_reporter",
            ),
        ]
        indexes = [
            models.Index(fields=["listing", "is_resolved"], name="report_listing_open_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.get_reason_display()} · {self.listing_id}"


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
