"""Бизнес-логика пользователей: OTP-вход и мягкое удаление аккаунта."""

import logging
import secrets
import uuid
from datetime import timedelta
from typing import Any

from django.apps import apps
from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from django.contrib.auth.models import update_last_login
from django.db import IntegrityError, transaction
from django.urls import reverse
from django.utils import timezone
from rest_framework_simplejwt.tokens import RefreshToken

from apps.catalog.enums import ListingStatus
from apps.common.audit import audit, record_audit
from apps.common.exceptions import ApiValidationError, ConflictError, InvalidCredentialsError
from apps.common.models import AuditLog
from apps.common.storages import private_storage
from apps.users.kyc import make_file_token, supports_presigned_urls
from apps.users.models import (
    DocumentType,
    IdentityVerification,
    OtpCode,
    OtpPurpose,
    SellerProfile,
    User,
    VerificationStatus,
)
from apps.users.phone import DELETED_PHONE_PREFIX
from apps.users.sms import mask_phone

logger = logging.getLogger(__name__)

# «deleted-» + 8 hex = ровно 16 символов, длина поля phone.
DELETED_SUFFIX_LENGTH = 8
DELETED_PHONE_ATTEMPTS = 5


# -- вход по SMS-коду --------------------------------------------------------


def generate_code(length: int | None = None) -> str:
    """Криптостойкий числовой код фиксированной длины."""
    size = length or settings.OTP_CODE_LENGTH
    return f"{secrets.randbelow(10**size):0{size}d}"


def uses_static_code(phone: str) -> bool:
    """Всегда возвращаем статический код (0000) без отправки SMS."""
    return True


def issue_otp(phone: str, purpose: str = OtpPurpose.LOGIN) -> tuple[OtpCode, bool]:
    """Создаёт код и ставит задачу на отправку. Возвращает (код, новый ли пользователь).

    Открытый код живёт только внутри этой функции и внутри задачи отправки:
    в БД уходит хеш, в ответ API — ничего.
    """
    is_new_user = not User.objects.filter(phone=phone).exists()
    static = uses_static_code(phone)
    code = settings.OTP_DEBUG_CODE if static else generate_code()

    otp = OtpCode.objects.create(
        phone=phone,
        code_hash=make_password(code),
        purpose=purpose,
        expires_at=timezone.now() + timedelta(seconds=settings.OTP_CODE_TTL_SECONDS),
    )

    if static:
        logger.info("Код для %s не отправляется: тестовый номер", mask_phone(phone))
    else:
        from apps.users.tasks import send_otp_sms

        transaction.on_commit(lambda: send_otp_sms.delay(phone, code))

    return otp, is_new_user


def _active_otp(phone: str, purpose: str) -> OtpCode | None:
    return (
        OtpCode.objects.filter(phone=phone, purpose=purpose, is_used=False)
        .order_by("-created_at", "-id")
        .first()
    )


def verify_otp(
    phone: str,
    code: str,
    name: str = "",
    purpose: str = OtpPurpose.LOGIN,
    accepted_terms_version: str = "",
    request: Any = None,
) -> tuple[User, bool]:
    """Проверяет код и возвращает (пользователь, новый ли он).

    Любая ошибка — ApiValidationError с человекочитаемым сообщением.
    Транзакцией накрыт только успешный путь: счётчик неудачных попыток
    должен сохраниться даже тогда, когда запрос завершается ошибкой.

    Регистрация нового аккаунта требует согласия на обработку ПДн: без
    `accepted_terms_version` пользователь не создаётся.
    """
    from apps.users.privacy import has_consent, record_consent, require_terms_version

    otp = _active_otp(phone, purpose)
    if otp is None:
        raise ApiValidationError("Код не найден, запросите новый.")

    if otp.is_expired:
        raise ApiValidationError("Код истёк, запросите новый.")

    if not check_password(code, otp.code_hash):
        otp.attempts += 1
        attempts_left = max(0, settings.OTP_MAX_ATTEMPTS - otp.attempts)

        if otp.attempts >= settings.OTP_MAX_ATTEMPTS:
            otp.is_used = True
            otp.save(update_fields=["attempts", "is_used"])
            logger.info("Код для %s сожжён: исчерпаны попытки", mask_phone(phone))
            raise ApiValidationError(
                "Код заблокирован, запросите новый.",
                {"attempts_left": 0},
            )

        otp.save(update_fields=["attempts"])
        raise ApiValidationError("Неверный код", {"attempts_left": attempts_left})

    # Согласие проверяется до создания аккаунта: обрабатывать ПДн без него
    # нельзя, а созданный и тут же брошенный пользователь — уже обработка.
    existing = User.objects.filter(phone=phone).first()
    needs_consent = existing is None or not has_consent(existing)
    if needs_consent:
        version = require_terms_version(accepted_terms_version)

    with transaction.atomic():
        otp.is_used = True
        otp.save(update_fields=["is_used"])
        user, is_new_user = _get_or_create_user(phone, name, purpose)
        if purpose == OtpPurpose.PRO_REGISTER:
            activate_pro(user)
        if needs_consent:
            record_consent(user, version, request=request)

    logger.info("Успешный вход %s (новый: %s)", mask_phone(phone), is_new_user)
    return user, is_new_user


