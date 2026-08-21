"""Хранилища файлов.

Приватное хранилище физически отделено от публичных медиа: локально — каталог
вне MEDIA_ROOT, в облаке — отдельный бакет с block-public-access. Публичных URL
у него нет вовсе: единственный доступ — подписанная ссылка с коротким TTL.
"""

from typing import Any

from django.conf import settings
from django.core.files.storage import FileSystemStorage, storages


class PrivateFileSystemStorage(FileSystemStorage):
    """Локальная замена приватного бакета.

    В отличие от обычного FileSystemStorage не умеет отдавать URL: если бы
    умел, файлы KYC оказались бы доступны прямой ссылкой без подписи.
    """

    def __init__(self, location: str | None = None, **kwargs: Any) -> None:
        kwargs.pop("base_url", None)
        super().__init__(location=location or str(settings.PRIVATE_MEDIA_ROOT), **kwargs)

    def url(self, name: str | None) -> str:
        raise ValueError(
            "Приватное хранилище не выдаёт публичных URL — используйте подписанную ссылку."
        )


def private_storage():
    """Хранилище для FileField-ов с чувствительными файлами.

    Передаётся в поле как callable: конкретный бэкенд выбирается в рантайме
    (локально — файловая система, в облаке — приватный бакет S3), а в миграции
    попадает ссылка на функцию, а не настройки окружения.
    """
    return storages[settings.PRIVATE_FILE_STORAGE]
