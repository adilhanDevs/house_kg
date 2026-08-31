"""Базовые настройки Django для проекта house_kgz.

Все окружения (local / production / test) наследуются от этого модуля.
Любой секрет читается только из переменных окружения — см. .env.example.
"""

from datetime import timedelta
from pathlib import Path

import environ
from celery.schedules import crontab

# backend/config/settings/base.py -> backend/
BASE_DIR = Path(__file__).resolve().parents[2]

env = environ.Env(
    DJANGO_DEBUG=(bool, False),
    DJANGO_ALLOWED_HOSTS=(list, ["localhost", "127.0.0.1"]),
    DJANGO_TIME_ZONE=(str, "Asia/Bishkek"),
    CELERY_TASK_ALWAYS_EAGER=(bool, False),
    USE_S3=(bool, False),
    AWS_S3_ENDPOINT_URL=(str, ""),
    AWS_S3_CUSTOM_DOMAIN=(str, ""),
    AWS_QUERYSTRING_AUTH=(bool, False),
    JWT_ACCESS_TOKEN_LIFETIME_MINUTES=(int, 15),
    JWT_REFRESH_TOKEN_LIFETIME_DAYS=(int, 30),
)

# Читаем backend/.env, если он есть (в docker-compose переменные приходят из окружения).
env_file = BASE_DIR / ".env"
if env_file.exists():
    env.read_env(str(env_file))

# ----------------------------------------------------------------------------
# Ядро
# ----------------------------------------------------------------------------
SECRET_KEY = env("DJANGO_SECRET_KEY")
DEBUG = env("DJANGO_DEBUG")
ALLOWED_HOSTS = env("DJANGO_ALLOWED_HOSTS")

ROOT_URLCONF = "config.urls"
AUTH_USER_MODEL = "users.User"
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

DJANGO_APPS = [
    # Своя админка: обязательный второй фактор для персонала.
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
    # 2FA для персонала: доступ к ПДн граждан не защищается одним паролем.
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
]

INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS

MIDDLEWARE = [
    # Метрики django-prometheus снаружи: они должны видеть полное время
    # запроса, включая работу остальных middleware.
    "django_prometheus.middleware.PrometheusBeforeMiddleware",
    "apps.common.middleware.RequestContextMiddleware",
    "apps.common.middleware.InternalOnlyMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    # Сразу после аутентификации: OTPMiddleware выставляет request.user.is_verified.
    "django_otp.middleware.OTPMiddleware",
    "apps.common.middleware.AdminIpRestrictionMiddleware",
    "apps.common.middleware.UserContextMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
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
    "default": env.db("DATABASE_URL"),
}
DATABASES["default"]["ATOMIC_REQUESTS"] = False
DATABASES["default"]["CONN_MAX_AGE"] = env.int("DATABASE_CONN_MAX_AGE", default=60)

# SQLite целевой БД быть не может (см. CLAUDE.md), но на демо-хостингах он
# иногда всё же оказывается в DATABASE_URL. Долгоживущее соединение к файлу на
# сетевой ФС там протухает и даёт «disk I/O error» на первой же записи, поэтому
# соединение не переиспользуется, а блокировка ждёт, а не падает сразу.
if "sqlite" in DATABASES["default"].get("ENGINE", ""):
    DATABASES["default"]["CONN_MAX_AGE"] = 0
    DATABASES["default"].setdefault("OPTIONS", {})
    DATABASES["default"]["OPTIONS"].setdefault("timeout", 20)

# ----------------------------------------------------------------------------
# Кэш (Redis)
# ----------------------------------------------------------------------------
REDIS_URL = env("REDIS_URL")

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
TIME_ZONE = env("DJANGO_TIME_ZONE")
USE_I18N = True
USE_TZ = True

# ----------------------------------------------------------------------------
# Статика и медиа
# ----------------------------------------------------------------------------
STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

# Приватные файлы (документы KYC) лежат ОТДЕЛЬНО от публичных медиа:
# другой каталог вне MEDIA_ROOT локально и другой бакет в облаке.
PRIVATE_MEDIA_ROOT = env.path("PRIVATE_MEDIA_ROOT", default=BASE_DIR / "private-media")

