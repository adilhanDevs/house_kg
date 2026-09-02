"""Уведомления пользователя.

Эндпоинты ленты уведомлений и push — фаза 4 ТЗ; здесь модель, которую уже
пишут другие части системы: результат проверки документов и совпадения по
сохранённым фильтрам.
"""

from django.conf import settings
from django.db import models
from django.utils import timezone

from apps.common.models import TimeStampedModel


class NotificationType(models.TextChoices):
    NEW_MESSAGE = "new_message", "Новое сообщение"
    PRICE_DROP = "price_drop", "Снижение цены"
    SAVED_FILTER_MATCH = "saved_filter_match", "Новые объекты по фильтру"
    LISTING_MODERATED = "listing_moderated", "Модерация объявления"
    PROMOTION_EXPIRING = "promotion_expiring", "Продвижение заканчивается"
    WALLET_TOPUP = "wallet_topup", "Пополнение кошелька"
    SYSTEM = "system", "Системное"


class DevicePlatform(models.TextChoices):
    ANDROID = "android", "Android"
    IOS = "ios", "iOS"


class Notification(TimeStampedModel):
    """Одно уведомление в ленте пользователя."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="Пользователь",
        on_delete=models.CASCADE,
        related_name="notifications",
    )
    type = models.CharField(
        "Тип",
        max_length=32,
        choices=NotificationType.choices,
        default=NotificationType.SYSTEM,
        db_index=True,
    )
    title = models.CharField("Заголовок", max_length=140)
    body = models.TextField("Текст", blank=True)
    payload = models.JSONField("Данные", default=dict, blank=True)
    listing = models.ForeignKey(
        "catalog.Listing",
        verbose_name="Объявление",
        on_delete=models.SET_NULL,
        related_name="notifications",
        blank=True,
        null=True,
    )
    is_read = models.BooleanField("Прочитано", default=False, db_index=True)

    class Meta:
        verbose_name = "Уведомление"
        verbose_name_plural = "Уведомления"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "-created_at"], name="notification_user_recent_idx"),
            models.Index(
                fields=["user", "is_read", "-created_at"],
                name="notification_user_unread_idx",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.get_type_display()}: {self.title}"


class DeviceToken(TimeStampedModel):
    """Push-токен устройства.

    Токен принадлежит устройству, а не аккаунту: на одном телефоне может
    смениться пользователь, и тогда токен переезжает к новому владельцу.
    """

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="Пользователь",
        on_delete=models.CASCADE,
        related_name="devices",
    )
    token = models.CharField("Токен", max_length=255, unique=True)
    platform = models.CharField("Платформа", max_length=16, choices=DevicePlatform.choices)
    app_version = models.CharField("Версия приложения", max_length=32, blank=True)
    is_active = models.BooleanField("Активен", default=True, db_index=True)
    last_seen_at = models.DateTimeField("Последняя активность", default=timezone.now)

    class Meta:
        verbose_name = "Устройство"
        verbose_name_plural = "Устройства"
        ordering = ["-last_seen_at"]
        indexes = [
            models.Index(fields=["user", "is_active"], name="device_user_active_idx"),
        ]

    def __str__(self) -> str:
        # Токен целиком в строку не выводим: он попадает в админку и логи.
        return f"{self.get_platform_display()} · …{self.token[-6:]}"


class NotificationSettings(models.Model):
    """Что пользователь готов получать пушем.

    Создаётся сигналом при регистрации: настройки должны быть у всех, иначе
    отправка вынуждена была бы каждый раз проверять их существование.
    """

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        verbose_name="Пользователь",
        on_delete=models.CASCADE,
        related_name="notification_settings",
    )
    push_enabled = models.BooleanField("Push-уведомления", default=True)

    new_message_enabled = models.BooleanField("Новые сообщения", default=True)
    price_drop_enabled = models.BooleanField("Снижение цены", default=True)
    saved_filter_enabled = models.BooleanField("Новые объекты по фильтру", default=True)
    listing_moderated_enabled = models.BooleanField("Модерация объявлений", default=True)
    promotion_expiring_enabled = models.BooleanField("Продвижение заканчивается", default=True)
    wallet_topup_enabled = models.BooleanField("Пополнение кошелька", default=True)
    system_enabled = models.BooleanField("Системные", default=True)

    class Meta:
        verbose_name = "Настройки уведомлений"
        verbose_name_plural = "Настройки уведомлений"

    def __str__(self) -> str:
        return f"Настройки уведомлений {self.user}"

    # Тип уведомления -> поле с флагом.
    TYPE_FIELDS = {
        NotificationType.NEW_MESSAGE: "new_message_enabled",
        NotificationType.PRICE_DROP: "price_drop_enabled",
        NotificationType.SAVED_FILTER_MATCH: "saved_filter_enabled",
        NotificationType.LISTING_MODERATED: "listing_moderated_enabled",
        NotificationType.PROMOTION_EXPIRING: "promotion_expiring_enabled",
        NotificationType.WALLET_TOPUP: "wallet_topup_enabled",
        NotificationType.SYSTEM: "system_enabled",
    }

    def allows(self, notification_type: str) -> bool:
        """Разрешён ли push этого типа."""
        if not self.push_enabled:
            return False
        field = self.TYPE_FIELDS.get(notification_type)
        return bool(getattr(self, field, True)) if field else True
