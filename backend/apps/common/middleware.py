"""Middleware: контекст запроса в логах и защита служебных эндпоинтов."""

import ipaddress
import time
from collections.abc import Callable
from typing import Any

from django.conf import settings
from django.http import HttpRequest, HttpResponse, JsonResponse

from apps.common.logging import get_logger, new_request_id, request_id_var, user_id_var

logger = get_logger("request")

REQUEST_ID_HEADER = "X-Request-ID"


class RequestContextMiddleware:
    """Проставляет request_id и пишет одну строку на запрос.

    request_id либо приходит от балансировщика (заголовок `X-Request-ID`),
    либо генерируется здесь; он же возвращается в ответе, чтобы клиент мог
    приложить его к обращению в поддержку.
    """

    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        request_id = new_request_id(request.headers.get(REQUEST_ID_HEADER))
        token = request_id_var.set(request_id)
        user_token = user_id_var.set("")
        request.request_id = request_id

        started = time.monotonic()
        try:
            response = self.get_response(request)
        except Exception:
            # Строка о падении нужна и здесь: до обработчика DRF доходят не все
            # исключения (например, поднятые в middleware ниже по стеку).
            logger.exception(
                "request_failed",
                path=request.path,
                method=request.method,
                duration_ms=round((time.monotonic() - started) * 1000, 2),
            )
            raise
        finally:
            request_id_var.reset(token)
            user_id_var.reset(user_token)

        duration_ms = round((time.monotonic() - started) * 1000, 2)
        response[REQUEST_ID_HEADER] = request_id

        user = getattr(request, "user", None)
        user_id = user.pk if user is not None and user.is_authenticated else None

        logger.info(
            "request",
            request_id=request_id,
            user_id=user_id,
            path=request.path,
            method=request.method,
            status=response.status_code,
            duration_ms=duration_ms,
        )
        return response


class InternalOnlyMiddleware:
    """Пускает к служебным путям только из внутренней сети.

    `/metrics/` отдаёт профиль нагрузки, состав эндпоинтов и объёмы —
    наружу это не показывают. Проверка здесь дублирует ограничение nginx
    осознанно: если приложение однажды окажется доступно напрямую, метрики
    не утекут вместе с ним.
    """

    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        protected = tuple(getattr(settings, "INTERNAL_ONLY_PATHS", ()))
        if protected and request.path.startswith(protected) and not self._allowed(request):
            logger.warning(
                "internal_path_denied",
                path=request.path,
                client_ip=self._client_ip(request),
            )
            return JsonResponse(
                {
                    "error": {
                        "code": "permission_denied",
                        "message": "Доступ разрешён только из внутренней сети.",
                        "details": {},
                    }
                },
                status=403,
            )

        return self.get_response(request)

    @staticmethod
    def _client_ip(request: HttpRequest) -> str:
        forwarded = request.headers.get("X-Forwarded-For", "")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return request.META.get("REMOTE_ADDR", "")

    def _allowed(self, request: HttpRequest) -> bool:
        networks = getattr(settings, "INTERNAL_NETWORKS", [])
        if not networks:
            return False

        try:
            address = ipaddress.ip_address(self._client_ip(request))
        except ValueError:
            return False

        return any(address in ipaddress.ip_network(network, strict=False) for network in networks)


class AdminIpRestrictionMiddleware:
    """Ограничивает админку списком доверенных адресов.

    Пустой список означает «без ограничения» — так работает разработка;
    на проде переменная обязана быть заполнена (проверяется в production.py).
    """

    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        allowed: list[str] = list(getattr(settings, "ALLOWED_ADMIN_IPS", []))
        admin_path = f"/{settings.ADMIN_URL_PATH}"

        if allowed and request.path.startswith(admin_path):
            client = InternalOnlyMiddleware._client_ip(request)
            if not self._matches(client, allowed):
                logger.warning("admin_access_denied", client_ip=client, path=request.path)
                return JsonResponse(
                    {
                        "error": {
                            "code": "not_found",
                            "message": "Запрашиваемый объект не найден.",
                            "details": {},
                        }
                    },
                    # Именно 404, а не 403: существование админки по этому
                    # адресу — не то, что стоит подтверждать чужому сканеру.
                    status=404,
                )

        return self.get_response(request)

    @staticmethod
    def _matches(client: str, allowed: list[str]) -> bool:
        try:
            address = ipaddress.ip_address(client)
        except ValueError:
            return False

        for entry in allowed:
            try:
                if address in ipaddress.ip_network(entry, strict=False):
                    return True
            except ValueError:
                continue
        return False


class UserContextMiddleware:
    """Кладёт user_id в контекст логов сразу после аутентификации."""

    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        user: Any = getattr(request, "user", None)
        if user is not None and user.is_authenticated:
            user_id_var.set(str(user.pk))
        return self.get_response(request)