USE_S3 = env("USE_S3")

STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
    # Хранилище без публичных URL: base_url не задан, поэтому storage.url()
    # для этих файлов невозможен — только подписанная ссылка (см. apps/users/kyc.py).
    "private": {
        "BACKEND": "apps.common.storages.PrivateFileSystemStorage",
        "OPTIONS": {"location": str(PRIVATE_MEDIA_ROOT)},
    },
}

# Алиас приватного хранилища — им пользуются FileField-ы моделей KYC.
PRIVATE_FILE_STORAGE = "private"

if USE_S3:
    AWS_ACCESS_KEY_ID = env("AWS_ACCESS_KEY_ID")
    AWS_SECRET_ACCESS_KEY = env("AWS_SECRET_ACCESS_KEY")
    AWS_STORAGE_BUCKET_NAME = env("AWS_STORAGE_BUCKET_NAME")
    AWS_S3_REGION_NAME = env("AWS_S3_REGION_NAME", default="us-east-1")
    AWS_S3_ENDPOINT_URL = env("AWS_S3_ENDPOINT_URL") or None
    AWS_S3_CUSTOM_DOMAIN = env("AWS_S3_CUSTOM_DOMAIN") or None
    AWS_QUERYSTRING_AUTH = env("AWS_QUERYSTRING_AUTH")
    AWS_DEFAULT_ACL = None
    AWS_S3_FILE_OVERWRITE = False
    STORAGES["default"] = {"BACKEND": "storages.backends.s3.S3Storage"}

    # Отдельный бакет для KYC: block-public-access, подписанные ссылки,
    # никакого CDN-домена. Складывать эти файлы в бакет медиа объявлений нельзя
    # даже в отдельную папку — политики доступа у бакетов разные.
    AWS_PRIVATE_STORAGE_BUCKET_NAME = env("AWS_PRIVATE_STORAGE_BUCKET_NAME")
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
    # Права выставляются явно в каждой вьюхе.
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
    },
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=env("JWT_ACCESS_TOKEN_LIFETIME_MINUTES")),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=env("JWT_REFRESH_TOKEN_LIFETIME_DAYS")),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN": True,
    "SIGNING_KEY": env("JWT_SIGNING_KEY", default=SECRET_KEY),
    "AUTH_HEADER_TYPES": ("Bearer",),
}

# ----------------------------------------------------------------------------
# Вход по SMS-коду (OTP)
# ----------------------------------------------------------------------------
OTP_CODE_LENGTH = 4
OTP_CODE_TTL_SECONDS = env.int("OTP_CODE_TTL_SECONDS", default=300)
OTP_RESEND_AFTER_SECONDS = env.int("OTP_RESEND_AFTER_SECONDS", default=60)
OTP_MAX_ATTEMPTS = env.int("OTP_MAX_ATTEMPTS", default=5)
# Номера, для которых код всегда OTP_DEBUG_CODE и SMS не отправляется
# (ревью в сторах, автотесты). В DEBUG так работают все номера.
OTP_TEST_PHONES = env.list("OTP_TEST_PHONES", default=[])
OTP_DEBUG_CODE = env.str("OTP_DEBUG_CODE", default="0000")
OTP_RETENTION_DAYS = env.int("OTP_RETENTION_DAYS", default=7)
OTP_SMS_TEMPLATE = env.str("OTP_SMS_TEMPLATE", default="house_kgz: код {code}")

# ----------------------------------------------------------------------------
# Платежи и пополнение кошелька
# ----------------------------------------------------------------------------
# Бонус за пополнение: 12 000 сом -> 12 000 кирпичей + 1 200 бонусных.
TOPUP_BONUS_RATE = env.float("TOPUP_BONUS_RATE", default=0.10)
# Сколько минут счёт ждёт оплаты.
PAYMENT_EXPIRY_MINUTES = env.int("PAYMENT_EXPIRY_MINUTES", default=30)
# Границы суммы пополнения, сом.
PAYMENT_MIN_AMOUNT = env.int("PAYMENT_MIN_AMOUNT", default=100)
PAYMENT_MAX_AMOUNT = env.int("PAYMENT_MAX_AMOUNT", default=500_000)
# Сколько живёт ключ идемпотентности пополнения.
PAYMENT_IDEMPOTENCY_TTL_HOURS = env.int("PAYMENT_IDEMPOTENCY_TTL_HOURS", default=24)

