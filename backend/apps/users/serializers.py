"""Сериализаторы профиля пользователя и публичного профиля продавца."""

import logging
import re
from typing import Any

from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.catalog.models import District
from apps.catalog.serializers import DistrictBriefSerializer
from apps.users.kyc import validate_document
from apps.users.models import (
    ConsentType,
    DataExport,
    IdentityVerification,
    OtpPurpose,
    Review,
    SellerProfile,
    SellerVerification,
    User,
    UserConsent,
    mask_iin,
)
from apps.users.phone import normalize_phone
from apps.users.services import REVIEW_APPROVE, REVIEW_REJECT, build_signed_files
from apps.users.validators import validate_iin

logger = logging.getLogger(__name__)

BRICK_CURRENCY = "brick"

# Время в часах работы: «09:00», «18:30».
TIME_RE = re.compile(r"^([01]\d|2[0-3]):[0-5]\d$")


class WalletBalanceSerializer(serializers.Serializer):
    """Баланс во внутренней валюте («кирпичи»)."""

    balance = serializers.IntegerField()
    currency = serializers.CharField()


class UserMeSerializer(serializers.ModelSerializer):
    """Профиль пользователя (чтение)."""

    iin = serializers.SerializerMethodField()
    avatar_url = serializers.SerializerMethodField()
    cover_url = serializers.SerializerMethodField()
    profile_cover_url = serializers.SerializerMethodField()
    wallet_balance = serializers.SerializerMethodField()
    is_pro = serializers.SerializerMethodField()
    has_seller_profile = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "phone",
            "name",
            "is_pro",
            "has_seller_profile",
            "seller_kind",
            "iin",
            "whatsapp_phone",
            "avatar_url",
            "cover_url",
            "profile_cover_url",
            "date_joined",
            "wallet_balance",
        ]
        read_only_fields = fields

    @extend_schema_field(serializers.BooleanField())
    def get_is_pro(self, obj: User) -> bool:
        return bool(obj.is_pro or hasattr(obj, "seller_profile"))

    @extend_schema_field(serializers.BooleanField())
    def get_has_seller_profile(self, obj: User) -> bool:
        return hasattr(obj, "seller_profile")

    @extend_schema_field(serializers.CharField(allow_blank=True))
    def get_iin(self, obj: User) -> str:
        """Полный ИИН видят только сам владелец и staff, остальные — маску."""
        viewer = getattr(self.context.get("request"), "user", None)
        if viewer and viewer.is_authenticated and (viewer.pk == obj.pk or viewer.is_staff):
            return obj.iin
        return mask_iin(obj.iin)

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_avatar_url(self, obj: User) -> str | None:
        if not obj.avatar:
            return None
        request = self.context.get("request")
        url = obj.avatar.url
        return request.build_absolute_uri(url) if request else url

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_cover_url(self, obj: User) -> str | None:
        if not obj.profile_cover:
            return None
        request = self.context.get("request")
        url = obj.profile_cover.url
        return request.build_absolute_uri(url) if request else url

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_profile_cover_url(self, obj: User) -> str | None:
        return self.get_cover_url(obj)

    @extend_schema_field(WalletBalanceSerializer)
    def get_wallet_balance(self, obj: User) -> dict[str, Any]:
        wallet = getattr(obj, "wallet", None)
        return {
            "balance": wallet.balance if wallet else 0,
            "currency": BRICK_CURRENCY,
        }


