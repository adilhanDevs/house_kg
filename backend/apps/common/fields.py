"""Шифрование персональных данных на уровне поля.

ИИН — идентификатор гражданина: по нему находят человека в государственных
реестрах, и утечка дампа БД с ИИН в открытом виде — это утечка ПДн, а не
просто «неприятность». Поэтому значение шифруется до записи в БД.

Реализация — Fernet (AES-128-CBC + HMAC) из `cryptography`, ключ из
`FIELD_ENCRYPTION_KEY`. Почему не pgcrypto: шифрование на стороне БД
привязывает проект к PostgreSQL (тесты идут на SQLite), а ключ всё равно
пришлось бы передавать в каждом запросе — то есть он оказался бы в логах
медленных запросов.

Пустой ключ (локальная разработка, тесты) означает хранение как есть —
поле продолжает работать, но данные не защищены. `production.py` требует
ключ явно.
"""

import base64
import hashlib
from typing import Any

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.db import models

# Префикс, по которому отличается зашифрованное значение от исторического
# открытого: без него нельзя мигрировать данные постепенно.
PREFIX = "enc:"


def _fernet() -> Any:
    """Fernet на ключе из настроек. None — шифрование выключено."""
    from cryptography.fernet import Fernet

    key = getattr(settings, "FIELD_ENCRYPTION_KEY", "")
    if not key:
        return None

    try:
        return Fernet(key)
    except Exception:
        # Ключ мог быть задан произвольной строкой — приводим к валидному
        # 32-байтному ключу Fernet детерминированно.
        derived = base64.urlsafe_b64encode(hashlib.sha256(key.encode("utf-8")).digest())
        return Fernet(derived)


def encrypt_value(value: str) -> str:
    """Шифрует значение. Без ключа возвращает как есть."""
    if not value:
        return value

    box = _fernet()
    if box is None:
        return value

    return PREFIX + box.encrypt(value.encode("utf-8")).decode("ascii")


def decrypt_value(value: str) -> str:
    """Расшифровывает значение. Открытое (историческое) возвращает как есть."""
    if not value or not value.startswith(PREFIX):
        return value

    box = _fernet()
    if box is None:
        # Ключ убрали, а данные зашифрованы — молча отдавать шифротекст
        # нельзя: это молчаливая порча данных.
        raise ImproperlyConfigured("Значение зашифровано, но FIELD_ENCRYPTION_KEY не задан.")

    from cryptography.fernet import InvalidToken

    try:
        return box.decrypt(value[len(PREFIX) :].encode("ascii")).decode("utf-8")
    except InvalidToken as exc:
        raise ImproperlyConfigured(
            "Не удалось расшифровать значение: FIELD_ENCRYPTION_KEY не тот, что при записи."
        ) from exc


class EncryptedCharField(models.CharField):
    """CharField, значение которого лежит в БД в зашифрованном виде.

    Поиск по такому полю точным сравнением невозможен — это осознанная
    плата: искать людей по ИИН всё равно нельзя.
    """

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        # Шифротекст длиннее исходника: под него нужен запас.
        kwargs.setdefault("max_length", 255)
        super().__init__(*args, **kwargs)

    def get_prep_value(self, value: Any) -> Any:
        value = super().get_prep_value(value)
        return encrypt_value(value) if isinstance(value, str) else value

    def from_db_value(self, value: Any, expression: Any, connection: Any) -> Any:
        return decrypt_value(value) if isinstance(value, str) else value

    def to_python(self, value: Any) -> Any:
        value = super().to_python(value)
        return decrypt_value(value) if isinstance(value, str) else value
