"""Структурированное логирование и маскирование персональных данных.

Ключевая идея: **ПДн маскируются процессором structlog, а не дисциплиной
разработчиков**. Любой `logger.info("...", phone=...)`, любое исключение с
номером в тексте, любой сторонний логгер проходят через один и тот же фильтр
до того, как строка попадёт в stdout. Полагаться на то, что никто никогда не
залогирует телефон, — значит гарантированно однажды его залогировать.

Маскируются: телефоны (+996…), ИИН (14 цифр), email, JWT и прочие длинные
токены, номера карт. Маска сохраняет узнаваемость (`+996 7XX XXX XX1`), чтобы
по логам всё ещё можно было разбирать инциденты.
"""

import logging
import re
import uuid
from contextvars import ContextVar
from typing import Any

import structlog

# request_id живёт в контексте запроса: его подхватывают и логи вьюхи, и
# логи сервисов, вызванных из неё, без передачи параметром через весь стек.
request_id_var: ContextVar[str] = ContextVar("request_id", default="")
user_id_var: ContextVar[str] = ContextVar("user_id", default="")


# -- маскирование ------------------------------------------------------------

# Телефон в любом виде: +996700123456, 996 700 123 456, 0700-123-456.
PHONE_RE = re.compile(r"(?<![\w.])(?:\+?996|0)[\s\-()]?\d[\d\s\-()]{7,12}\d(?![\w.])")
# ИИН Кыргызстана — ровно 14 цифр подряд.
IIN_RE = re.compile(r"(?<!\d)\d{14}(?!\d)")
EMAIL_RE = re.compile(r"[\w.+-]+@[\w-]+\.[\w.]+")
# JWT и прочие длинные непрерывные токены.
JWT_RE = re.compile(r"\beyJ[\w-]+\.[\w-]+\.[\w-]+\b")
TOKEN_RE = re.compile(r"(?<![\w/+=])[A-Za-z0-9_\-]{32,}(?![\w/+=])")
CARD_RE = re.compile(r"(?<!\d)(?:\d[ -]?){13,19}(?!\d)")

# Ключи, значение которых маскируется целиком независимо от содержимого.
SENSITIVE_KEYS = frozenset(
    {
        "password",
        "new_password",
        "old_password",
        "token",
        "access",
        "refresh",
        "access_token",
        "refresh_token",
        "authorization",
        "secret",
        "signature",
        "code",
        "otp",
        "otp_code",
        "iin",
        "card",
        "card_number",
        "cvv",
        "cvc",
        "pan",
        "api_key",
        "private_key",
    }
)

# Ключи, значение которых заведомо не ПДн. Без этого списка маска токенов
# съедала бы идентификаторы: request_id и UUID платежа — те же 32 символа,
# а без них логи невозможно связать в цепочку.
SAFE_KEYS = frozenset(
    {
        "request_id",
        "trace_id",
        "span_id",
        "correlation_id",
        "payment_id",
        "promotion_id",
        "listing_slug",
        "slug",
        "idempotency_key",
        "logger",
        "level",
        "timestamp",
        "event",
    }
)

REDACTED = "***"
MAX_DEPTH = 6


def mask_phone(value: str) -> str:
    """+996700123456 -> «+996 7XX XXX XX6»: узнаваемо, но бесполезно для звонка."""
    digits = re.sub(r"\D", "", value)
    if len(digits) < 4:
        return REDACTED

    # Локальная запись (0700…) приводится к международной, иначе в логах
    # один и тот же номер выглядел бы двумя разными масками.
    if not digits.startswith("996"):
        digits = "996" + digits.lstrip("0")

    # Последовательность из одних нулей после lstrip оставляет голый префикс —
    # маскировать в ней нечего, а обращение к digits[3] роняло бы логгер.
    if len(digits) < 4:
        return REDACTED

    return f"+{digits[:3]} {digits[3]}XX XXX XX{digits[-1]}"


def mask_iin(value: str) -> str:
    """ИИН оставляем только по первым и последним двум цифрам."""
    return f"{value[:2]}**********{value[-2:]}" if len(value) == 14 else REDACTED


def mask_email(value: str) -> str:
    local, _, domain = value.partition("@")
    head = local[0] if local else ""
    return f"{head}***@{domain}"


def mask_text(value: str) -> str:
    """Прогоняет строку через все маски.

    Порядок важен: сначала самые специфичные шаблоны (JWT, email, ИИН),
    потом общие — иначе «токен» съел бы ИИН, а «карта» — телефон.
    """
    if not value:
        return value

    masked = JWT_RE.sub(REDACTED, value)
    masked = EMAIL_RE.sub(lambda m: mask_email(m.group()), masked)
    masked = IIN_RE.sub(lambda m: mask_iin(m.group()), masked)
    masked = PHONE_RE.sub(lambda m: mask_phone(m.group()), masked)
    masked = CARD_RE.sub(REDACTED, masked)
    return TOKEN_RE.sub(REDACTED, masked)


