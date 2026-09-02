"""Единый файл настроек Django для проекта house_kgz (Base + Production).

Объединяет базовую конфигурацию, параметры безопасности production,
настройки базы данных PostgreSQL (quantum_db) и переменные окружения.
"""

from datetime import timedelta
from pathlib import Path

import environ
from celery.schedules import crontab

# backend/config/settings.py -> backend/
BASE_DIR = Path(__file__).resolve().parent.parent

env = environ.Env(
    DJANGO_DEBUG=(bool, False),
    DJANGO_ALLOWED_HOSTS=(list, ["*"]),
    DJANGO_TIME_ZONE=(str, "Asia/Bishkek"),
    CELERY_TASK_ALWAYS_EAGER=(bool, False),
    USE_S3=(bool, False),
    AWS_S3_ENDPOINT_URL=(str, ""),
    AWS_S3_CUSTOM_DOMAIN=(str, ""),
    AWS_QUERYSTRING_AUTH=(bool, False),
    JWT_ACCESS_TOKEN_LIFETIME_MINUTES=(int, 15),
    JWT_REFRESH_TOKEN_LIFETIME_DAYS=(int, 30),
    REDIS_URL=(str, "redis://localhost:6379/0"),
)

# Читаем backend/.env, если он существует
env_file = BASE_DIR / ".env"
if env_file.exists():
    env.read_env(str(env_file))

# ----------------------------------------------------------------------------
# Ядро
# ----------------------------------------------------------------------------
SECRET_KEY = env.str("DJANGO_SECRET_KEY", default="django-insecure-house-kgz-secret-key-prod-2026")
DEBUG = env.bool("DJANGO_DEBUG", default=False)
ALLOWED_HOSTS = env.list("DJANGO_ALLOWED_HOSTS", default=["*"])

ROOT_URLCONF = "config.urls"
AUTH_USER_MODEL = "users.User"
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

DJANGO_APPS = [
    # Своя админка: поддержка 2FA для персонала
    "apps.common.admin_site.HouseAdminConfig",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
]

THIRD_PARTY_APPS = [
    "rest_framework",
    "rest_framework_simplejwt.token_blacklist",
    "django_filters",
    "drf_spectacular",
    "corsheaders",
    "storages",
    "django_celery_beat",
    "django_prometheus",
    "csp",
    # 2FA для персонала
    "django_otp",
    "django_otp.plugins.otp_totp",
    "django_otp.plugins.otp_static",
]

LOCAL_APPS = [
    "apps.common",
    "apps.users",
    "apps.catalog",
    "apps.engagement",
    "apps.billing",
    "apps.notifications",
    "apps.messaging",
]

INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS

MIDDLEWARE = [
    # Метрики django-prometheus снаружи
    "django_prometheus.middleware.PrometheusBeforeMiddleware",
    "apps.common.middleware.RequestContextMiddleware",
    "apps.common.middleware.InternalOnlyMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    # Сразу после аутентификации: OTPMiddleware выставляет request.user.is_verified
    "django_otp.middleware.OTPMiddleware",
    "apps.common.middleware.AdminIpRestrictionMiddleware",
    "apps.common.middleware.UserContextMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "csp.middleware.CSPMiddleware",
    "django_prometheus.middleware.PrometheusAfterMiddleware",
]

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

# ----------------------------------------------------------------------------
# База данных
# ----------------------------------------------------------------------------
DATABASES = {
    "default": env.db(
        "DATABASE_URL",
        default="postgres://quantum_user:Adil2008!@localhost:5432/quantum_db",
    )
}
DATABASES["default"]["ATOMIC_REQUESTS"] = False
DATABASES["default"]["CONN_MAX_AGE"] = env.int("DATABASE_CONN_MAX_AGE", default=60)

if "sqlite" in DATABASES["default"].get("ENGINE", ""):
    DATABASES["default"]["CONN_MAX_AGE"] = 0
    DATABASES["default"].setdefault("OPTIONS", {})
    DATABASES["default"]["OPTIONS"].setdefault("timeout", 20)

