"""Модели общего назначения.

Здесь живут абстрактные базовые модели проекта и «инфраструктурные» модели,
которые не относятся ни к одному домену: конфигурация мобильного клиента,
онбординг, статические страницы и обращения в поддержку.
"""

import uuid
from typing import Any

from django.conf import settings
from django.db import models


def default_feature_flags() -> dict[str, bool]:
    """Фича-флаги по умолчанию (значения на функциях — чтобы миграции сериализовались)."""
    return {"mortgage_calculator": False, "natural_search": False}


def default_constants() -> dict[str, float | int]:
    """Константы, которые клиент читает из конфига, а не хардкодит."""
    return {
        "topup_bonus_rate": 0.1,
        "promotion_price_per_day": 780,
        "max_photos": 20,
        "max_videos": 20,
        "free_active_listings": 3,
    }


class TimeStampedModel(models.Model):
    """Добавляет отметки о создании и изменении записи."""

    created_at = models.DateTimeField("Создано", auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField("Обновлено", auto_now=True)

    class Meta:
        abstract = True
        ordering = ["-created_at"]


class UUIDModel(models.Model):
    """Первичный ключ — UUID4 вместо автоинкремента."""

    id = models.UUIDField(
        "Идентификатор",
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
    )

    class Meta:
        abstract = True


class AppConfig(TimeStampedModel):
    """Конфигурация мобильного клиента — singleton, всегда одна строка (pk=1).

    Всё, что должно меняться без релиза приложения: версии, режим обслуживания,
    фича-флаги и числовые константы (бонус за пополнение, цена продвижения,
    лимиты медиа). Клиент читает значения отсюда и не хардкодит их у себя.
    """

    SINGLETON_ID = 1

    min_supported_version = models.CharField(
        "Минимальная поддерживаемая версия",
        max_length=32,
        default="1.0.0",
        help_text="Клиент с версией ниже получает force_update.",
    )
    recommended_version = models.CharField(
        "Рекомендуемая версия",
        max_length=32,
        default="1.0.0",
    )
    android_store_url = models.URLField("Ссылка на Google Play", blank=True)
    ios_store_url = models.URLField("Ссылка на App Store", blank=True)

    maintenance_mode = models.BooleanField("Режим обслуживания", default=False)
    maintenance_message = models.TextField(
        "Текст режима обслуживания",
        blank=True,
        help_text="Показывается на сплэше, пока включён режим обслуживания.",
    )

    feature_flags = models.JSONField(
        "Фича-флаги",
        default=default_feature_flags,
        blank=True,
        help_text='Например: {"mortgage_calculator": true}',
    )
    constants = models.JSONField(
        "Константы",
        default=default_constants,
        blank=True,
        help_text=(
            "topup_bonus_rate, promotion_price_per_day, max_photos, "
            "max_videos, free_active_listings"
        ),
    )

    class Meta:
        verbose_name = "Конфигурация приложения"
        verbose_name_plural = "Конфигурация приложения"

    def __str__(self) -> str:
        return f"Конфигурация приложения (мин. {self.min_supported_version})"

    def save(self, *args: Any, **kwargs: Any) -> None:
        """Строка всегда одна: любой save пишет в pk=1."""
        self.pk = self.SINGLETON_ID
        super().save(*args, **kwargs)

    @classmethod
    def get_solo(cls) -> "AppConfig":
        """Возвращает единственную строку, создавая её при первом обращении."""
        config, _ = cls.objects.get_or_create(pk=cls.SINGLETON_ID)
        return config

    def store_url(self, platform: str) -> str:
        return {
            "android": self.android_store_url,
            "ios": self.ios_store_url,
        }.get(platform, "")


class OnboardingSlide(TimeStampedModel):
    """Слайд онбординга — экраны onboarding_1..3 во Flutter."""

    title = models.CharField("Заголовок", max_length=150)
    text = models.TextField("Текст", blank=True)
    image = models.ImageField("Изображение", upload_to="onboarding/", blank=True, null=True)
    order = models.PositiveSmallIntegerField("Порядок", default=0, db_index=True)
    is_active = models.BooleanField("Показывать", default=True)

    class Meta:
        verbose_name = "Слайд онбординга"
        verbose_name_plural = "Слайды онбординга"
        ordering = ["order", "id"]

    def __str__(self) -> str:
        return f"{self.order}. {self.title}"


class StaticPage(TimeStampedModel):
    """Статическая страница: соглашение, политика ПДн, «О приложении», FAQ, поддержка.

    `version` меняется вручную при правке текста соглашений: на неё ссылается
    модель согласий пользователя — новая версия требует нового согласия.
    """

    class Slug(models.TextChoices):
        TERMS = "terms", "Пользовательское соглашение"
        PRIVACY = "privacy", "Политика конфиденциальности"
        ABOUT = "about", "О приложении"
        FAQ = "faq", "Частые вопросы"
        SUPPORT = "support", "Поддержка"

    slug = models.SlugField("Слаг", max_length=32, unique=True, choices=Slug.choices)
    title = models.CharField("Заголовок", max_length=200)
    content = models.TextField("Текст (markdown)", blank=True)
    version = models.CharField(
        "Версия",
        max_length=32,
        default="1",
        help_text=(
            "Увеличивайте при изменении текста соглашений — у пользователей "
            "будет запрошено новое согласие."
        ),
    )
    is_active = models.BooleanField("Опубликована", default=True)

    class Meta:
        verbose_name = "Статическая страница"
        verbose_name_plural = "Статические страницы"
        ordering = ["slug"]

    def __str__(self) -> str:
        return f"{self.title} (v{self.version})"


class SupportTicket(TimeStampedModel):
    """Обращение в поддержку из приложения."""

    class Status(models.TextChoices):
        NEW = "new", "Новое"
        IN_PROGRESS = "in_progress", "В работе"
        CLOSED = "closed", "Закрыто"

    class Platform(models.TextChoices):
        ANDROID = "android", "Android"
        IOS = "ios", "iOS"
        WEB = "web", "Web"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="Пользователь",
        on_delete=models.SET_NULL,
        related_name="support_tickets",
        blank=True,
        null=True,
    )
    subject = models.CharField("Тема", max_length=200)
    message = models.TextField("Сообщение")
    contact_phone = models.CharField("Телефон для связи", max_length=16, blank=True)
    app_version = models.CharField("Версия приложения", max_length=32, blank=True)
    platform = models.CharField("Платформа", max_length=16, choices=Platform.choices, blank=True)
    status = models.CharField("Статус", max_length=16, choices=Status.choices, default=Status.NEW)

    class Meta:
        verbose_name = "Обращение в поддержку"
        verbose_name_plural = "Обращения в поддержку"
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return f"#{self.pk} {self.subject}"