# Активный провайдер: mock (разработка) или код банка.
PAYMENT_PROVIDER = env.str("PAYMENT_PROVIDER", default="mock")
# Общий секрет для проверки подписи вебхука.
PAYMENT_WEBHOOK_SECRET = env.str("PAYMENT_WEBHOOK_SECRET", default="")
# Куда клиент возвращается после оплаты.
PAYMENT_RETURN_URL = env.str("PAYMENT_RETURN_URL", default="housekgz://wallet/topup")

# Шлюз банка (заполняется при подключении реального провайдера).
BANK_PAYMENT_API_URL = env.str("BANK_PAYMENT_API_URL", default="")
BANK_PAYMENT_MERCHANT_ID = env.str("BANK_PAYMENT_MERCHANT_ID", default="")
BANK_PAYMENT_SECRET = env.str("BANK_PAYMENT_SECRET", default="")
BANK_PAYMENT_TIMEOUT = env.int("BANK_PAYMENT_TIMEOUT", default=15)

# Шлюз Finik Pay (finik.kg / averspay.kg).
# Имена совпадают с тем, что читает apps/billing/providers/finik.py.
# Ключ и идентификатор счёта выдаёт менеджер Finik.
FINIK_API_KEY = env.str("FINIK_API_KEY", default="")
FINIK_ACCOUNT_ID = env.str("FINIK_ACCOUNT_ID", default="")
# Секрет для HMAC-подписи колбэка. Если Finik подпись не шлёт, оставьте пустым:
# подлинность тогда проверяется обратным запросом в Finik (см. ниже).
FINIK_SECRET_KEY = env.str("FINIK_SECRET_KEY", default="")
# Адрес, который Finik дёргает после оплаты.
FINIK_CALLBACK_URL = env.str("FINIK_CALLBACK_URL", default="")
# Песочница Finik: beta-домены вместо боевых.
FINIK_BETA = env.bool("FINIK_BETA", default=False)
# Полный URL GraphQL. Задаётся, только если Finik выдал нестандартный адрес.
FINIK_GRAPHQL_URL = env.str("FINIK_GRAPHQL_URL", default="")
FINIK_TIMEOUT_SECONDS = env.int("FINIK_TIMEOUT_SECONDS", default=15)
# Шаблон ссылки на оплату. Finik может выдать свой домен — тогда меняется здесь,
# без правок кода. Подстановка: {item_id}.
FINIK_CHECKOUT_URL_TEMPLATE = env.str(
    "FINIK_CHECKOUT_URL_TEMPLATE", default="https://pay.finik.kg/checkout/{item_id}"
)
# Колбэк без HMAC-подписи принимается, только если Finik подтвердил транзакцию
# обратным запросом. Выключать нельзя нигде, кроме тестов.
FINIK_REQUIRE_VERIFICATION = env.bool("FINIK_REQUIRE_VERIFICATION", default=True)

# ----------------------------------------------------------------------------
# Push-уведомления (FCM)
# ----------------------------------------------------------------------------
# Либо путь к service-account JSON, либо его содержимое в base64.
FCM_CREDENTIALS_FILE = env.str("FCM_CREDENTIALS_FILE", default="")
FCM_CREDENTIALS_BASE64 = env.str("FCM_CREDENTIALS_BASE64", default="")

# ----------------------------------------------------------------------------
# Каталог
# ----------------------------------------------------------------------------
# Резервный курс USD/KGS: используется, пока НБКР ни разу не ответил.
FALLBACK_USD_KGS_RATE = env.float("FALLBACK_USD_KGS_RATE", default=87.5)
# Откуда берём курсы валют.
NBKR_RATES_URL = env.str("NBKR_RATES_URL", default="https://www.nbkr.kg/XML/daily.xml")
NBKR_TIMEOUT = env.int("NBKR_TIMEOUT", default=10)

