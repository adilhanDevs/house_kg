"""Единый формат ошибок API.

Любая ошибка (DRF-овская, Django-овская или непойманная) превращается в::

    {"error": {"code": "<slug>", "message": "<по-русски>", "details": {...}}}
"""

import logging
from typing import Any

from django.core.exceptions import PermissionDenied as DjangoPermissionDenied
from django.core.exceptions import ValidationError as DjangoValidationError
from django.http import Http404
from rest_framework import status
from rest_framework.exceptions import APIException, Throttled
from rest_framework.response import Response
from rest_framework.views import exception_handler as drf_exception_handler

logger = logging.getLogger(__name__)

# Слаг ошибки по HTTP-статусу.
CODE_BY_STATUS: dict[int, str] = {
    status.HTTP_400_BAD_REQUEST: "validation_error",
    status.HTTP_401_UNAUTHORIZED: "authentication_failed",
    status.HTTP_402_PAYMENT_REQUIRED: "insufficient_funds",
    status.HTTP_403_FORBIDDEN: "permission_denied",
    status.HTTP_404_NOT_FOUND: "not_found",
    status.HTTP_405_METHOD_NOT_ALLOWED: "method_not_allowed",
    status.HTTP_406_NOT_ACCEPTABLE: "not_acceptable",
    status.HTTP_409_CONFLICT: "conflict",
    status.HTTP_415_UNSUPPORTED_MEDIA_TYPE: "unsupported_media_type",
    status.HTTP_429_TOO_MANY_REQUESTS: "throttled",
}

# Человекочитаемые сообщения по слагу.
MESSAGE_BY_CODE: dict[str, str] = {
    "validation_error": "Проверьте правильность заполнения полей.",
    "authentication_failed": "Требуется авторизация. Войдите в аккаунт и повторите запрос.",
    "insufficient_funds": "Недостаточно кирпичей на балансе",
    "permission_denied": "У вас нет прав на это действие.",
    "not_found": "Запрашиваемый объект не найден.",
    "method_not_allowed": "Метод не поддерживается для этого адреса.",
    "not_acceptable": "Запрошенный формат ответа не поддерживается.",
    "conflict": "Конфликт: объект уже существует или изменён другим запросом.",
    "unsupported_media_type": "Неподдерживаемый тип содержимого запроса.",
    "throttled": "Слишком много запросов. Попробуйте позже.",
    "server_error": "Внутренняя ошибка сервера. Мы уже разбираемся.",
}


class ConflictError(APIException):
    """409 — конфликт состояния (дубликат, гонка изменений и т.п.)."""

    status_code = status.HTTP_409_CONFLICT
    default_detail = MESSAGE_BY_CODE["conflict"]
    default_code = "conflict"


class ApiValidationError(APIException):
    """400 с человекочитаемым сообщением и произвольным содержимым `details`.

    DRF-овский ValidationError кладёт в `details` ошибки полей; здесь нужна
    возможность отдать своё сообщение («Неверный код») вместе со своими
    подробностями (например, `attempts_left`).
    """

    status_code = status.HTTP_400_BAD_REQUEST
    default_detail = MESSAGE_BY_CODE["validation_error"]
    default_code = "validation_error"

    def __init__(self, message: str | None = None, details: dict[str, Any] | None = None):
        super().__init__(message or self.default_detail)
        self.extra_details = details or {}


class InvalidCredentialsError(APIException):
    """401 при неудачном входе.

    Свой класс, а не DRF-овский AuthenticationFailed: DRF подменяет его статус
    на 403, если у вьюхи нет ни одного аутентификатора (некому отдать заголовок
    WWW-Authenticate). Для эндпоинта входа нужен именно 401.
    """

    status_code = status.HTTP_401_UNAUTHORIZED
    default_detail = MESSAGE_BY_CODE["authentication_failed"]
    default_code = "authentication_failed"


class InsufficientFundsError(APIException):
    """402 — не хватает средств на балансе пользователя.

    В `details` уходит, сколько нужно, сколько есть и сколько не хватает:
    приложению этого хватает, чтобы сразу открыть экран пополнения на
    недостающую сумму, ничего не пересчитывая.
    """

    status_code = status.HTTP_402_PAYMENT_REQUIRED
    default_detail = MESSAGE_BY_CODE["insufficient_funds"]
    default_code = "insufficient_funds"

    def __init__(
        self,
        message: str | None = None,
        required: int | None = None,
        available: int | None = None,
    ):
        super().__init__(message or self.default_detail)
        self.extra_details: dict[str, Any] = {}
        if required is not None:
            self.extra_details["required"] = required
        if available is not None:
            self.extra_details["available"] = available
        if required is not None and available is not None:
            self.extra_details["shortfall"] = max(required - available, 0)


