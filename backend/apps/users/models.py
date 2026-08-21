"""Пользователь: вход по телефону, флаг pro, ИИН как персональные данные."""

from typing import Any

from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.models import PermissionsMixin
from django.db import models
from django.utils import timezone

from apps.catalog.enums import SellerKind
from apps.common.models import TimeStampedModel
from apps.common.storages import private_storage
from apps.users.phone import is_deleted_phone, normalize_phone
from apps.users.validators import validate_iin

# Сколько первых символов ИИН остаётся видимым: «12345678******».
IIN_VISIBLE_CHARS = 8


def mask_iin(value: str) -> str:
    """«20101199001234» -> «20101199******». Пустое значение остаётся пустым."""
    if not value:
        return ""
    return value[:IIN_VISIBLE_CHARS] + "*" * max(0, len(value) - IIN_VISIBLE_CHARS)


class UserManager(BaseUserManager):
    """Менеджер пользователей: вместо username — телефон."""

    use_in_migrations = True

    def create_user(self, phone: str, password: str | None = None, **extra_fields: Any):
        user = self.model(phone=phone, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, phone: str, password: str | None = None, **extra_fields: Any):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)
        if not extra_fields["is_staff"] or not extra_fields["is_superuser"]:
            raise ValueError("Суперпользователь должен иметь is_staff и is_superuser.")
        return self.create_user(phone, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    """Аккаунт приложения. Один и тот же аккаунт может быть клиентом и pro."""

    phone = models.CharField(
        "Телефон",
        max_length=16,
        unique=True,
        help_text="Хранится в E.164, например +996700123456.",
    )
    name = models.CharField("Имя", max_length=120, blank=True)
    is_pro = models.BooleanField("Исполнитель (pro)", default=False)
    # Чем именно является pro — риелтором или агентством. У клиента не заполнено.
    seller_kind = models.CharField(
        "Тип продавца",
        max_length=16,
        choices=SellerKind.choices,
        blank=True,
    )
    # Персональные данные: наружу отдаётся маскированным, в логи не попадает.
    iin = models.CharField(
        "ИИН",
        max_length=14,
        blank=True,
        validators=[validate_iin],
        help_text="Заполняется только при pro-регистрации, 14 цифр.",
    )
    # null=True — по требованию ТЗ поле nullable; DJ001 отключён осознанно.
    whatsapp_phone = models.CharField(  # noqa: DJ001
        "WhatsApp",
        max_length=16,
        blank=True,
        null=True,
        help_text="Номер для связи в WhatsApp, E.164.",
    )
    avatar = models.ImageField("Аватар", upload_to="avatars/%Y/%m/", blank=True, null=True)

    is_active = models.BooleanField("Активен", default=True)
    is_staff = models.BooleanField("Доступ в админку", default=False)
    date_joined = models.DateTimeField("Дата регистрации", default=timezone.now)
    updated_at = models.DateTimeField("Обновлён", auto_now=True)

    objects = UserManager()

    USERNAME_FIELD = "phone"
    REQUIRED_FIELDS: list[str] = []

    class Meta:
        verbose_name = "Пользователь"
        verbose_name_plural = "Пользователи"
        ordering = ["-date_joined"]
        constraints = [
            # ИИН уникален, но пустое значение — у большинства аккаунтов.
            models.UniqueConstraint(
                fields=["iin"],
                condition=~models.Q(iin=""),
                name="user_iin_unique",
            ),
        ]

    def __str__(self) -> str:
        # ИИН здесь не место: __str__ уходит в админку и в логи.
        return f"{self.name or 'Без имени'} ({self.phone})"

    def clean(self) -> None:
        super().clean()
        self.phone = self._normalized_phone()

    def save(self, *args: Any, **kwargs: Any) -> None:
        self.phone = self._normalized_phone()
        super().save(*args, **kwargs)

    def _normalized_phone(self) -> str:
        """Анонимизированный аккаунт остаётся с техническим «номером»."""
        if is_deleted_phone(self.phone):
            return self.phone
        return normalize_phone(self.phone)

    def get_short_name(self) -> str:
        return self.name or self.phone

    @property
    def masked_iin(self) -> str:
        return mask_iin(self.iin)

    @property
    def is_anonymized(self) -> bool:
        return is_deleted_phone(self.phone)


class OtpPurpose(models.TextChoices):
    """Зачем запрашивается код."""

    LOGIN = "login", "Вход"
    PRO_REGISTER = "pro_register", "Регистрация исполнителя"


class OtpCode(models.Model):
    """Одноразовый код подтверждения.

    В базе лежит только хеш кода — открытый код существует ровно столько,
    сколько нужно, чтобы отдать его SMS-провайдеру.
    """

    phone = models.CharField("Телефон", max_length=16, db_index=True)
    code_hash = models.CharField("Хеш кода", max_length=128)
    purpose = models.CharField(
        "Назначение",
        max_length=16,
        choices=OtpPurpose.choices,
        default=OtpPurpose.LOGIN,
    )
    attempts = models.PositiveSmallIntegerField("Неудачных попыток", default=0)
    is_used = models.BooleanField("Использован", default=False)
    created_at = models.DateTimeField("Создан", auto_now_add=True)
    expires_at = models.DateTimeField("Действует до")

    class Meta:
        verbose_name = "Код подтверждения"
        verbose_name_plural = "Коды подтверждения"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["phone", "purpose", "-created_at"], name="otp_lookup_idx"),
        ]

    def __str__(self) -> str:
        # Ни кода, ни его хеша здесь быть не должно.
        return f"OTP {self.get_purpose_display()} для {self.phone}"

    @property
    def is_expired(self) -> bool:
        return timezone.now() >= self.expires_at


