"""Сериализаторы профиля пользователя."""

from typing import Any

from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.users.kyc import validate_document
from apps.users.models import IdentityVerification, OtpPurpose, User, mask_iin
from apps.users.phone import normalize_phone
from apps.users.services import REVIEW_APPROVE, REVIEW_REJECT, build_signed_files
from apps.users.validators import validate_iin

BRICK_CURRENCY = "brick"


class WalletBalanceSerializer(serializers.Serializer):
    """Баланс во внутренней валюте («кирпичи»)."""

    balance = serializers.IntegerField()
    currency = serializers.CharField()


class UserMeSerializer(serializers.ModelSerializer):
    """Профиль пользователя (чтение)."""

    iin = serializers.SerializerMethodField()
    avatar_url = serializers.SerializerMethodField()
    wallet_balance = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "phone",
            "name",
            "is_pro",
            "iin",
            "avatar_url",
            "date_joined",
            "wallet_balance",
        ]
        read_only_fields = fields

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

    @extend_schema_field(WalletBalanceSerializer)
    def get_wallet_balance(self, obj: User) -> dict[str, Any]:
        wallet = getattr(obj, "wallet", None)
        return {
            "balance": wallet.balance if wallet else 0,
            "currency": BRICK_CURRENCY,
        }


class UserUpdateSerializer(serializers.ModelSerializer):
    """Изменение профиля: доступны только имя и аватар.

    Остальные поля объявлены read-only — попытка их передать молча игнорируется,
    а не возвращает 400.
    """

    class Meta:
        model = User
        fields = ["name", "avatar", "phone", "is_pro", "iin", "is_staff"]
        read_only_fields = ["phone", "is_pro", "iin", "is_staff"]


class OtpRequestSerializer(serializers.Serializer):
    """Запрос SMS-кода."""

    phone = serializers.CharField(max_length=32)
    purpose = serializers.ChoiceField(
        choices=OtpPurpose.choices,
        default=OtpPurpose.LOGIN,
    )

    def validate_phone(self, value: str) -> str:
        return normalize_phone(value)


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

    def validate_phone(self, value: str) -> str:
        return normalize_phone(value)


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
