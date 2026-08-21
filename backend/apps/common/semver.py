"""Сравнение версий приложения по семверу, а не по строкам.

Строковое сравнение врёт: "1.0.9" > "1.0.10", хотя 9-я версия старее 10-й.
"""

import re

_NUMBER = re.compile(r"\d+")


def parse_version(value: str, parts: int = 3) -> tuple[int, ...]:
    """ "1.2.10-beta.1" -> (1, 2, 10). Нечисловые части считаются нулями."""
    core = re.split(r"[-+]", (value or "").strip(), maxsplit=1)[0]
    numbers: list[int] = []
    for chunk in core.split("."):
        match = _NUMBER.match(chunk)
        numbers.append(int(match.group()) if match else 0)
    numbers = numbers[:parts]
    numbers += [0] * (parts - len(numbers))
    return tuple(numbers)


def is_outdated(current: str, minimum: str) -> bool:
    """True, если версия клиента ниже минимально поддерживаемой."""
    if not current:
        # Версию не прислали — не выгоняем клиента на принудительное обновление.
        return False
    return parse_version(current) < parse_version(minimum)