# ----------------------------------------------------------------------------
# Кэш (Redis / LocMem)
# ----------------------------------------------------------------------------
REDIS_URL = env.str("REDIS_URL", default="redis://localhost:6379/0")

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
    }
}

# ----------------------------------------------------------------------------
# Пароли / локаль
# ----------------------------------------------------------------------------
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "ru-ru"
TIME_ZONE = env.str("DJANGO_TIME_ZONE", default="Asia/Bishkek")
USE_I18N = True
USE_TZ = True

# ----------------------------------------------------------------------------
# Статика и медиа
# ----------------------------------------------------------------------------
STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

# Лимиты размера загружаемых файлов (50 МБ для фото/видео)
DATA_UPLOAD_MAX_MEMORY_SIZE = 50 * 1024 * 1024
FILE_UPLOAD_MAX_MEMORY_SIZE = 50 * 1024 * 1024

# Приватные файлы (документы KYC) лежат отдельно от публичных медиа
PRIVATE_MEDIA_ROOT = env.path("PRIVATE_MEDIA_ROOT", default=BASE_DIR / "private-media")

USE_S3 = env.bool("USE_S3", default=False)

STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
    "private": {
        "BACKEND": "apps.common.storages.PrivateFileSystemStorage",
        "OPTIONS": {"location": str(PRIVATE_MEDIA_ROOT)},
    },
}

PRIVATE_FILE_STORAGE = "private"

if USE_S3:
    AWS_ACCESS_KEY_ID = env.str("AWS_ACCESS_KEY_ID", default="")
    AWS_SECRET_ACCESS_KEY = env.str("AWS_SECRET_ACCESS_KEY", default="")
    AWS_STORAGE_BUCKET_NAME = env.str("AWS_STORAGE_BUCKET_NAME", default="")
    AWS_S3_REGION_NAME = env.str("AWS_S3_REGION_NAME", default="us-east-1")
    AWS_S3_ENDPOINT_URL = env.str("AWS_S3_ENDPOINT_URL", default="") or None
    AWS_S3_CUSTOM_DOMAIN = env.str("AWS_S3_CUSTOM_DOMAIN", default="") or None
    AWS_QUERYSTRING_AUTH = env.bool("AWS_QUERYSTRING_AUTH", default=False)
    AWS_DEFAULT_ACL = None
    AWS_S3_FILE_OVERWRITE = False
    STORAGES["default"] = {"BACKEND": "storages.backends.s3.S3Storage"}

    AWS_PRIVATE_STORAGE_BUCKET_NAME = env.str("AWS_PRIVATE_STORAGE_BUCKET_NAME", default="")
    STORAGES["private"] = {
        "BACKEND": "storages.backends.s3.S3Storage",
        "OPTIONS": {
            "bucket_name": AWS_PRIVATE_STORAGE_BUCKET_NAME,
            "default_acl": "private",
            "querystring_auth": True,
            "querystring_expire": env.int("KYC_SIGNED_URL_TTL", default=600),
            "custom_domain": None,
            "file_overwrite": False,
        },
    }

