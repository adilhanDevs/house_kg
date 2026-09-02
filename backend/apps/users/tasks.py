"""Фоновые задачи пользователей."""

import logging
from datetime import timedelta
from pathlib import Path

from celery import shared_task
from django.conf import settings
from django.utils import timezone

from apps.users.sms import get_sms_provider, mask_phone

logger = logging.getLogger(__name__)

SMS_MAX_RETRIES = 3


@shared_task(
    bind=True,
    name="users.send_otp_sms",
    max_retries=SMS_MAX_RETRIES,
    ignore_result=True,
)
def send_otp_sms(self, phone: str, code: str, otp_id: int | None = None) -> None:
    """Отправляет SMS/OTP с кодом. Код в логи не пишем — только замаскированный номер."""
    from apps.users.models import OtpCode

    provider = get_sms_provider()
    text = settings.OTP_SMS_TEMPLATE.format(code=code)

    try:
        if hasattr(provider, "send_code"):
            result = provider.send_code(
                phone=phone,
                code=code,
                ttl=getattr(settings, "OTP_CODE_TTL_SECONDS", 300),
            )
        else:
            result = provider.send(phone, text)

        # Сохраняем request_id шлюза, если он вернулся
        request_id = getattr(result, "request_id", None)
        if request_id:
            if otp_id:
                OtpCode.objects.filter(pk=otp_id).update(request_id=request_id)
            else:
                latest = (
                    OtpCode.objects.filter(phone=phone, is_used=False, request_id="")
                    .order_by("-created_at")
                    .first()
                )
                if latest:
                    latest.request_id = request_id
                    latest.save(update_fields=["request_id"])

    except Exception as exc:
        attempt = self.request.retries + 1
        logger.warning(
            "Не удалось отправить SMS на %s (попытка %s из %s): %s",
            mask_phone(phone),
            attempt,
            SMS_MAX_RETRIES + 1,
            exc.__class__.__name__,
        )
        # Экспоненциальная задержка между попытками: 10, 20, 40 секунд.
        raise self.retry(exc=exc, countdown=10 * (2**self.request.retries)) from exc

    logger.info("SMS с кодом отправлена на %s", mask_phone(phone))


@shared_task(name="users.report_telegram_verification_status", ignore_result=True)
def report_telegram_verification_status(request_id: str, code: str) -> None:
    """Уведомляет Telegram Gateway о введённом коде для сбора статистики конверсий."""
    from apps.users.sms import TelegramGatewayProvider

    try:
        provider = TelegramGatewayProvider()
        provider.check_verification_status(request_id, code)
    except Exception as exc:
        logger.warning(
            "Не удалось отправить checkVerificationStatus в Telegram Gateway (request_id=%s): %s",
            request_id,
            exc.__class__.__name__,
        )


@shared_task(name="users.purge_old_otp_codes", ignore_result=True)
def purge_old_otp_codes() -> int:
    """Раз в сутки чистит коды старше OTP_RETENTION_DAYS."""
    from apps.users.models import OtpCode

    threshold = timezone.now() - timedelta(days=settings.OTP_RETENTION_DAYS)
    deleted, _ = OtpCode.objects.filter(created_at__lt=threshold).delete()
    logger.info("Удалено устаревших OTP-кодов: %s", deleted)
    return deleted


@shared_task(name="users.process_identity_documents", ignore_result=True)
def process_identity_documents(verification_id: int) -> str:
    """Проверяет документы заявки и вычищает из них EXIF.

    Файл пересобирается без метаданных, а исходник с EXIF удаляется из
    хранилища. Публичных превью не создаём и в CDN ничего не кладём.
    """
    from django.core.exceptions import ValidationError
    from django.core.files.base import ContentFile

    from apps.users.kyc import strip_exif, validate_document
    from apps.users.models import IdentityVerification, VerificationStatus

    verification = IdentityVerification.objects.filter(pk=verification_id).first()
    if verification is None:
        logger.warning("Заявка на верификацию %s не найдена", verification_id)
        return "not_found"

    problems: list[str] = []

    for field_name, file_field in verification.files():
        with file_field.open("rb") as handler:
            data = handler.read()

        try:
            validate_document(data, field_name)
        except ValidationError as exc:
            problems.append(f"{field_name}: {exc.messages[0]}")
            continue

        cleaned = strip_exif(data)
        original_name = file_field.name
        file_field.save(Path(original_name).name, ContentFile(cleaned), save=True)
        # Исходник с метаданными в хранилище оставлять нельзя.
        if file_field.name != original_name:
            file_field.storage.delete(original_name)

    if problems:
        verification.status = VerificationStatus.REJECTED
        verification.reject_reason = "Документы не прошли автоматическую проверку."
        verification.save(update_fields=["status", "reject_reason", "updated_at"])
        logger.info("Заявка %s отклонена автоматически: %s", verification_id, len(problems))
        return "rejected"

    logger.info("Документы заявки %s обработаны", verification_id)
    return "processed"