# Сколько активных объявлений можно держать бесплатно.
FREE_ACTIVE_LISTINGS = env.int("FREE_ACTIVE_LISTINGS", default=3)
# Сколько дней объявление висит активным после публикации.
LISTING_ACTIVE_DAYS = env.int("LISTING_ACTIVE_DAYS", default=30)
# За сколько дней предупреждать о снятии с публикации.
LISTING_EXPIRY_WARNING_DAYS = env.int("LISTING_EXPIRY_WARNING_DAYS", default=3)
# Как часто можно бесплатно поднимать объявление, часы.
LISTING_BUMP_COOLDOWN_HOURS = env.int("LISTING_BUMP_COOLDOWN_HOURS", default=24)

# Сколько дней храним историю просмотров.
VIEW_HISTORY_RETENTION_DAYS = env.int("VIEW_HISTORY_RETENTION_DAYS", default=90)

# Границы ползунка цены, когда активных объявлений в городе ещё нет.
CATALOG_DEFAULT_PRICE_MIN = env.int("CATALOG_DEFAULT_PRICE_MIN", default=30_000)
CATALOG_DEFAULT_PRICE_MAX = env.int("CATALOG_DEFAULT_PRICE_MAX", default=350_000)

# ----------------------------------------------------------------------------
# Модерация объявлений
# ----------------------------------------------------------------------------
# Окно, за которое считается медиана цены по району, дни.
MODERATION_PRICE_WINDOW_DAYS = env.int("MODERATION_PRICE_WINDOW_DAYS", default=90)
# Меньше этого числа соседей — проверка цены пропускается: медиана по пяти
# объектам ничего не значит, а ложная метка стоит модератору времени.
MODERATION_PRICE_MIN_PEERS = env.int("MODERATION_PRICE_MIN_PEERS", default=10)
MODERATION_PRICE_SIGMAS = env.float("MODERATION_PRICE_SIGMAS", default=3.0)
# Запасной порог, когда все соседи стоят одинаково и сигма нулевая.
MODERATION_PRICE_FALLBACK_RATIO = env.float("MODERATION_PRICE_FALLBACK_RATIO", default=0.5)

# Допуски поиска дубликата: площадь ±2 м², цена ±3 %.
MODERATION_DUPLICATE_AREA_SPREAD = env.float("MODERATION_DUPLICATE_AREA_SPREAD", default=2.0)
MODERATION_DUPLICATE_PRICE_RATIO = env.float("MODERATION_DUPLICATE_PRICE_RATIO", default=0.03)

# Порог расстояния Хэмминга для «то же самое фото» и предел сканирования.
MODERATION_PHASH_MAX_DISTANCE = env.int("MODERATION_PHASH_MAX_DISTANCE", default=5)
MODERATION_PHASH_SCAN_LIMIT = env.int("MODERATION_PHASH_SCAN_LIMIT", default=5000)

# Сколько неразрешённых жалоб снимают активное объявление с публикации.
MODERATION_REPORTS_THRESHOLD = env.int("MODERATION_REPORTS_THRESHOLD", default=3)
# Сколько прошлых отклонений автора показывать модератору.
MODERATION_HISTORY_LIMIT = env.int("MODERATION_HISTORY_LIMIT", default=10)

# ----------------------------------------------------------------------------
# Медиафайлы объявления
# ----------------------------------------------------------------------------
# Тип файла проверяется по содержимому; список — то, что принимает клиент.
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

# Максимальная сторона каждого варианта изображения, пиксели.
LISTING_IMAGE_VARIANTS = {
    "thumb": env.int("LISTING_THUMB_SIZE", default=400),
    "medium": env.int("LISTING_MEDIUM_SIZE", default=1080),
    "original": env.int("LISTING_ORIGINAL_SIZE", default=2560),
}
LISTING_WEBP_QUALITY = env.int("LISTING_WEBP_QUALITY", default=82)
LISTING_JPEG_QUALITY = env.int("LISTING_JPEG_QUALITY", default=85)