def _get_or_create_user(phone: str, name: str, purpose: str) -> tuple[User, bool]:
    user = User.objects.filter(phone=phone).first()
    if user is not None:
        # Имя существующего пользователя запросом на вход не переписываем.
        return user, False

    user = User.objects.create_user(
        phone=phone,
        name=name or "",
        is_active=True,
        is_pro=purpose == OtpPurpose.PRO_REGISTER,
    )
    return user, True


# -- регистрация исполнителя (pro) -------------------------------------------


def ensure_wallet(user: User) -> None:
    """Заводит кошелёк исполнителя, если приложение биллинга подключено."""
    if not apps.is_installed("apps.billing"):
        # TODO: убрать проверку, когда billing станет обязательным приложением.
        logger.info("Биллинг не подключён — кошелёк для %s не создан", user.pk)
        return
    wallet_model = apps.get_model("billing", "Wallet")
    wallet_model.objects.get_or_create(user=user)


def activate_pro(user: User) -> None:
    """Подтверждённая pro-регистрация: включаем флаг и заводим кошелёк."""
    if not user.is_pro:
        user.is_pro = True
        user.save(update_fields=["is_pro", "updated_at"])
    ensure_wallet(user)


@transaction.atomic
def register_pro(
    phone: str,
    name: str,
    password: str,
    iin: str,
    whatsapp: str = "",
) -> tuple[User, bool]:
    """Заявка на регистрацию исполнителя. Возвращает (пользователь, новый ли он).

    Второй аккаунт на тот же телефон не создаётся: профиль дозаполняется.
    Флаг is_pro включится только после подтверждения кода (см. verify_otp).
    """
    if User.objects.filter(iin=iin).exclude(phone=phone).exists():
        raise ConflictError("Этот ИИН уже зарегистрирован на другой аккаунт.")

    user = User.objects.filter(phone=phone).first()
    is_new_user = user is None

    if user is None:
        user = User(phone=phone, is_pro=False)
    elif user.iin and user.iin != iin:
        raise ConflictError("Для этого номера уже указан другой ИИН.")

    if name:
        user.name = name
    user.iin = iin
    user.whatsapp_phone = whatsapp or user.whatsapp_phone or None
    user.is_active = True
    user.set_password(password)

    try:
        with transaction.atomic():
            user.save()
    except IntegrityError as exc:
        raise ConflictError("Этот ИИН уже зарегистрирован на другой аккаунт.") from exc

    issue_otp(phone, OtpPurpose.PRO_REGISTER)
    logger.info("Заявка на pro-регистрацию: %s (новый: %s)", mask_phone(phone), is_new_user)
    return user, is_new_user


# -- вход по паролю ----------------------------------------------------------

# Одно и то же сообщение на любой отказ: по ответу нельзя понять,
# зарегистрирован ли номер.
LOGIN_FAILED_MESSAGE = "Неверный номер телефона или пароль."


