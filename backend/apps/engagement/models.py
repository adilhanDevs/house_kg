"""Избранное и история просмотров.

Полноценные эндпоинты появятся в фазе 4 ТЗ; здесь — модели, без которых
не работают карточки каталога (`is_favourite`) и отметка просмотра.
"""

from django.conf import settings
from django.db import models
from django.utils import timezone

from apps.common.models import TimeStampedModel


class Favourite(TimeStampedModel):
    """Объявление, добавленное пользователем в избранное."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="Пользователь",
        on_delete=models.CASCADE,
        related_name="favourites",
    )
    listing = models.ForeignKey(
        "catalog.Listing",
        verbose_name="Объявление",
        on_delete=models.CASCADE,
        related_name="favourited_by",
    )
    # Цена на момент добавления: по ней задача считает падение.
    price_at_add = models.DecimalField(
        "Цена при добавлении, USD",
        max_digits=12,
        decimal_places=2,
        blank=True,
        null=True,
        editable=False,
    )

    class Meta:
        verbose_name = "Избранное"
        verbose_name_plural = "Избранное"
        ordering = ["-created_at"]
        unique_together = [("user", "listing")]
        indexes = [
            models.Index(fields=["user", "-created_at"], name="favourite_user_recent_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.user} ♥ {self.listing.slug}"


class ViewHistory(models.Model):
    """История просмотров: одна запись на пару пользователь-объявление."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="Пользователь",
        on_delete=models.CASCADE,
        related_name="view_history",
    )
    listing = models.ForeignKey(
        "catalog.Listing",
        verbose_name="Объявление",
        on_delete=models.CASCADE,
        related_name="view_history",
    )
    viewed_at = models.DateTimeField("Просмотрено", auto_now=True, db_index=True)
    # Первый просмотр отдельно от последнего: `viewed_at` перезаписывается на
    # каждом заходе (auto_now), и без этого поля момент знакомства с объектом
    # восстановить нельзя.
    first_viewed_at = models.DateTimeField("Впервые просмотрено", default=timezone.now)
    # Сколько раз пользователь возвращался к объявлению. Строка по-прежнему
    # одна на пару: заводить запись на каждый просмотр — это таблица, растущая
    # без предела ради счётчика.
    view_count = models.PositiveIntegerField("Просмотров", default=1)

    class Meta:
        verbose_name = "Просмотр"
        verbose_name_plural = "История просмотров"
        ordering = ["-viewed_at"]
        unique_together = [("user", "listing")]
        indexes = [
            models.Index(fields=["user", "-viewed_at"], name="view_history_recent_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.user} → {self.listing.slug}"


class SavedFilter(TimeStampedModel):
    """Сохранённый поиск: набор параметров каталога с уведомлениями о новинках."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="Пользователь",
        on_delete=models.CASCADE,
        related_name="saved_filters",
    )
    name = models.CharField("Название", max_length=100)
    # Нормализованный вид параметров: только известные ключи, значения строками.
    params = models.JSONField("Параметры", default=dict)
    notify_on_new = models.BooleanField("Уведомлять о новых", default=True)
    last_notified_at = models.DateTimeField("Последнее уведомление", blank=True, null=True)
    matches_count = models.PositiveIntegerField("Подходящих объектов", default=0)

    class Meta:
        verbose_name = "Сохранённый фильтр"
        verbose_name_plural = "Сохранённые фильтры"
        ordering = ["-created_at"]
        unique_together = [("user", "name")]
        indexes = [
            models.Index(fields=["notify_on_new"], name="saved_filter_notify_idx"),
        ]

    def __str__(self) -> str:
        return self.name

    @property
    def notify_since(self):
        """С какого момента считать объявления новыми."""
        return self.last_notified_at or self.created_at


class CollectionMode(models.TextChoices):
    QUERY = "query", "По фильтру"
    MANUAL = "manual", "Ручной список"


class Collection(TimeStampedModel):
    """Редакционная подборка для экрана «Подборки»."""

    title = models.CharField("Заголовок", max_length=150)
    subtitle = models.CharField("Подзаголовок", max_length=200, blank=True)
    slug = models.SlugField("Слаг", max_length=160, unique=True)
    cover = models.ImageField("Обложка", upload_to="collections/%Y/%m/", blank=True, null=True)
    description = models.TextField("Описание", blank=True)

    mode = models.CharField(
        "Режим",
        max_length=16,
        choices=CollectionMode.choices,
        default=CollectionMode.QUERY,
    )
    params = models.JSONField(
        "Параметры фильтра",
        default=dict,
        blank=True,
        help_text="Для режима «По фильтру».",
    )
    listings = models.ManyToManyField(
        "catalog.Listing",
        verbose_name="Объявления",
        through="engagement.CollectionItem",
        related_name="collections",
        blank=True,
    )

    is_active = models.BooleanField("Активна", default=True)
    order = models.PositiveSmallIntegerField("Порядок", default=0, db_index=True)

    class Meta:
        verbose_name = "Подборка"
        verbose_name_plural = "Подборки"
        ordering = ["order", "-created_at"]

    def __str__(self) -> str:
        return self.title

    @property
    def is_manual(self) -> bool:
        return self.mode == CollectionMode.MANUAL


class CollectionItem(models.Model):
    """Позиция ручной подборки — порядок задаёт редактор."""

    collection = models.ForeignKey(
        Collection,
        verbose_name="Подборка",
        on_delete=models.CASCADE,
        related_name="items",
    )
    listing = models.ForeignKey(
        "catalog.Listing",
        verbose_name="Объявление",
        on_delete=models.CASCADE,
        related_name="collection_items",
    )
    order = models.PositiveSmallIntegerField("Порядок", default=0)

    class Meta:
        verbose_name = "Объект подборки"
        verbose_name_plural = "Объекты подборки"
        ordering = ["order", "id"]
        constraints = [
            models.UniqueConstraint(
                fields=["collection", "listing"], name="collection_item_unique"
            ),
        ]

    def __str__(self) -> str:
        return f"{self.collection.slug} #{self.order}"