class UserUpdateSerializer(serializers.ModelSerializer):
    """Изменение профиля: доступны имя, аватар, обложка и WhatsApp.

    Остальные поля объявлены read-only — попытка их передать молча игнорируется,
    а не возвращает 400.
    """

    avatar = serializers.ImageField(required=False, allow_null=True)
    profile_cover = serializers.ImageField(required=False, allow_null=True)
    cover = serializers.ImageField(source="profile_cover", required=False, allow_null=True)
    delete_avatar = serializers.BooleanField(required=False, write_only=True)
    delete_cover = serializers.BooleanField(required=False, write_only=True)
    whatsapp_phone = serializers.CharField(required=False, allow_blank=True, allow_null=True)

    class Meta:
        model = User
        fields = [
            "name",
            "avatar",
            "profile_cover",
            "cover",
            "delete_avatar",
            "delete_cover",
            "whatsapp_phone",
            "phone",
            "is_pro",
            "iin",
            "is_staff",
        ]
        read_only_fields = ["phone", "is_pro", "iin", "is_staff"]

    def validate_whatsapp_phone(self, value: str | None) -> str | None:
        if not value:
            return None
        value = value.strip()
        if not value:
            return None
        try:
            return normalize_phone(value)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(list(exc.messages)) from exc

    def update(self, instance: User, validated_data: dict[str, Any]) -> User:
        if validated_data.pop("delete_avatar", False):
            validated_data["avatar"] = None
        if validated_data.pop("delete_cover", False):
            validated_data["profile_cover"] = None

        old_avatar = instance.avatar if "avatar" in validated_data else None
        old_cover = instance.profile_cover if "profile_cover" in validated_data else None

        user = super().update(instance, validated_data)

        if old_avatar and old_avatar != user.avatar:
            try:
                old_avatar.delete(save=False)
            except Exception as exc:
                logger.warning("Не удалось удалить старый файл аватара: %s", exc)
        if old_cover and old_cover != user.profile_cover:
            try:
                old_cover.delete(save=False)
            except Exception as exc:
                logger.warning("Не удалось удалить старый файл обложки: %s", exc)
        return user


class PasswordChangeSerializer(serializers.Serializer):
    """Смена пароля текущим авторизованным пользователем."""

    current_password = serializers.CharField(
        required=False,
        allow_blank=True,
        write_only=True,
        style={"input_type": "password"},
    )
    new_password = serializers.CharField(
        required=True,
        write_only=True,
        style={"input_type": "password"},
    )
    new_password_confirmation = serializers.CharField(
        required=False,
        allow_blank=True,
        write_only=True,
        style={"input_type": "password"},
    )
    new_password_confirm = serializers.CharField(
        required=False,
        allow_blank=True,
        write_only=True,
        style={"input_type": "password"},
    )

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        user: User = self.context["request"].user
        current = attrs.get("current_password") or ""
        new_password = attrs.get("new_password") or ""
        confirm = attrs.get("new_password_confirmation") or attrs.get("new_password_confirm") or ""

        # 1. Проверка текущего пароля (если у пользователя уже задан пароль)
        if user.has_usable_password():
            if not current:
                raise serializers.ValidationError({"current_password": ["Введите текущий пароль."]})
            if not user.check_password(current):
                raise serializers.ValidationError(
                    {"current_password": ["Неверный текущий пароль."]}
                )
            if current == new_password:
                raise serializers.ValidationError(
                    {"new_password": ["Новый пароль должен отличаться от текущего."]}
                )

        # 2. Проверка подтверждения нового пароля (если передано)
        if confirm and confirm != new_password:
            raise serializers.ValidationError(
                {"new_password_confirmation": ["Пароли не совпадают."]}
            )

        # 3. Валидация стандартными правилами Django
        try:
            validate_password(new_password, user=user)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"new_password": list(exc.messages)}) from exc

        return attrs

    def save(self, **kwargs: Any) -> User:
        user: User = self.context["request"].user
        new_password = self.validated_data["new_password"]
        user.set_password(new_password)
        user.save(update_fields=["password"])
        return user