# ----------------------------------------------------------------------------
# Django REST Framework
# ----------------------------------------------------------------------------
REST_FRAMEWORK = {
    "DEFAULT_VERSIONING_CLASS": "rest_framework.versioning.URLPathVersioning",
    "DEFAULT_VERSION": "v1",
    "ALLOWED_VERSIONS": ["v1"],
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.AllowAny",),
    "DEFAULT_PAGINATION_CLASS": "apps.common.pagination.DefaultCursorPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_FILTER_BACKENDS": ("django_filters.rest_framework.DjangoFilterBackend",),
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "EXCEPTION_HANDLER": "apps.common.exceptions.custom_exception_handler",
    "DEFAULT_RENDERER_CLASSES": ("rest_framework.renderers.JSONRenderer",),
    "TEST_REQUEST_DEFAULT_FORMAT": "json",
    "DEFAULT_THROTTLE_CLASSES": (
        "apps.common.throttling.DefaultAnonThrottle",
        "apps.common.throttling.DefaultUserThrottle",
    ),
    "DEFAULT_THROTTLE_RATES": {
        "anon": env.str("ANON_THROTTLE", default="10000/min"),
        "user": env.str("USER_THROTTLE", default="10000/min"),
        "support_tickets": env.str("SUPPORT_TICKET_THROTTLE", default="1000/hour"),
        "otp_phone_resend": env.str("OTP_PHONE_RESEND_THROTTLE", default="1000/min"),
        "otp_phone_hourly": env.str("OTP_PHONE_HOURLY_THROTTLE", default="1000/hour"),
        "otp_ip": env.str("OTP_IP_THROTTLE", default="1000/hour"),
        "password_login_phone": env.str("PASSWORD_LOGIN_PHONE_THROTTLE", default="1000/hour"),
        "password_login_ip": env.str("PASSWORD_LOGIN_IP_THROTTLE", default="1000/hour"),
        "kyc_submit": env.str("KYC_SUBMIT_THROTTLE", default="1000/day"),
        "contact_reveal": env.str("CONTACT_REVEAL_THROTTLE", default="1000/hour"),
        "review_create": env.str("REVIEW_CREATE_THROTTLE", default="1000/day"),
        "media_upload": env.str("MEDIA_UPLOAD_THROTTLE", default="1000/hour"),
        "wallet_topup": env.str("WALLET_TOPUP_THROTTLE", default="1000/hour"),
        "message_send": env.str("MESSAGE_SEND_THROTTLE", default="30/min"),
    },
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(
        minutes=env.int("JWT_ACCESS_TOKEN_LIFETIME_MINUTES", default=15)
    ),
    "REFRESH_TOKEN_LIFETIME": timedelta(
        days=env.int("JWT_REFRESH_TOKEN_LIFETIME_DAYS", default=30)
    ),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN": True,
    "SIGNING_KEY": env.str("JWT_SIGNING_KEY", default=SECRET_KEY) or SECRET_KEY,
    "AUTH_HEADER_TYPES": ("Bearer",),
}

# ----------------------------------------------------------------------------
# Вход по SMS-коду (OTP)
# ----------------------------------------------------------------------------
OTP_CODE_LENGTH = 4
OTP_CODE_TTL_SECONDS = env.int("OTP_CODE_TTL_SECONDS", default=300)
OTP_RESEND_AFTER_SECONDS = env.int("OTP_RESEND_AFTER_SECONDS", default=60)
OTP_MAX_ATTEMPTS = env.int("OTP_MAX_ATTEMPTS", default=5)
OTP_TEST_PHONES = env.list("OTP_TEST_PHONES", default=[])
OTP_DEBUG_CODE = env.str("OTP_DEBUG_CODE", default="0000")
OTP_RETENTION_DAYS = env.int("OTP_RETENTION_DAYS", default=7)
OTP_SMS_TEMPLATE = env.str("OTP_SMS_TEMPLATE", default="house_kgz: код {code}")

# ----------------------------------------------------------------------------
# Платежи и пополнение кошелька
# ----------------------------------------------------------------------------
TOPUP_BONUS_RATE = env.float("TOPUP_BONUS_RATE", default=0.10)
PAYMENT_EXPIRY_MINUTES = env.int("PAYMENT_EXPIRY_MINUTES", default=30)
PAYMENT_MIN_AMOUNT = env.int("PAYMENT_MIN_AMOUNT", default=1)
PAYMENT_MAX_AMOUNT = env.int("PAYMENT_MAX_AMOUNT", default=500_000)
PAYMENT_IDEMPOTENCY_TTL_HOURS = env.int("PAYMENT_IDEMPOTENCY_TTL_HOURS", default=24)

PAYMENT_PROVIDER = env.str("PAYMENT_PROVIDER", default="mock")
PAYMENT_WEBHOOK_SECRET = env.str("PAYMENT_WEBHOOK_SECRET", default="")
PAYMENT_RETURN_URL = env.str("PAYMENT_RETURN_URL", default="housekgz://wallet/topup")

