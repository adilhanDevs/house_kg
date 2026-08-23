"""Определение типа файла по содержимому.

Расширению и заголовку Content-Type доверять нельзя: и то и другое задаёт
клиент. Тип определяется тремя способами, от точного к грубому:

1. libmagic (python-magic) — если библиотека есть в системе;
2. сигнатуры (magic numbers) — работает без внешних зависимостей и покрывает
   все форматы, которые принимает приложение;
3. Pillow — последний рубеж для картинок.
"""

import logging
from io import BytesIO

logger = logging.getLogger(__name__)

OCTET_STREAM = "application/octet-stream"

# Pillow-форматы, которым доверяем, и их MIME.
PILLOW_FORMAT_TO_MIME = {
    "JPEG": "image/jpeg",
    "PNG": "image/png",
    "HEIF": "image/heic",
    "WEBP": "image/webp",
}

# Префиксы файла -> MIME. Проверяются по порядку.
BYTE_SIGNATURES: tuple[tuple[bytes, str], ...] = (
    (b"\xff\xd8\xff", "image/jpeg"),
    (b"\x89PNG\r\n\x1a\n", "image/png"),
    (b"GIF87a", "image/gif"),
    (b"GIF89a", "image/gif"),
    (b"%PDF-", "application/pdf"),
    (b"PK\x03\x04", "application/zip"),
    (b"\x1a\x45\xdf\xa3", "video/webm"),
)

# Бренды ISO-BMFF (байты 4..12 файла: "....ftyp<brand>") -> MIME.
FTYP_BRANDS: dict[bytes, str] = {
    b"heic": "image/heic",
    b"heix": "image/heic",
    b"heim": "image/heic",
    b"heis": "image/heic",
    b"hevc": "image/heic",
    b"hevx": "image/heic",
    b"mif1": "image/heic",
    b"msf1": "image/heic",
    b"avif": "image/avif",
    b"qt  ": "video/quicktime",
    b"isom": "video/mp4",
    b"iso2": "video/mp4",
    b"iso4": "video/mp4",
    b"iso5": "video/mp4",
    b"iso6": "video/mp4",
    b"mp41": "video/mp4",
    b"mp42": "video/mp4",
    b"avc1": "video/mp4",
    b"dash": "video/mp4",
    b"M4V ": "video/mp4",
}


def _mime_by_signature(data: bytes) -> str:
    """MIME по первым байтам файла."""
    for prefix, mime in BYTE_SIGNATURES:
        if data.startswith(prefix):
            return mime

    if data[4:8] == b"ftyp":
        return FTYP_BRANDS.get(data[8:12], OCTET_STREAM)

    return OCTET_STREAM


def _mime_by_pillow(data: bytes) -> str:
    from PIL import Image

    try:
        with Image.open(BytesIO(data)) as image:
            return PILLOW_FORMAT_TO_MIME.get(image.format or "", OCTET_STREAM)
    except Exception:
        return OCTET_STREAM


def detect_mime(data: bytes) -> str:
    """MIME по содержимому файла, а не по расширению или заголовку запроса."""
    head = data[:4096]

    try:
        import magic
    except (ImportError, OSError):
        logger.debug("libmagic недоступна, тип файла определяется по сигнатуре")
    else:
        detected = magic.from_buffer(head, mime=True)
        if detected and detected != OCTET_STREAM:
            return detected

    detected = _mime_by_signature(head)
    if detected != OCTET_STREAM:
        return detected

    return _mime_by_pillow(data)