# Внешние утилиты для видео. Само видео не перекодируется — только читается.
FFPROBE_BIN = env.str("FFPROBE_BIN", default="ffprobe")
FFMPEG_BIN = env.str("FFMPEG_BIN", default="ffmpeg")
FFPROBE_TIMEOUT = env.int("FFPROBE_TIMEOUT", default=30)
FFMPEG_TIMEOUT = env.int("FFMPEG_TIMEOUT", default=60)

# ----------------------------------------------------------------------------
# Верификация личности (KYC)
# ----------------------------------------------------------------------------
# Ограничения на загружаемые документы.
KYC_MAX_FILE_SIZE = env.int("KYC_MAX_FILE_SIZE", default=10 * 1024 * 1024)
KYC_MIN_WIDTH = env.int("KYC_MIN_WIDTH", default=800)
KYC_MIN_HEIGHT = env.int("KYC_MIN_HEIGHT", default=600)
KYC_ALLOWED_MIME_TYPES = env.list(
    "KYC_ALLOWED_MIME_TYPES", default=["image/jpeg", "image/png", "image/heic"]
)
# Срок жизни подписанной ссылки на документ, секунды.
KYC_SIGNED_URL_TTL = env.int("KYC_SIGNED_URL_TTL", default=600)
# Через сколько дней после решения удаляются сами файлы.
KYC_PURGE_AFTER_DAYS = env.int("KYC_PURGE_AFTER_DAYS", default=30)

# ----------------------------------------------------------------------------
# SMS-провайдер
# ----------------------------------------------------------------------------
SMS_PROVIDER = env.str("SMS_PROVIDER", default="console")  # console | http
SMS_API_URL = env.str("SMS_API_URL", default="")
SMS_API_TOKEN = env.str("SMS_API_TOKEN", default="")
SMS_TIMEOUT = env.int("SMS_TIMEOUT", default=10)
SMS_RETRIES = env.int("SMS_RETRIES", default=2)
SMS_RETRY_BACKOFF = env.float("SMS_RETRY_BACKOFF", default=1.0)

# ----------------------------------------------------------------------------
# drf-spectacular
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
    # `kind` встречается и у объявления, и у медиа, и у операции кошелька —
    # подсказываем генератору, как назвать соответствующие enum'ы схемы.
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

# Кому уходят письма о новых обращениях в поддержку.
SUPPORT_NOTIFY_EMAILS = env.list("SUPPORT_NOTIFY_EMAILS", default=[])

# ----------------------------------------------------------------------------
# Celery
# ----------------------------------------------------------------------------
CELERY_BROKER_URL = env("CELERY_BROKER_URL", default=REDIS_URL)
CELERY_RESULT_BACKEND = env("CELERY_RESULT_BACKEND", default=REDIS_URL)
CELERY_TASK_DEFAULT_QUEUE = "default"
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TIMEZONE = TIME_ZONE
CELERY_TASK_TRACK_STARTED = True
CELERY_TASK_TIME_LIMIT = env.int("CELERY_TASK_TIME_LIMIT", default=300)
CELERY_TASK_ALWAYS_EAGER = env("CELERY_TASK_ALWAYS_EAGER")
CELERY_BEAT_SCHEDULER = "django_celery_beat.schedulers:DatabaseScheduler"