BANK_PAYMENT_API_URL = env.str("BANK_PAYMENT_API_URL", default="")
BANK_PAYMENT_MERCHANT_ID = env.str("BANK_PAYMENT_MERCHANT_ID", default="")
BANK_PAYMENT_SECRET = env.str("BANK_PAYMENT_SECRET", default="")
BANK_PAYMENT_TIMEOUT = env.int("BANK_PAYMENT_TIMEOUT", default=15)

FINIK_API_KEY = env.str("FINIK_API_KEY", default="")
FINIK_ACCOUNT_ID = env.str("FINIK_ACCOUNT_ID", default="")
FINIK_SECRET_KEY = env.str("FINIK_SECRET_KEY", default="")
FINIK_CALLBACK_URL = env.str("FINIK_CALLBACK_URL", default="")
FINIK_BETA = env.bool("FINIK_BETA", default=False)
FINIK_GRAPHQL_URL = env.str("FINIK_GRAPHQL_URL", default="")
FINIK_TIMEOUT_SECONDS = env.int("FINIK_TIMEOUT_SECONDS", default=15)
FINIK_CHECKOUT_URL_TEMPLATE = env.str(
    "FINIK_CHECKOUT_URL_TEMPLATE", default="https://pay.finik.kg/checkout/{item_id}"
)
FINIK_REQUIRE_VERIFICATION = env.bool("FINIK_REQUIRE_VERIFICATION", default=True)
FINIK_TEST_AMOUNT_KGS = env.str("FINIK_TEST_AMOUNT_KGS", default="").strip()
FINIK_TEST_USER_IDS = env.list("FINIK_TEST_USER_IDS", default=[])

# ----------------------------------------------------------------------------
# Push-уведомления (FCM)
# ----------------------------------------------------------------------------
FCM_CREDENTIALS_FILE = env.str("FCM_CREDENTIALS_FILE", default="")
FCM_CREDENTIALS_BASE64 = env.str("FCM_CREDENTIALS_BASE64", default="")

# ----------------------------------------------------------------------------
# Каталог
# ----------------------------------------------------------------------------
FALLBACK_USD_KGS_RATE = env.float("FALLBACK_USD_KGS_RATE", default=87.5)
NBKR_RATES_URL = env.str("NBKR_RATES_URL", default="https://www.nbkr.kg/XML/daily.xml")
NBKR_TIMEOUT = env.int("NBKR_TIMEOUT", default=10)

FREE_ACTIVE_LISTINGS = env.int("FREE_ACTIVE_LISTINGS", default=3)
LISTING_ACTIVE_DAYS = env.int("LISTING_ACTIVE_DAYS", default=30)
LISTING_EXPIRY_WARNING_DAYS = env.int("LISTING_EXPIRY_WARNING_DAYS", default=3)
LISTING_BUMP_COOLDOWN_HOURS = env.int("LISTING_BUMP_COOLDOWN_HOURS", default=24)

VIEW_HISTORY_RETENTION_DAYS = env.int("VIEW_HISTORY_RETENTION_DAYS", default=90)
CATALOG_DEFAULT_PRICE_MIN = env.int("CATALOG_DEFAULT_PRICE_MIN", default=30_000)
CATALOG_DEFAULT_PRICE_MAX = env.int("CATALOG_DEFAULT_PRICE_MAX", default=350_000)

# ----------------------------------------------------------------------------
# Модерация объявлений
# ----------------------------------------------------------------------------
MODERATION_PRICE_WINDOW_DAYS = env.int("MODERATION_PRICE_WINDOW_DAYS", default=90)
MODERATION_PRICE_MIN_PEERS = env.int("MODERATION_PRICE_MIN_PEERS", default=10)
MODERATION_PRICE_SIGMAS = env.float("MODERATION_PRICE_SIGMAS", default=3.0)
MODERATION_PRICE_FALLBACK_RATIO = env.float("MODERATION_PRICE_FALLBACK_RATIO", default=0.5)

MODERATION_DUPLICATE_AREA_SPREAD = env.float("MODERATION_DUPLICATE_AREA_SPREAD", default=2.0)
MODERATION_DUPLICATE_PRICE_RATIO = env.float("MODERATION_DUPLICATE_PRICE_RATIO", default=0.03)