def build_error_payload(
    code: str,
    message: str,
    details: Any | None = None,
) -> dict[str, dict[str, Any]]:
    """Собирает тело ответа с ошибкой."""
    return {
        "error": {
            "code": code,
            "message": message,
            "details": details if details is not None else {},
        }
    }


def custom_exception_handler(exc: Exception, context: dict[str, Any]) -> Response:
    """EXCEPTION_HANDLER для DRF."""
    # Приводим «джанговские» исключения к DRF-овским, чтобы формат был один.
    if isinstance(exc, Http404 | DjangoPermissionDenied | DjangoValidationError):
        exc = _to_drf_exception(exc)

    response = drf_exception_handler(exc, context)

    if response is None:
        # Непойманное исключение — отдаём 500 в том же формате и пишем в лог.
        logger.exception("Необработанная ошибка при обработке запроса", exc_info=exc)
        return Response(
            build_error_payload("server_error", MESSAGE_BY_CODE["server_error"]),
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    code = _extract_code(exc, response.status_code)
    response.data = build_error_payload(
        code=code,
        message=_extract_message(exc, code),
        details=_extract_details(exc, response.data),
    )
    return response


def _to_drf_exception(exc: Exception) -> APIException:
    from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError

    if isinstance(exc, Http404):
        return NotFound()
    if isinstance(exc, DjangoPermissionDenied):
        return PermissionDenied()
    return ValidationError(getattr(exc, "message_dict", None) or list(exc.messages))


def _extract_code(exc: Exception, status_code: int) -> str:
    if status_code >= status.HTTP_500_INTERNAL_SERVER_ERROR:
        return "server_error"

    default_code = getattr(exc, "default_code", None)
    if default_code and default_code in MESSAGE_BY_CODE:
        return str(default_code)

    return CODE_BY_STATUS.get(status_code, "error")


def _seconds_word(value: int) -> str:
    """секунду / секунды / секунд — по правилам русского счёта."""
    if 11 <= value % 100 <= 14:
        return "секунд"
    remainder = value % 10
    if remainder == 1:
        return "секунду"
    if remainder in (2, 3, 4):
        return "секунды"
    return "секунд"


def _extract_message(exc: Exception, code: str) -> str:
    if isinstance(exc, Throttled):
        if exc.wait:
            seconds = int(exc.wait)
            return f"Повторите через {seconds} {_seconds_word(seconds)}."
        return MESSAGE_BY_CODE["throttled"]

    detail = getattr(exc, "detail", None)
    default_detail = getattr(exc, "default_detail", None)

    # Строковый detail, отличающийся от дефолтного, — это уже осмысленное
    # сообщение, написанное в коде вьюхи. Его и показываем.
    if isinstance(detail, str) and str(detail) != str(default_detail):
        return str(detail)

    return MESSAGE_BY_CODE.get(code, MESSAGE_BY_CODE["server_error"])


def _extract_details(exc: Exception, data: Any) -> Any:
    if isinstance(exc, Throttled):
        return {"retry_after": exc.wait}

    # Своё содержимое details (см. ApiValidationError).
    extra = getattr(exc, "extra_details", None)
    if isinstance(extra, dict) and extra:
        return _normalize(extra)

    detail = getattr(exc, "detail", data)

    if isinstance(detail, dict):
        return _normalize(detail)
    if isinstance(detail, list):
        normalized = _normalize(detail)
        return {"non_field_errors": normalized}
    return {}


def _normalize(value: Any) -> Any:
    """Превращает ErrorDetail и вложенные структуры в обычные str/list/dict.

    Числа, флаги и None остаются как есть: клиенту нужен `attempts_left: 4`,
    а не `"4"`. ErrorDetail — наследник str, поэтому тексты ошибок полей
    по-прежнему приводятся к строке.
    """
    if isinstance(value, dict):
        return {str(key): _normalize(item) for key, item in value.items()}
    if isinstance(value, list | tuple):
        return [_normalize(item) for item in value]
    if value is None or isinstance(value, bool | int | float):
        return value
    return str(value)
