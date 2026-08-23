"""Проверка и обработка медиафайлов объявления.

Файл приходит с телефона пользователя, поэтому:

* тип определяется по содержимому (`detect_mime`), а не по расширению —
  ".jpg" с PDF внутри отклоняется;
* EXIF снимается ПОЛНОСТЬЮ и в первую очередь: в метаданных фотографии
  квартиры лежат GPS-координаты, модель телефона и время съёмки, и ничему
  из этого не место в публичном доступе;
* имя файла с телефона нигде не используется — ключ в хранилище собирается
  из UUID объявления и UUID записи (см. `media_upload_to`).
"""

import json
import logging
import subprocess
import uuid
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path
from typing import Any

from django.conf import settings
from django.core.exceptions import ValidationError
from PIL import Image

from apps.catalog.enums import MediaKind
from apps.common.files import detect_mime

logger = logging.getLogger(__name__)

# Варианты изображения: имя -> максимальная сторона в пикселях.
VARIANTS: tuple[str, ...] = ("thumb", "medium", "original")


def media_upload_to(instance: Any, filename: str) -> str:
    """Ключ файла: listings/{listing_uuid}/{media_uuid}_{variant}.{ext}.

    Пользовательское имя файла отбрасывается целиком — оно может содержать
    ПДн («паспорт_Иванов.jpg») и попадёт в публичный URL.
    """
    return f"listings/{instance.listing.uuid}/{filename}"


def variant_name(media: Any, variant: str, extension: str) -> str:
    return f"{media.uuid}_{variant}.{extension}"


# Расширение исходника выбирается по определённому типу, а не по тому,
# что прислал клиент.
EXTENSION_BY_MIME = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/heic": "heic",
    "video/mp4": "mp4",
    "video/quicktime": "mov",
}


def source_extension(data: bytes, kind: str) -> str:
    default = "jpg" if kind == MediaKind.PHOTO else "mp4"
    return EXTENSION_BY_MIME.get(detect_mime(data), default)


# -- валидация ---------------------------------------------------------------


@dataclass(frozen=True)
class UploadSpec:
    """Ограничения на файл одного типа."""

    mime_types: list[str]
    max_size: int
    human_type: str


def upload_spec(kind: str) -> UploadSpec:
    if kind == MediaKind.PHOTO:
        return UploadSpec(
            mime_types=list(settings.LISTING_PHOTO_MIME_TYPES),
            max_size=settings.LISTING_PHOTO_MAX_SIZE,
            human_type="фото",
        )
    return UploadSpec(
        mime_types=list(settings.LISTING_VIDEO_MIME_TYPES),
        max_size=settings.LISTING_VIDEO_MAX_SIZE,
        human_type="видео",
    )


def _mb(value: int) -> int:
    return value // (1024 * 1024)


def validate_photo(data: bytes) -> tuple[int, int]:
    """Проверяет тип, размер и разрешение фотографии. Возвращает (ширина, высота)."""
    spec = upload_spec(MediaKind.PHOTO)

    if len(data) > spec.max_size:
        raise ValidationError(
            f"Фото больше {_mb(spec.max_size)} МБ.",
            code="file_too_large",
        )

    mime = detect_mime(data)
    if mime not in spec.mime_types:
        raise ValidationError(
            "Загрузите фотографию в формате JPEG, PNG или HEIC.",
            code="unsupported_file_type",
        )

    try:
        with Image.open(BytesIO(data)) as image:
            width, height = image.size
    except Exception as exc:
        raise ValidationError(
            "Файл не удалось прочитать как изображение.", code="broken_image"
        ) from exc

    min_width = settings.LISTING_PHOTO_MIN_WIDTH
    min_height = settings.LISTING_PHOTO_MIN_HEIGHT
    if width < min_width or height < min_height:
        raise ValidationError(
            f"Фото должно быть не меньше {min_width}×{min_height} пикселей.",
            code="image_too_small",
        )

    return width, height


def validate_video(data: bytes, source_path: str | None = None) -> dict[str, Any]:
    """Проверяет тип, размер и длительность видео ДО сохранения в хранилище.

    Длительность читается ffprobe'ом: 200-мегабайтный файл на четыре минуты
    незачем класть в бакет только чтобы потом удалить.
    """
    spec = upload_spec(MediaKind.VIDEO)

    if len(data) > spec.max_size:
        raise ValidationError(
            f"Видео больше {_mb(spec.max_size)} МБ.",
            code="file_too_large",
        )

    mime = detect_mime(data)
    if mime not in spec.mime_types:
        raise ValidationError(
            "Загрузите видео в формате MP4 или MOV.",
            code="unsupported_file_type",
        )

    probe = probe_video(source_path) if source_path else {}
    duration = probe.get("duration_seconds")
    limit = settings.LISTING_VIDEO_MAX_DURATION

    if duration is not None and duration > limit:
        raise ValidationError(
            f"Видео длиннее {limit // 60} минут. Обрежьте ролик и попробуйте снова.",
            code="video_too_long",
        )

    return probe


