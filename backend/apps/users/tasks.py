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
def send_otp_sms(self, phone: str, code: str) -> None:
    """Отправляет SMS с кодом. Код в логи не пишем — только замаскированный номер."""
    provider = get_sms_provider()
    text = settings.OTP_SMS_TEMPLATE.format(code=code)

    try:
        provider.send(phone, text)
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
