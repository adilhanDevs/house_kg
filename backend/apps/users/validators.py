"""Валидаторы полей пользователя."""

import re

from django.core.exceptions import ValidationError

IIN_LENGTH = 14
IIN_RE = re.compile(rf"^\d{{{IIN_LENGTH}}}$")


def validate_iin(value: str) -> str:
    """Проверяет ИИН: ровно 14 цифр.

    TODO: добавить проверку контрольной суммы. Официальный алгоритм расчёта
    контрольного разряда ПИН/ИИН Кыргызстана (ГРС КР) в открытом доступе не
    опубликован, поэтому пока проверяется только формат. Когда алгоритм будет
    подтверждён — досчитывать контрольный разряд здесь же, не меняя сигнатуру.

    Сам ИИН — персональные данные, поэтому в текст ошибки он не подставляется.
    """
    raw = (value or "").strip()
    if not IIN_RE.match(raw):
        raise ValidationError(
            f"ИИН должен состоять ровно из {IIN_LENGTH} цифр.",
            code="invalid_iin",
        )
    return raw