@shared_task(name="users.purge_identity_files", ignore_result=True)
def purge_identity_files() -> int:
    """Удаляет файлы заявок, у которых вышел срок хранения.

    Запись остаётся: факт проверки нужен, сканы паспорта — нет.
    """
    from apps.users.models import IdentityVerification

    now = timezone.now()
    stale = IdentityVerification.objects.filter(purge_after__lt=now).exclude(selfie="")

    purged = 0
    for verification in stale:
        for field_name, file_field in verification.files():
            file_field.delete(save=False)
            setattr(verification, field_name, "" if field_name == "selfie" else None)
        verification.save(
            update_fields=[*IdentityVerification.FILE_FIELDS, "updated_at"],
        )
        purged += 1

    logger.info("Удалены документы у заявок: %s", purged)
    return purged


@shared_task(name="users.build_data_export", ignore_result=True)
def build_data_export(export_id: int) -> str:
    """Собирает выгрузку персональных данных и кладёт в приватное хранилище."""
    import json
    from datetime import timedelta

    from django.conf import settings
    from django.core.files.base import ContentFile
    from django.utils import timezone

    from apps.notifications.models import NotificationType
    from apps.notifications.services import notify
    from apps.users.models import DataExport, DataExportStatus
    from apps.users.privacy import collect_user_data

    export = DataExport.objects.select_related("user").filter(pk=export_id).first()
    if export is None:
        logger.info("Выгрузка %s удалена до начала сборки", export_id)
        return "missing"

    try:
        payload = collect_user_data(export.user)
        content = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
    except Exception as exc:  # noqa: BLE001 - причина уходит в поле и в лог
        logger.exception("Не удалось собрать выгрузку %s", export_id)
        DataExport.objects.filter(pk=export_id).update(
            status=DataExportStatus.FAILED,
            error=f"{exc.__class__.__name__}: {exc}"[:255],
        )
        return "failed"

    # Имя файла без телефона и имени: выгрузка лежит в хранилище, и ключ
    # не должен сам по себе быть персональными данными.
    export.file.save(f"export-{export.pk}-{export.user_id}.json", ContentFile(content), save=False)
    export.status = DataExportStatus.READY
    export.size_bytes = len(content)
    export.completed_at = timezone.now()
    export.expires_at = timezone.now() + timedelta(seconds=settings.DATA_EXPORT_URL_TTL)
    export.save(update_fields=["file", "status", "size_bytes", "completed_at", "expires_at"])

    notify(
        user=export.user,
        notification_type=NotificationType.SYSTEM,
        title="Выгрузка данных готова",
        body="Файл с вашими данными доступен для скачивания в течение суток.",
        payload={"kind": "data_export_ready", "export_id": export.pk},
    )
    logger.info("Выгрузка %s готова: %s байт", export.pk, export.size_bytes)
    return "ready"


@shared_task(name="users.purge_user_data", ignore_result=True)
def purge_user_data(user_id: int) -> dict[str, int]:
    """Удаляет файлы пользователя и обезличивает записи в леджере.

    Сами операции по кошельку остаются: они нужны бухгалтерии и сходимости
    баланса. Но всё, что связывает их с человеком, из них уходит.
    """
    from apps.billing.models import Wallet, WalletTransaction
    from apps.catalog.models import Listing, ListingMedia
    from apps.users.models import DataExport, User

    user = User.objects.filter(pk=user_id).first()
    if user is None:
        logger.info("Пользователь %s исчез до очистки данных", user_id)
        return {}

    # 1. Медиафайлы объявлений: физически удаляем из хранилища.
    removed_files = 0
    media = ListingMedia.objects.filter(listing__owner_id=user_id).select_related("listing")
    for item in media:
        item.delete_files()
        removed_files += 1
    media.delete()

    # 2. Выгрузки данных: файл с полным профилем не должен пережить аккаунт.
    for export in DataExport.objects.filter(user_id=user_id):
        if export.file:
            export.file.delete(save=False)
    DataExport.objects.filter(user_id=user_id).delete()

    # 3. Прочие файлы профиля.
    profile = getattr(user, "seller_profile", None)
    if profile is not None and profile.logo:
        profile.logo.delete(save=False)
        profile.save(update_fields=["logo"])

    # 4. Леджер: записи остаются, персональные подписи из них уходят.
    anonymized = 0
    wallet = Wallet.objects.filter(user_id=user_id).first()
    if wallet is not None:
        anonymized = WalletTransaction.objects.filter(wallet=wallet).update(
            label="операция удалённого аккаунта"
        )

    # 5. Контактные данные в объявлениях: объявления уже в архиве, но
    #    телефон в контактных полях остаётся ПДн.
    listings = Listing.all_objects.filter(owner_id=user_id).update(
        contact_phone="", contact_name=""
    )

    logger.info(
        "Данные пользователя %s очищены: файлов %s, операций %s, объявлений %s",
        user_id,
        removed_files,
        anonymized,
        listings,
    )
    return {"files": removed_files, "transactions": anonymized, "listings": listings}