MODERATION_PHASH_MAX_DISTANCE = env.int("MODERATION_PHASH_MAX_DISTANCE", default=5)
MODERATION_PHASH_SCAN_LIMIT = env.int("MODERATION_PHASH_SCAN_LIMIT", default=5000)

MODERATION_REPORTS_THRESHOLD = env.int("MODERATION_REPORTS_THRESHOLD", default=3)
MODERATION_HISTORY_LIMIT = env.int("MODERATION_HISTORY_LIMIT", default=10)

# ----------------------------------------------------------------------------
# Медиафайлы объявления
# ----------------------------------------------------------------------------
LISTING_PHOTO_MIME_TYPES = env.list(
    "LISTING_PHOTO_MIME_TYPES", default=["image/jpeg", "image/png", "image/heic"]
)
LISTING_VIDEO_MIME_TYPES = env.list(
    "LISTING_VIDEO_MIME_TYPES", default=["video/mp4", "video/quicktime"]
)
LISTING_PHOTO_MAX_SIZE = env.int("LISTING_PHOTO_MAX_SIZE", default=15 * 1024 * 1024)
LISTING_VIDEO_MAX_SIZE = env.int("LISTING_VIDEO_MAX_SIZE", default=200 * 1024 * 1024)
LISTING_PHOTO_MIN_WIDTH = env.int("LISTING_PHOTO_MIN_WIDTH", default=600)
LISTING_PHOTO_MIN_HEIGHT = env.int("LISTING_PHOTO_MIN_HEIGHT", default=400)
LISTING_VIDEO_MAX_DURATION = env.int("LISTING_VIDEO_MAX_DURATION", default=180)

LISTING_IMAGE_VARIANTS = {
    "thumb": env.int("LISTING_THUMB_SIZE", default=400),
    "medium": env.int("LISTING_MEDIUM_SIZE", default=1080),
    "original": env.int("LISTING_ORIGINAL_SIZE", default=2560),
}
LISTING_WEBP_QUALITY = env.int("LISTING_WEBP_QUALITY", default=82)
LISTING_JPEG_QUALITY = env.int("LISTING_JPEG_QUALITY", default=85)

FFPROBE_BIN = env.str("FFPROBE_BIN", default="ffprobe")
FFMPEG_BIN = env.str("FFMPEG_BIN", default="ffmpeg")
FFPROBE_TIMEOUT = env.int("FFPROBE_TIMEOUT", default=30)
FFMPEG_TIMEOUT = env.int("FFMPEG_TIMEOUT", default=60)

# ----------------------------------------------------------------------------
# Верификация личности (KYC)
# ----------------------------------------------------------------------------
KYC_MAX_FILE_SIZE = env.int("KYC_MAX_FILE_SIZE", default=10 * 1024 * 1024)
KYC_MIN_WIDTH = env.int("KYC_MIN_WIDTH", default=800)
KYC_MIN_HEIGHT = env.int("KYC_MIN_HEIGHT", default=600)
KYC_ALLOWED_MIME_TYPES = env.list(
    "KYC_ALLOWED_MIME_TYPES", default=["image/jpeg", "image/png", "image/heic"]
)
KYC_SIGNED_URL_TTL = env.int("KYC_SIGNED_URL_TTL", default=600)
KYC_PURGE_AFTER_DAYS = env.int("KYC_PURGE_AFTER_DAYS", default=30)

# ----------------------------------------------------------------------------
# SMS-провайдер
# ----------------------------------------------------------------------------
SMS_PROVIDER = env.str("SMS_PROVIDER", default="console")
SMS_API_URL = env.str("SMS_API_URL", default="")
SMS_API_TOKEN = env.str("SMS_API_TOKEN", default="")
SMS_TIMEOUT = env.int("SMS_TIMEOUT", default=10)
SMS_RETRIES = env.int("SMS_RETRIES", default=2)
SMS_RETRY_BACKOFF = env.float("SMS_RETRY_BACKOFF", default=1.0)