def mask_value(key: str, value: Any, depth: int = 0) -> Any:
    """Рекурсивно маскирует значение с учётом имени ключа."""
    if depth > MAX_DEPTH:
        return value

    if key.lower() in SAFE_KEYS:
        return value

    if key.lower() in SENSITIVE_KEYS:
        return REDACTED

    if isinstance(value, str):
        return mask_text(value)

    if isinstance(value, dict):
        return {
            inner_key: mask_value(str(inner_key), inner_value, depth + 1)
            for inner_key, inner_value in value.items()
        }

    if isinstance(value, list | tuple | set):
        masked = [mask_value(key, item, depth + 1) for item in value]
        return type(value)(masked) if isinstance(value, list | tuple) else set(masked)

    return value


def mask_pii(logger: Any, method_name: str, event_dict: dict[str, Any]) -> dict[str, Any]:
    """Процессор structlog: последний рубеж перед записью в лог."""
    return {key: mask_value(str(key), value) for key, value in event_dict.items()}


class PiiMaskingFilter(logging.Filter):
    """Тот же фильтр для логгеров, которые пишут мимо structlog.

    Django, requests и сторонние библиотеки не знают про наши процессоры,
    но телефон в тексте исключения от этого не перестаёт быть ПДн.
    """

    def filter(self, record: logging.LogRecord) -> bool:
        if isinstance(record.msg, str):
            record.msg = mask_text(record.msg)
        if record.args:
            if isinstance(record.args, dict):
                record.args = {
                    key: mask_value(str(key), value) for key, value in record.args.items()
                }
            else:
                record.args = tuple(mask_value("", arg) for arg in record.args)
        return True


# -- контекст запроса --------------------------------------------------------


def add_request_context(
    logger: Any, method_name: str, event_dict: dict[str, Any]
) -> dict[str, Any]:
    """Подмешивает request_id и user_id из контекста текущего запроса."""
    request_id = request_id_var.get()
    if request_id:
        event_dict.setdefault("request_id", request_id)

    user_id = user_id_var.get()
    if user_id:
        event_dict.setdefault("user_id", user_id)

    return event_dict


def new_request_id(incoming: str | None = None) -> str:
    """Свой идентификатор или тот, что прислал балансировщик.

    Чужое значение обрезается и чистится: X-Request-ID приходит снаружи,
    и класть его в лог как есть — это инъекция в лог.
    """
    if incoming:
        cleaned = re.sub(r"[^A-Za-z0-9\-_.]", "", incoming)[:64]
        if cleaned:
            return cleaned
    return uuid.uuid4().hex


# -- конфигурация ------------------------------------------------------------


def configure_structlog(json_logs: bool = True, level: str = "INFO") -> None:
    """Настраивает structlog поверх стандартного logging.

    Цепочка заканчивается `wrap_for_formatter`, а не рендерером: рендерит
    один раз ProcessorFormatter из LOGGING. Иначе структурированная запись
    сначала превращается в JSON-строку, а потом эта строка ещё раз
    заворачивается в JSON — и лог становится нечитаемым.
    """
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            add_request_context,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.processors.TimeStamper(fmt="iso", utc=True),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.UnicodeDecoder(),
            structlog.processors.format_exc_info,
            # Маскирование — последним: к этому моменту в event_dict уже всё,
            # что попадёт в лог.
            mask_pii,
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )


def foreign_pre_chain() -> list[Any]:
    """Процессоры для записей из обычного logging.

    Такие записи приходят без уровня, имени логгера и времени — их надо
    добавить, иначе JSON-строка от Django окажется беднее, чем от structlog.
    """
    return [
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.TimeStamper(fmt="iso", utc=True),
        add_request_context,
        mask_pii,
    ]


def stdlib_renderer(logger: Any, name: str, event_dict: dict[str, Any]) -> str:
    """Финальный рендерер: JSON на проде, читаемая строка локально."""
    from django.conf import settings

    # Служебные ключи ProcessorFormatter в вывод не идут. Удаляем мягко:
    # для «чужих» записей формтер уже успел их снять сам.
    event_dict.pop("_record", None)
    event_dict.pop("_from_structlog", None)

    if getattr(settings, "LOG_JSON", True):
        return structlog.processors.JSONRenderer(ensure_ascii=False)(logger, name, event_dict)
    return structlog.dev.ConsoleRenderer(colors=False)(logger, name, event_dict)


def get_logger(name: str | None = None) -> Any:
    """Структурированный логгер. Для нового кода — предпочтительный способ."""
    return structlog.get_logger(name)