# -- ffmpeg / ffprobe --------------------------------------------------------


def _run(command: list[str], timeout: int) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(  # noqa: S603 - команда собирается кодом, не пользователем
        command,
        capture_output=True,
        timeout=timeout,
        check=True,
    )


def probe_video(path: str) -> dict[str, Any]:
    """Длительность и разрешение через ffprobe.

    ffprobe отсутствует или не понял файл — возвращаем пустой словарь:
    отсутствие длительности не должно ронять загрузку.
    """
    command = [
        settings.FFPROBE_BIN,
        "-v",
        "error",
        "-show_entries",
        "format=duration:stream=width,height,codec_type",
        "-of",
        "json",
        path,
    ]
    try:
        result = _run(command, timeout=settings.FFPROBE_TIMEOUT)
        payload = json.loads(result.stdout or b"{}")
    except (OSError, subprocess.SubprocessError, ValueError) as exc:
        logger.warning("ffprobe не смог прочитать файл: %s", exc.__class__.__name__)
        return {}

    probe: dict[str, Any] = {}

    duration = (payload.get("format") or {}).get("duration")
    if duration is not None:
        try:
            probe["duration_seconds"] = int(round(float(duration)))
        except (TypeError, ValueError):
            pass

    for stream in payload.get("streams") or []:
        if stream.get("codec_type") == "video":
            probe["width"] = stream.get("width")
            probe["height"] = stream.get("height")
            break

    return probe


def extract_video_frame(path: str, at_second: int = 1) -> bytes | None:
    """Кадр видео на указанной секунде — превью для карточки."""
    command = [
        settings.FFMPEG_BIN,
        "-v",
        "error",
        "-ss",
        str(at_second),
        "-i",
        path,
        "-frames:v",
        "1",
        "-f",
        "image2",
        "-c:v",
        "mjpeg",
        "pipe:1",
    ]
    try:
        result = _run(command, timeout=settings.FFMPEG_TIMEOUT)
    except (OSError, subprocess.SubprocessError) as exc:
        logger.warning("ffmpeg не смог достать кадр: %s", exc.__class__.__name__)
        return None

    return result.stdout or None


# -- обработка изображения ---------------------------------------------------


def strip_exif(image: Image.Image) -> Image.Image:
    """Пиксели без метаданных: ни EXIF, ни GPS, ни ICC, ни XMP.

    Пиксели переносятся в новое изображение — в объект-приёмник ничего, кроме
    самой картинки, не копируется.
    """
    source = image.convert("RGBA") if image.mode in ("RGBA", "LA", "P") else image.convert("RGB")
    clean = Image.new(source.mode, source.size)
    clean.paste(source)
    return clean


def resize_to(image: Image.Image, max_side: int) -> Image.Image:
    """Уменьшает до max_side по большей стороне. Меньшие не увеличивает."""
    width, height = image.size
    if max(width, height) <= max_side:
        return image.copy()

    resized = image.copy()
    resized.thumbnail((max_side, max_side), Image.LANCZOS)
    return resized


def encode(image: Image.Image, image_format: str) -> bytes:
    """WebP (quality=82) или JPEG-фолбэк для старых клиентов."""
    buffer = BytesIO()
    if image_format == "WEBP":
        image.save(buffer, format="WEBP", quality=settings.LISTING_WEBP_QUALITY, method=4)
    else:
        image.convert("RGB").save(
            buffer, format="JPEG", quality=settings.LISTING_JPEG_QUALITY, optimize=True
        )
    return buffer.getvalue()


def perceptual_hash(image: Image.Image) -> str:
    """phash — по нему модератор увидит одно и то же фото в разных объявлениях."""
    try:
        import imagehash
    except ImportError:
        logger.warning("imagehash недоступен, перцептивный хеш не посчитан")
        return ""

    try:
        return str(imagehash.phash(image))
    except Exception as exc:
        logger.warning("Не удалось посчитать phash: %s", exc.__class__.__name__)
        return ""


def local_path(file_field: Any) -> str | None:
    """Путь к файлу на диске, если хранилище локальное. Для S3 — None."""
    try:
        return file_field.path
    except (AttributeError, NotImplementedError):
        return None


def temporary_bytes(data: bytes, suffix: str = "") -> Path:
    """Кладёт байты во временный файл — ffprobe/ffmpeg работают с путями."""
    import tempfile

    handle = tempfile.NamedTemporaryFile(suffix=suffix, delete=False)
    with handle:
        handle.write(data)
    return Path(handle.name)


def temporary_copy(file_field: Any, suffix: str = "") -> Path:
    """Копия файла во временном каталоге — ffprobe/ffmpeg работают с путями."""
    import tempfile

    handle = tempfile.NamedTemporaryFile(suffix=suffix, delete=False)
    with handle:
        file_field.open("rb")
        try:
            for chunk in file_field.chunks():
                handle.write(chunk)
        finally:
            file_field.close()
    return Path(handle.name)


def new_uuid() -> uuid.UUID:
    return uuid.uuid4()