class SellerProfile(TimeStampedModel):
    """Публичный профиль продавца — агента или агентства."""

    user = models.OneToOneField(
        "users.User",
        verbose_name="Пользователь",
        on_delete=models.CASCADE,
        related_name="seller_profile",
    )
    company_name = models.CharField("Название компании", max_length=150, blank=True)
    logo = models.ImageField("Логотип", upload_to="sellers/%Y/%m/", blank=True, null=True)
    about = models.TextField("О себе", blank=True)
    rating = models.DecimalField("Рейтинг", max_digits=3, decimal_places=2, default=0)
    reviews_count = models.PositiveIntegerField("Отзывов", default=0)
    is_verified = models.BooleanField("Личность подтверждена", default=False)
    verified_at = models.DateTimeField("Подтверждено", blank=True, null=True)

    class Meta:
        verbose_name = "Профиль продавца"
        verbose_name_plural = "Профили продавцов"
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return self.company_name or str(self.user)


class DocumentType(models.TextChoices):
    PASSPORT = "passport", "Паспорт"
    ID_CARD = "id_card", "ID-карта"


class VerificationStatus(models.TextChoices):
    PENDING = "pending", "На проверке"
    APPROVED = "approved", "Подтверждена"
    REJECTED = "rejected", "Отклонена"
    EXPIRED = "expired", "Истекла"


class IdentityVerification(TimeStampedModel):
    """Заявка на подтверждение личности исполнителя.

    Самые чувствительные данные системы: селфи и фото документа. Файлы лежат
    в отдельном приватном хранилище, отдаются только по подписанной ссылке
    с коротким TTL, каждая выдача пишется в журнал аудита, а через
    KYC_PURGE_AFTER_DAYS после решения файлы удаляются — остаётся только факт
    проверки.
    """

    user = models.ForeignKey(
        "users.User",
        verbose_name="Пользователь",
        on_delete=models.CASCADE,
        related_name="identity_verifications",
    )
    selfie = models.FileField(
        "Селфи",
        storage=private_storage,
        upload_to="kyc/%Y/%m/",
    )
    document_front = models.FileField(  # noqa: DJ001 - null=True по требованию ТЗ
        "Документ, лицевая сторона",
        storage=private_storage,
        upload_to="kyc/%Y/%m/",
        blank=True,
        null=True,
    )
    document_back = models.FileField(  # noqa: DJ001 - null=True по требованию ТЗ
        "Документ, оборот",
        storage=private_storage,
        upload_to="kyc/%Y/%m/",
        blank=True,
        null=True,
    )
    document_type = models.CharField(
        "Тип документа",
        max_length=16,
        choices=DocumentType.choices,
        default=DocumentType.PASSPORT,
    )
    status = models.CharField(
        "Статус",
        max_length=16,
        choices=VerificationStatus.choices,
        default=VerificationStatus.PENDING,
    )
    reject_reason = models.CharField("Причина отказа", max_length=255, blank=True)
    comment = models.TextField("Комментарий модератора", blank=True)
    reviewed_by = models.ForeignKey(
        "users.User",
        verbose_name="Проверил",
        on_delete=models.SET_NULL,
        related_name="reviewed_verifications",
        blank=True,
        null=True,
    )
    reviewed_at = models.DateTimeField("Проверено", blank=True, null=True)
    purge_after = models.DateTimeField("Удалить файлы после", blank=True, null=True)

    class Meta:
        verbose_name = "Проверка личности"
        verbose_name_plural = "Проверки личности"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "-created_at"], name="kyc_user_recent_idx"),
            models.Index(fields=["status", "created_at"], name="kyc_status_created_idx"),
        ]
        permissions = [
            ("can_review_identity", "Может проверять документы пользователей"),
        ]

    def __str__(self) -> str:
        # Никаких имён файлов: строка попадает в админку и в логи.
        return f"Проверка личности #{self.pk} · {self.get_status_display()}"

    # Поля с файлами — перечислены в одном месте, чтобы обход был единообразным.
    FILE_FIELDS = ("selfie", "document_front", "document_back")

    def files(self) -> list[tuple[str, models.FileField]]:
        """Пары (имя поля, файл) для непустых файлов заявки."""
        return [(name, getattr(self, name)) for name in self.FILE_FIELDS if getattr(self, name)]

    @property
    def is_pending(self) -> bool:
        return self.status == VerificationStatus.PENDING

    @property
    def can_resubmit(self) -> bool:
        """Подать заново можно, пока заявка не на проверке и не одобрена."""
        return self.status in (VerificationStatus.REJECTED, VerificationStatus.EXPIRED)
