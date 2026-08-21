"""Работа с документами верификации личности.

Три вещи, ради которых существует этот модуль:
1. проверка загруженного файла (тип, размер, разрешение);
2. полное удаление EXIF — в метаданных снимка лежат геокоординаты и модель камеры;
3. подписанные ссылки с коротким TTL — единственный способ увидеть файл.

Ни имена файлов, ни ссылки в логи не пишутся.
"""

import logging
from io import BytesIO
from typing import Any

from django.conf import settings
from django.core import signing
from django.core.exceptions import ValidationError
from PIL import Image

logger = logging.getLogger(__name__)

SIGNING_SALT = "kyc.file"

# Pillow-форматы, которым доверяем, и их MIME.
PILLOW_FORMAT_TO_MIME = {
    "JPEG": "image/jpeg",
    "PNG": "image/png",
    "HEIF": "image/heic",
}


def detect_mime(data: bytes) -> str:
    """MIME по содержимому файла, а не по расширению или заголовку запроса.

    Основной путь — libmagic (python-magic). Если библиотеки в системе нет,
    откатываемся на определение формата средствами Pillow: это слабее, но
    всё равно смотрит на содержимое, а не на то, что прислал клиент.
    """
    try:
        import magic
    except (ImportError, OSError):
        logger.warning("libmagic недоступна, тип файла определяется через Pillow")
    else:
        return magic.from_buffer(data[:2048], mime=True)

    try:
        with Image.open(BytesIO(data)) as image:
            return PILLOW_FORMAT_TO_MIME.get(image.format or "", "application/octet-stream")
    except Exception:
        return "application/octet-stream"


def validate_document(data: bytes, field_name: str = "файл") -> None:
    """Проверяет, что это изображение допустимого типа, размера и разрешения."""
    if len(data) > settings.KYC_MAX_FILE_SIZE:
        limit_mb = settings.KYC_MAX_FILE_SIZE // (1024 * 1024)
        raise ValidationError(f"Файл больше {limit_mb} МБ.", code="file_too_large")

    mime = detect_mime(data)
    if mime not in settings.KYC_ALLOWED_MIME_TYPES:
        raise ValidationError(
            "Загрузите фотографию в формате JPEG или PNG.",
            code="unsupported_file_type",
        )

    try:
        with Image.open(BytesIO(data)) as image:
            width, height = image.size
    except Exception as exc:
        raise ValidationError(
            "Файл не удалось прочитать как изображение.", code="broken_image"
        ) from exc

    if width < settings.KYC_MIN_WIDTH or height < settings.KYC_MIN_HEIGHT:
        raise ValidationError(
            f"Снимок должен быть не меньше {settings.KYC_MIN_WIDTH}×{settings.KYC_MIN_HEIGHT}.",
            code="image_too_small",
        )

    logger.debug("Документ (%s) прошёл проверку: %s, %sx%s", field_name, mime, width, height)


def strip_exif(data: bytes) -> bytes:
    """Пересобирает изображение без метаданных: EXIF, GPS, ICC-профиля.

    Пиксели копируются в новое изображение, поэтому в результат не попадает
    ничего, кроме самой картинки.
    """
    with Image.open(BytesIO(data)) as image:
        image_format = image.format or "JPEG"
        converted = image.convert("RGB") if image_format == "JPEG" else image.copy()
        # Пиксели переносим в чистое изображение: ни EXIF, ни ICC, ни XMP
        # в новый объект не копируются.
        clean = Image.new(converted.mode, converted.size)
        clean.paste(converted)

    buffer = BytesIO()
    save_format = "JPEG" if image_format == "JPEG" else "PNG"
    clean.save(buffer, format=save_format, quality=90)
    return buffer.getvalue()


# -- подписанные ссылки ------------------------------------------------------


def supports_presigned_urls(storage: Any) -> bool:
    """S3-хранилище умеет подписывать ссылки само (querystring_auth)."""
    return hasattr(storage, "bucket") and getattr(storage, "querystring_auth", False)


def make_file_token(verification_id: int, field_name: str, staff_id: int) -> str:
    """Подписанный токен доступа к конкретному файлу конкретным сотрудником."""
    return signing.dumps(
        {"pk": verification_id, "field": field_name, "staff": staff_id},
        salt=SIGNING_SALT,
    )


def read_file_token(token: str) -> dict[str, Any]:
    """Разбирает токен и проверяет срок жизни. Просроченный — ошибка."""
    return signing.loads(token, salt=SIGNING_SALT, max_age=settings.KYC_SIGNED_URL_TTL)