def authenticate_pro(phone: str, password: str) -> User:
    """Вход по паролю — только для подтверждённых исполнителей."""
    user = User.objects.filter(phone=phone).first()

    if user is None:
        # Считаем хеш вхолостую, чтобы время ответа не выдавало наличие номера.
        User().check_password(password)
        raise InvalidCredentialsError(LOGIN_FAILED_MESSAGE)

    is_seller_or_pro = bool(user.is_pro or hasattr(user, "seller_profile") or user.is_staff or user.is_superuser)
    if not (user.is_active and is_seller_or_pro and user.check_password(password)):
        audit(
            actor=user,
            action=AuditLog.Action.PASSWORD_LOGIN,
            target=user,
            target_user=user,
            extra={"result": "failed"},
        )
        raise InvalidCredentialsError(LOGIN_FAILED_MESSAGE)

    audit(
        actor=user,
        action=AuditLog.Action.PASSWORD_LOGIN,
        target=user,
        target_user=user,
        extra={"result": "success"},
    )
    return user


def issue_tokens(user: User) -> dict[str, str]:
    """Пара JWT для пользователя."""
    refresh = RefreshToken.for_user(user)
    update_last_login(None, user)
    return {"access": str(refresh.access_token), "refresh": str(refresh)}


# -- мягкое удаление аккаунта ------------------------------------------------


def build_deleted_phone() -> str:
    """Уникальный технический «номер» для анонимизированного аккаунта."""
    for _ in range(DELETED_PHONE_ATTEMPTS):
        candidate = f"{DELETED_PHONE_PREFIX}{uuid.uuid4().hex[:DELETED_SUFFIX_LENGTH]}"
        if not User.objects.filter(phone=candidate).exists():
            return candidate
    raise RuntimeError("Не удалось подобрать свободный технический номер.")


def archive_user_listings(user: User) -> int:
    """Переводит объявления пользователя в архив. Возвращает число изменённых."""
    if not apps.is_installed("apps.catalog"):
        # Каталог ещё не подключён — архивировать нечего.
        return 0
    listing_model = apps.get_model("catalog", "Listing")
    return listing_model.objects.filter(owner=user).update(status=ListingStatus.ARCHIVED)


@transaction.atomic
def anonymize_user(user: User) -> int:
    """Мягкое удаление аккаунта: чистим ПДн, гасим объявления, отключаем вход.

    Строка в БД остаётся — на неё ссылаются объявления, обращения и леджер.
    """
    archived = archive_user_listings(user)
    # Журнал пишем ДО обезличивания: после него неоткуда взять, чей это был
    # аккаунт, а факт удаления должен остаться восстановимым.
    audit(
        actor=user,
        action=AuditLog.Action.USER_DELETED,
        target=user,
        target_user=user,
        changes={"is_active": {"before": True, "after": False}},
        extra={"archived_listings": archived},
    )

    # Файлы и обезличивание леджера — в фоне: их много, и держать на них
    # HTTP-запрос пользователя незачем.
    from apps.users.tasks import purge_user_data

    transaction.on_commit(lambda: purge_user_data.delay(user.pk))

    if user.avatar:
        user.avatar.delete(save=False)

    user.phone = build_deleted_phone()
    user.name = ""
    user.iin = ""
    user.avatar = None
    user.seller_kind = ""
    user.is_pro = False
    user.is_active = False
    user.set_unusable_password()
    user.save(
        update_fields=[
            "phone",
            "name",
            "iin",
            "avatar",
            "seller_kind",
            "is_pro",
            "is_active",
            "password",
            "updated_at",
        ]
    )
    logger.info("Аккаунт %s анонимизирован, объявлений в архив: %s", user.pk, archived)
    return archived


# -- верификация личности (KYC) ----------------------------------------------

REVIEW_APPROVE = "approve"
REVIEW_REJECT = "reject"