# Telegram Gateway API
TELEGRAM_GATEWAY_TOKEN = env.str("TELEGRAM_GATEWAY_TOKEN", default="")
TELEGRAM_GATEWAY_BASE_URL = env.str(
    "TELEGRAM_GATEWAY_BASE_URL", default="https://gatewayapi.telegram.org"
)
TELEGRAM_GATEWAY_TTL = env.int("TELEGRAM_GATEWAY_TTL", default=300)
TELEGRAM_GATEWAY_TIMEOUT = env.int("TELEGRAM_GATEWAY_TIMEOUT", default=10)

# ----------------------------------------------------------------------------
# drf-spectacular (OpenAPI)
# ----------------------------------------------------------------------------
SPECTACULAR_SETTINGS = {
    "TITLE": "house_kgz API",
    "DESCRIPTION": (
        "REST API мобильного приложения-агрегатора недвижимости house_kgz.\n\n"
        "Аутентификация — JWT (заголовок `Authorization: Bearer <access>`).\n"
        "Все ошибки возвращаются в формате "
        '`{"error": {"code": ..., "message": ..., "details": ...}}`.'
    ),
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "SCHEMA_PATH_PREFIX": "/api/v[0-9]+",
    "COMPONENT_SPLIT_REQUEST": True,
    "SORT_OPERATIONS": False,
    "ENUM_NAME_OVERRIDES": {
        "PropertyKindEnum": "apps.catalog.enums.PropertyKind.choices",
        "MediaKindEnum": "apps.catalog.enums.MediaKind.choices",
        "ListingStatusEnum": "apps.catalog.enums.ListingStatus.choices",
        "SellerKindEnum": "apps.catalog.enums.SellerKind.choices",
        "WalletEntryKindEnum": "apps.common.enums.WalletEntryKind.choices",
        "ModerationStatusEnum": "apps.catalog.enums.ModerationStatus.choices",
        "PromotionStatusEnum": "apps.billing.models.PromotionStatus.choices",
        "SubscriptionStatusEnum": "apps.billing.models.SubscriptionStatus.choices",
        "ReviewStatusEnum": "apps.users.models.ReviewStatus.choices",
        "VerificationStatusEnum": "apps.users.models.VerificationStatus.choices",
    },
}

# ----------------------------------------------------------------------------
# Почта
# ----------------------------------------------------------------------------
EMAIL_BACKEND = env.str("EMAIL_BACKEND", default="django.core.mail.backends.smtp.EmailBackend")
EMAIL_HOST = env.str("EMAIL_HOST", default="localhost")
EMAIL_PORT = env.int("EMAIL_PORT", default=25)
EMAIL_HOST_USER = env.str("EMAIL_HOST_USER", default="")
EMAIL_HOST_PASSWORD = env.str("EMAIL_HOST_PASSWORD", default="")
EMAIL_USE_TLS = env.bool("EMAIL_USE_TLS", default=False)
DEFAULT_FROM_EMAIL = env.str("DEFAULT_FROM_EMAIL", default="noreply@house.kg")
SUPPORT_NOTIFY_EMAILS = env.list("SUPPORT_NOTIFY_EMAILS", default=[])

# ----------------------------------------------------------------------------
# Celery
# ----------------------------------------------------------------------------
CELERY_BROKER_URL = env.str("CELERY_BROKER_URL", default=REDIS_URL)
CELERY_RESULT_BACKEND = env.str("CELERY_RESULT_BACKEND", default=REDIS_URL)
CELERY_TASK_DEFAULT_QUEUE = "default"
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TIMEZONE = TIME_ZONE
CELERY_TASK_TRACK_STARTED = True
CELERY_TASK_TIME_LIMIT = env.int("CELERY_TASK_TIME_LIMIT", default=300)
CELERY_TASK_ALWAYS_EAGER = env.bool("CELERY_TASK_ALWAYS_EAGER", default=False)
CELERY_BEAT_SCHEDULER = "django_celery_beat.schedulers:DatabaseScheduler"