class OtpRequestSerializer(serializers.Serializer):
    """Запрос SMS-кода."""

    phone = serializers.CharField(max_length=32)
    purpose = serializers.ChoiceField(
        choices=OtpPurpose.choices,
        default=OtpPurpose.LOGIN,
    )
    password = serializers.CharField(
        max_length=128,
        required=False,
        allow_blank=True,
        default="",
        write_only=True,
        style={"input_type": "password"},
    )
    name = serializers.CharField(
        max_length=120, 
        required=False, 
        allow_blank=True, 
        default=""
    )

    def validate_phone(self, value: str) -> str:
        return normalize_phone(value)

    def validate_password(self, value: str) -> str:
        if not value:
            return value
        from django.contrib.auth.password_validation import validate_password
        from django.core.exceptions import ValidationError as DjangoValidationError
        try:
            validate_password(value)
        except DjangoValidationError as e:
            raise serializers.ValidationError(list(e.messages))
        return value

    def validate(self, attrs: dict) -> dict:
        purpose = attrs.get("purpose")
        password = attrs.get("password") or ""
        
        # Если цель - регистрация (или регистрация pro), пароль обязателен.
        if purpose in (OtpPurpose.REGISTER, OtpPurpose.REGISTER):
            if not password:
                # Временно не требуем строго, если клиент еще не обновился,
                # но если передали - он уже провалидирован.
                pass
        return attrs

class OtpRequestResponseSerializer(serializers.Serializer):
    """Ответ на запрос кода. Самого кода здесь нет и быть не может."""

    expires_in = serializers.IntegerField(help_text="Через сколько секунд код истечёт.")
    resend_after = serializers.IntegerField(
        help_text="Через сколько секунд можно запросить следующий код."
    )
    is_new_user = serializers.BooleanField()


class OtpVerifySerializer(serializers.Serializer):
    """Проверка кода."""

    phone = serializers.CharField(max_length=32)
    code = serializers.RegexField(r"^\d{4}$", help_text="4 цифры из SMS.")
    name = serializers.CharField(max_length=120, required=False, allow_blank=True, default="")
    purpose = serializers.ChoiceField(
        choices=OtpPurpose.choices,
        default=OtpPurpose.LOGIN,
    )
    # Согласие на обработку ПДн обязательно: без него аккаунт не заводится.
    # Проверку версии делает сервис, здесь поле просто принимается.
    accepted_terms_version = serializers.CharField(
        max_length=32,
        required=False,
        allow_blank=True,
        default="",
        help_text="Версия принятого соглашения (см. GET /app/pages/terms/).",
    )
    # Пароль задаётся здесь, а не в отдельном запросе до подтверждения: до
    # ввода кода мы не знаем, владеет ли человек номером, и заводить под него
    # учётные данные рано.
    password = serializers.CharField(
        max_length=128,
        required=False,
        allow_blank=True,
        default="",
        write_only=True,
        style={"input_type": "password"},
        help_text="Пароль для входа. Учитывается только при создании аккаунта.",
    )

    def validate_phone(self, value: str) -> str:
        return normalize_phone(value)

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        """Пароль — теми же правилами, что и у исполнителя.

        Пустой пропускаем: вход по коду пароля не требует, поле заполняется
        только на регистрации.
        """
        password = attrs.get("password") or ""
        if not password:
            return attrs

        candidate = User(phone=attrs["phone"], name=attrs.get("name", ""))
        try:
            validate_password(password, user=candidate)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"password": list(exc.messages)}) from exc
        return attrs


class AuthTokensSerializer(serializers.Serializer):
    """Пара токенов и профиль вошедшего пользователя."""

    access = serializers.CharField()
    refresh = serializers.CharField()
    user = UserMeSerializer()
    is_new_user = serializers.BooleanField()


class LogoutSerializer(serializers.Serializer):
    """Выход: refresh-токен уходит в blacklist."""

    refresh = serializers.CharField()


class ProRegisterSerializer(serializers.Serializer):
    """Заявка на регистрацию исполнителя — экран pro_signup_page."""

    phone = serializers.CharField(max_length=32)
    name = serializers.CharField(max_length=120)
    password = serializers.CharField(
        max_length=128,
        write_only=True,
        style={"input_type": "password"},
    )
    iin = serializers.CharField(max_length=14)
    whatsapp = serializers.CharField(
        max_length=32,
        required=False,
        allow_blank=True,
        default="",
        help_text="Номер WhatsApp, если отличается от основного.",
    )

    def validate_phone(self, value: str) -> str:
        return normalize_phone(value)

    def validate_whatsapp(self, value: str) -> str:
        return normalize_phone(value) if value else ""

    def validate_iin(self, value: str) -> str:
        return validate_iin(value)

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        # Проверяем пароль правилами из AUTH_PASSWORD_VALIDATORS: минимум
        # 8 символов, не только цифры, не похож на телефон и имя.
        candidate = User(phone=attrs["phone"], name=attrs.get("name", ""))
        try:
            validate_password(attrs["password"], user=candidate)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"password": list(exc.messages)}) from exc
        return attrs


