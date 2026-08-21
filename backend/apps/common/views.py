"""Служебные вьюхи: health-check."""

import logging
from copy import deepcopy

from django.core.cache import cache
from django.db import connections, transaction
from django.http import HttpRequest, JsonResponse
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import status
from rest_framework.exceptions import NotFound
from rest_framework.generics import CreateAPIView
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.common.exceptions import MESSAGE_BY_CODE, build_error_payload
from apps.common.http import conditional_response
from apps.common.models import SupportTicket
from apps.common.semver import is_outdated
from apps.common.serializers import (
    AppConfigResponseSerializer,
    ErrorSerializer,
    HealthSerializer,
    OnboardingSlideSerializer,
    StaticPageSerializer,
    SupportTicketSerializer,
)
from apps.common.services import (
    enqueue_ticket_notification,
    get_config_payload,
    get_onboarding_payload,
    get_page_payload,
    normalize_platform,
)
from apps.common.throttling import SupportTicketThrottle

logger = logging.getLogger(__name__)

CACHE_PROBE_KEY = "house_kgz:health:probe"


def check_database() -> bool:
    """Реально ходит в БД: SELECT 1."""
    try:
        with connections["default"].cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
    except Exception:
        logger.warning("Health-check: база данных недоступна", exc_info=True)
        return False
    return True


def check_redis() -> bool:
    """Реально ходит в кэш (в prod/local это Redis): SET + GET."""
    try:
        cache.set(CACHE_PROBE_KEY, "ok", timeout=10)
        return cache.get(CACHE_PROBE_KEY) == "ok"
    except Exception:
        logger.warning("Health-check: redis недоступен", exc_info=True)
        return False


class HealthView(APIView):
    """GET /api/v1/health/ — проверка живости сервиса и его зависимостей."""

    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(
        operation_id="health",
        summary="Проверка работоспособности сервиса",
        description=(
            "Проверяет соединение с PostgreSQL и Redis. "
            "Возвращает 503, если хотя бы одна зависимость недоступна."
        ),
        responses={
            status.HTTP_200_OK: HealthSerializer,
            status.HTTP_503_SERVICE_UNAVAILABLE: HealthSerializer,
        },
        auth=[],
    )
    def get(self, request: Request) -> Response:
        db_ok = check_database()
        redis_ok = check_redis()
        healthy = db_ok and redis_ok

        payload = {
            "status": "ok" if healthy else "error",
            "db": db_ok,
            "redis": redis_ok,
        }
        http_status = status.HTTP_200_OK if healthy else status.HTTP_503_SERVICE_UNAVAILABLE
        return Response(payload, status=http_status)


def json_404(request: HttpRequest, exception: Exception | None = None) -> JsonResponse:
    """handler404: даже «не тот URL» отдаём в общем формате ошибок."""
    return JsonResponse(
        build_error_payload("not_found", MESSAGE_BY_CODE["not_found"]),
        status=status.HTTP_404_NOT_FOUND,
        json_dumps_params={"ensure_ascii": False},
    )


def json_500(request: HttpRequest) -> JsonResponse:
    """handler500: то же самое для непойманных ошибок вне DRF."""
    return JsonResponse(
        build_error_payload("server_error", MESSAGE_BY_CODE["server_error"]),
        status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        json_dumps_params={"ensure_ascii": False},
    )


class AppConfigView(APIView):
    """GET /api/v1/app/config/ — всё, что клиент читает на сплэше."""

    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(
        operation_id="app_config",
        summary="Конфигурация мобильного приложения",
        description=(
            "Версии, режим обслуживания, фича-флаги, константы и ссылки на документы.\n\n"
            "`force_update` считается сравнением семвера переданной `version` с "
            "`min_supported_version`. Ответ кэшируется на 15 минут и снабжается ETag: "
            "при `If-None-Match` с текущим тегом возвращается 304 без тела."
        ),
        parameters=[
            OpenApiParameter(
                "platform",
                str,
                description="android | ios — от неё зависит store_url.",
            ),
            OpenApiParameter(
                "version",
                str,
                description="Версия клиента, например 1.0.3.",
            ),
        ],
        responses={
            status.HTTP_200_OK: AppConfigResponseSerializer,
            status.HTTP_304_NOT_MODIFIED: None,
        },
        auth=[],
    )
    def get(self, request: Request) -> Response:
        platform = normalize_platform(request.query_params.get("platform"))
        cached = deepcopy(get_config_payload(platform))

        documents = {
            slug: {
                "url": request.build_absolute_uri(document["url"]),
                "version": document["version"],
            }
            for slug, document in cached["documents"].items()
        }

        payload = {
            "min_supported_version": cached["min_supported_version"],
            "recommended_version": cached["recommended_version"],
            "force_update": is_outdated(
                request.query_params.get("version", ""), cached["min_supported_version"]
            ),
            "store_url": cached["store_url"],
            "maintenance": cached["maintenance"],
            "feature_flags": cached["feature_flags"],
            "constants": cached["constants"],
            "documents": documents,
        }
        return conditional_response(request, payload)


class OnboardingView(APIView):
    """GET /api/v1/app/onboarding/ — активные слайды по порядку."""

    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(
        operation_id="app_onboarding",
        summary="Слайды онбординга",
        description="Активные слайды в порядке показа. Кэш 15 минут, поддерживается ETag.",
        responses={
            status.HTTP_200_OK: OnboardingSlideSerializer(many=True),
            status.HTTP_304_NOT_MODIFIED: None,
        },
        auth=[],
    )
    def get(self, request: Request) -> Response:
        payload = [
            {
                **slide,
                "image": (request.build_absolute_uri(slide["image"]) if slide["image"] else None),
            }
            for slide in deepcopy(get_onboarding_payload())
        ]
        return conditional_response(request, payload)


class StaticPageView(APIView):
    """GET /api/v1/app/pages/{slug}/ — соглашение, политика, FAQ и т.п."""

    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(
        operation_id="app_static_page",
        summary="Статическая страница",
        description="Текст в markdown и его версия. Кэш 15 минут, поддерживается ETag.",
        responses={
            status.HTTP_200_OK: StaticPageSerializer,
            status.HTTP_304_NOT_MODIFIED: None,
            status.HTTP_404_NOT_FOUND: ErrorSerializer,
        },
        auth=[],
    )
    def get(self, request: Request, slug: str) -> Response:
        payload = get_page_payload(slug)
        if payload is None:
            raise NotFound("Страница не найдена.")
        return conditional_response(request, payload)


class SupportTicketCreateView(CreateAPIView):
    """POST /api/v1/support/tickets/ — обращение в поддержку."""

    permission_classes = [AllowAny]
    throttle_classes = [SupportTicketThrottle]
    serializer_class = SupportTicketSerializer
    queryset = SupportTicket.objects.all()

    @extend_schema(
        operation_id="support_ticket_create",
        summary="Создать обращение в поддержку",
        description="Не более 5 обращений в час с одного аккаунта или IP.",
        responses={
            status.HTTP_201_CREATED: SupportTicketSerializer,
            status.HTTP_429_TOO_MANY_REQUESTS: ErrorSerializer,
        },
    )
    def post(self, request: Request, *args: object, **kwargs: object) -> Response:
        return super().post(request, *args, **kwargs)

    def perform_create(self, serializer: SupportTicketSerializer) -> None:
        user = self.request.user if self.request.user.is_authenticated else None
        ticket = serializer.save(user=user)
        # Письмо шлём после коммита: до него задача не увидит объект в БД.
        transaction.on_commit(lambda: enqueue_ticket_notification(ticket.pk))