CELERY_BEAT_SCHEDULE = {
    "purge-old-otp-codes": {
        "task": "users.purge_old_otp_codes",
        "schedule": crontab(hour="3", minute="15"),
        "options": {"queue": CELERY_TASK_DEFAULT_QUEUE},
    },
    "expire-listings": {
        "task": "catalog.expire_listings",
        "schedule": crontab(hour="5", minute="0"),
        "options": {"queue": CELERY_TASK_DEFAULT_QUEUE},
    },
    "expire-payments": {
        "task": "billing.expire_payments",
        "schedule": crontab(minute="*/5"),
        "options": {"queue": CELERY_TASK_DEFAULT_QUEUE},
    },
    "notify-price-drop": {
        "task": "notifications.notify_price_drop",
        "schedule": crontab(hour="10", minute="0"),
        "options": {"queue": CELERY_TASK_DEFAULT_QUEUE},
    },
    "purge-view-history": {
        "task": "engagement.purge_view_history",
        "schedule": crontab(hour="4", minute="20"),
        "options": {"queue": CELERY_TASK_DEFAULT_QUEUE},
    },
    "notify-saved-filters": {
        "task": "engagement.notify_saved_filters",
        "schedule": crontab(minute="10"),
        "options": {"queue": CELERY_TASK_DEFAULT_QUEUE},
    },
    "fetch-exchange-rates": {
        "task": "catalog.fetch_exchange_rates",
        "schedule": crontab(hour="9", minute="0"),
        "options": {"queue": CELERY_TASK_DEFAULT_QUEUE},
    },
    "expire-promotions": {
        "task": "billing.expire_promotions",
        "schedule": crontab(minute="5"),
        "options": {"queue": CELERY_TASK_DEFAULT_QUEUE},
    },
    "flush-impressions": {
        "task": "catalog.flush_impressions",
        "schedule": crontab(minute="*/5"),
        "options": {"queue": CELERY_TASK_DEFAULT_QUEUE},
    },
    "process-subscriptions": {
        "task": "billing.process_subscriptions",
        "schedule": crontab(hour="6", minute="0"),
        "options": {"queue": CELERY_TASK_DEFAULT_QUEUE},
    },
    "auto-bump-listings": {
        "task": "billing.auto_bump_listings",
        "schedule": crontab(hour="6", minute="30"),
        "options": {"queue": CELERY_TASK_DEFAULT_QUEUE},
    },
    "refresh-metrics": {
        "task": "common.refresh_metrics",
        "schedule": crontab(minute="*/2"),
        "options": {"queue": CELERY_TASK_DEFAULT_QUEUE},
    },
    "purge-identity-files": {
        "task": "users.purge_identity_files",
        "schedule": crontab(hour="3", minute="45"),
        "options": {"queue": CELERY_TASK_DEFAULT_QUEUE},
    },
}

# ----------------------------------------------------------------------------
# Админка, служебные пути и внутренняя сеть
# ----------------------------------------------------------------------------
ADMIN_URL_PATH = env.str("ADMIN_URL_PATH", default="admin/").strip("/") + "/"
ALLOWED_ADMIN_IPS = env.list("ALLOWED_ADMIN_IPS", default=[])
ADMIN_REQUIRE_OTP = env.bool("ADMIN_REQUIRE_OTP", default=False)

INTERNAL_ONLY_PATHS = ("/metrics",)
INTERNAL_NETWORKS = env.list(
    "INTERNAL_NETWORKS",
    default=["127.0.0.1/32", "::1/128", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],
)

# ----------------------------------------------------------------------------
# Персональные данные
# ----------------------------------------------------------------------------
FIELD_ENCRYPTION_KEY = env.str("FIELD_ENCRYPTION_KEY", default="")
CONSENT_DOCUMENT_VERSION = env.str("CONSENT_DOCUMENT_VERSION", default="1")
DATA_EXPORT_COOLDOWN_HOURS = env.int("DATA_EXPORT_COOLDOWN_HOURS", default=24)
DATA_EXPORT_URL_TTL = env.int("DATA_EXPORT_URL_TTL", default=24 * 3600)