class ProRegisterResponseSerializer(serializers.Serializer):
    """Ответ на заявку: код отправлен, ждём подтверждения."""

    expires_in = serializers.IntegerField()
    resend_after = serializers.IntegerField()


class PasswordLoginSerializer(serializers.Serializer):
    """Вход исполнителя по паролю."""

    phone = serializers.CharField(max_length=32)
    password = serializers.CharField(
        max_length=128,
        write_only=True,
        style={"input_type": "password"},
    )

    def validate_phone(self, value: str) -> str:
        return normalize_phone(value)


class PasswordResetSerializer(serializers.Serializer):
    """Смена пароля по коду из SMS — экран «Забыли пароль»."""

    phone = serializers.CharField(max_length=32)
    code = serializers.RegexField(r"^\d{4}$", help_text="4 цифры из SMS.")
    password = serializers.CharField(
        max_length=128,
        write_only=True,
        style={"input_type": "password"},
        help_text="Новый пароль.",
    )

    def validate_phone(self, value: str) -> str:
        return normalize_phone(value)

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        # Те же правила, что при регистрации: иначе восстановление пароля
        # становится способом обойти требования к нему.
        candidate = User(phone=attrs["phone"])
        try:
            validate_password(attrs["password"], user=candidate)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"password": list(exc.messages)}) from exc
        return attrs


class IdentitySubmitSerializer(serializers.ModelSerializer):
    """Подача документов на верификацию."""

    class Meta:
        model = IdentityVerification
        fields = ["selfie", "document_front", "document_back", "document_type"]
        extra_kwargs = {
            "selfie": {"required": True},
            "document_front": {"required": True, "allow_null": False},
            "document_back": {"required": False},
        }

    def validate_selfie(self, value: Any) -> Any:
        return _validated_document(value, "selfie")

    def validate_document_front(self, value: Any) -> Any:
        return _validated_document(value, "document_front")

    def validate_document_back(self, value: Any) -> Any:
        return _validated_document(value, "document_back") if value else value


def _validated_document(uploaded: Any, field_name: str) -> Any:
    """Проверяет содержимое файла до того, как он попадёт в хранилище."""
    data = uploaded.read()
    uploaded.seek(0)
    validate_document(data, field_name)
    return uploaded


class IdentitySubmittedSerializer(serializers.Serializer):
    """Ответ на подачу — без единой ссылки на файлы."""

    id = serializers.IntegerField()
    status = serializers.CharField()
    submitted_at = serializers.DateTimeField()


class IdentityStatusSerializer(serializers.Serializer):
    """Статус собственной заявки.

    Ссылок на свои файлы пользователю тоже не отдаём: смотреть их ему незачем,
    а лишний канал доступа к сканам паспорта — лишний риск.
    """

    status = serializers.CharField()
    reject_reason = serializers.CharField(allow_blank=True)
    reviewed_at = serializers.DateTimeField(allow_null=True)
    can_resubmit = serializers.BooleanField()


class IdentityQueueUserSerializer(serializers.ModelSerializer):
    """Данные заявителя, которые нужны модератору для сверки с документом."""

    class Meta:
        model = User
        fields = ["id", "phone", "name", "iin"]
        read_only_fields = fields


class IdentityQueueItemSerializer(serializers.ModelSerializer):
    """Заявка в очереди модерации — с подписанными ссылками на файлы."""

    user = IdentityQueueUserSerializer(read_only=True)
    files = serializers.SerializerMethodField()

    class Meta:
        model = IdentityVerification
        fields = ["id", "user", "document_type", "status", "created_at", "files"]
        read_only_fields = fields

    @extend_schema_field(serializers.DictField(child=serializers.URLField()))
    def get_files(self, obj: IdentityVerification) -> dict[str, str]:
        request = self.context.get("request")
        return build_signed_files(obj, request, request.user)


