"""Нормализация телефонов к E.164 через phonenumbers.

Регион по умолчанию — KG: пользователь вводит «0700 12-34-56», в базе лежит
«+996700123456».
"""

import phonenumbers
from django.core.exceptions import ValidationError

DEFAULT_REGION = "KG"

# Телефон анонимизированного аккаунта (см. services.anonymize_user) не является
# номером и через нормализацию не проходит.
DELETED_PHONE_PREFIX = "deleted-"

INVALID_MESSAGE = "Укажите корректный номер телефона, например +996700123456."


def is_deleted_phone(value: str) -> bool:
    return bool(value) and value.startswith(DELETED_PHONE_PREFIX)


def normalize_phone(value: str, region: str = DEFAULT_REGION) -> str:
    """Приводит номер к E.164 или бросает ValidationError.

    Сам номер в текст ошибки не подставляем — это персональные данные,
    а сообщения об ошибках попадают в логи.
    """
    raw = (value or "").strip()
    if not raw:
        raise ValidationError("Укажите номер телефона.", code="invalid_phone")

    try:
        parsed = phonenumbers.parse(raw, region)
    except phonenumbers.NumberParseException as exc:
        raise ValidationError(INVALID_MESSAGE, code="invalid_phone") from exc

    if not phonenumbers.is_valid_number(parsed):
        raise ValidationError(INVALID_MESSAGE, code="invalid_phone")

    return phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)


def mask_public_phone(phone: str) -> str:
    """«+996700123456» -> «+996 7XX XXX XX6».

    Аноним видит код страны, первую цифру оператора и последнюю цифру номера:
    достаточно, чтобы узнать свой номер в списке, и мало, чтобы собрать базу.
    """
    digits = "".join(character for character in phone or "" if character.isdigit())
    if len(digits) < 5:
        return "+XXX XXX XXX XX"

    country, rest = digits[:3], digits[3:]
    return f"+{country} {rest[0]}XX XXX XX{rest[-1]}"