# ----------------------------------------------------------------------------
# CORS / CSRF (Production & Development)
# ----------------------------------------------------------------------------
CORS_ALLOW_ALL_ORIGINS = env.bool("CORS_ALLOW_ALL_ORIGINS", default=True)
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_METHODS = ["*"]
CORS_ALLOW_HEADERS = ["*"]
CSRF_TRUSTED_ORIGINS = env.list(
    "CSRF_TRUSTED_ORIGINS",
    default=["https://*", "http://*"],
)

# ----------------------------------------------------------------------------
# Безопасность и Cookie (Production)
# ----------------------------------------------------------------------------
SECURE_SSL_REDIRECT = env.bool("SECURE_SSL_REDIRECT", default=False)
SECURE_HSTS_SECONDS = env.int("SECURE_HSTS_SECONDS", default=31536000)
SECURE_HSTS_INCLUDE_SUBDOMAINS = env.bool("SECURE_HSTS_INCLUDE_SUBDOMAINS", default=True)
SECURE_HSTS_PRELOAD = env.bool("SECURE_HSTS_PRELOAD", default=True)
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_REFERRER_POLICY = "strict-origin-when-cross-origin"
X_FRAME_OPTIONS = "DENY"
SECURE_CROSS_ORIGIN_OPENER_POLICY = "same-origin"

SESSION_COOKIE_SECURE = env.bool("SESSION_COOKIE_SECURE", default=False)
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_SECURE = env.bool("CSRF_COOKIE_SECURE", default=False)
CSRF_COOKIE_HTTPONLY = True

SESSION_COOKIE_AGE = env.int("SESSION_COOKIE_AGE", default=8 * 3600)
SESSION_EXPIRE_AT_BROWSER_CLOSE = True
SESSION_COOKIE_SAMESITE = "Lax"
CSRF_COOKIE_SAMESITE = "Lax"

# ----------------------------------------------------------------------------
# CSP — Content Security Policy (для админки и Swagger)
# ----------------------------------------------------------------------------
CONTENT_SECURITY_POLICY = {
    "DIRECTIVES": {
        "default-src": ["'self'"],
        "script-src": ["'self'", "'unsafe-inline'"],
        "style-src": ["'self'", "'unsafe-inline'"],
        "img-src": ["'self'", "data:", env.str("MEDIA_CSP_ORIGIN", default="*")],
        "font-src": ["'self'", "data:"],
        "connect-src": ["'self'"],
        "frame-ancestors": ["'none'"],
        "form-action": ["'self'"],
        "base-uri": ["'self'"],
        "object-src": ["'none'"],
    }
}

# ----------------------------------------------------------------------------
# Наблюдаемость
# ----------------------------------------------------------------------------
SENTRY_DSN = env.str("SENTRY_DSN", default="")
SENTRY_ENVIRONMENT = env.str("SENTRY_ENVIRONMENT", default="production")
SENTRY_TRACES_SAMPLE_RATE = env.float("SENTRY_TRACES_SAMPLE_RATE", default=0.0)
SENTRY_PROFILES_SAMPLE_RATE = env.float("SENTRY_PROFILES_SAMPLE_RATE", default=0.0)

# ----------------------------------------------------------------------------
# Логирование
# ----------------------------------------------------------------------------
from apps.common.logging import foreign_pre_chain, stdlib_renderer  # noqa: E402

LOG_JSON = env.bool("LOG_JSON", default=False)
LOG_LEVEL = env.str("DJANGO_LOG_LEVEL", default="INFO")

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "filters": {
        "mask_pii": {"()": "apps.common.logging.PiiMaskingFilter"},
    },
    "formatters": {
        "verbose": {
            "format": "[{asctime}] {levelname} {name}: {message}",
            "style": "{",
        },
        "structured": {
            "()": "structlog.stdlib.ProcessorFormatter",
            "processor": stdlib_renderer,
            "foreign_pre_chain": foreign_pre_chain(),
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "structured" if LOG_JSON else "verbose",
            "filters": ["mask_pii"],
        },
    },
    "root": {"handlers": ["console"], "level": LOG_LEVEL},
    "loggers": {
        "django.db.backends": {"level": "WARNING", "handlers": ["console"], "propagate": False},
        "urllib3": {"level": "WARNING", "handlers": ["console"], "propagate": False},
    },
}