class IdentityReviewSerializer(serializers.Serializer):
    """Решение модератора."""

    action = serializers.ChoiceField(choices=[REVIEW_APPROVE, REVIEW_REJECT])
    reason = serializers.CharField(max_length=255, required=False, allow_blank=True, default="")
    comment = serializers.CharField(required=False, allow_blank=True, default="")

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        if attrs["action"] == REVIEW_REJECT and not attrs.get("reason"):
            raise serializers.ValidationError({"reason": "Укажите причину отказа."})
        return attrs


class SellerContactsSerializer(serializers.Serializer):
    """Контакты продавца. Анониму телефон приходит замаскированным."""

    phone = serializers.CharField()
    whatsapp = serializers.CharField(allow_blank=True)
    telegram = serializers.CharField(allow_blank=True)
    instagram = serializers.CharField(allow_blank=True)


class SellerCardSerializer(serializers.Serializer):
    """Публичная карточка продавца — экран «Агент»."""

    id = serializers.IntegerField()
    name = serializers.CharField(allow_blank=True)
    company_name = serializers.CharField(allow_blank=True)
    seller_kind = serializers.CharField()
    logo_url = serializers.SerializerMethodField()
    avatar_url = serializers.SerializerMethodField()
    cover_url = serializers.SerializerMethodField()
    about = serializers.CharField(allow_blank=True)
    experience_years = serializers.IntegerField()
    is_verified = serializers.BooleanField()
    rating = serializers.DecimalField(max_digits=3, decimal_places=2)
    reviews_count = serializers.IntegerField()
    active_listings_count = serializers.IntegerField()
    sold_listings_count = serializers.IntegerField(default=0)
    member_since = serializers.DateTimeField()
    work_districts = DistrictBriefSerializer(many=True)
    working_hours = serializers.JSONField()
    contacts = SellerContactsSerializer()

    def _url(self, file_field: Any) -> str | None:
        if not file_field:
            return None
        request = self.context.get("request")
        return request.build_absolute_uri(file_field.url) if request else file_field.url

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_logo_url(self, obj: dict[str, Any]) -> str | None:
        return self._url(obj.get("logo"))

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_avatar_url(self, obj: dict[str, Any]) -> str | None:
        return self._url(obj.get("avatar"))

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_cover_url(self, obj: dict[str, Any]) -> str | None:
        return self._url(obj.get("profile_cover"))


class SellerProfileSerializer(serializers.ModelSerializer):
    """Свой профиль продавца: всё, что можно редактировать.

    `rating`, `reviews_count` и `is_verified` только на чтение: рейтинг —
    агрегат отзывов, а значок проверенного ставит модератор.
    """

    work_districts = serializers.PrimaryKeyRelatedField(
        many=True,
        queryset=District.objects.filter(is_active=True),
        required=False,
    )
    logo_url = serializers.SerializerMethodField()

    class Meta:
        model = SellerProfile
        fields = [
            "company_name",
            "logo",
            "logo_url",
            "about",
            "experience_years",
            "work_districts",
            "whatsapp",
            "telegram",
            "instagram",
            "working_hours",
            "rating",
            "reviews_count",
            "is_verified",
            "verified_at",
        ]
        read_only_fields = ["rating", "reviews_count", "is_verified", "verified_at"]

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_logo_url(self, obj: SellerProfile) -> str | None:
        if not obj.logo:
            return None
        request = self.context.get("request")
        return request.build_absolute_uri(obj.logo.url) if request else obj.logo.url

    def validate_working_hours(self, value: Any) -> dict[str, Any]:
        """`{"mon": ["09:00", "18:00"]}`; пустой список — выходной."""
        if not isinstance(value, dict):
            raise serializers.ValidationError('Ожидается объект вида {"mon": ["09:00", "18:00"]}.')

        allowed = {"mon", "tue", "wed", "thu", "fri", "sat", "sun"}
        unknown = sorted(set(value) - allowed)
        if unknown:
            raise serializers.ValidationError(f"Неизвестные дни недели: {', '.join(unknown)}.")

        for day, hours in value.items():
            if hours in ([], None):
                continue
            if not isinstance(hours, list | tuple) or len(hours) != 2:
                raise serializers.ValidationError(
                    f"{day}: ожидается пара «начало, конец» или пустой список."
                )
            for moment in hours:
                if not isinstance(moment, str) or not TIME_RE.match(moment):
                    raise serializers.ValidationError(f"{day}: время в формате ЧЧ:ММ.")

        return value


class ReviewAuthorSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField(allow_blank=True)


class ReviewSerializer(serializers.ModelSerializer):
    """Отзыв в публичном списке и в ответе на создание."""

    author = serializers.SerializerMethodField()
    listing_slug = serializers.CharField(source="listing.slug", default=None, read_only=True)

    class Meta:
        model = Review
        fields = [
            "id",
            "author",
            "rating",
            "text",
            "listing_slug",
            "status",
            "created_at",
        ]
        read_only_fields = ["id", "author", "listing_slug", "status", "created_at"]

    @extend_schema_field(ReviewAuthorSerializer())
    def get_author(self, obj: Review) -> dict[str, Any]:
        return {"id": obj.author_id, "name": obj.author.name}


class ReviewCreateSerializer(serializers.Serializer):
    """Тело нового отзыва."""

    rating = serializers.IntegerField(min_value=1, max_value=5)
    text = serializers.CharField(allow_blank=True, required=False, default="")
    listing = serializers.SlugField(required=False, allow_blank=True, default="")


class ReviewUpdateSerializer(serializers.Serializer):
    rating = serializers.IntegerField(min_value=1, max_value=5, required=False)
    text = serializers.CharField(allow_blank=True, required=False)


class SellerVerificationSerializer(serializers.ModelSerializer):
    documents_count = serializers.SerializerMethodField()

    class Meta:
        model = SellerVerification
        fields = ["id", "status", "comment", "documents_count", "created_at", "reviewed_at"]
        read_only_fields = fields

    @extend_schema_field(serializers.IntegerField())
    def get_documents_count(self, obj: SellerVerification) -> int:
        return len(obj.documents or [])


class SellerVerificationRequestSerializer(serializers.Serializer):
    documents = serializers.ListField(child=serializers.FileField(), allow_empty=False)


class ContactRevealSerializer(serializers.Serializer):
    """Ответ на раскрытие контакта."""

    phone = serializers.CharField()
    whatsapp = serializers.CharField(allow_blank=True)
    name = serializers.CharField(allow_blank=True)


class DataExportSerializer(serializers.ModelSerializer):
    """Статус выгрузки и ссылка на скачивание, пока она жива."""

    download_url = serializers.SerializerMethodField()

    class Meta:
        model = DataExport
        fields = [
            "id",
            "status",
            "size_bytes",
            "error",
            "download_url",
            "expires_at",
            "created_at",
            "completed_at",
        ]
        read_only_fields = fields

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_download_url(self, obj: DataExport) -> str | None:
        """Подписанная ссылка живёт сутки — как и требует ТЗ."""
        if not obj.is_ready:
            return None

        from django.urls import reverse

        from apps.users.privacy import make_export_token

        path = reverse("users:data-export-file", args=[make_export_token(obj.pk, obj.user_id)])
        request = self.context.get("request")
        return request.build_absolute_uri(path) if request else path


class UserConsentSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserConsent
        fields = ["id", "consent_type", "document_version", "granted", "created_at"]
        read_only_fields = fields


class ConsentRequestSerializer(serializers.Serializer):
    """Согласие, данное уже после регистрации (реклама, аналитика)."""

    consent_type = serializers.ChoiceField(choices=ConsentType.choices)
    document_version = serializers.CharField(max_length=32)
    granted = serializers.BooleanField(default=True)