def submit_identity(
    user: User,
    *,
    selfie: Any,
    document_front: Any = None,
    document_back: Any = None,
    document_type: str = DocumentType.PASSPORT,
) -> IdentityVerification:
    """Принимает документы на проверку.

    Пока предыдущая заявка на проверке, новую подать нельзя — иначе очередь
    засоряется, а модератор смотрит устаревшие снимки.
    """
    if IdentityVerification.objects.filter(user=user, status=VerificationStatus.PENDING).exists():
        raise ConflictError("Ваша заявка уже на проверке, дождитесь решения.")

    verification = IdentityVerification.objects.create(
        user=user,
        selfie=selfie,
        document_front=document_front,
        document_back=document_back,
        document_type=document_type,
    )

    from apps.users.tasks import process_identity_documents

    transaction.on_commit(lambda: process_identity_documents.delay(verification.pk))
    logger.info("Заявка на верификацию %s принята от пользователя %s", verification.pk, user.pk)
    return verification


def latest_identity(user: User) -> IdentityVerification | None:
    return IdentityVerification.objects.filter(user=user).order_by("-created_at", "-id").first()


def issue_signed_url(
    verification: IdentityVerification,
    field_name: str,
    request: Any,
    staff: User,
) -> str:
    """Ссылка на документ со сроком жизни KYC_SIGNED_URL_TTL.

    Каждая выдача фиксируется в журнале аудита: кто, чьи документы, когда
    и с какого IP. Сама ссылка в лог не попадает.
    """
    storage = private_storage()
    file_field = getattr(verification, field_name)

    if supports_presigned_urls(storage):
        # S3 подписывает сам, срок берётся из querystring_expire бакета.
        url = storage.url(file_field.name)
    else:
        token = make_file_token(verification.pk, field_name, staff.pk)
        url = reverse("users:kyc-file", kwargs={"token": token})
        if request is not None:
            url = request.build_absolute_uri(url)

    record_audit(
        action=AuditLog.Action.KYC_URL_ISSUED,
        request=request,
        actor=staff,
        target_user=verification.user,
        obj=verification,
        extra={"field": field_name},
    )
    return url


def build_signed_files(
    verification: IdentityVerification,
    request: Any,
    staff: User,
) -> dict[str, str]:
    """Подписанные ссылки на все файлы заявки."""
    return {
        field_name: issue_signed_url(verification, field_name, request, staff)
        for field_name, _ in verification.files()
    }


def notify_identity_result(verification: IdentityVerification) -> None:
    """Уведомление пользователю о решении по заявке."""
    from apps.notifications.models import NotificationType
    from apps.notifications.services import notify

    approved = verification.status == VerificationStatus.APPROVED

    notify(
        user=verification.user,
        notification_type=NotificationType.SYSTEM,
        title="Личность подтверждена" if approved else "Проверка не пройдена",
        body="" if approved else verification.reject_reason,
        # Отдельного типа для KYC в списке ТЗ нет — маршрут кладём в payload.
        payload={"kind": "identity_verification", "verification_id": verification.pk},
    )


@transaction.atomic
def review_identity(
    verification: IdentityVerification,
    staff: User,
    action: str,
    reason: str = "",
    comment: str = "",
    request: Any = None,
) -> IdentityVerification:
    """Решение модератора по заявке."""
    if not verification.is_pending:
        raise ConflictError("По этой заявке уже принято решение.")

    now = timezone.now()
    verification.reviewed_by = staff
    verification.reviewed_at = now
    verification.comment = comment
    # Файлы живут ещё KYC_PURGE_AFTER_DAYS — на случай апелляции, — потом удаляются.
    verification.purge_after = now + timedelta(days=settings.KYC_PURGE_AFTER_DAYS)

    if action == REVIEW_APPROVE:
        verification.status = VerificationStatus.APPROVED
        verification.reject_reason = ""
        profile, _ = SellerProfile.objects.get_or_create(user=verification.user)
        profile.is_verified = True
        profile.verified_at = now
        profile.save(update_fields=["is_verified", "verified_at", "updated_at"])
    else:
        verification.status = VerificationStatus.REJECTED
        verification.reject_reason = reason

    verification.save(
        update_fields=[
            "status",
            "reject_reason",
            "comment",
            "reviewed_by",
            "reviewed_at",
            "purge_after",
            "updated_at",
        ]
    )

    record_audit(
        action=AuditLog.Action.KYC_REVIEWED,
        request=request,
        actor=staff,
        target_user=verification.user,
        obj=verification,
        extra={"decision": action},
    )
    notify_identity_result(verification)
    return verification