# Расписание синхронизируется в БД при старте beat (django-celery-beat).
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
        # 10:00 по Asia/Bishkek — CELERY_TIMEZONE совпадает с TIME_ZONE проекта.
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
        "schedule": crontab(minute="10"),  # каждый час в :10
        "options": {"queue": CELERY_TASK_DEFAULT_QUEUE},
    },
    "fetch-exchange-rates": {
        "task": "catalog.fetch_exchange_rates",
        # 09:00 по Asia/Bishkek — CELERY_TIMEZONE совпадает с TIME_ZONE проекта.
        "schedule": crontab(hour="9", minute="0"),
        "options": {"queue": CELERY_TASK_DEFAULT_QUEUE},
    },
    "expire-promotions": {
        "task": "billing.expire_promotions",
        "schedule": crontab(minute="5"),  # каждый час в :05
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
        # После обработки подписок: у истёкших фича уже не действует.
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
# Путь админки берётся из окружения: /admin/ сканируют боты по умолчанию.
ADMIN_URL_PATH = env.str("ADMIN_URL_PATH", default="admin/").strip("/") + "/"
# Список адресов, с которых пускают в админку. Пусто — без ограничения
# (так работает разработка); на проде обязателен, см. production.py.
ALLOWED_ADMIN_IPS = env.list("ALLOWED_ADMIN_IPS", default=[])
# Требовать ли подтверждение второго фактора при входе в админку.
# Локально удобно выключить, на проде — включено (см. production.py).
ADMIN_REQUIRE_OTP = env.bool("ADMIN_REQUIRE_OTP", default=False)

# Пути, доступные только из внутренней сети.
INTERNAL_ONLY_PATHS = ("/metrics",)
INTERNAL_NETWORKS = env.list(
    "INTERNAL_NETWORKS",
    default=["127.0.0.1/32", "::1/128", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],
)

# ----------------------------------------------------------------------------
# Персональные данные
# ----------------------------------------------------------------------------
# Ключ шифрования ИИН (Fernet, base64). Пустой — поле хранится как есть:
# так работают тесты и локальная разработка, на проде ключ обязателен.
FIELD_ENCRYPTION_KEY = env.str("FIELD_ENCRYPTION_KEY", default="")

# Актуальная версия документа о согласии на обработку ПДн.
CONSENT_DOCUMENT_VERSION = env.str("CONSENT_DOCUMENT_VERSION", default="1")
# Не чаще одного экспорта данных в сутки и ссылка живёт 24 часа.
DATA_EXPORT_COOLDOWN_HOURS = env.int("DATA_EXPORT_COOLDOWN_HOURS", default=24)
DATA_EXPORT_URL_TTL = env.int("DATA_EXPORT_URL_TTL", default=24 * 3600)

# ----------------------------------------------------------------------------
# Наблюдаемость
# ----------------------------------------------------------------------------
SENTRY_DSN = env.str("SENTRY_DSN", default="")
SENTRY_ENVIRONMENT = env.str("SENTRY_ENVIRONMENT", default="local")
SENTRY_TRACES_SAMPLE_RATE = env.float("SENTRY_TRACES_SAMPLE_RATE", default=0.0)
SENTRY_PROFILES_SAMPLE_RATE = env.float("SENTRY_PROFILES_SAMPLE_RATE", default=0.0)

# ----------------------------------------------------------------------------
# Логирование
# ----------------------------------------------------------------------------
# Импорт модуля логирования здесь безопасен: он не тянет ни моделей,
# ни настроек — только structlog и стандартную библиотеку.
from apps.common.logging import foreign_pre_chain, stdlib_renderer  # noqa: E402

# JSON-логи по умолчанию везде, кроме локальной разработки: их читает
# агрегатор, а не человек.
LOG_JSON = env.bool("LOG_JSON", default=True)
LOG_LEVEL = env.str("DJANGO_LOG_LEVEL", default="INFO")

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    # Фильтр висит на обработчике, а не на отдельных логгерах: через него
    # обязаны пройти и Django, и requests, и любая сторонняя библиотека.
    # Маскирование ПДн не может зависеть от того, вспомнил ли о нём автор кода.
    "filters": {
        "mask_pii": {"()": "apps.common.logging.PiiMaskingFilter"},
    },
    "formatters": {
        "verbose": {
            "format": "[{asctime}] {levelname} {name}: {message}",
            "style": "{",
        },
        "structured": {
            # Процессоры передаются объектами, а не путями: dictConfig не
            # резолвит строки внутри чужих формтеров.
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
        # Тело запроса к платёжному шлюзу логируем сами, с маскированием.
        "urllib3": {"level": "WARNING", "handlers": ["console"], "propagate": False},
    },
}