class AuditLog(models.Model):
    """Журнал доступа к чувствительным данным.

    Пишется, например, при каждой выдаче подписанной ссылки на документ KYC.
    Ни имён файлов, ни ссылок здесь нет — только кто, к чьим данным и когда
    обращался.
    """

    class Action(models.TextChoices):
        KYC_URL_ISSUED = "kyc.url_issued", "Выдана ссылка на документ"
        KYC_FILE_DOWNLOADED = "kyc.file_downloaded", "Документ скачан"
        KYC_REVIEWED = "kyc.reviewed", "Решение по заявке"

    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="Кто",
        on_delete=models.SET_NULL,
        related_name="audit_actions",
        blank=True,
        null=True,
    )
    target_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="Чьи данные",
        on_delete=models.SET_NULL,
        related_name="audit_records",
        blank=True,
        null=True,
    )
    action = models.CharField("Действие", max_length=64, choices=Action.choices, db_index=True)
    object_type = models.CharField("Тип объекта", max_length=64, blank=True)
    object_id = models.CharField("ID объекта", max_length=64, blank=True)
    ip_address = models.GenericIPAddressField("IP", blank=True, null=True)
    user_agent = models.CharField("User-Agent", max_length=256, blank=True)
    # Только безопасные подробности: имя поля, причина отказа и т.п.
    extra = models.JSONField("Подробности", default=dict, blank=True)
    created_at = models.DateTimeField("Когда", auto_now_add=True, db_index=True)

    class Meta:
        verbose_name = "Запись аудита"
        verbose_name_plural = "Журнал аудита"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["action", "-created_at"], name="audit_action_recent_idx"),
            models.Index(fields=["target_user", "-created_at"], name="audit_target_recent_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.get_action_display()} · {self.created_at:%d.%m.%Y %H:%M}"
