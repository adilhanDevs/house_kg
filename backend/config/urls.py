"""Корневые URL-маршруты проекта.

Всё публичное API живёт под префиксом /api/v1/ (URLPathVersioning).
"""

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularRedocView,
    SpectacularSwaggerView,
)

api_v1_patterns = [
    path("", include("apps.common.urls")),
    path("", include("apps.users.urls")),
    path("", include("apps.catalog.urls")),
    path("", include("apps.engagement.urls")),
    path("", include("apps.notifications.urls")),
    path("", include("apps.billing.urls")),
    # versioning_class=None — чтобы в info.version была ровно "1.0.0",
    # без автоматического суффикса " (v1)" от URLPathVersioning.
    path("schema/", SpectacularAPIView.as_view(versioning_class=None), name="schema"),
    path(
        "docs/",
        SpectacularSwaggerView.as_view(url_name="schema"),
        name="swagger-ui",
    ),
    path(
        "redoc/",
        SpectacularRedocView.as_view(url_name="schema"),
        name="redoc",
    ),
]

# API всегда отвечает JSON — даже на несуществующий URL и на 500.
handler404 = "apps.common.views.json_404"
handler500 = "apps.common.views.json_500"

urlpatterns = [
    # Путь админки — из окружения: /admin/ сканируют боты по умолчанию.
    # Доступ дополнительно ограничен по IP (AdminIpRestrictionMiddleware).
    path(settings.ADMIN_URL_PATH, admin.site.urls),
    # Версия зашита в путь: URLPathVersioning + DEFAULT_VERSION="v1".
    path("api/v1/", include(api_v1_patterns)),
    # Метрики Prometheus. Наружу не выставляются: InternalOnlyMiddleware
    # пускает сюда только из внутренней сети.
    path("", include("django_prometheus.urls")),
]

from django.views.static import serve
from django.urls import re_path

urlpatterns += [
    re_path(r"^api/v1/media/(?P<path>.*)$", serve, {"document_root": settings.MEDIA_ROOT}),
    re_path(r"^media/(?P<path>.*)$", serve, {"document_root": settings.MEDIA_ROOT}),
]

if settings.DEBUG and "debug_toolbar" in settings.INSTALLED_APPS:
    try:
        import debug_toolbar  # noqa: F401
    except ImportError:  # pragma: no cover - тулбар не установлен
        pass
    else:
        urlpatterns += [path("__debug__/", include("debug_toolbar.urls"))]
