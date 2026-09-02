"""Пользователь: вход по телефону, флаг pro, ИИН как персональные данные."""

from typing import Any

from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.models import PermissionsMixin
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils import timezone

from apps.catalog.enums import SellerKind
from apps.common.fields import EncryptedCharField
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
    # Персональные данные: в БД хранится зашифрованным, наружу отдаётся
    # маскированным, в логи не попадает вовсе. По ИИН нельзя искать —
    # это осознанная плата за шифрование, искать людей по нему и не нужно.
    iin = EncryptedCharField(
        "ИИН",
        max_length=255,
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
    is_trusted = models.BooleanField(
        "Доверенный",
        default=False,
        help_text="Объявления публикуются сразу, минуя модерацию.",
    )
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
    REGISTER = "register", "Регистрация"
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
    experience_years = models.PositiveSmallIntegerField("Опыт, лет", default=0)
    work_districts = models.ManyToManyField(
        "catalog.District",
        verbose_name="Районы работы",
        related_name="sellers",
        blank=True,
    )

    whatsapp = models.CharField("WhatsApp", max_length=32, blank=True)
    telegram = models.CharField("Telegram", max_length=64, blank=True)
    instagram = models.CharField("Instagram", max_length=64, blank=True)
    # {"mon": ["09:00", "18:00"], ...}; пустой список — выходной.
    working_hours = models.JSONField("Часы работы", default=dict, blank=True)

    # Денормализация: агрегат по опубликованным отзывам. Меняется только
    # через recalc_seller_rating, чтобы карточка продавца не считала Avg
    # на каждый показ.
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


class ReviewStatus(models.TextChoices):
    """Состояние отзыва."""

    PENDING = "pending", "На модерации"
    PUBLISHED = "published", "Опубликован"
    REJECTED = "rejected", "Отклонён"


class Review(TimeStampedModel):
    """Отзыв о продавце.

    В публичную выдачу и в рейтинг попадают только опубликованные: отзыв —
    это текст от постороннего человека на чужой странице, он проходит
    модерацию.
    """

    seller = models.ForeignKey(
        "users.User",
        verbose_name="Продавец",
        on_delete=models.CASCADE,
        related_name="reviews_received",
    )
    author = models.ForeignKey(
        "users.User",
        verbose_name="Автор",
        on_delete=models.CASCADE,
        related_name="reviews_written",
    )
    listing = models.ForeignKey(
        "catalog.Listing",
        verbose_name="Объявление",
        # Объявление могут снять, а отзыв о продавце остаётся.
        on_delete=models.SET_NULL,
        related_name="reviews",
        blank=True,
        null=True,
    )
    rating = models.PositiveSmallIntegerField(
        "Оценка",
        validators=[MinValueValidator(1), MaxValueValidator(5)],
    )
    text = models.TextField("Текст", blank=True)
    status = models.CharField(
        "Статус",
        max_length=16,
        choices=ReviewStatus.choices,
        default=ReviewStatus.PENDING,
        db_index=True,
    )
    moderator_comment = models.TextField("Комментарий модератора", blank=True)

    class Meta:
        verbose_name = "Отзыв"
        verbose_name_plural = "Отзывы"
        ordering = ["-created_at"]
        constraints = [
            # Один отзыв на продавца от пользователя: иначе рейтинг
            # накручивается одним человеком.
            models.UniqueConstraint(
                fields=["seller", "author"],
                name="review_unique_author_per_seller",
            ),
            models.CheckConstraint(
                condition=models.Q(rating__gte=1) & models.Q(rating__lte=5),
                name="review_rating_range",
            ),
        ]
        indexes = [
            models.Index(fields=["seller", "status", "-created_at"], name="review_seller_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.rating}★ о {self.seller_id} от {self.author_id}"

    @property
    def is_published(self) -> bool:
        return self.status == ReviewStatus.PUBLISHED


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


class SellerVerification(TimeStampedModel):
    """Заявка на подтверждение агентства.

    Это не KYC: здесь документы юрлица (свидетельство, лицензия), а не
    паспорт. Они не так чувствительны, поэтому лежат в обычном хранилище,
    но всё равно видны только модератору.
    """

    seller = models.ForeignKey(
        "users.User",
        verbose_name="Продавец",
        on_delete=models.CASCADE,
        related_name="seller_verifications",
    )
    # Список путей загруженных файлов: [{"name": ..., "url": ...}, ...]
    documents = models.JSONField("Документы", default=list, blank=True)
    status = models.CharField(
        "Статус",
        max_length=16,
        choices=VerificationStatus.choices,
        default=VerificationStatus.PENDING,
        db_index=True,
    )
    comment = models.TextField("Комментарий", blank=True)
    reviewed_by = models.ForeignKey(
        "users.User",
        verbose_name="Кто проверил",
        on_delete=models.SET_NULL,
        related_name="seller_verifications_reviewed",
        blank=True,
        null=True,
    )
    reviewed_at = models.DateTimeField("Когда проверено", blank=True, null=True)

    class Meta:
        verbose_name = "Заявка на подтверждение продавца"
        verbose_name_plural = "Заявки на подтверждение продавцов"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status", "-created_at"], name="seller_verif_status_idx"),
        ]

    def __str__(self) -> str:
        return f"Проверка продавца {self.seller_id} ({self.get_status_display()})"


class ContactEvent(models.Model):
    """Раскрытие телефона продавца — след для антифрода.

    Массовый обход каталога с выгрузкой номеров выглядит именно так: один
    пользователь, десятки объявлений, минуты между событиями.
    """

    listing = models.ForeignKey(
        "catalog.Listing",
        verbose_name="Объявление",
        on_delete=models.CASCADE,
        related_name="contact_events",
    )
    user = models.ForeignKey(
        "users.User",
        verbose_name="Кто смотрел",
        on_delete=models.CASCADE,
        related_name="contact_events",
    )
    ip_address = models.GenericIPAddressField("IP", blank=True, null=True)
    created_at = models.DateTimeField("Когда", auto_now_add=True, db_index=True)

    class Meta:
        verbose_name = "Раскрытие контакта"
        verbose_name_plural = "Раскрытия контактов"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "-created_at"], name="contact_user_recent_idx"),
            models.Index(fields=["listing", "-created_at"], name="contact_listing_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.user_id} -> {self.listing_id}"


class ConsentType(models.TextChoices):
    """На что даётся согласие."""

    PERSONAL_DATA = "personal_data", "Обработка персональных данных"
    MARKETING = "marketing", "Рекламные рассылки"
    COOKIES = "cookies", "Аналитика и cookies"


class UserConsent(models.Model):
    """Согласие пользователя, привязанное к версии документа.

    Хранится историей, а не флагом: закон требует уметь показать, **какую
    именно** редакцию документа человек принял, когда и с какого адреса.
    Новая версия соглашения — новая запись, старая остаётся.
    """

    user = models.ForeignKey(
        "users.User",
        verbose_name="Пользователь",
        on_delete=models.CASCADE,
        related_name="consents",
    )
    consent_type = models.CharField(
        "Тип согласия",
        max_length=32,
        choices=ConsentType.choices,
        default=ConsentType.PERSONAL_DATA,
    )
    document_version = models.CharField("Версия документа", max_length=32)
    granted = models.BooleanField("Дано", default=True)
    ip_address = models.GenericIPAddressField("IP", blank=True, null=True)
    user_agent = models.CharField("User-Agent", max_length=256, blank=True)
    created_at = models.DateTimeField("Когда", auto_now_add=True, db_index=True)

    class Meta:
        verbose_name = "Согласие пользователя"
        verbose_name_plural = "Согласия пользователей"
        ordering = ["-created_at"]
        indexes = [
            models.Index(
                fields=["user", "consent_type", "-created_at"],
                name="consent_user_type_idx",
            ),
        ]

    def __str__(self) -> str:
        state = "дано" if self.granted else "отозвано"
        return f"{self.get_consent_type_display()} v{self.document_version}: {state}"


class DataExportStatus(models.TextChoices):
    PENDING = "pending", "Готовится"
    READY = "ready", "Готово"
    FAILED = "failed", "Ошибка"
    EXPIRED = "expired", "Ссылка истекла"


class DataExport(models.Model):
    """Выгрузка персональных данных по запросу пользователя.

    Файл лежит в приватном хранилище и отдаётся только по подписанной
    ссылке с коротким сроком жизни: выгрузка — это всё, что мы знаем о
    человеке, одним файлом.
    """

    user = models.ForeignKey(
        "users.User",
        verbose_name="Пользователь",
        on_delete=models.CASCADE,
        related_name="data_exports",
    )
    status = models.CharField(
        "Статус",
        max_length=16,
        choices=DataExportStatus.choices,
        default=DataExportStatus.PENDING,
        db_index=True,
    )
    file = models.FileField(
        "Файл",
        storage=private_storage,
        upload_to="exports/%Y/%m/",
        blank=True,
        null=True,
    )
    size_bytes = models.PositiveBigIntegerField("Размер", blank=True, null=True)
    error = models.CharField("Ошибка", max_length=255, blank=True)
    expires_at = models.DateTimeField("Ссылка истекает", blank=True, null=True)
    created_at = models.DateTimeField("Создана", auto_now_add=True, db_index=True)
    completed_at = models.DateTimeField("Готова", blank=True, null=True)

    class Meta:
        verbose_name = "Выгрузка данных"
        verbose_name_plural = "Выгрузки данных"
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return f"Выгрузка {self.user_id} ({self.get_status_display()})"

    @property
    def is_ready(self) -> bool:
        return self.status == DataExportStatus.READY and bool(self.file)
