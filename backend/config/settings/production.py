"""Настройки production-окружения."""

from django.core.exceptions import ImproperlyConfigured

from .base import *  # noqa: F403
from .base import (
    ADMIN_URL_PATH,
    ALLOWED_ADMIN_IPS,
    FIELD_ENCRYPTION_KEY,
    MIDDLEWARE,
    env,
)

# CSP нужен только там, где браузер что-то рисует: админка и Swagger.
MIDDLEWARE = [*MIDDLEWARE, "csp.middleware.CSPMiddleware"]

DEBUG = False

ALLOWED_HOSTS = env.list("DJANGO_ALLOWED_HOSTS")

# ----------------------------------------------------------------------------
# CORS / CSRF
# ----------------------------------------------------------------------------
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = env.list("CORS_ALLOWED_ORIGINS", default=[])
CORS_ALLOW_CREDENTIALS = True
CSRF_TRUSTED_ORIGINS = env.list("CSRF_TRUSTED_ORIGINS", default=[])

# ----------------------------------------------------------------------------
# Безопасность
# ----------------------------------------------------------------------------
SECURE_SSL_REDIRECT = env.bool("SECURE_SSL_REDIRECT", default=True)
SECURE_HSTS_SECONDS = env.int("SECURE_HSTS_SECONDS", default=31536000)  # 1 год
SECURE_HSTS_INCLUDE_SUBDOMAINS = env.bool("SECURE_HSTS_INCLUDE_SUBDOMAINS", default=True)
SECURE_HSTS_PRELOAD = env.bool("SECURE_HSTS_PRELOAD", default=True)
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_REFERRER_POLICY = "same-origin"

SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_SECURE = True
CSRF_COOKIE_HTTPONLY = True

SECURE_REFERRER_POLICY = "strict-origin-when-cross-origin"
X_FRAME_OPTIONS = "DENY"
SECURE_CROSS_ORIGIN_OPENER_POLICY = "same-origin"

# Сессии персонала живут недолго и не переживают закрытие браузера:
# доступ к ПДн не должен оставаться открытым на неделю.
SESSION_COOKIE_AGE = env.int("SESSION_COOKIE_AGE", default=8 * 3600)
SESSION_EXPIRE_AT_BROWSER_CLOSE = True
SESSION_COOKIE_SAMESITE = "Lax"
CSRF_COOKIE_SAMESITE = "Lax"

# ----------------------------------------------------------------------------
# CSP — только для админки и Swagger: API отдаёт JSON и в браузере не рисуется
# ----------------------------------------------------------------------------
CONTENT_SECURITY_POLICY = {
    "DIRECTIVES": {
        "default-src": ["'self'"],
        "script-src": ["'self'"],
        "style-src": ["'self'", "'unsafe-inline'"],  # админка Django инлайнит стили
        "img-src": ["'self'", "data:", env.str("MEDIA_CSP_ORIGIN", default="")],
        "font-src": ["'self'", "data:"],
        "connect-src": ["'self'"],
        "frame-ancestors": ["'none'"],
        "form-action": ["'self'"],
        "base-uri": ["'self'"],
        "object-src": ["'none'"],
    }
}

# ----------------------------------------------------------------------------
# Админка: закрытый путь, список адресов и обязательная 2FA
# ----------------------------------------------------------------------------
# Пустой список означал бы «пускать всех» — на проде это недопустимо.
if not ALLOWED_ADMIN_IPS:
    raise ImproperlyConfigured(
        "ALLOWED_ADMIN_IPS обязателен в production: админка не должна быть доступна из интернета."
    )

if ADMIN_URL_PATH == "admin/":
    raise ImproperlyConfigured(
        "ADMIN_URL_PATH обязателен в production: путь /admin/ сканируют боты."
    )

# Ключ шифрования ИИН: без него персональные данные легли бы в БД открытыми.
if not FIELD_ENCRYPTION_KEY:
    raise ImproperlyConfigured(
        "FIELD_ENCRYPTION_KEY обязателен в production: ИИН хранится зашифрованным."
    )

# Вход в админку — только с подтверждением второго фактора (django-otp).
ADMIN_REQUIRE_OTP = env.bool("ADMIN_REQUIRE_OTP", default=True)

# ----------------------------------------------------------------------------
# Логи и наблюдаемость
# ----------------------------------------------------------------------------
LOG_JSON = True
