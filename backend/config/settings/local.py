"""Настройки для локальной разработки."""

from .base import *  # noqa: F403
from .base import INSTALLED_APPS, MIDDLEWARE, env

DEBUG = env.bool("DJANGO_DEBUG", default=True)

ALLOWED_HOSTS = ["*"]

# В разработке фронт/мобилка могут стучаться откуда угодно.
CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# Логи для человека, а не для агрегатора.
LOG_JSON = env.bool("LOG_JSON", default=False)

# Второй фактор в разработке не требуем: заводить TOTP на каждый запуск
# локальной среды — лишнее трение. На проде он обязателен.
ADMIN_REQUIRE_OTP = env.bool("ADMIN_REQUIRE_OTP", default=False)

# django-debug-toolbar ставится только в dev-группе зависимостей.
try:
    import debug_toolbar  # noqa: F401
except ImportError:  # pragma: no cover - тулбар не установлен
    pass
else:
    INSTALLED_APPS += ["debug_toolbar"]
    MIDDLEWARE.insert(0, "debug_toolbar.middleware.DebugToolbarMiddleware")
    INTERNAL_IPS = ["127.0.0.1", "localhost"]
    # В контейнере IP клиента не совпадает с INTERNAL_IPS — показываем всегда.
    DEBUG_TOOLBAR_CONFIG = {"SHOW_TOOLBAR_CALLBACK": lambda request: DEBUG}
