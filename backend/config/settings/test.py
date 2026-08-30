"""Настройки для прогона тестов.

Специально не требуют поднятых Postgres/Redis: по умолчанию используется
in-memory SQLite и локальный кэш, поэтому `make test` работает и без docker.
Если задать DATABASE_URL/REDIS_URL — тесты пойдут по ним.
"""

import os

os.environ.setdefault("DJANGO_SECRET_KEY", "test-secret-key-not-for-production")
os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/1")
# Приватные файлы (KYC) в тестах лежат отдельно от публичных медиа.
os.environ.setdefault("PRIVATE_MEDIA_ROOT", "/tmp/house-kgz-test-private-media")

from .base import *  # noqa: E402, F403
from .base import env  # noqa: E402

DEBUG = False
SECRET_KEY = "test-secret-key-not-for-production"
SIMPLE_JWT = {**SIMPLE_JWT, "SIGNING_KEY": SECRET_KEY}

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
        "LOCATION": "house-kgz-tests",
    }
}

# Быстрое хеширование паролей в тестах.
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]

EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"

CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True

CORS_ALLOW_ALL_ORIGINS = True

MEDIA_ROOT = env.str("TEST_MEDIA_ROOT", default="/tmp/house-kgz-test-media")
