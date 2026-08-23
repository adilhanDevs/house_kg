# Техническое задание: бэкенд для мобильного приложения «house_kgz»

**Стек:** Python 3.12 · Django 5 · Django REST Framework · PostgreSQL 16 · Redis · Celery
**Клиент:** Flutter-приложение (`flutter_app`, пакет `house_kgz`) — агрегатор недвижимости для рынка Кыргызстана
**Версия документа:** 1.0 · 20.08.2026

---

## Как пользоваться этим документом

Документ разбит на **фазы**, фазы — на **задачи**. У каждой задачи есть:

- **Цель** — что должно появиться в проекте
- **Требования** — что именно и как реализуется
- **Критерии приёмки** — по чему проверять, что задача закрыта
- **Промпт** — готовый текст, который вы отдаёте Claude Code

Промпты самодостаточны, но **перед первой задачей** положите в корень бэкенд-репозитория файл `CLAUDE.md` с содержимым раздела «Общий контекст проекта» (§1). Тогда Claude Code будет подхватывать соглашения автоматически, и промпты останутся короткими.

Задачи внутри фазы выполняются последовательно. Фазы 0–6 — обязательный MVP, фазы 7–9 — доведение до продакшена, фаза 10 — перспективные фичи.

---

# §1. Общий контекст проекта

> Этот раздел целиком копируется в `CLAUDE.md` в корне бэкенд-репозитория.

## 1.1. Что это за продукт

Мобильное приложение — агрегатор недвижимости для Бишкека и Кыргызстана. Два типа пользователей:

- **Клиент** — ищет недвижимость: смотрит каталог, фильтрует, добавляет в избранное, ведёт историю просмотров, получает уведомления.
- **Исполнитель / продавец («pro»)** — размещает объявления, платит за продвижение внутренней валютой, ведёт профиль агента/агентства.

Один и тот же аккаунт может быть и клиентом, и pro — во Flutter это флаг `AppState.pro`.

## 1.2. Внутренняя валюта — «кирпичи»

Приложение оперирует внутренней валютой «кирпич» (brick):

- Пополнение: **1 сом = 1 кирпич**, сверху **бонус 10 %** от суммы пополнения (12 000 сом → 12 000 кирпичей + 1 200 бонусных).
- Списания: продвижение объявления — **780 кирпичей за день продвижения**.
- Бонусы также начисляются «за квесты» (отдельный тип операции).
- Баланс и история операций (типы: `topup`, `spend`, `bonus`) показываются на экране «История пополнения и трат» с вкладками: Все операции / Пополнение / Списание / Бонусы.

## 1.3. Технологические решения

| Решение | Выбор |
|---|---|
| Фреймворк | Django 5.x + Django REST Framework 3.15+ |
| БД | PostgreSQL 16 (обязательно — используются JSONB, GIN-индексы, `pg_trgm`) |
| Аутентификация | Телефон + 4-значный OTP → JWT (`djangorestframework-simplejwt`), access 15 мин / refresh 30 дней с ротацией |
| Кэш, брокер, rate limit | Redis 7 |
| Фоновые задачи | Celery + Celery Beat |
| Файлы | S3-совместимое хранилище через `django-storages`; локально — `MEDIA_ROOT` |
| Документация API | `drf-spectacular` (OpenAPI 3.1), Swagger UI на `/api/docs/` |
| Фильтрация | `django-filter` |
| Конфигурация | `django-environ`, все секреты — из переменных окружения, ни одного секрета в коде |
| Форматирование/линт | `ruff` (line-length 100) + `ruff format`, `mypy` в нестрогом режиме |
| Тесты | `pytest` + `pytest-django` + `factory-boy` |

**Запрещено:** хранить секреты в репозитории, использовать SQLite в качестве целевой БД, писать бизнес-логику во `views` (логика живёт в `services/`), делать N+1 запросы в списочных эндпоинтах.

## 1.4. Структура репозитория

```
backend/
├── config/                  # settings/, urls.py, celery.py, asgi.py, wsgi.py
│   └── settings/            # base.py, local.py, production.py, test.py
├── apps/
│   ├── common/              # базовые модели, пагинация, обработчик ошибок, permissions
│   ├── users/               # User, профили, OTP, JWT
│   ├── catalog/             # Listing, справочники, медиа, поиск, фильтры
│   ├── engagement/          # избранное, история просмотров, сохранённые фильтры, подборки
│   ├── billing/             # кошелёк, транзакции, платежи, продвижение, подписки
│   └── notifications/       # уведомления, push
├── tests/
├── docker/
├── pyproject.toml
├── docker-compose.yml
├── Makefile
└── CLAUDE.md
```

Каждое приложение: `models.py`, `serializers.py`, `views.py`, `urls.py`, `services.py`, `filters.py`, `admin.py`, `selectors.py` (запросы к БД), `tests/`.

## 1.5. Соглашения по API

**База:** все эндпоинты под `/api/v1/`. Формат — JSON, кодировка UTF-8.

**Именование:** пути — `kebab-case` во множественном числе (`/api/v1/listings/`, `/api/v1/saved-filters/`). Поля JSON — `snake_case`.

**Аутентификация:** заголовок `Authorization: Bearer <access_token>`.

**Пагинация** — курсорная для лент и списков объектов (стабильна при вставке новых записей):

```json
{
  "results": [ ... ],
  "next": "https://api.example.com/api/v1/listings/?cursor=cD0yMDI2LTA4LTIw",
  "previous": null,
  "count": 1043
}
```

Размер страницы: `?page_size=` (по умолчанию 20, максимум 100).

**Формат ошибок — единый для всего API** (реализуется кастомным `EXCEPTION_HANDLER`):

```json
{
  "error": {
    "code": "validation_error",
    "message": "Проверьте правильность заполнения полей",
    "details": {
      "price": ["Цена должна быть положительным числом"]
    }
  }
}
```

Коды: `validation_error` (400), `authentication_failed` (401), `permission_denied` (403), `not_found` (404), `conflict` (409), `throttled` (429), `insufficient_funds` (402), `server_error` (500).

**Даты:** ISO 8601 в UTC с таймзоной (`2026-08-20T14:30:00Z`). Клиент сам приводит к `Asia/Bishkek`.

**Деньги:** цены объектов — целое число в минимальных единицах не используется; `price` — `DecimalField(max_digits=12, decimal_places=2)`, отдаётся строкой. Валюта — отдельное поле `currency` (`USD` / `KGS`). Балансы в кирпичах — целые (`BigIntegerField`).

**Локализация:** заголовок `Accept-Language: ru | ky | en`, по умолчанию `ru`. Пользовательский контент (описания объявлений) не переводится; переводятся справочники и тексты уведомлений.

**Идемпотентность:** для всех POST, меняющих баланс (пополнение, покупка продвижения), обязателен заголовок `Idempotency-Key`. Повторный запрос с тем же ключом в течение 24 часов возвращает первоначальный ответ, не создавая новую операцию.

## 1.6. Доменная модель (сводка)

Из Flutter-прототипа (`lib/data/listings.dart`, `lib/app/app_state.dart`) извлекаются следующие сущности и перечисления. **Значения enum'ов менять нельзя** — на них завязан клиент.

**`PropertyKind`** (тип недвижимости): `house` (Дома) · `apartment` (Квартиры) · `plot` (Участки) · `new_building` (Новостройки) · `room` (Комната) · `commercial` (Коммерция)

**`SellerKind`** (кто продаёт): `owner` (Только собственник) · `realtor` (Риелторы) · `agency` (Агентство недвижимости)

**`WalletEntryKind`** (тип операции): `topup` (Пополнение) · `spend` (Списание) · `bonus` (Бонусы)

**`ListingStatus`**: `draft` · `pending` (на модерации) · `active` · `rejected` · `archived` · `sold`

**Ключевые сущности:**

| Сущность | Поля (сокращённо) |
|---|---|
| `User` | phone (уникальный, E.164), name, is_pro, iin (для pro), avatar, is_active, date_joined |
| `Listing` | slug, owner, kind, seller_kind, district(FK), address, price, currency, old_price, rooms, area, floor, floors, series(FK), is_secondary, below_market, red_book, description, builder, status, published_at, views_count, promoted_until |
| `ListingMedia` | listing, file, kind (`photo`/`video`), order, is_cover, allow_download |
| `District` | name, city, slug, coordinates |
| `HouseSeries` | code (`103`, `105`), name |
| `Favourite` | user, listing, created_at (уникальная пара) |
| `ViewHistory` | user, listing, viewed_at (уникальная пара, обновляется по времени) |
| `SavedFilter` | user, name, params (JSONB), notify_on_new |
| `Wallet` | user (OneToOne), balance (кирпичи) |
| `WalletTransaction` | wallet, amount (может быть отрицательным), kind, label, related_object, created_at, idempotency_key |
| `Payment` | user, amount_kgs, bricks, bonus_bricks, provider, provider_ref, status, created_at |
| `Promotion` | listing, days, cost_bricks, starts_at, ends_at, options (JSONB) |
| `Notification` | user, type, title, body, payload (JSONB), listing, is_read, created_at |
| `SellerProfile` | user, company_name, logo, about, rating, reviews_count, is_verified |
| `IdentityVerification` | user, selfie, document_front/back, status, reviewed_by, purge_after |
| `ModerationTask` | listing, assigned_to, status, checks (JSONB), priority, reject_reason |

## 1.7. Соответствие экранов Flutter и эндпоинтов

| Экран (`lib/ui/pages`) | Эндпоинты |
|---|---|
| `splash_page` / `onboarding_page` | `GET /app/config/`, `GET /app/onboarding/` |
| `welcome_page` / `code_page` | `POST /auth/otp/request/`, `POST /auth/otp/verify/` |
| `pro_signup_page` | `POST /auth/pro/register/`, `POST /auth/otp/verify/` |
| `pro_photo_confirm_page` | `POST /verification/identity/`, `GET /verification/identity/` |
| `home_page` | `GET /listings/?kind=&limit=4`, `GET /listings/featured/` |
| `catalog_page` | `GET /listings/?search=&<фильтры>` |
| `filter_page` | `GET /catalog/filter-options/`, `GET /listings/?...` |
| `savedFilters` (`/filters/saved`) | `GET/POST/DELETE /saved-filters/` |
| `listing_page`, `listing/photos` | `GET /listings/{slug}/`, `POST /listings/{slug}/view/` |
| `favourites_page` | `GET /favourites/`, `POST/DELETE /listings/{slug}/favourite/` |
| `view_history_page` | `GET /view-history/`, `DELETE /view-history/` |
| `notifications_page` | `GET /notifications/`, `POST /notifications/read/` |
| `profile_page` | `GET/PATCH /users/me/`, `POST /auth/logout/` |
| `pro_profile_page` | `GET /users/me/listings/`, `GET /wallet/`, `GET /sellers/me/` |
| `agent`, `agentProfile`, `agentListings` | `GET /sellers/{id}/`, `GET /sellers/{id}/listings/`, `GET /sellers/{id}/reviews/` |
| `collection` (Подборки) | `GET /collections/`, `GET /collections/{slug}/listings/` |
| `ad_form_page` → `ad_photos` → `ad_video` → `ad_promo` | `POST /listings/draft/`, `PATCH /listings/{slug}/`, `POST /listings/{slug}/media/`, `POST /listings/{slug}/promote/`, `POST /listings/{slug}/publish/` |
| `topup_page` | `POST /wallet/topup/`, `GET /wallet/topup/{id}/`, `POST /webhooks/payments/` |
| `wallet_history_page` | `GET /wallet/transactions/?kind=` |
| `subscriptions` / `tariffs` | `GET /tariffs/`, `POST /subscriptions/` |

---

# §2. Фазы и задачи

## ФАЗА 0. Фундамент

---

### Задача 0.1. Каркас проекта и инфраструктура разработки

**Цель.** Пустой, но полностью рабочий Django-проект: поднимается одной командой, имеет линтер, тесты, миграции и Swagger.

**Требования.**

- Структура из §1.4, настройки разбиты на `base/local/production/test`.
- `docker-compose.yml`: `web`, `db` (postgres:16), `redis`, `celery`, `celery-beat`, `minio` (S3 локально).
- `Makefile` с целями: `up`, `down`, `migrate`, `makemigrations`, `shell`, `test`, `lint`, `format`, `superuser`.
- `.env.example` со всеми переменными и комментариями.
- Кастомная пагинация, кастомный `EXCEPTION_HANDLER` из §1.5, базовые абстрактные модели (`TimeStampedModel` с `created_at`/`updated_at`, `UUIDModel`).
- `drf-spectacular` настроен, `/api/v1/docs/` отдаёт Swagger UI, `/api/v1/schema/` — OpenAPI-файл.
- `/api/v1/health/` — проверка живости (БД + Redis).
- `pytest.ini`/`pyproject.toml` с настройками pytest, один smoke-тест на health-эндпоинт.
- Настроен CORS (`django-cors-headers`) и `SECURE_*` заголовки в production-настройках.

**Критерии приёмки.**

- `docker compose up` поднимает стек, `make migrate && make test` проходят без ошибок.
- `http://localhost:8000/api/v1/docs/` открывается.
- `make lint` не выдаёт замечаний.
- В репозитории нет ни одного секрета; `.env` в `.gitignore`.

**Промпт для Claude Code:**

```
Создай с нуля каркас бэкенд-проекта на Django 5 + Django REST Framework для мобильного
приложения-агрегатора недвижимости. Целевая БД — PostgreSQL 16, кэш и брокер — Redis 7,
фоновые задачи — Celery.

Структура репозитория:
backend/
├── config/settings/{base,local,production,test}.py, config/{urls,celery,asgi,wsgi}.py
├── apps/common/  (пока только базовые абстракции)
├── tests/
├── docker/
├── pyproject.toml, docker-compose.yml, Makefile, .env.example, README.md

Что нужно сделать:

1. Настройки разбить на base/local/production/test. Конфигурация — через django-environ,
   все секреты только из переменных окружения. В .env.example перечисли все переменные
   с комментариями. .env добавь в .gitignore.

2. Зависимости в pyproject.toml: django, djangorestframework, djangorestframework-simplejwt,
   django-filter, drf-spectacular, django-environ, django-cors-headers, django-storages[s3],
   psycopg[binary], celery, redis, pillow, а в dev-группе: pytest, pytest-django, pytest-cov,
   factory-boy, ruff, mypy, django-debug-toolbar.

3. В apps/common создай:
   - models.py: абстрактные TimeStampedModel (created_at, updated_at) и UUIDModel (uuid-pk).
   - pagination.py: CursorPagination с page_size=20, max_page_size=100, параметром page_size,
     и ответом вида {"results": [...], "next": ..., "previous": ..., "count": ...}.
   - exceptions.py: кастомный EXCEPTION_HANDLER, приводящий ЛЮБУЮ ошибку DRF к формату
     {"error": {"code": "<slug>", "message": "<человекочитаемо, по-русски>", "details": {...}}}.
     Коды: validation_error(400), authentication_failed(401), permission_denied(403),
     not_found(404), conflict(409), throttled(429), insufficient_funds(402), server_error(500).
     Определи также собственные исключения ConflictError и InsufficientFundsError.
   - permissions.py: IsOwnerOrReadOnly.

4. Настрой DRF: версионирование через URL-префикс /api/v1/, JWT как дефолтная аутентификация,
   AllowAny по умолчанию (permission'ы задаются явно во вьюхах), кастомная пагинация,
   django_filters как дефолтный backend, drf-spectacular как AUTOSCHEMA.

5. Настрой drf-spectacular: /api/v1/schema/ и /api/v1/docs/ (Swagger UI). Title
   "house_kgz API", описание, версия 1.0.0.

6. Эндпоинт GET /api/v1/health/ — возвращает {"status": "ok", "db": true, "redis": true},
   реально проверяя соединения. При недоступности зависимости — 503.

7. Celery: config/celery.py с автодискавери, отдельная очередь "default", Celery Beat
   на django-celery-beat.

8. docker-compose.yml с сервисами web, db (postgres:16 с healthcheck), redis, celery,
   celery-beat, minio + minio-init (создаёт бакет). Dockerfile в docker/ на python:3.12-slim,
   многостадийный, non-root пользователь.

9. Makefile: up, down, logs, migrate, makemigrations, shell, test, lint, format, superuser, seed.

10. Настрой ruff (line-length 100, правила E,F,I,N,UP,B,DJ) и ruff format. Настрой pytest
    (pytest-django, --reuse-db, покрытие). Напиши один smoke-тест на /api/v1/health/.

11. CORS через django-cors-headers (в local — разрешить всё, в production — из переменной
    окружения). В production.py включи SECURE_HSTS_SECONDS, SECURE_SSL_REDIRECT,
    SESSION_COOKIE_SECURE, CSRF_COOKIE_SECURE.

12. README.md: как поднять локально, как запустить тесты, что где лежит.

Не создавай пока никаких доменных моделей — только каркас. После генерации убедись, что
`make lint` и `make test` проходят чисто.
```

---

### Задача 0.2. Наполнение `CLAUDE.md` и фикстуры-сидер

**Цель.** Зафиксировать соглашения проекта в файле, который Claude Code читает автоматически, и получить команду наполнения БД реалистичными данными.

**Требования.**

- `CLAUDE.md` в корне репозитория = содержимое §1 этого ТЗ.
- Management-команда `seed_demo` создаёт: 3 пользователей (клиент, риелтор, агентство), справочники районов Бишкека и серий домов, 40 объявлений с медиа, кошельки с историей операций, уведомления.
- Данные для сидера берутся из `flutter_app/lib/data/listings.dart` — те же районы, цены, площади: так фронтенд можно переключить на API, не заметив разницы.

**Критерии приёмки.** `make seed` наполняет пустую БД, `GET /api/v1/listings/` возвращает те же 10 объектов, что зашиты в прототипе (Технопарк, Асанбай, Джал, Восток-5, Кок-Жар, Юг-2, Центр, Орто-Сай, Байтик, Чуй-Манаса) плюс сгенерированные.

**Промпт:**

```
1. Создай в корне репозитория файл CLAUDE.md и помести туда раздел «Общий контекст проекта»
   из ТЗ (я вставлю его сам — сделай файл со структурой заголовков и плейсхолдерами, если
   текста нет под рукой; если текст ТЗ доступен в репозитории — скопируй из него).

2. Создай management-команду `python manage.py seed_demo [--flush]` в apps/common, которая
   наполняет БД демо-данными, повторяющими прототип Flutter:

   Районы Бишкека: Технопарк, Асанбай, Джал, Восток-5, Кок-Жар, Юг-2, Центр, Орто-Сай,
   Байтик, Чуй-Манаса, Аламедин-1, Тунгуч, Джал-23, Кызыл-Аскер, Верхний Джал.
   Серии домов: 103, 104, 105, 106, Индивидуальная, Элитка.

   10 «якорных» объявлений — точная копия kListings из flutter_app/lib/data/listings.dart
   (район, цена в USD, старая цена, комнаты, площадь, этаж/этажность, тип, продавец,
   вторичка, серия, флаги below_market и red_book). Плюс 40 сгенерированных объявлений
   с правдоподобным разбросом по районам, ценам (30 000–350 000 USD) и типам.

   3 пользователя: +996700000001 (клиент), +996700000002 (риелтор, is_pro),
   +996700000003 (агентство, is_pro). У каждого pro — кошелёк с балансом 16 700 кирпичей
   и историей операций, повторяющей экран «История пополнения и трат»
   (+12 000 пополнение, +1 200 бонус за пополнение, +300 бонус за квест, −500 списание —
   за два разных дня).

   Каждому объявлению — 3–5 записей ListingMedia. Файлы генерируй программно
   (Pillow: цветной прямоугольник с текстом «district / price»), не тяни картинки из сети.

   Команда должна быть идемпотентной: повторный запуск не плодит дубли (используй
   get_or_create по стабильному slug). Флаг --flush предварительно чистит доменные таблицы.

3. Добавь цель `seed` в Makefile.

Запусти команду на чистой БД и убедись, что она отрабатывает без ошибок.
```

---

### Задача 0.3. Конфигурация приложения и статический контент

**Цель.** Экраны `splash_page`, `onboarding_page` и всё, что должно меняться без релиза мобильного приложения.

**Требования.**

- `GET /api/v1/app/config/` — единый ответ, который приложение запрашивает на сплэше: минимальная поддерживаемая версия, рекомендуемая версия, флаг принудительного обновления, ссылки на сторы, режим обслуживания с текстом, фича-флаги, базовые константы (курс бонуса пополнения, стоимость продвижения, лимиты медиа), ссылки на документы.
- `OnboardingSlide` (справочник): заголовок, текст, изображение, порядок, `is_active` — три экрана онбординга редактируются из админки.
- `StaticPage`: пользовательское соглашение, политика ПДн, «О приложении», FAQ, контакты поддержки — с версионированием (`version`, на неё ссылаются согласия из задачи 9.2).
- `POST /api/v1/support/tickets/` — обращение в поддержку из приложения.
- Всё кэшируется в Redis на 15 минут; ответ содержит `ETag`, клиент шлёт `If-None-Match` и получает 304.

**Критерии приёмки.** Изменение слайда онбординга в админке видно в API после инвалидации кэша; повторный запрос с `If-None-Match` возвращает 304; `force_update` корректно рассчитывается по переданной версии клиента.

**Промпт:**

```
В apps/common создай эндпоинты конфигурации приложения и статического контента —
всё, что должно меняться без релиза мобильного клиента.

Модель AppConfig (singleton, одна строка, редактируется в админке):
  min_supported_version, recommended_version (CharField, семвер)
  android_store_url, ios_store_url
  maintenance_mode (bool), maintenance_message (TextField)
  feature_flags: JSONField(default=dict)
  constants: JSONField — topup_bonus_rate, promotion_price_per_day, max_photos,
    max_videos, free_active_listings. Значения читаются отсюда, а не хардкодятся
    в клиенте.

Модель OnboardingSlide: title, text, image (ImageField), order, is_active
  (три слайда экранов onboarding_1..3 во Flutter)

Модель StaticPage: slug (unique: terms, privacy, about, faq, support),
  title, content (TextField, markdown), version (CharField), updated_at, is_active
  Версия нужна модели согласий из задачи 9.2 — при изменении текста соглашения
  версия увеличивается, и у пользователей запрашивается новое согласие.

Эндпоинты (AllowAny):
  GET /api/v1/app/config/?platform=android&version=1.0.0
    {
      "min_supported_version": "1.0.0", "recommended_version": "1.2.0",
      "force_update": false, "store_url": "...",
      "maintenance": {"enabled": false, "message": ""},
      "feature_flags": {"mortgage_calculator": false, "natural_search": false},
      "constants": {"topup_bonus_rate": 0.1, "promotion_price_per_day": 780,
                    "max_photos": 20, "max_videos": 20, "free_active_listings": 3},
      "documents": {"terms": {"url": "...", "version": "2026-08-01"},
                    "privacy": {"url": "...", "version": "2026-08-01"}}
    }
    force_update = true, если переданная version < min_supported_version
    (сравнение семвера, а не строк).
  GET /api/v1/app/onboarding/   — активные слайды по порядку
  GET /api/v1/app/pages/{slug}/ — статическая страница
  POST /api/v1/support/tickets/ — тело {"subject", "message", "contact_phone",
       "app_version", "platform"}; создаёт SupportTicket, уведомляет staff по email.
       Throttle: 5 обращений в час на пользователя/IP.

Кэширование: config, onboarding и страницы кэшируй в Redis на 15 минут. Отдавай
заголовок ETag (хеш содержимого); при запросе с If-None-Match, совпадающим с текущим,
возвращай 304 без тела — приложение дёргает config на каждом старте, и незачем
гонять его целиком.
Инвалидация кэша сигналами post_save на все три модели.

Админка: AppConfig как singleton (запрет на создание второй записи и на удаление),
OnboardingSlide с превью изображения и сортировкой, StaticPage с подсказкой
про увеличение version при изменении текста соглашений.

Тесты: force_update считается по семверу (1.0.0 < 1.0.10); If-None-Match даёт 304;
изменение слайда инвалидирует кэш; maintenance_mode отдаётся в конфиге;
6-е обращение в поддержку за час → 429.
```

---

## ФАЗА 1. Пользователи и аутентификация

---

### Задача 1.1. Модель пользователя и профиль

**Цель.** Кастомный `User` с телефоном вместо username, поддержка режима «pro», профиль и его редактирование.

**Требования.**

- `User(AbstractBaseUser, PermissionsMixin)`: `phone` (уникальный, E.164, `+996XXXXXXXXX`), `name`, `is_pro`, `iin` (14 цифр, только для pro, зашифрован/маскируется в API), `avatar`, `is_active`, `is_staff`, `date_joined`, `last_login`. `USERNAME_FIELD = "phone"`.
- Валидация телефона: нормализация к E.164 (`phonenumbers`), кыргызские номера по умолчанию.
- ИИН — персональные данные: в ответах API отдаётся маскированным (`12345678******`), полностью виден только владельцу и staff. В логи не пишется никогда.
- `GET /api/v1/users/me/` — профиль текущего пользователя. `PATCH /api/v1/users/me/` — имя, аватар. `DELETE /api/v1/users/me/` — мягкое удаление аккаунта (анонимизация ПДн, объявления архивируются).
- Django Admin: список, поиск по телефону/имени, фильтр по `is_pro`.

**Критерии приёмки.** Тесты: создание пользователя с невалидным телефоном падает; ИИН чужого пользователя не виден; `PATCH` не даёт изменить `phone`, `is_pro`, `iin`; мягкое удаление анонимизирует и деактивирует.

**Промпт:**

```
В приложении apps/users реализуй кастомную модель пользователя и профиль.

Модель User(AbstractBaseUser, PermissionsMixin), USERNAME_FIELD = "phone":
- phone: CharField(unique, max_length=16), формат E.164. Нормализуй через библиотеку
  phonenumbers при сохранении, регион по умолчанию KG. Невалидный номер — ValidationError.
- name: CharField(max_length=120, blank=True)
- is_pro: BooleanField(default=False) — пользователь зарегистрирован как исполнитель/продавец
- iin: CharField(max_length=14, blank=True) — ИИН, заполняется только при pro-регистрации.
  Это персональные данные: в API отдавай маскированным ("12345678******"), полностью —
  только самому владельцу и staff. Никогда не логируй.
- avatar: ImageField(upload_to="avatars/%Y/%m/", null=True, blank=True)
- is_active, is_staff, date_joined, updated_at
Менеджер UserManager с create_user(phone, ...) и create_superuser.

Эндпоинты (apps/users/views.py, все требуют IsAuthenticated):
- GET /api/v1/users/me/ — профиль: id, phone, name, is_pro, iin (маскированный),
  avatar_url, date_joined, а также вложенный объект wallet_balance (пока 0, подключим в фазе 5).
- PATCH /api/v1/users/me/ — изменить можно ТОЛЬКО name и avatar. Попытка передать phone,
  is_pro, iin, is_staff — игнорируется молча (read_only_fields), а не 400.
- DELETE /api/v1/users/me/ — мягкое удаление: is_active=False, phone заменяется на
  "deleted-<uuid>", name/iin/avatar очищаются, все объявления пользователя переводятся
  в статус archived. Возвращает 204.

Сериализаторы: UserMeSerializer (чтение), UserUpdateSerializer (запись).

Django Admin: регистрация User с list_display (phone, name, is_pro, is_active, date_joined),
search_fields (phone, name), list_filter (is_pro, is_active), поле iin — readonly.

Напиши тесты (pytest + factory_boy, фабрика UserFactory):
- невалидный телефон отклоняется, валидный нормализуется к E.164;
- PATCH не меняет phone/is_pro/iin;
- ИИН другого пользователя не возвращается в API;
- DELETE анонимизирует пользователя и архивирует его объявления (заглушку на объявления
  оставь TODO, если модель Listing ещё не создана).

Не забудь AUTH_USER_MODEL = "users.User" в settings и миграции.
```

---

### Задача 1.2. Аутентификация по SMS-коду + JWT

**Цель.** Флоу экранов `welcome_page` → `code_page`: ввод телефона, 4-значный код, вход.

**Требования.**

- `POST /api/v1/auth/otp/request/` `{phone}` → создаёт `OtpCode`, отправляет SMS через провайдера, отвечает `{"expires_in": 300, "resend_after": 60, "is_new_user": true}`. Существование номера в ответе **не раскрывается** сверх флага `is_new_user` (он нужен клиенту, чтобы решить, показывать ли форму имени).
- `POST /api/v1/auth/otp/verify/` `{phone, code, name?}` → при успехе создаёт пользователя (если нового) и возвращает `{access, refresh, user, is_new_user}`.
- Код — 4 цифры (как в макете), TTL 5 минут, максимум 5 попыток ввода, после чего код сжигается.
- Rate limit: 1 запрос кода в 60 секунд на номер, 5 в час на номер, 20 в час на IP. Отдельный throttle-класс, состояние в Redis.
- Провайдер SMS — абстракция `SmsProvider` с методом `send(phone, text)`. Реализации: `ConsoleSmsProvider` (dev — печатает в лог), `NikitaSmsProvider`/generic HTTP-провайдер (production, конфигурируется через env). Выбор — через `settings.SMS_PROVIDER`.
- В `DEBUG=True` и для номеров из `settings.OTP_TEST_PHONES` код всегда `0000` — иначе разработчик Flutter не сможет тестировать.
- JWT через SimpleJWT: access 15 мин, refresh 30 дней, ротация refresh, blacklist. `POST /api/v1/auth/refresh/`, `POST /api/v1/auth/logout/` (кладёт refresh в blacklist).
- Отправка SMS — через Celery-задачу, чтобы HTTP-ответ не ждал провайдера.

**Критерии приёмки.** Тесты: неверный код → 400 и счётчик попыток растёт; 6-я попытка → код сожжён; повторный запрос кода раньше 60 с → 429; успешный verify возвращает валидную пару токенов; logout делает refresh неработающим.

**Промпт:**

```
В apps/users реализуй аутентификацию по телефону и SMS-коду с выдачей JWT.

Модель OtpCode:
  phone (индекс), code_hash (хеш кода, не открытый текст — используй django.contrib.auth.hashers),
  purpose (choices: login, pro_register), attempts (int, default 0), is_used (bool),
  created_at, expires_at. Индекс по (phone, purpose, created_at).

Абстракция SMS-провайдера в apps/users/sms.py:
  class SmsProvider(Protocol): def send(self, phone: str, text: str) -> None
  - ConsoleSmsProvider — логирует "SMS to +996...: код 1234" (для разработки)
  - HttpSmsProvider — POST на settings.SMS_API_URL с телефоном и текстом, авторизация
    по токену из env, таймаут 10 с, 2 ретрая с экспоненциальной задержкой
  Фабрика get_sms_provider() читает settings.SMS_PROVIDER ("console" | "http").

Celery-задача send_otp_sms(phone, code) — отправляет SMS через провайдера,
логирует результат, при ошибке ретраит 3 раза.

Эндпоинты:

POST /api/v1/auth/otp/request/
  Тело: {"phone": "+996700123456", "purpose": "login"}
  - Нормализует телефон, генерирует 4-значный код (secrets.randbelow), сохраняет хеш,
    expires_at = now + 5 минут, ставит задачу отправки в Celery.
  - Если settings.DEBUG или телефон в settings.OTP_TEST_PHONES — код всегда "0000",
    SMS не отправляется.
  - Ответ 200: {"expires_in": 300, "resend_after": 60, "is_new_user": <bool>}
  - Throttle: не чаще 1 раза в 60 секунд на номер, 5 в час на номер, 20 в час на IP.
    Реализуй кастомные ScopedRateThrottle-классы поверх Redis. Превышение — 429 с телом
    {"error": {"code": "throttled", "message": "Повторите через N секунд", "details": {"retry_after": N}}}

POST /api/v1/auth/otp/verify/
  Тело: {"phone": "...", "code": "1234", "name": "Азамат"}  (name опционален, нужен новым)
  - Берёт последний неиспользованный неистёкший код для номера. Сверяет хеш.
  - Неверный код: attempts += 1, ответ 400 code="validation_error" с сообщением
    "Неверный код" и details.attempts_left. При attempts >= 5 код помечается is_used=True
    и ответ "Код заблокирован, запросите новый".
  - Истёкший код: 400, "Код истёк".
  - Успех: код is_used=True; пользователь берётся по телефону или создаётся
    (is_active=True, name из запроса). Возвращает 200:
    {"access": "...", "refresh": "...", "user": {...UserMeSerializer...}, "is_new_user": bool}

POST /api/v1/auth/refresh/ — стандартный TokenRefreshView SimpleJWT.
POST /api/v1/auth/logout/ — тело {"refresh": "..."}, кладёт токен в blacklist, 204.

Настройки SimpleJWT: ACCESS_TOKEN_LIFETIME=15 минут, REFRESH_TOKEN_LIFETIME=30 дней,
ROTATE_REFRESH_TOKENS=True, BLACKLIST_AFTER_ROTATION=True, подключи
rest_framework_simplejwt.token_blacklist в INSTALLED_APPS.

Celery Beat задача раз в сутки: удалять OtpCode старше 7 дней.

Тесты обязательно покрывают:
- запрос кода дважды подряд → второй раз 429;
- неверный код увеличивает attempts, на 5-й попытке код сжигается;
- истёкший код отклоняется;
- verify нового номера создаёт пользователя и возвращает is_new_user=true;
- verify существующего возвращает is_new_user=false и не меняет имя;
- logout делает refresh-токен непригодным для /auth/refresh/;
- в DEBUG код "0000" работает для тестового номера.

Открытый код НИКОГДА не попадает ни в ответ API, ни в логи (кроме ConsoleSmsProvider в DEBUG).
```

---

### Задача 1.3. Регистрация исполнителя (pro)

**Цель.** Экран `pro_signup_page`: телефон (с WhatsApp), имя, пароль, ИИН → код подтверждения → режим исполнителя.

**Требования.**

- `POST /api/v1/auth/pro/register/` `{phone, name, password, iin, whatsapp?}` → валидирует, создаёт/обновляет пользователя как неподтверждённого pro, шлёт OTP с `purpose=pro_register`.
- Подтверждение — тем же `POST /auth/otp/verify/` с `purpose=pro_register`; при успехе `is_pro=True`, создаётся кошелёк, возвращаются токены.
- Валидация ИИН: 14 цифр, проверка контрольной суммы по кыргызскому алгоритму (если алгоритм неизвестен — только формат + уникальность, с TODO).
- Пароль: минимум 8 символов, стандартные валидаторы Django. Пароль у pro нужен для будущего веб-кабинета; вход в мобильном приложении остаётся по OTP.
- `POST /api/v1/auth/password/login/` `{phone, password}` — альтернативный вход для pro (веб-кабинет).
- Существующий клиент может стать pro, не создавая второй аккаунт: если телефон уже зарегистрирован — заполняются недостающие поля.

**Критерии приёмки.** Тесты: регистрация pro для нового и для существующего номера; невалидный ИИН отклоняется; дубль ИИН отклоняется; до подтверждения кодом `is_pro` остаётся `False`.

**Промпт:**

```
В apps/users добавь регистрацию исполнителя (pro) — экран pro_signup_page Flutter-приложения
с полями: номер телефона (с WhatsApp), имя, пароль, ИИН.

POST /api/v1/auth/pro/register/
  Тело: {"phone": "+996700123456", "name": "Азамат", "password": "...", "iin": "12345678901234",
         "whatsapp": "+996700123456"}
  Логика:
  - Валидация ИИН: ровно 14 цифр, уникален среди пользователей. Реализуй функцию
    validate_iin(value) в apps/users/validators.py; если контрольная сумма по кыргызскому
    алгоритму неизвестна — проверяй формат и оставь TODO с комментарием.
  - Валидация пароля: settings.AUTH_PASSWORD_VALIDATORS (минимум 8 символов).
  - Если пользователя с таким телефоном нет — создать (is_active=True, is_pro=False до
    подтверждения). Если есть — дозаполнить name/iin/password, НЕ создавая второй аккаунт.
    Если у существующего пользователя уже есть другой ИИН — 409 conflict.
  - Сохранить whatsapp (добавь поле whatsapp_phone в User, nullable).
  - Отправить OTP с purpose="pro_register" (переиспользуй сервис из задачи 1.2).
  Ответ 200: {"expires_in": 300, "resend_after": 60}

Подтверждение — через существующий POST /api/v1/auth/otp/verify/ с purpose="pro_register".
Расширь его: при успешной проверке кода с этим purpose ставить is_pro=True и создавать
кошелёк пользователя (если модель Wallet ещё не существует — оставь вызов сервиса
за фича-флагом/TODO).

POST /api/v1/auth/password/login/
  Тело: {"phone": "...", "password": "..."}
  Только для is_pro=True. Возвращает ту же пару токенов, что и otp/verify.
  Throttle: 10 попыток в час на номер + 30 в час на IP. Неверный пароль — 401
  authentication_failed с общим сообщением (не раскрывай, существует ли номер).

Тесты:
- регистрация pro нового номера → пользователь создан, is_pro=False до verify;
- verify с purpose="pro_register" → is_pro=True, кошелёк создан;
- регистрация pro на существующий номер клиента дозаполняет профиль, аккаунт один;
- ИИН из 13 цифр отклоняется; повтор чужого ИИН → 409;
- password/login для не-pro → 401;
- брутфорс пароля упирается в throttle.
```

---

### Задача 1.4. Верификация личности исполнителя (KYC)

**Цель.** Экраны `pro_photo_confirm_page` (кадры 24–25): загрузка селфи и фотографии паспорта для подтверждения личности продавца.

**Требования.**

> Это самая чувствительная часть системы. Фото паспорта и селфи — биометрические и документальные персональные данные; их утечка несравнимо дороже утечки каталога. Требования ниже не опциональны.

- `IdentityVerification`: `user`, `selfie`, `document_front`, `document_back`, `document_type` (паспорт/ID), `status` (`pending`/`approved`/`rejected`), `reject_reason`, `reviewed_by`, `reviewed_at`, `submitted_at`, `purge_after`.
- Файлы хранятся **в отдельном приватном бакете** с политикой «запрет публичного доступа», доступ — только по подписанным URL со сроком жизни 10 минут, выдаваемым staff-пользователям. Ни при каких условиях эти файлы не попадают в тот же бакет, что и медиа объявлений.
- EXIF из загруженных фото удаляется, как и в задаче 6.2.
- **Автоудаление:** после решения модератора (одобрено или отклонено) сами файлы удаляются через 30 дней, остаётся только факт верификации, тип документа и дата. Хранить сканы паспортов бессрочно нет ни основания, ни смысла.
- Доступ к просмотру — только у staff с отдельным правом `can_review_identity`, каждый просмотр пишется в `AuditLog` (кто, чьи документы, когда).
- `POST /api/v1/verification/identity/` (multipart), `GET /api/v1/verification/identity/` — статус своей заявки, `POST /api/v1/verification/identity/{id}/review/` (staff).
- После одобрения — `is_verified=True` в `SellerProfile`, бейдж «проверенный продавец», уведомление.
- Rate limit: не более 3 подач в сутки; повторная подача при `status=pending` отклоняется.

**Критерии приёмки.** Файлы недоступны по прямой ссылке без подписи; обычный staff без права `can_review_identity` получает 403; каждый просмотр документа отражён в аудите; Celery-задача удаляет файлы через 30 дней после решения, сохраняя запись о верификации.

**Промпт:**

```
В apps/users реализуй верификацию личности исполнителя (экраны загрузки селфи и фото
паспорта, кадры 24–25 макета).

ВАЖНО ДО НАЧАЛА: это фото документа и селфи — самые чувствительные данные во всей системе.
Отнесись к требованиям ниже как к обязательным, а не рекомендательным: отдельное приватное
хранилище, подписанные ссылки, аудит каждого просмотра и автоматическое удаление файлов
после решения.

Модель IdentityVerification (TimeStampedModel):
  user: FK(User, related_name="identity_verifications")
  selfie: FileField(storage=private_storage, upload_to="kyc/%Y/%m/")
  document_front / document_back: FileField(storage=private_storage, null=True)
  document_type: CharField(choices: passport, id_card)
  status: CharField(choices: pending, approved, rejected, expired, default="pending")
  reject_reason: CharField(blank=True), comment: TextField(blank=True)
  reviewed_by: FK(User, null=True), reviewed_at: DateTimeField(null=True)
  purge_after: DateTimeField(null=True)   # когда удалить сами файлы
  Meta: indexes на (user, "-created_at"), (status, created_at)

Хранилище: настрой ОТДЕЛЬНЫЙ приватный бакет (settings.PRIVATE_FILE_STORAGE) с политикой
block-public-access. Файлы KYC не должны попадать в тот же бакет, что медиа объявлений,
даже в отдельную папку — разные бакеты с разными политиками. Доступ к файлу — только
через подписанный URL со сроком жизни 10 минут, генерируемый по запросу staff.

Обработка при загрузке (Celery-задача):
  - удалить EXIF полностью (как в задаче 6.2);
  - проверить, что это изображение (python-magic), размер до 10 МБ, минимум 800×600;
  - НЕ создавать публичных превью и НЕ класть эти файлы в CDN.

Эндпоинты:
  POST /api/v1/verification/identity/   (IsAuthenticated, is_pro, multipart)
    Поля: selfie, document_front, document_back (опционально), document_type.
    Отклоняется с 409, если у пользователя уже есть заявка со status="pending".
    Throttle: 3 подачи в сутки.
    Ответ 201: {"id", "status": "pending", "submitted_at"} — без ссылок на файлы.
  GET  /api/v1/verification/identity/   (IsAuthenticated)
    Статус СВОЕЙ последней заявки: {"status", "reject_reason", "reviewed_at",
    "can_resubmit": bool}. Ссылки на собственные загруженные файлы пользователю
    тоже не отдаём — ему нечего с ними делать, а лишний канал доступа не нужен.
  GET  /api/v1/verification/queue/   (staff с правом can_review_identity)
    Очередь заявок. Для каждой — подписанные URL файлов со сроком 10 минут.
    КАЖДАЯ выдача ссылки пишется в AuditLog: кто из staff, чьи документы, когда, с какого IP.
  POST /api/v1/verification/identity/{id}/review/   (staff с правом can_review_identity)
    Тело {"action": "approve|reject", "reason": "...", "comment": "..."}
    approve → SellerProfile.is_verified=True, verified_at=now, уведомление пользователю,
              purge_after = now + 30 дней
    reject  → уведомление с причиной, can_resubmit=True, purge_after = now + 30 дней

Права: кастомное разрешение can_review_identity (Permission на модели). Обычный is_staff
БЕЗ этого права получает 403 на очереди и на review. Проверь это тестом.

Celery Beat раз в сутки — задача purge_identity_files:
  Для заявок с purge_after < now: удалить файлы из хранилища, очистить поля файлов,
  но сохранить саму запись (user, status, document_type, reviewed_at) — факт верификации
  нужен, сканы паспорта — нет.

Логирование: имена файлов, содержимое и подписанные URL НИКОГДА не пишутся в обычные логи.

Тесты:
- файл KYC недоступен по прямому URL без подписи (проверь storage-конфигурацию);
- staff без права can_review_identity получает 403;
- каждая выдача подписанной ссылки создаёт запись в AuditLog;
- вторая подача при pending → 409;
- 4-я подача за сутки → 429;
- approve выставляет is_verified и purge_after;
- purge_identity_files удаляет файлы, но оставляет запись о верификации;
- EXIF удалён из загруженного селфи.
```

---

## ФАЗА 2. Каталог

---

### Задача 2.1. Справочники

**Цель.** Районы, города, серии домов, застройщики — то, из чего собираются фильтры и формы.

**Требования.**

- `City` (Бишкек, Ош, …), `District` (FK на город, slug, координаты центра `PointField` или пара `lat/lon`), `HouseSeries` (`103`, `105`, …), `Builder` (застройщик — поле «Кто застройщик» в форме объявления).
- `GET /api/v1/catalog/districts/?city=bishkek` — список районов.
- `GET /api/v1/catalog/filter-options/` — один запрос, отдающий всё для экрана `filter_page`: типы недвижимости, варианты комнат (1–5+), преднастроенные диапазоны площади (35–45, 45–55, 65–75, 75–85), типы продавцов, серии, границы цен (`min`/`max` по активным объявлениям), районы. Ответ кэшируется в Redis на 10 минут.
- Все справочники редактируются в админке, у каждого — `is_active` и `order`.

**Критерии приёмки.** `GET /catalog/filter-options/` отдаёт готовую структуру для отрисовки экрана фильтра одним запросом; повторный вызов берётся из кэша (проверяется по числу SQL-запросов).

**Промпт:**

```
В apps/catalog создай справочники и эндпоинт опций фильтра.

Модели (все наследуют TimeStampedModel, у всех is_active: bool = True и order: int = 0):
- City: name, slug (unique), is_default (bool)
- District: city (FK, related_name="districts"), name, slug, latitude/longitude
  (DecimalField, nullable). unique_together (city, slug).
- HouseSeries: code (unique, например "103", "105"), name ("103 серия")
- Builder: name, slug (unique), logo (ImageField, nullable), description

Эндпоинты (все AllowAny, только чтение):

GET /api/v1/catalog/cities/  → [{id, name, slug, is_default}]
GET /api/v1/catalog/districts/?city=<slug>  → [{id, name, slug, city, latitude, longitude}]
GET /api/v1/catalog/builders/  → [{id, name, slug, logo_url}]

GET /api/v1/catalog/filter-options/?city=<slug>
  Один ответ со всем, что нужно экрану фильтра Flutter:
  {
    "property_kinds": [{"value": "house", "label": "Дома"}, {"value": "apartment", "label": "Квартиры"},
                       {"value": "plot", "label": "Участки"}, {"value": "new_building", "label": "Новостройки"},
                       {"value": "room", "label": "Комната"}, {"value": "commercial", "label": "Коммерция"}],
    "seller_kinds": [{"value": "owner", "label": "Только собственник"},
                     {"value": "realtor", "label": "Риелторы"},
                     {"value": "agency", "label": "Агентство недвижимости"}],
    "rooms": [1, 2, 3, 4, 5],
    "area_ranges": [{"from": 35, "to": 45, "label": "35-45"}, {"from": 45, "to": 55, "label": "45-55"},
                    {"from": 65, "to": 75, "label": "65-75"}, {"from": 75, "to": 85, "label": "75-85"}],
    "series": [{"code": "103", "name": "103 серия"}, ...],
    "districts": [...],
    "price_range": {"currency": "USD", "min": 30000, "max": 350000}
  }
  price_range считается агрегатом по активным объявлениям выбранного города.
  Весь ответ кэшируй в Redis на 10 минут под ключом с учётом города и Accept-Language.
  Инвалидируй кэш сигналом post_save/post_delete на District, HouseSeries и Listing.

  ВАЖНО: значения property_kinds и seller_kinds точно совпадают с enum'ами PropertyKind
  и SellerKind во Flutter (lib/data/listings.dart) — переименовывать их нельзя.

Админка: все справочники с list_display, list_editable для is_active и order, поиском.

Тесты: filter-options отдаёт полную структуру; второй запрос не делает SQL-запросов
(проверь через django_assert_num_queries); изменение района инвалидирует кэш.
```

---

### Задача 2.2. Модель объявления и медиа

**Цель.** Центральная сущность `Listing` со всеми полями прототипа и её медиафайлы.

**Требования.**

- Поля `Listing`: `slug` (уникальный, генерируется), `owner` (FK User), `kind`, `seller_kind`, `city`, `district` (FK), `address` (текст), `price` (Decimal), `currency` (`USD`/`KGS`), `old_price` (nullable — «было 107 000$»), `rooms` (0 для участков), `area` (Decimal, м²), `land_area` (для участков, соток), `floor`, `floors`, `series` (FK nullable), `builder` (FK nullable), `is_secondary` (вторичка), `below_market` (флаг «ниже рынка»), `red_book` (флаг «красная книга»), `description`, `status`, `published_at`, `expires_at`, `views_count`, `favourites_count`, `promoted_until`, `allow_media_download`, `contact_phone`, `contact_name`.
- `ListingMedia`: `listing`, `file`, `kind` (`photo`/`video`), `order`, `is_cover`, `width`, `height`, `duration` (для видео), `thumbnail`. Ограничение — **20 фото и 20 видео на объявление** (лимит из `AppState.draftMediaLimit`).
- Денормализованные счётчики (`views_count`, `favourites_count`) обновляются через сервис, не сигналами внутри транзакции запроса.
- Индексы: составной по `(status, published_at DESC)`, по `(status, district, kind)`, по `price`, GIN по `description` + `address` для полнотекстового поиска (`pg_trgm` + `SearchVector`).
- `promoted_until` — по нему объявление поднимается в выдаче.

**Критерии приёмки.** Миграции применяются; попытка добавить 21-е фото → `validation_error`; `EXPLAIN` списочного запроса использует индекс; фабрика `ListingFactory` создаёт валидные объекты.

**Промпт:**

```
В apps/catalog создай модель Listing и ListingMedia — центральные сущности проекта.

Модель Listing (наследует TimeStampedModel):
  slug: SlugField(unique, max_length=140) — генерируется как "<district-slug>-<rooms>k-<short-uuid>",
        стабилен после создания
  owner: FK(User, on_delete=CASCADE, related_name="listings")
  kind: CharField(choices=PropertyKind) — house|apartment|plot|new_building|room|commercial
  seller_kind: CharField(choices=SellerKind) — owner|realtor|agency
  city: FK(City), district: FK(District, related_name="listings")
  address: CharField(max_length=255, blank=True)
  latitude / longitude: DecimalField(nullable)
  price: DecimalField(max_digits=12, decimal_places=2)
  currency: CharField(choices=[("USD","USD"),("KGS","KGS")], default="USD")
  old_price: DecimalField(nullable) — зачёркнутая старая цена в карточке
  rooms: PositiveSmallIntegerField(default=0)   # 0 для участков и коммерции
  area: DecimalField(max_digits=8, decimal_places=2)          # м²
  land_area: DecimalField(nullable)                            # соток, для участков
  floor / floors: PositiveSmallIntegerField(default=0)
  series: FK(HouseSeries, null=True), builder: FK(Builder, null=True)
  is_secondary: BooleanField(default=False)       # вторичка
  below_market: BooleanField(default=False)       # бейдж «ниже рынка»
  red_book: BooleanField(default=False)           # бейдж «красная книга»
  description: TextField(blank=True)
  status: CharField(choices=ListingStatus: draft|pending|active|rejected|archived|sold,
                    default="draft", db_index=True)
  rejection_reason: TextField(blank=True)
  published_at / expires_at: DateTimeField(nullable)
  promoted_until: DateTimeField(nullable, db_index=True)
  views_count / favourites_count: PositiveIntegerField(default=0)
  allow_media_download: BooleanField(default=True)   # тумблер «разрешить скачивание» в форме
  contact_name / contact_phone: CharField(blank=True)
  search_vector: SearchVectorField(nullable)

  Meta.indexes:
    - (status, "-published_at")
    - (status, district, kind)
    - (status, price)
    - GinIndex на search_vector
    - GinIndex(fields=["address"], opclasses=["gin_trgm_ops"]) — включи расширение pg_trgm
      отдельной миграцией

  Свойства: is_plot (kind == plot), is_promoted (promoted_until > now),
  price_display, discount_percent (если есть old_price).

Модель ListingMedia:
  listing: FK(Listing, related_name="media", on_delete=CASCADE)
  file: FileField(upload_to="listings/%Y/%m/")
  kind: CharField(choices=[("photo","photo"),("video","video")])
  order: PositiveSmallIntegerField(default=0)
  is_cover: BooleanField(default=False)   # первое фото = обложка карточки
  width / height / duration_seconds / size_bytes: nullable
  thumbnail: ImageField(nullable)   # для видео и для превью списка
  Meta: ordering = ("order", "id"); constraint — только одна обложка на объявление
  (UniqueConstraint с condition=Q(is_cover=True)).

Лимиты (в apps/catalog/constants.py): MAX_PHOTOS_PER_LISTING = 20, MAX_VIDEOS_PER_LISTING = 20 —
это лимиты из AppState.draftMediaLimit во Flutter. Проверка лимита — в сервисном слое
и в clean() модели, при превышении — ValidationError с кодом validation_error.

Enum'ы PropertyKind, SellerKind, ListingStatus вынеси в apps/catalog/enums.py как
django.db.models.TextChoices с русскими человекочитаемыми label — значения должны точно
совпадать с enum'ами во Flutter (lib/data/listings.dart).

Счётчики views_count и favourites_count — денормализация. Обновляй их ТОЛЬКО через
сервисные функции с F-выражениями (F("views_count") + 1), никогда не читая-записывая
в Python. Не вешай сигналы, которые делают лишний UPDATE в горячем пути.

Django Admin: Listing с инлайном ListingMedia, list_display (slug, district, kind, price,
status, published_at, views_count), list_filter (status, kind, seller_kind, city, district,
is_secondary), search_fields (slug, address, description), autocomplete по district/builder,
действия «Опубликовать», «Отклонить», «Архивировать».

Фабрики factory_boy: ListingFactory, ListingMediaFactory, DistrictFactory.

Тесты: генерация slug уникальна; добавление 21-го фото падает с ValidationError;
две обложки на одно объявление нарушают constraint; is_promoted корректно считается.
```

---

### Задача 2.3. Публичный каталог: список и карточка объекта

**Цель.** Экраны `home_page`, `catalog_page`, `listing_page`, `listing/photos`.

**Требования.**

- `GET /api/v1/listings/` — только `status=active`, курсорная пагинация. Сортировки: `?ordering=-published_at | price | -price | -views_count`. Продвинутые (`promoted_until > now`) всегда выше в выдаче.
- Два сериализатора: **краткий** для списка (обложка, район, цена, старая цена, комнаты, площадь, этаж/этажность, бейджи `below_market`/`red_book`, `is_favourite` для авторизованного) и **полный** для карточки (все фото и видео, описание, адрес, координаты, продавец с именем и телефоном, похожие объекты).
- `GET /api/v1/listings/{slug}/` — карточка. Телефон продавца отдаётся **только авторизованным**; неавторизованному — маска `+996 7XX XXX XX9`.
- `POST /api/v1/listings/{slug}/view/` — отметить просмотр (инкремент `views_count` + запись в историю просмотров). Защита от накрутки: один просмотр от пользователя/IP за 30 минут (ключ в Redis).
- `GET /api/v1/listings/featured/` — подборка для главной: по 4 объекта на каждый `PropertyKind` (главный экран показывает вкладки по типам).
- `GET /api/v1/listings/{slug}/similar/` — 6 похожих: тот же район или тип, цена ±25 %.
- Оптимизация: `select_related("district", "city", "series", "builder", "owner")`, `prefetch_related` медиа с ограничением, `annotate` избранного одним запросом. Списочный эндпоинт — **не больше 5 SQL-запросов** независимо от размера страницы.

**Критерии приёмки.** `django_assert_num_queries` подтверждает отсутствие N+1; неавторизованный не видит полный телефон; повторный `view/` в течение 30 минут не увеличивает счётчик; продвинутые объявления идут первыми.

**Промпт:**

```
В apps/catalog реализуй публичные эндпоинты каталога.

GET /api/v1/listings/
  Только status="active". Курсорная пагинация (page_size по умолчанию 20).
  Сортировка через ?ordering=: -published_at (по умолчанию), price, -price, -views_count, area.
  ВАЖНО: объявления с promoted_until > now() всегда идут выше остальных независимо
  от ordering — реализуй через annotate(is_promoted=Case(...)) и сортировку
  ("-is_promoted", <ordering>).

  ListingListSerializer (краткий, для карточки в сетке):
  {
    "slug", "kind", "kind_label", "district": {"id","name","slug"},
    "price": "102000.00", "currency": "USD", "old_price": "107000.00",
    "rooms": 3, "area": "92.00", "floor": 8, "floors": 12,
    "cover_url", "photos_count", "is_secondary", "series_code",
    "below_market": true, "red_book": true, "seller_kind",
    "is_promoted": false, "is_favourite": false, "published_at"
  }
  is_favourite — annotate через Exists(Favourite.objects.filter(...)) для авторизованного,
  всегда false для анонима. Никаких дополнительных запросов на объект.

GET /api/v1/listings/{slug}/
  ListingDetailSerializer: все поля краткого плюс description, address, latitude, longitude,
  builder, allow_media_download, views_count, favourites_count,
  media: [{id, kind, url, thumbnail_url, order, is_cover, width, height, duration_seconds}],
  seller: {"id", "name", "kind": seller_kind, "phone", "avatar_url", "listings_count",
           "member_since"}.
  Телефон продавца: полный только для аутентифицированных; анониму — маска
  "+996 7XX XXX XX9" (видны код страны, первая цифра оператора и последняя цифра).

POST /api/v1/listings/{slug}/view/
  Отмечает просмотр: инкрементит views_count через F-выражение и (для авторизованного)
  пишет/обновляет запись в истории просмотров.
  Дедупликация: ключ Redis "view:{slug}:{user_id or ip}" с TTL 30 минут — повторный вызов
  внутри окна возвращает 200, но ничего не инкрементит.
  Ответ: {"views_count": 1043}

GET /api/v1/listings/featured/
  Для главного экрана: {"apartment": [4 объекта], "house": [...], "new_building": [...],
  "plot": [...], "room": [...], "commercial": [...]} — по 4 самых свежих активных объекта
  каждого типа, продвинутые вперёд. Кэш Redis 5 минут.

GET /api/v1/listings/{slug}/similar/
  6 похожих: тот же district ИЛИ тот же kind, цена в диапазоне ±25%, исключая сам объект,
  только active. Сортировка: сначала совпадение по району, потом по близости цены.

Оптимизация обязательна:
- select_related("district", "city", "series", "builder", "owner")
- prefetch_related обложки (Prefetch с queryset media.filter(is_cover=True)) — НЕ тяни
  все медиа в списочном эндпоинте
- is_favourite через Exists-annotate
Списочный эндпоинт должен укладываться в 5 SQL-запросов на страницу любого размера.
Проверь это тестом с django_assert_num_queries.

Все эндпоинты этой задачи — AllowAny (кроме поведения телефона и is_favourite,
зависящего от аутентификации).

Тесты:
- список отдаёт только active;
- продвинутое объявление первое в выдаче;
- аноним получает маскированный телефон, авторизованный — полный;
- повторный POST view/ в течение 30 минут не меняет счётчик;
- нет N+1 (django_assert_num_queries);
- similar не возвращает сам объект и не возвращает неактивные.
```

---

## ФАЗА 3. Поиск и фильтры

---

### Задача 3.1. Фильтрация и полнотекстовый поиск

**Цель.** Экран `filter_page` + строка поиска в каталоге — все условия из `AppState`.

**Требования.**

Все параметры комбинируются через `AND`, значения внутри одного параметра — через `OR` (мультивыбор, как чипы в макете):

| Параметр | Пример | Смысл |
|---|---|---|
| `search` | `?search=Технопарк` | по району, адресу, описанию, названию застройщика |
| `kind` | `?kind=apartment,house` | тип недвижимости (мультивыбор) |
| `district` | `?district=technopark,jal` | район (мультивыбор) |
| `rooms` | `?rooms=1,2,3` | комнатность; `5` означает «5 и более» |
| `area_min` / `area_max` | `?area_min=65&area_max=75` | площадь |
| `area_ranges` | `?area_ranges=35-45,65-75` | преднастроенные чипы; объединяются по `OR` с `area_min/max` |
| `price_min` / `price_max` | `?price_min=50000` | цена в валюте `currency` |
| `currency` | `?currency=USD` | валюта, в которой заданы границы цены |
| `seller_kind` | `?seller_kind=owner` | продавец (мультивыбор) |
| `is_secondary` | `?is_secondary=true` | «Вторичка» |
| `series` | `?series=103` | серия дома |
| `floor_min` / `floor_max`, `not_first_floor`, `not_last_floor` | | этаж |
| `below_market`, `red_book`, `has_video` | | бейджи |

- Поиск — PostgreSQL: `SearchVector` (русская конфигурация) с весами (район = A, адрес = B, описание = C) + `trigram_similarity` как fallback для опечаток. `search_vector` пересчитывается триггером или при сохранении.
- Границы цены в другой валюте: если `currency=KGS`, а объявление в `USD`, сравнение идёт по нормализованной цене. Заводится модель `ExchangeRate` (курс USD/KGS, обновляется Celery-задачей из НБКР) и денормализованное поле `price_usd` на `Listing`, пересчитываемое при сохранении и при обновлении курса.
- `GET /api/v1/listings/count/?<те же параметры>` — только число совпадений, для кнопки «Показать N объектов» на экране фильтра. Ответ быстрый, без пагинации.

**Критерии приёмки.** Тесты покрывают каждый параметр по отдельности и три комбинации; поиск «технпарк» (с опечаткой) находит Технопарк; `count` совпадает с длиной полной выдачи.

**Промпт:**

```
В apps/catalog реализуй фильтрацию и полнотекстовый поиск каталога через django-filter.

Создай ListingFilterSet (apps/catalog/filters.py) со всеми параметрами. Мультивыбор
передаётся списком через запятую и объединяется по OR внутри параметра; разные параметры
комбинируются по AND.

Параметры:
  search       — полнотекстовый (см. ниже)
  kind         — CharInFilter по choices PropertyKind, "?kind=apartment,house"
  district     — по slug района, мультивыбор
  city         — по slug города
  rooms        — NumberInFilter; значение 5 трактуется как "5 и более" (rooms__gte=5)
  area_min / area_max        — DecimalField по area
  area_ranges  — строка "35-45,65-75": каждый диапазон превращается в Q(area__range=...),
                 диапазоны объединяются по OR, результат объединяется по OR с area_min/max
  price_min / price_max      — по нормализованной цене (см. про валюту)
  currency     — валюта, в которой заданы price_min/price_max (USD по умолчанию)
  seller_kind  — мультивыбор
  is_secondary — BooleanFilter
  series       — по code, мультивыбор
  floor_min / floor_max, not_first_floor (floor__gt=1), not_last_floor (floor__lt=F("floors"))
  below_market, red_book — BooleanFilter
  has_video    — BooleanFilter, Exists по media с kind="video"
  builder      — по slug

Полнотекстовый поиск (PostgreSQL):
- Добавь на Listing поле search_vector (SearchVectorField) и обновляй его при сохранении:
  SearchVector("district__name", weight="A", config="russian") +
  SearchVector("address", weight="B", config="russian") +
  SearchVector("description", weight="C", config="russian") +
  SearchVector("builder__name", weight="B", config="russian")
  Обновление делай в Celery-задаче/через bulk-обновление в сервисе публикации, а также
  management-командой rebuild_search_index для пересчёта всей таблицы.
- Фильтр search: сначала SearchQuery(config="russian", search_type="websearch") по
  search_vector с сортировкой по SearchRank. Если результатов нет — fallback на
  TrigramSimilarity по district__name и address с порогом 0.3 (расширение pg_trgm).
  Это нужно, чтобы «технпарк» с опечаткой находил «Технопарк».

Валюты и нормализация цены:
- Модель ExchangeRate: currency_from, currency_to, rate (Decimal), fetched_at.
- Celery Beat раз в сутки в 09:00 по Asia/Bishkek тянет курс USD/KGS с сайта НБКР
  (www.nbkr.kg, XML) и сохраняет. При недоступности источника — логирует и оставляет
  прошлый курс, задача не падает.
- Денормализованное поле Listing.price_usd (DecimalField, db_index=True), пересчитывается
  при save() объявления и bulk-пересчётом при обновлении курса. Все фильтры по цене и
  сортировки работают по price_usd, а price_min/price_max при currency=KGS конвертируются
  в USD перед сравнением.

GET /api/v1/listings/count/?<все те же параметры>
  Возвращает {"count": 137} — для кнопки «Показать N объектов» на экране фильтра.
  Без пагинации, без сериализации объектов, только .count() по отфильтрованному queryset.
  Кэшируй результат в Redis на 60 секунд по хешу нормализованной строки параметров.

Подключи ListingFilterSet к GET /api/v1/listings/ и к /listings/count/.

Тесты — по одному на каждый параметр плюс комбинации:
- kind=apartment,house возвращает объекты обоих типов и ничего лишнего;
- rooms=5 находит и пятикомнатные, и шестикомнатные;
- area_ranges=35-45,65-75 отбирает объединение диапазонов;
- price_min в KGS корректно конвертируется и отбирает объекты в USD;
- not_last_floor исключает объекты с floor == floors;
- поиск «технпарк» (опечатка) находит «Технопарк» через триграммы;
- /listings/count/ совпадает с длиной полной выдачи того же фильтра.
```

---

### Задача 3.2. Сохранённые фильтры и подборки

**Цель.** Экран `savedFilters` (`/filters/saved`) и `collection` — сохранённые поиски с уведомлениями о новых объектах.

**Требования.**

- `SavedFilter`: `user`, `name`, `params` (JSONB — нормализованные параметры фильтра), `notify_on_new` (bool), `last_notified_at`, `matches_count` (денормализованный счётчик).
- CRUD: `GET/POST /api/v1/saved-filters/`, `PATCH/DELETE /api/v1/saved-filters/{id}/`. Максимум 20 фильтров на пользователя.
- `GET /api/v1/saved-filters/{id}/listings/` — выдача по сохранённому фильтру.
- Celery Beat каждый час: для фильтров с `notify_on_new=True` найти объявления, опубликованные после `last_notified_at`, и создать уведомление «По вашему фильтру “Квартиры Асанбай” 3 новых объекта». Задача батчевая, не по одному запросу на фильтр.
- `Collection` (редакционные подборки для экрана `collection`): `title`, `subtitle`, `cover`, `params` (JSONB) **или** ручной список объявлений, `is_active`, `order`. Управляется из админки.
- `GET /api/v1/collections/`, `GET /api/v1/collections/{slug}/listings/`.

**Критерии приёмки.** Сохранённый фильтр воспроизводит ту же выдачу, что и исходный запрос; 21-й фильтр отклоняется; Celery-задача создаёт ровно одно уведомление на фильтр за прогон и двигает `last_notified_at`.

**Промпт:**

```
В apps/engagement реализуй сохранённые фильтры и редакционные подборки.

Модель SavedFilter (TimeStampedModel):
  user: FK(User, related_name="saved_filters")
  name: CharField(max_length=100)
  params: JSONField — нормализованный словарь параметров фильтра каталога
  notify_on_new: BooleanField(default=True)
  last_notified_at: DateTimeField(nullable)
  matches_count: PositiveIntegerField(default=0)
  Meta: unique_together (user, name)

Эндпоинты (IsAuthenticated, доступ только к своим объектам):
  GET    /api/v1/saved-filters/           — список фильтров пользователя с matches_count
  POST   /api/v1/saved-filters/           — тело {"name": "...", "params": {...},
                                                  "notify_on_new": true}
  PATCH  /api/v1/saved-filters/{id}/      — переименовать, включить/выключить уведомления
  DELETE /api/v1/saved-filters/{id}/
  GET    /api/v1/saved-filters/{id}/listings/  — выдача каталога по сохранённым params,
                                                 с той же пагинацией и сериализатором

Валидация params: прогоняй словарь через ListingFilterSet — неизвестные ключи и невалидные
значения отклоняй с validation_error, чтобы в БД не попадал мусор. Сохраняй уже
нормализованный вид. Лимит: 20 фильтров на пользователя, 21-й — 409 conflict.

Celery Beat задача notify_saved_filters, каждый час:
  Для всех SavedFilter с notify_on_new=True: посчитать объявления со status="active"
  и published_at > COALESCE(last_notified_at, saved_filter.created_at), подходящие
  под params. Если найдено N > 0 — создать одно уведомление типа "saved_filter_match"
  с телом «По фильтру "<name>" — N новых объектов» и payload {"saved_filter_id": ..., "count": N},
  затем обновить last_notified_at = now и matches_count.
  Обрабатывай фильтры батчами (например, по 200) и не делай по отдельному запросу на каждый —
  сгруппируй одинаковые params. Задача должна быть идемпотентной при повторном запуске.

Модель Collection (редакционные подборки для экрана «Подборки»):
  title, subtitle, slug (unique), cover: ImageField, description
  mode: CharField(choices=[("query","По фильтру"),("manual","Ручной список")])
  params: JSONField(blank) — для mode="query"
  listings: M2M(Listing, blank=True, through=CollectionItem с полем order) — для mode="manual"
  is_active, order, created_at

Эндпоинты (AllowAny):
  GET /api/v1/collections/                  — активные подборки, отсортированные по order
  GET /api/v1/collections/{slug}/listings/  — объекты подборки (по params или из M2M),
                                              пагинация как в каталоге

Админка: Collection с инлайном CollectionItem и сортировкой drag-n-drop (или просто
полем order), превью обложки.

Тесты:
- сохранённый фильтр воспроизводит выдачу исходного запроса один-в-один;
- params с неизвестным ключом отклоняются;
- 21-й фильтр → 409;
- notify_saved_filters создаёт ровно одно уведомление и двигает last_notified_at;
- повторный прогон задачи сразу после первого не создаёт уведомлений;
- подборка в режиме manual отдаёт объекты в заданном порядке.
```

---

## ФАЗА 4. Персональные данные пользователя

---

### Задача 4.1. Избранное и история просмотров

**Цель.** Экраны `favourites_page` и `view_history_page`.

**Требования.**

- `POST /api/v1/listings/{slug}/favourite/` — добавить, `DELETE` — убрать. Идемпотентно: повторное добавление не создаёт дубль и не отдаёт ошибку.
- `GET /api/v1/favourites/` — избранное с полными карточками, пагинация, сортировка по дате добавления.
- Счётчик `favourites_count` на объявлении обновляется в той же транзакции через `F`.
- `ViewHistory`: `user`, `listing`, `viewed_at`, уникальная пара — повторный просмотр обновляет время и поднимает запись наверх (как `noteViewed` во Flutter).
- `GET /api/v1/view-history/` — история, сгруппированная по дням (`Сегодня`, `Вчера`, `20 августа`) — экран показывает именно так.
- `DELETE /api/v1/view-history/` с телом `{"listing_slugs": [...]}` — удалить выбранные; без тела — очистить всю историю (`forgetViewed` во Flutter).
- Хранение истории — 90 дней, чистится Celery-задачей.
- При удалении объявления записи остаются, но карточка отдаётся с флагом `is_available: false` — пользователь должен понимать, что объект снят.

**Критерии приёмки.** Двойное добавление в избранное не ломает счётчик; история группируется корректно на границе суток по `Asia/Bishkek`; удалённое объявление отдаётся с `is_available: false`.

**Промпт:**

```
В apps/engagement реализуй избранное и историю просмотров.

Модель Favourite (TimeStampedModel):
  user: FK(User, related_name="favourites"), listing: FK(Listing, related_name="favourited_by")
  Meta: unique_together (user, listing), indexes на (user, "-created_at")

Модель ViewHistory:
  user: FK(User, related_name="view_history"), listing: FK(Listing)
  viewed_at: DateTimeField(auto_now=True, db_index=True)
  Meta: unique_together (user, listing), indexes на (user, "-viewed_at")

Эндпоинты (IsAuthenticated):

POST   /api/v1/listings/{slug}/favourite/
  Идемпотентно: get_or_create. Если создано — инкремент listing.favourites_count через
  F-выражение в той же транзакции. Ответ 200 {"is_favourite": true, "favourites_count": 42}.
DELETE /api/v1/listings/{slug}/favourite/
  Идемпотентно: если записи нет — всё равно 200. При удалении — декремент счётчика
  (не уходя ниже нуля). Ответ {"is_favourite": false, "favourites_count": 41}.

GET /api/v1/favourites/
  Список избранного пользователя, ListingListSerializer, курсорная пагинация,
  сортировка по -created_at записи Favourite (не объявления).
  Включай объявления в любом статусе, но с полем is_available = (status == "active").

GET /api/v1/view-history/
  История просмотров, сгруппированная по дням в таймзоне Asia/Bishkek:
  {
    "results": [
      {"day": "today",     "day_label": "Сегодня",    "items": [ ...ListingListSerializer... ]},
      {"day": "yesterday", "day_label": "Вчера",      "items": [...]},
      {"day": "2026-08-18","day_label": "18 августа", "items": [...]}
    ],
    "next": null
  }
  Группировку делай в Python по уже отсортированному queryset (не по отдельному запросу
  на день). Пагинация — по дням: страница отдаёт целые дни, курсор указывает на дату.
  У каждого элемента есть viewed_at и is_available.

DELETE /api/v1/view-history/
  Тело {"listing_slugs": ["a", "b"]} — удалить эти записи. Пустое тело или
  {"all": true} — очистить всю историю пользователя. Ответ 204.

Сервис note_view(user, listing) — вызывается из POST /listings/{slug}/view/ (задача 2.3):
  update_or_create по (user, listing) с viewed_at=now. Для анонимов ничего не пишет.

Celery Beat раз в сутки: удалять ViewHistory старше 90 дней.

Тесты:
- двойной POST favourite/ не создаёт дубль и не удваивает счётчик;
- DELETE несуществующего избранного возвращает 200, счётчик не уходит в минус;
- повторный просмотр обновляет viewed_at и поднимает объект в начало истории;
- группировка по дням корректна на границе суток в Asia/Bishkek (проверь с freezegun);
- архивное объявление отдаётся с is_available=false;
- DELETE view-history с {"all": true} чистит всё.
```

---

### Задача 4.2. Уведомления и push

**Цель.** Экран `notifications_page` и доставка push на устройство.

**Требования.**

- `Notification`: `user`, `type`, `title`, `body`, `payload` (JSONB), `listing` (nullable), `is_read`, `created_at`.
- Типы: `price_drop` (цена упала на объект в избранном), `saved_filter_match`, `listing_moderated` (объявление одобрено/отклонено), `promotion_expiring`, `wallet_topup`, `system`.
- `GET /api/v1/notifications/?is_read=false` — список, `GET /api/v1/notifications/unread-count/` — бейдж, `POST /api/v1/notifications/read/` `{ids: [...]}` или `{all: true}`, `DELETE /api/v1/notifications/{id}/`.
- Push через FCM (`firebase-admin`): модель `DeviceToken` (`user`, `token`, `platform`, `is_active`, `last_seen_at`), эндпоинты `POST /api/v1/devices/` и `DELETE /api/v1/devices/{token}/`. Невалидные токены деактивируются по ответу FCM.
- Настройки уведомлений на пользователя: `NotificationSettings` (`push_enabled`, по типам). `GET/PATCH /api/v1/notifications/settings/`.
- Celery-задача `notify_price_drop`: раз в сутки сравнивает текущие цены с сохранёнными в избранном и шлёт уведомление при падении ≥ 3 %.
- Отправка push — всегда через Celery, батчами (FCM multicast до 500 токенов).

**Критерии приёмки.** Уведомление создаётся ровно один раз на событие; push не шлётся при `push_enabled=False`; невалидный FCM-токен деактивируется; `unread-count` совпадает с фактическим числом.

**Промпт:**

```
В apps/notifications реализуй уведомления и push.

Модель Notification (TimeStampedModel):
  user: FK(User, related_name="notifications")
  type: CharField(choices: price_drop, saved_filter_match, listing_moderated,
                  promotion_expiring, wallet_topup, system)
  title: CharField(max_length=140), body: TextField
  payload: JSONField(default=dict) — данные для навигации в приложении
  listing: FK(Listing, null=True, on_delete=SET_NULL)
  is_read: BooleanField(default=False, db_index=True)
  Meta: indexes на (user, is_read, "-created_at")

Модель DeviceToken:
  user: FK(User, related_name="devices"), token: CharField(unique, max_length=255)
  platform: CharField(choices: android, ios), app_version, is_active (default True),
  last_seen_at
Модель NotificationSettings (OneToOne с User):
  push_enabled: bool = True, плюс булев флаг на каждый тип уведомления
  (price_drop_enabled, saved_filter_enabled, ...). Создаётся сигналом при создании User.

Эндпоинты (IsAuthenticated):
  GET    /api/v1/notifications/?is_read=false&type=price_drop   — курсорная пагинация
  GET    /api/v1/notifications/unread-count/   → {"count": 7}
  POST   /api/v1/notifications/read/           — тело {"ids": [1,2]} или {"all": true} → 200
                                                  с новым unread_count
  DELETE /api/v1/notifications/{id}/
  GET    /api/v1/notifications/settings/       — текущие настройки
  PATCH  /api/v1/notifications/settings/       — изменить
  POST   /api/v1/devices/                      — тело {"token": "...", "platform": "android",
                                                  "app_version": "1.0.0"}; upsert по токену,
                                                  переносит токен на текущего пользователя,
                                                  если он был привязан к другому
  DELETE /api/v1/devices/{token}/              — деактивировать (при выходе из аккаунта)

Push через FCM (firebase-admin, креды из env — путь к service-account JSON или его
содержимое base64):
  Сервис push.send_to_user(user, notification) — берёт активные токены пользователя,
  проверяет NotificationSettings (push_enabled и флаг конкретного типа), шлёт multicast
  батчами по 500. Токены, на которые FCM ответил UNREGISTERED или INVALID_ARGUMENT,
  помечает is_active=False.
  Все отправки — через Celery-задачу send_push(notification_id), синхронно из вьюх не шлём.

Единая точка создания уведомлений — сервис notify(user, type, title, body, payload=None,
listing=None): создаёт Notification и ставит задачу отправки push. Все остальные модули
(модерация, кошелёк, сохранённые фильтры) вызывают только его.

Celery Beat задача notify_price_drop, раз в сутки в 10:00 Asia/Bishkek:
  Для каждого объявления в чьём-то избранном сравнить текущую price_usd с ценой на момент
  добавления в избранное (добавь поле Favourite.price_at_add). Если падение ≥ 3% —
  уведомление типа price_drop «Цена снизилась на 5%: Технопарк, 3-комн. — 97 000$»
  и обновить price_at_add, чтобы не слать повторно на ту же цену.

Тесты:
- notify создаёт одну запись и ставит ровно одну задачу push;
- при push_enabled=False уведомление создаётся, push не отправляется;
- FCM-ответ UNREGISTERED деактивирует токен;
- unread-count совпадает с фактическим числом непрочитанных;
- POST read/ с {"all": true} обнуляет счётчик;
- падение цены на 2% не создаёт уведомление, на 5% — создаёт ровно одно.
```

---

## ФАЗА 5. Кошелёк и платежи

---

### Задача 5.1. Кошелёк, кирпичи и леджер операций

**Цель.** Экран `wallet_history_page` и весь учёт внутренней валюты.

**Требования.**

- `Wallet` (OneToOne с `User`): `balance` (BigInteger, кирпичи), `updated_at`. Создаётся при регистрации.
- `WalletTransaction`: `wallet`, `amount` (может быть отрицательным), `kind` (`topup`/`spend`/`bonus`), `label` (человекочитаемая строка, как в макете), `balance_after`, `related_content_type`/`related_object_id` (GenericFK — платёж, продвижение, подписка), `idempotency_key` (уникальный, nullable), `created_at`.
- **Леджер неизменяем**: транзакции не редактируются и не удаляются; ошибочная операция компенсируется обратной транзакцией.
- Все изменения баланса — через единственный сервис `apply_transaction(wallet, amount, kind, label, related=None, idempotency_key=None)` внутри `transaction.atomic()` с `select_for_update()` на кошельке. Никто не пишет `wallet.balance` напрямую.
- Списание при недостатке средств → `InsufficientFundsError` → HTTP 402 с кодом `insufficient_funds` и деталями `{required, available}`.
- `GET /api/v1/wallet/` → `{balance, balance_display}` (`balance_display` — «16.700», формат из макета).
- `GET /api/v1/wallet/transactions/?kind=topup|spend|bonus` — история с группировкой по дням (вкладки «Все операции / Пополнение / Списание / Бонусы»).
- Constraint в БД: `balance >= 0`.

**Критерии приёмки.** Конкурентные списания (тест с двумя потоками/транзакциями) не уводят баланс в минус; повтор с тем же `idempotency_key` не создаёт вторую транзакцию; `balance_after` в каждой транзакции согласован с суммой предыдущих.

**Промпт:**

```
В apps/billing реализуй кошелёк внутренней валюты «кирпичи» и неизменяемый леджер операций.

Модель Wallet:
  user: OneToOneField(User, related_name="wallet")
  balance: BigIntegerField(default=0)   # в кирпичах
  updated_at
  Meta.constraints: CheckConstraint(check=Q(balance__gte=0), name="wallet_balance_non_negative")
  Свойство balance_display — форматирование как в макете: 16700 → "16.700"
  (разряды тысяч разделяются точкой).
  Создаётся сигналом post_save на User (get_or_create).

Модель WalletTransaction (append-only леджер):
  wallet: FK(Wallet, related_name="transactions")
  amount: BigIntegerField   # положительное — приход, отрицательное — расход
  kind: CharField(choices: topup, spend, bonus)
  label: CharField(max_length=200)  # человекочитаемо, как в макете:
         "+12 000 сом (12 000 кирпичей)", "+1 200 кирпичей (бонус за пополнение)",
         "-500 кирпичей", "+300 кирпичей (бонус за квест)"
  balance_after: BigIntegerField
  related_content_type / related_object_id — GenericForeignKey на Payment, Promotion,
    Subscription и т.п.
  idempotency_key: CharField(max_length=64, null=True, unique=True)
  created_at (db_index=True)
  Meta: ordering ("-created_at",), indexes на (wallet, "-created_at"), (wallet, kind, "-created_at")
  ЗАПРЕТИ изменение и удаление: переопредели save() (при наличии pk — RuntimeError)
  и delete() (RuntimeError). Ошибочную операцию компенсируют обратной транзакцией,
  а не правкой.

Сервис apply_transaction (apps/billing/services.py) — ЕДИНСТВЕННЫЙ способ менять баланс:
  def apply_transaction(*, wallet, amount: int, kind: str, label: str,
                        related=None, idempotency_key: str | None = None) -> WalletTransaction
  Логика:
  - Внутри transaction.atomic().
  - Если передан idempotency_key и транзакция с ним уже есть — вернуть существующую,
    ничего не создавая (идемпотентность).
  - Wallet.objects.select_for_update().get(pk=...) — блокировка строки.
  - Для отрицательного amount: если wallet.balance + amount < 0 — поднять
    InsufficientFundsError(required=abs(amount), available=wallet.balance).
  - Обновить баланс, создать транзакцию с balance_after.
  Никакой другой код не имеет права писать в wallet.balance — проверь это по репозиторию.

Обработчик исключений: InsufficientFundsError → HTTP 402,
  {"error": {"code": "insufficient_funds", "message": "Недостаточно кирпичей на балансе",
             "details": {"required": 780, "available": 300}}}

Эндпоинты (IsAuthenticated):
  GET /api/v1/wallet/  → {"balance": 16700, "balance_display": "16.700", "currency": "brick"}
  GET /api/v1/wallet/transactions/?kind=topup|spend|bonus
      Курсорная пагинация. Группировка по дням в Asia/Bishkek — как на экране «История
      пополнения и трат»:
      {"results": [{"day_label": "21 августа",
                    "items": [{"id", "amount", "kind", "label", "balance_after", "created_at"}]}],
       "next": ...}
      Без параметра kind — все операции (вкладка «Все операции»).

Тесты (важные):
- параллельные списания: два одновременных apply_transaction с суммой больше половины
  баланса — второй падает с InsufficientFundsError, баланс не уходит в минус
  (используй transaction.atomic + threading или pytest-django с двумя соединениями);
- повторный вызов с тем же idempotency_key возвращает ту же транзакцию, вторая не создаётся;
- попытка изменить сохранённую транзакцию поднимает RuntimeError;
- balance_after каждой транзакции равен сумме всех предыдущих amount;
- balance_display форматирует 16700 → "16.700", 500 → "500", 1200000 → "1.200.000";
- фильтр по kind отдаёт только нужный тип.
```

---

### Задача 5.2. Пополнение кошелька и платёжный провайдер

**Цель.** Флоу `topup_page` (5 шагов: сумма → банк → QR → оплата → «Спасибо за пополнение»).

**Требования.**

- Абстракция `PaymentProvider` с методами `create_payment(amount, order_id, return_url)` и `verify_webhook(request)`. Реализации: `MockPaymentProvider` (dev — платёж подтверждается вручную через `POST /api/v1/wallet/topup/{id}/mock-confirm/`, доступный только при `DEBUG`), заготовка `BankPaymentProvider` под будущий шлюз.
- `POST /api/v1/wallet/topup/` `{amount_kgs}` (обязателен `Idempotency-Key`) → создаёт `Payment` в статусе `pending`, возвращает `{payment_id, amount_kgs, bricks, bonus_bricks, total_bricks, payment_url, qr_code_url, providers: [{name, deeplink, logo}]}`. `providers` — список банков для экрана выбора (MBank, О!Деньги, Элсом, Оптима) из справочника.
- Курс: 1 сом = 1 кирпич, бонус = `round(amount * BONUS_RATE)`, `BONUS_RATE = 0.10` — вынести в настройку `TOPUP_BONUS_RATE`, чтобы маркетинг менял без релиза.
- `POST /api/v1/webhooks/payments/{provider}/` — приём коллбэка. **Обязательна** проверка подписи. Обработка идемпотентна по `provider_ref`. При успехе: `Payment.status = succeeded`, две транзакции в леджере (`topup` на сумму + `bonus` на 10 %), уведомление `wallet_topup`.
- `GET /api/v1/wallet/topup/{payment_id}/` — поллинг статуса клиентом, пока идёт оплата.
- Платёж, не подтверждённый за 30 минут, переводится в `expired` Celery-задачей.
- Все запросы и ответы провайдера логируются в `PaymentLog` (без чувствительных полей) — это нужно для разбора спорных платежей.

**Критерии приёмки.** Двойной webhook с тем же `provider_ref` начисляет кирпичи один раз; webhook с неверной подписью → 403 и ничего не меняет; при `DEBUG=False` mock-подтверждение недоступно; истёкший платёж не начисляется даже при позднем webhook.

**Промпт:**

```
В apps/billing реализуй пополнение кошелька и абстракцию платёжного провайдера.

Модель PaymentProviderConfig (справочник банков для экрана выбора):
  code (unique: "mbank", "odengi", "elsom", "optima"), name, logo (ImageField),
  deeplink_template (CharField), is_active, order

Модель Payment (TimeStampedModel):
  user: FK(User, related_name="payments")
  amount_kgs: DecimalField(max_digits=12, decimal_places=2)
  bricks: BigIntegerField          # 1 сом = 1 кирпич
  bonus_bricks: BigIntegerField    # round(amount * settings.TOPUP_BONUS_RATE)
  provider: CharField, provider_ref: CharField(null, db_index=True)  # id платежа у провайдера
  status: CharField(choices: pending, succeeded, failed, expired, refunded, default="pending")
  idempotency_key: CharField(unique, max_length=64)
  paid_at, expires_at (created_at + 30 минут)
  raw_response: JSONField(default=dict)

Модель PaymentLog: payment (FK, nullable), direction (in/out), endpoint, payload (JSONField,
  с вырезанными чувствительными полями — маскируй card, cvv, token, signature), status_code,
  created_at. Нужен для разбора спорных платежей.

Абстракция провайдера (apps/billing/providers/base.py):
  class PaymentProvider(ABC):
      def create_payment(self, *, payment: Payment, return_url: str) -> PaymentIntent
      def verify_webhook(self, request) -> WebhookResult   # подпись + распарсенные данные
  PaymentIntent = dataclass(payment_url, qr_code_url, provider_ref, extra)
  WebhookResult = dataclass(provider_ref, status, amount, raw)

  Реализации:
  - MockPaymentProvider (providers/mock.py) — create_payment возвращает фиктивный URL и
    QR (сгенерируй QR-картинку библиотекой qrcode и сохрани в media). verify_webhook
    проверяет общий секрет из env.
  - BankPaymentProvider (providers/bank.py) — заготовка с TODO и понятной структурой:
    HTTP-запрос к шлюзу, HMAC-SHA256 подпись, разбор ответа. Оставь абстрактные методы
    с комментариями, куда подставить реальные поля конкретного банка.
  Фабрика get_payment_provider(code) читает settings.PAYMENT_PROVIDER.

Настройки: TOPUP_BONUS_RATE = 0.10 (env-переменная), PAYMENT_EXPIRY_MINUTES = 30.

Эндпоинты:

POST /api/v1/wallet/topup/   (IsAuthenticated, обязателен заголовок Idempotency-Key)
  Тело: {"amount_kgs": 12000, "provider": "mbank"}
  Валидация: сумма от 100 до 500 000 сом, целое число.
  Создаёт Payment(pending), считает bricks = amount, bonus_bricks = round(amount * BONUS_RATE),
  вызывает provider.create_payment.
  Ответ 201:
  {
    "payment_id": "uuid", "amount_kgs": "12000.00",
    "bricks": 12000, "bonus_bricks": 1200, "total_bricks": 13200,
    "payment_url": "...", "qr_code_url": "...",
    "expires_at": "...",
    "providers": [{"code": "mbank", "name": "MBank", "logo_url": "...", "deeplink": "..."}]
  }
  Повторный запрос с тем же Idempotency-Key в течение 24 часов возвращает тот же ответ
  и НЕ создаёт второй Payment.

GET /api/v1/wallet/topup/{payment_id}/   — поллинг статуса клиентом:
  {"status": "pending|succeeded|failed|expired", "balance": 16700, "credited_bricks": 13200}

POST /api/v1/webhooks/payments/{provider}/   (AllowAny, но с обязательной проверкой подписи)
  - provider.verify_webhook(request); неверная подпись → 403, запись в PaymentLog, выход.
  - Найти Payment по provider_ref. Идемпотентность: если статус уже succeeded — вернуть
    200 и ничего не делать.
  - Если payment.status == "expired" — не начислять, вернуть 200 с пометкой в логе.
  - При успехе внутри одной transaction.atomic():
      payment.status = succeeded, paid_at = now
      apply_transaction(wallet, +bricks, kind="topup",
                        label=f"+{formatted} сом ({formatted} кирпичей)",
                        related=payment, idempotency_key=f"payment-{payment.id}-main")
      apply_transaction(wallet, +bonus_bricks, kind="bonus",
                        label=f"+{formatted_bonus} кирпичей (бонус за пополнение)",
                        related=payment, idempotency_key=f"payment-{payment.id}-bonus")
      notify(user, type="wallet_topup", ...)
  - Всегда 200 при успешной обработке (провайдеры ретраят при не-200).

POST /api/v1/wallet/topup/{payment_id}/mock-confirm/   (только при settings.DEBUG,
  иначе 404) — имитирует успешный webhook, чтобы Flutter-разработчик мог пройти флоу.

Celery Beat каждые 5 минут: платежи в статусе pending с expires_at < now переводить
в expired.

Тесты:
- двойной webhook с одним provider_ref начисляет кирпичи один раз;
- webhook с неверной подписью → 403, баланс не меняется, есть запись в PaymentLog;
- webhook по expired-платежу не начисляет;
- повтор POST /wallet/topup/ с тем же Idempotency-Key не создаёт второй Payment;
- сумма 50 сом отклоняется (ниже минимума);
- при DEBUG=False эндпоинт mock-confirm возвращает 404;
- после успешного webhook баланс вырос ровно на bricks + bonus_bricks и в леджере
  ровно две транзакции.

В PaymentLog никогда не пишутся номера карт, CVV и токены — маскируй их перед сохранением.
```

---

## ФАЗА 6. Объявления: создание, медиа, модерация

---

### Задача 6.1. Черновик и публикация объявления

**Цель.** Флоу `ad_form_page` → `ad_photos_page` → `ad_video_page` → `ad_promo_page`.

**Требования.**

- Черновик живёт на сервере, а не только в памяти приложения (`AppState.draft*`) — иначе пользователь теряет заполненную форму при закрытии приложения.
- `POST /api/v1/listings/draft/` — создать/получить текущий черновик пользователя (один активный черновик на пользователя). `PATCH /api/v1/listings/{slug}/` — сохранять форму по мере заполнения (частично, любое подмножество полей).
- Поля формы: тип (Новостройки / Комната / Коммерция / Частный дом), район, комнаты, площадь, этаж, этажность, застройщик, цена + валюта (USD/KGS), продавец (собственник / риелтор / агентство), «разрешить скачивание медиа», описание, контактный телефон.
- `POST /api/v1/listings/{slug}/publish/` — валидация полноты (обязательны: тип, район, цена, площадь, ≥ 1 фото) → `status=pending` (или сразу `active`, если у пользователя включён `is_trusted`).
- Лимиты: бесплатно 3 активных объявления на пользователя; сверх — требуется подписка (фаза 7). Значение — в настройках.
- `GET /api/v1/users/me/listings/?status=` — «Мои объявления» для `pro_profile_page`.
- Действия владельца: `POST /{slug}/archive/`, `POST /{slug}/restore/`, `POST /{slug}/mark-sold/`, `DELETE /{slug}/` (мягкое удаление), `POST /{slug}/bump/` (поднять в выдаче, раз в 24 часа бесплатно).
- Объявление автоматически архивируется через 30 дней без продления; за 3 дня — уведомление.

**Критерии приёмки.** Черновик переживает перезапуск приложения; публикация без фото → `validation_error` с перечнем недостающих полей; 4-е активное объявление без подписки → 409; чужое объявление нельзя изменить.

**Промпт:**

```
В apps/catalog реализуй создание и жизненный цикл объявления (флоу «Продать недвижимость»
во Flutter: ad_form_page → ad_photos_page → ad_video_page → ad_promo_page).

Черновик хранится на СЕРВЕРЕ, а не только в памяти приложения — пользователь не должен
терять заполненную форму.

POST /api/v1/listings/draft/   (IsAuthenticated)
  get_or_create черновика: возвращает существующий Listing со status="draft" у пользователя
  или создаёт новый с дефолтами (kind="new_building", rooms=1, floor=1, floors=1,
  currency="USD", seller_kind="owner", allow_media_download=True — те же дефолты, что
  в AppState Flutter). Ответ — ListingDetailSerializer + поле completeness:
  {"is_complete": false, "missing_fields": ["price", "area", "photos"]}

PATCH /api/v1/listings/{slug}/   (владелец, статус draft/rejected/active)
  Частичное обновление любого подмножества полей формы: kind, district, address, rooms,
  area, land_area, floor, floors, series, builder, price, currency, seller_kind,
  is_secondary, description, allow_media_download, contact_name, contact_phone,
  latitude, longitude.
  Клиент вызывает это по мере заполнения формы, поэтому эндпоинт должен быть дешёвым
  и не требовать полного набора полей.
  Изменение price у активного объявления сохраняет предыдущее значение в old_price,
  если новая цена ниже (для бейджа «было 107 000$»).

POST /api/v1/listings/{slug}/publish/   (владелец)
  Проверки перед публикацией:
  - обязательны: kind, district, price, area, минимум 1 фото; для не-участков — rooms,
    floor, floors; недостающее — 400 validation_error с details.missing_fields
  - лимит активных объявлений: settings.FREE_ACTIVE_LISTINGS = 3. Если у пользователя
    уже столько активных и нет действующей подписки — 409 conflict с кодом и сообщением
    «Достигнут лимит бесплатных объявлений»
  Результат: status = "pending" (на модерацию), либо сразу "active" + published_at=now,
  если у пользователя флаг is_trusted (добавь такое поле в User, по умолчанию False).
  expires_at = published_at + 30 дней.

GET /api/v1/users/me/listings/?status=draft|pending|active|rejected|archived|sold
  «Мои объявления» для экрана pro_profile_page. Возвращает все статусы, если параметр
  не задан. Сортировка: сначала draft и rejected (требуют внимания), затем по -published_at.
  Для каждого — краткая статистика: views_count, favourites_count, is_promoted,
  promoted_until, expires_at.

Действия владельца (все — IsAuthenticated + IsOwner):
  POST   /api/v1/listings/{slug}/archive/     — status="archived"
  POST   /api/v1/listings/{slug}/restore/     — из archived обратно в active,
                                                 если не превышен лимит; expires_at продлевается
  POST   /api/v1/listings/{slug}/mark-sold/   — status="sold", убирается из выдачи
  DELETE /api/v1/listings/{slug}/             — мягкое удаление (поле is_deleted + фильтрация
                                                 в дефолтном менеджере)
  POST   /api/v1/listings/{slug}/bump/        — поднять: published_at = now.
                                                 Бесплатно не чаще раза в 24 часа,
                                                 иначе 429 с retry_after

Менеджеры: Listing.objects — без удалённых; Listing.all_objects — все.
Права: кастомный permission IsListingOwner. Чужое объявление — 403, а не 404
(владение объектом не секрет), но черновик чужого пользователя — 404.

Celery Beat раз в сутки:
  - объявления с expires_at < now → archived + уведомление;
  - за 3 дня до expires_at → уведомление «Объявление скоро будет снято с публикации».

Тесты:
- draft/ дважды подряд возвращает один и тот же черновик;
- PATCH сохраняет частичные данные и не требует полного набора полей;
- publish без фото → 400 с missing_fields = ["photos"];
- 4-я публикация без подписки → 409;
- is_trusted публикует сразу в active;
- чужое объявление нельзя изменить (403);
- bump дважды подряд → 429;
- снижение цены у активного объявления записывает old_price.
```

---

### Задача 6.2. Загрузка и обработка медиа

**Цель.** Экраны `ad_photos_page`, `ad_video_page`, `photos_page` — до 20 фото и 20 видео.

**Требования.**

- `POST /api/v1/listings/{slug}/media/` — `multipart/form-data`, поддержка загрузки нескольких файлов за раз (пользователь выбирает пачку в галерее).
- Валидация: фото — JPEG/PNG/HEIC, до 15 МБ, минимум 600×400; видео — MP4/MOV, до 200 МБ, до 3 минут. Проверка по фактическому содержимому (`python-magic`), а не по расширению.
- Обработка в Celery: EXIF-очистка (**обязательно** — в EXIF лежат GPS-координаты квартиры продавца), ресайз в 3 размера (thumb 400px, medium 1080px, original ≤ 2560px), конвертация в WebP с сохранением JPEG-фолбэка, генерация превью для видео (первый кадр через ffmpeg), извлечение длительности и разрешения.
- Пока обработка идёт, медиа отдаётся со статусом `processing` и временным URL оригинала — экран не должен ждать.
- `PATCH /api/v1/listings/{slug}/media/reorder/` `{order: [id, id, ...]}` — порядок фото (drag-n-drop в галерее). `POST /media/{id}/set-cover/`. `DELETE /media/{id}/`.
- Лимиты 20/20 проверяются с учётом уже загруженных; попытка превысить → `validation_error` с указанием, сколько слотов свободно (`freePhotoSlots` во Flutter).
- Модерация изображений: базовая проверка на дубликаты (perceptual hash) — одно и то же фото в разных объявлениях подсвечивается модератору.

**Критерии приёмки.** Загруженный JPEG с GPS в EXIF после обработки не содержит геоданных; загрузка 21-го фото отклоняется с указанием свободных слотов; файл с подменённым расширением отклоняется; видео дольше 3 минут отклоняется.

**Промпт:**

```
В apps/catalog реализуй загрузку и обработку медиафайлов объявления.

POST /api/v1/listings/{slug}/media/   (владелец, multipart/form-data)
  Принимает НЕСКОЛЬКО файлов за раз (поле files, список) — пользователь выбирает пачку
  в галерее телефона. Параметр kind: "photo" | "video".

  Валидация каждого файла:
  - Определяй тип по СОДЕРЖИМОМУ через python-magic, не по расширению и не по Content-Type.
  - Фото: image/jpeg, image/png, image/heic. Максимум 15 МБ. Минимум 600×400 px.
  - Видео: video/mp4, video/quicktime. Максимум 200 МБ. Максимум 180 секунд
    (проверь через ffprobe до сохранения).
  - Лимиты: MAX_PHOTOS_PER_LISTING=20, MAX_VIDEOS_PER_LISTING=20 с учётом уже загруженных.
    При превышении — 400 validation_error с details {"free_slots": 3,
    "message": "Можно добавить ещё 3 фото"} — во Flutter это freePhotoSlots.
    Если в пачке файлов больше, чем свободных слотов — прими сколько влезает и верни
    в ответе, сколько принято и сколько отклонено (как делает AppState._append).

  Ответ 201: {"accepted": 3, "rejected": 2, "reason": "Достигнут лимит 20 фото",
              "media": [{id, kind, status: "processing", url, order, is_cover}]}

Обработка в Celery (задача process_media(media_id)):
  1. EXIF-очистка — ОБЯЗАТЕЛЬНО и в первую очередь. В EXIF фотографий квартиры лежат
     GPS-координаты, модель телефона и время съёмки; всё это не должно попасть в публичный
     доступ. Используй Pillow: пересохрани изображение без EXIF полностью.
  2. Ресайз в три варианта: thumb (400px по большей стороне), medium (1080px),
     original (не больше 2560px, если исходник больше — уменьшить).
  3. Конвертация в WebP (quality=82) с сохранением JPEG-фолбэка для старых клиентов.
  4. Для видео: превью-кадр на 1-й секунде через ffmpeg, длительность и разрешение
     через ffprobe. Само видео не перекодируй (дорого) — только валидируй.
  5. Перцептивный хеш (imagehash.phash) фото сохраняй в поле ListingMedia.phash —
     по нему модератор увидит одно и то же фото в разных объявлениях.
  6. По завершении: status = "ready", заполнены width, height, duration_seconds, size_bytes,
     все URL-варианты.

  Добавь на ListingMedia поля: status (uploading|processing|ready|failed), phash,
  url_thumb, url_medium, url_original. Пока status != "ready", отдавай url оригинала —
  экран не должен ждать обработки.

Прочие эндпоинты (владелец):
  PATCH  /api/v1/listings/{slug}/media/reorder/  — тело {"order": [12, 8, 3, 5]},
         переставляет порядок одним bulk_update; id не из этого объявления → 400
  POST   /api/v1/listings/{slug}/media/{id}/set-cover/ — снимает флаг с прежней обложки
         и ставит на эту, в одной транзакции
  DELETE /api/v1/listings/{slug}/media/{id}/ — удаляет запись и файлы из хранилища
         (все варианты размеров). Если удалена обложка — обложкой становится первая
         оставшаяся фотография.

Хранилище: django-storages S3 (в dev — MinIO). Ключи файлов —
"listings/{listing_uuid}/{media_uuid}_{variant}.webp", без пользовательских имён файлов
в путях (имя файла с телефона может содержать ПДн).

Тесты:
- JPEG с GPS в EXIF после обработки не содержит EXIF вообще (проверь Pillow-ом);
- .jpg с содержимым PDF отклоняется;
- 21-е фото отклоняется, в ответе указано free_slots;
- пачка из 5 фото при 18 загруженных принимает 2 и отклоняет 3, ответ это отражает;
- видео 4 минуты отклоняется;
- reorder меняет порядок; чужой media_id в списке → 400;
- удаление обложки назначает новую обложку;
- set-cover оставляет ровно одну обложку.
```

---

### Задача 6.3. Модерация

**Цель.** Поток `pending → active | rejected`, инструменты модератора и антифрод-минимум.

**Требования.**

- `ModerationTask`: `listing`, `assigned_to`, `status`, `checks` (JSONB — результаты автопроверок), `created_at`, `resolved_at`.
- Автопроверки при подаче: стоп-слова в описании (телефоны, ссылки, мессенджеры — контакты обходят платную площадку), цена вне разумного диапазона для района (±3σ), дубль объявления (та же связка район+площадь+этаж+цена у другого пользователя), дубль фото по `phash`.
- `GET /api/v1/moderation/queue/` (staff) — очередь с приоритетом: сначала объявления с сработавшими проверками. `POST /api/v1/moderation/{id}/approve/`, `POST /api/v1/moderation/{id}/reject/` `{reason, comment}`.
- Отклонение → уведомление владельцу с причиной, статус `rejected`, объявление можно исправить и подать повторно.
- Причины отклонения — справочник, редактируемый в админке.
- `POST /api/v1/listings/{slug}/report/` `{reason, comment}` — жалоба от пользователя; 3 жалобы автоматически отправляют объявление на перепроверку.

**Критерии приёмки.** Описание с телефоном помечается автопроверкой; повторная подача после исправления снова попадает в очередь; отклонённое объявление не видно в публичном каталоге; 3 жалобы переводят активное объявление в `pending`.

**Промпт:**

```
В apps/catalog создай подсистему модерации объявлений.

Модель ModerationTask (TimeStampedModel):
  listing: FK(Listing, related_name="moderation_tasks")
  assigned_to: FK(User, null=True, limit_choices_to={"is_staff": True})
  status: CharField(choices: open, approved, rejected, default="open")
  checks: JSONField(default=dict) — результаты автопроверок
  priority: PositiveSmallIntegerField(default=0) — чем больше сработавших проверок, тем выше
  reject_reason: FK(RejectReason, null=True), comment: TextField(blank=True)
  resolved_by: FK(User, null=True), resolved_at: DateTimeField(null=True)

Модель RejectReason (справочник, редактируется в админке):
  code (unique), title, description, is_active, order
  Наполни начальными значениями через миграцию данных: «Контакты в описании»,
  «Недостоверная цена», «Дубликат объявления», «Плохое качество фото»,
  «Не соответствует категории», «Подозрение на мошенничество».

Автопроверки (apps/catalog/moderation/checks.py) — запускаются Celery-задачей
run_moderation_checks(listing_id) при переводе объявления в pending:
  1. contacts_in_text — регулярками ищет в description и address: телефоны
     (в т.ч. записанные словами и с разделителями: «0 555 12 34 56», «ноль пятьсот»),
     ссылки, упоминания WhatsApp/Telegram/Instagram. Контакты в тексте — способ увести
     сделку мимо площадки, поэтому проверка обязательна.
  2. price_outlier — сравнивает price_usd за м² с медианой по району и типу за последние
     90 дней; отклонение больше 3 сигм помечается. Если объектов в районе меньше 10 —
     проверка пропускается (мало данных).
  3. duplicate_listing — ищет другое активное объявление с той же связкой
     (district, area ±2 м², floor, rooms, price ±3%) у ДРУГОГО пользователя.
  4. duplicate_photos — по ListingMedia.phash ищет фото с расстоянием Хэмминга ≤ 5
     в объявлениях других пользователей.
  Каждая проверка возвращает {"triggered": bool, "details": {...}}; результат пишется
  в ModerationTask.checks, priority = количество сработавших.

Эндпоинты модератора (permission: IsAdminUser):
  GET  /api/v1/moderation/queue/?status=open&has_triggers=true
       Очередь, отсортированная по -priority, затем по created_at. Каждая запись включает
       объявление целиком, результаты проверок и историю прошлых отклонений этого автора.
  POST /api/v1/moderation/{task_id}/assign/   — взять задачу себе
  POST /api/v1/moderation/{task_id}/approve/  — listing.status="active", published_at=now,
       expires_at=+30 дней, уведомление владельцу типа listing_moderated
  POST /api/v1/moderation/{task_id}/reject/   — тело {"reason_code": "contacts",
       "comment": "..."}, listing.status="rejected", rejection_reason сохраняется,
       уведомление владельцу с причиной и комментарием

Повторная подача: PATCH объявления в статусе rejected разрешён; publish/ создаёт НОВУЮ
ModerationTask, старая остаётся в истории.

Жалобы пользователей:
  Модель ListingReport: listing, reporter (FK User), reason (choices: fraud, sold,
  wrong_info, duplicate, spam), comment, created_at, is_resolved.
  POST /api/v1/listings/{slug}/report/ (IsAuthenticated, один репорт на пользователя
  на объявление). При достижении 3 неразрешённых жалоб активное объявление автоматически
  переводится в pending и создаётся ModerationTask с priority=10 и пометкой в checks.

Админка: ModerationTask с удобным превью (фото объявления, текст, результаты проверок),
действиями approve/reject прямо из списка, фильтрами по статусу и приоритету.

Тесты:
- описание «звоните 0555123456» помечается contacts_in_text;
- описание «звоните мне» — не помечается;
- объявление с ценой в 10 раз выше медианы района помечается price_outlier;
- при менее чем 10 объектах в районе проверка price_outlier пропускается;
- одинаковое фото в двух объявлениях разных пользователей помечается duplicate_photos;
- отклонённое объявление не появляется в GET /api/v1/listings/;
- после исправления и повторной публикации создаётся новая задача модерации;
- 3 жалобы переводят активное объявление в pending;
- обычный пользователь получает 403 на эндпоинтах модерации.
```

---

## ФАЗА 7. Монетизация

---

### Задача 7.1. Продвижение объявлений

**Цель.** Экран `ad_promo_page`: продвижение за кирпичи, 780 за день, опции «точное продвижение», «клиентская база», «WhatsApp база».

**Требования.**

- `PromotionPackage` (справочник): `code`, `name`, `price_per_day_bricks` (базовое — 780), `description`, `is_active`.
- `Promotion`: `listing`, `package`, `days`, `cost_bricks`, `starts_at`, `ends_at`, `options` (JSONB: `exact_targeting`, `client_base`, `whatsapp_base`), `transaction` (FK на `WalletTransaction`).
- `POST /api/v1/listings/{slug}/promote/` `{days, options}` (нужен `Idempotency-Key`) → считает стоимость, списывает через `apply_transaction`, ставит `listing.promoted_until = max(now, promoted_until) + days` (продление складывается, а не обнуляет остаток).
- Недостаточно кирпичей → 402 `insufficient_funds` с `{required, available, shortfall}` — приложение по этому ответу открывает экран пополнения.
- `GET /api/v1/promotions/pricing/?days=3&options=...` — предварительный расчёт для экрана, без списания.
- Celery Beat: за сутки до окончания — уведомление `promotion_expiring`; по окончании — снять флаг.
- `GET /api/v1/listings/{slug}/stats/` (владелец) — показы, просмотры, добавления в избранное, звонки по дням; для продвинутых объявлений — сравнение «до / во время продвижения».

**Критерии приёмки.** Продление активного продвижения складывает дни; при нехватке средств не создаётся ни `Promotion`, ни транзакция; повтор с тем же `Idempotency-Key` не списывает дважды.

**Промпт:**

```
В apps/billing реализуй платное продвижение объявлений (экран ad_promo_page во Flutter).

Модель PromotionPackage (справочник, миграция данных с начальным значением):
  code (unique), name, price_per_day_bricks (BigInteger; базовый пакет — 780 кирпичей/день,
  как в AppState.promoCost = promoDays * 780), description, is_active, order

Модель PromotionOption (справочник дополнительных опций из макета):
  code: "exact_targeting" («Использовать точное продвижение»),
        "client_base" («Использовать клиентскую базу»),
        "whatsapp_base" («Использовать Whatsapp базу»)
  name, price_per_day_bricks, description, is_active

Модель Promotion (TimeStampedModel):
  listing: FK(Listing, related_name="promotions")
  package: FK(PromotionPackage), days: PositiveSmallIntegerField
  options: JSONField(default=list) — список кодов выбранных опций
  cost_bricks: BigIntegerField
  starts_at, ends_at: DateTimeField
  transaction: FK(WalletTransaction, null=True, on_delete=PROTECT)
  status: CharField(choices: active, finished, refunded)

GET /api/v1/promotions/pricing/?days=3&options=exact_targeting,whatsapp_base
  Предрасчёт для экрана, БЕЗ списания:
  {
    "days": 3, "base_cost": 2340,
    "options": [{"code": "exact_targeting", "name": "...", "cost": 300}],
    "options_cost": 600, "total_cost": 2940,
    "balance": 16700, "is_affordable": true,
    "promoted_until_after": "2026-08-26T10:00:00Z"
  }
  Также отдаёт список доступных пакетов и опций — экран рисует их из этого ответа.

POST /api/v1/listings/{slug}/promote/   (владелец, обязателен Idempotency-Key)
  Тело: {"days": 3, "package": "standard", "options": ["exact_targeting"]}
  Логика в одной transaction.atomic():
  - Объявление должно быть в статусе active — иначе 409.
  - Считает стоимость (дни × цена пакета + дни × цены опций).
  - apply_transaction(wallet, -cost, kind="spend", label=f"-{cost} кирпичей",
                      related=promotion, idempotency_key=<из заголовка>)
    При нехватке средств — InsufficientFundsError → 402 с details
    {"required": 2940, "available": 300, "shortfall": 2640}. Ни Promotion, ни транзакция
    при этом не создаются (весь блок атомарный). Приложение по коду insufficient_funds
    открывает экран пополнения.
  - listing.promoted_until = max(now, listing.promoted_until or now) + timedelta(days=days)
    ВАЖНО: продление складывается с остатком, а не обнуляет его.
  Ответ 201: {"promotion_id", "cost_bricks", "promoted_until", "balance_after"}

GET /api/v1/listings/{slug}/promotions/   (владелец) — история продвижений объявления.

GET /api/v1/listings/{slug}/stats/   (владелец)
  Статистика по дням за последние 30 дней: impressions (показы в выдаче), views (открытия
  карточки), favourites, phone_reveals (нажатия «показать телефон»).
  Для этого заведи модель ListingDailyStat (listing, date, impressions, views, favourites,
  phone_reveals) с unique_together (listing, date) и инкрементируй её через F-выражения
  из соответствующих эндпоинтов (показы — батчем из списочного эндпоинта, не по одному
  UPDATE на объект: собирай id в Redis и сбрасывай в БД Celery-задачей раз в 5 минут).
  Если объявление продвигалось — добавь блок сравнения средних значений до продвижения
  и во время.

Celery Beat каждый час:
  - promotions с ends_at < now → status="finished"; если у объявления не осталось активных
    продвижений — promoted_until = None;
  - за 24 часа до ends_at — уведомление promotion_expiring «Продвижение заканчивается завтра».

Тесты:
- продвижение на 3 дня списывает ровно 3 × 780 кирпичей;
- опции добавляются к стоимости;
- нехватка средств → 402, Promotion не создан, баланс не изменился;
- повторный вызов с тем же Idempotency-Key не списывает дважды;
- продление активного продвижения складывает дни, а не заменяет;
- продвижение неактивного объявления → 409;
- истёкшее продвижение снимает promoted_until.
```

---

### Задача 7.2. Подписки и тарифы

**Цель.** Экраны `subscriptions` и `tariffs` — тарифы для риелторов и агентств.

**Требования.**

- `Tariff`: `code`, `name`, `price_bricks_per_month`, `listings_limit`, `features` (JSONB: приоритет в выдаче, расширенная статистика, бейдж «проверенный», автоподнятие), `is_active`, `order`.
- `Subscription`: `user`, `tariff`, `starts_at`, `ends_at`, `is_auto_renew`, `status`, `transaction`.
- `GET /api/v1/tariffs/`, `POST /api/v1/subscriptions/` `{tariff_code, months}`, `GET /api/v1/subscriptions/current/`, `POST /api/v1/subscriptions/cancel/`.
- Оплата — кирпичами через `apply_transaction`.
- Активная подписка расширяет лимит объявлений (проверка в задаче 6.1) и даёт бонусы, описанные в `features`.
- Автопродление: Celery-задача за сутки до окончания списывает следующий период; при нехватке средств — уведомление и перевод в `expired` (объявления сверх бесплатного лимита архивируются с уведомлением, не удаляются).

**Критерии приёмки.** Активная подписка снимает лимит на публикацию; автопродление при нехватке средств не уводит баланс в минус; отмена подписки не отбирает оплаченный период.

**Промпт:**

```
В apps/billing реализуй подписки и тарифы для риелторов и агентств (экраны subscriptions
и tariffs).

Модель Tariff (справочник):
  code (unique: "free", "realtor", "agency"), name, description
  price_bricks_per_month: BigIntegerField
  listings_limit: PositiveIntegerField (0 = без ограничений)
  features: JSONField(default=dict) — {"priority_in_search": true, "advanced_stats": true,
            "verified_badge": true, "auto_bump_daily": true, "support_priority": false}
  is_active, order
  Миграция данных с тремя начальными тарифами.

Модель Subscription (TimeStampedModel):
  user: FK(User, related_name="subscriptions"), tariff: FK(Tariff, on_delete=PROTECT)
  starts_at, ends_at: DateTimeField
  is_auto_renew: BooleanField(default=True)
  status: CharField(choices: active, expired, cancelled)
  transaction: FK(WalletTransaction, null=True, on_delete=PROTECT)
  Свойство is_current = status == "active" and ends_at > now

Эндпоинты:
  GET  /api/v1/tariffs/   (AllowAny) — активные тарифы с features и ценами; у текущего
       тарифа пользователя пометка is_current
  POST /api/v1/subscriptions/   (IsAuthenticated, Idempotency-Key)
       Тело {"tariff_code": "realtor", "months": 1}
       Списывает price_bricks_per_month × months через apply_transaction
       (kind="spend", label="-N кирпичей (подписка «Риелтор», 1 мес.)").
       Если активная подписка уже есть: продление того же тарифа складывает срок;
       смена тарифа на более дорогой — пересчёт с зачётом остатка (pro rata),
       на более дешёвый — вступает в силу после окончания текущего периода.
       Нехватка средств → 402 insufficient_funds.
  GET  /api/v1/subscriptions/current/  — текущая подписка с ends_at, лимитами и остатком
       свободных слотов объявлений
  POST /api/v1/subscriptions/cancel/   — is_auto_renew=False; подписка ДЕЙСТВУЕТ
       до конца оплаченного периода (не отбирай оплаченное), status меняется на cancelled
       только по истечении

Интеграция с лимитом объявлений (задача 6.1): сервис get_listings_limit(user) возвращает
settings.FREE_ACTIVE_LISTINGS для пользователя без подписки и tariff.listings_limit
при активной подписке. Публикация проверяет лимит через этот сервис.

Приоритет в выдаче: если features["priority_in_search"] — объявления пользователя
поднимаются в каталоге после продвинутых, но выше обычных. Реализуй через annotate
в списочном queryset (без N+1: одним подзапросом Exists по активным подпискам).

Celery Beat раз в сутки:
  - за 24 часа до ends_at при is_auto_renew=True — попытка списать следующий период.
    Успех — продление и уведомление; нехватка средств — уведомление «Не удалось продлить
    подписку, пополните баланс» и НИКАКОГО ухода баланса в минус;
  - подписки с ends_at < now → status="expired". Если активных объявлений больше
    бесплатного лимита — архивировать самые старые сверх лимита и уведомить владельца
    (не удалять!);
  - auto_bump_daily: для тарифов с этой фичей раз в сутки поднимать объявления
    пользователя (published_at = now).

Тесты:
- покупка подписки списывает верную сумму и снимает лимит публикации;
- продление того же тарифа складывает сроки;
- отмена не отбирает оплаченный период;
- автопродление при нулевом балансе не уходит в минус и шлёт уведомление;
- истечение подписки архивирует объявления сверх лимита, начиная с самых старых;
- priority_in_search поднимает объявления в выдаче, но ниже продвинутых.
```

---

## ФАЗА 8. Профиль исполнителя и агентства

---

### Задача 8.1. Публичный профиль продавца

**Цель.** Экраны `agent`, `agentProfile`, `agentListings`, `pro_profile_page`.

**Требования.**

- `SellerProfile` (OneToOne с `User`): `company_name`, `logo`, `about`, `experience_years`, `work_area` (районы), `rating`, `reviews_count`, `is_verified`, `verified_at`, `whatsapp`, `telegram`, `working_hours`.
- `GET /api/v1/sellers/{id}/` — публичный профиль: имя/компания, бейдж «проверенный», число объявлений, стаж на площадке, рейтинг.
- `GET /api/v1/sellers/{id}/listings/` — активные объявления продавца, с фильтрами.
- Отзывы: `Review` (`seller`, `author`, `rating` 1–5, `text`, `listing` nullable, `is_moderated`). `POST /api/v1/sellers/{id}/reviews/`, `GET /api/v1/sellers/{id}/reviews/`. Один отзыв от пользователя на продавца; отзыв проходит модерацию перед публикацией; рейтинг пересчитывается денормализованно.
- Верификация агентства: `POST /api/v1/sellers/me/verification/` с документами → задача в очередь модерации → бейдж.
- `POST /api/v1/listings/{slug}/contact/` — фиксирует раскрытие телефона (для статистики и антифрода) и возвращает контакты продавца.

**Критерии приёмки.** Рейтинг пересчитывается при добавлении/удалении отзыва; отзыв самому себе отклоняется; немодерированный отзыв не виден публично.

**Промпт:**

```
В apps/users реализуй публичный профиль продавца (экраны «Агент», «Профиль агента»,
«Объявления агента»).

Модель SellerProfile (OneToOne с User, related_name="seller_profile", создаётся при
получении is_pro=True):
  company_name: CharField(blank=True)      # для агентств
  logo: ImageField(nullable), about: TextField(blank=True)
  experience_years: PositiveSmallIntegerField(default=0)
  work_districts: M2M(District, blank=True)
  whatsapp, telegram, instagram: CharField(blank=True)
  working_hours: JSONField(default=dict)   # {"mon": ["09:00","18:00"], ...}
  rating: DecimalField(max_digits=3, decimal_places=2, default=0)  # денормализовано
  reviews_count: PositiveIntegerField(default=0)
  is_verified: BooleanField(default=False), verified_at: DateTimeField(null=True)

Модель Review (TimeStampedModel):
  seller: FK(User, related_name="reviews_received")
  author: FK(User, related_name="reviews_written")
  listing: FK(Listing, null=True, on_delete=SET_NULL)  # по какому объекту был контакт
  rating: PositiveSmallIntegerField (валидатор 1–5)
  text: TextField(blank=True)
  status: CharField(choices: pending, published, rejected, default="pending")
  Meta: unique_together (seller, author)

Модель SellerVerification:
  seller: FK(User), documents: JSONField (список ссылок на загруженные файлы),
  status (pending/approved/rejected), comment, reviewed_by, reviewed_at

Эндпоинты:
  GET  /api/v1/sellers/{user_id}/   (AllowAny)
       {id, name, company_name, seller_kind, logo_url, about, experience_years,
        is_verified, rating, reviews_count, active_listings_count, member_since,
        work_districts, contacts: {phone, whatsapp, telegram}}
       Контакты — полностью только авторизованным, анониму маскированы (как в задаче 2.3).
  GET  /api/v1/sellers/{user_id}/listings/   (AllowAny) — активные объявления продавца
       с той же фильтрацией и пагинацией, что и каталог
  GET  /api/v1/sellers/me/  /  PATCH /api/v1/sellers/me/   (IsAuthenticated, is_pro)
       — свой профиль продавца, редактирование всех полей кроме rating/is_verified
  GET  /api/v1/sellers/{user_id}/reviews/    — только status="published"
  POST /api/v1/sellers/{user_id}/reviews/    (IsAuthenticated)
       Нельзя оставить отзыв самому себе (400). Один отзыв на продавца от пользователя
       (повтор → 409, для изменения — PATCH своего отзыва). Создаётся со status="pending",
       уходит в модерацию.
  POST /api/v1/sellers/me/verification/  — загрузка документов агентства (multipart),
       создаёт заявку и задачу модератору
  POST /api/v1/listings/{slug}/contact/   (IsAuthenticated)
       Фиксирует раскрытие телефона: инкремент ListingDailyStat.phone_reveals,
       запись ContactEvent (listing, user, created_at) для антифрода.
       Возвращает {phone, whatsapp, name}. Throttle: 30 раскрытий в час на пользователя.

Пересчёт рейтинга: сервис recalc_seller_rating(seller) — агрегат Avg по published-отзывам,
вызывается при публикации, изменении и удалении отзыва. Не сигналом на каждое сохранение
Review, а явным вызовом из сервиса модерации отзывов.

Модерация отзывов: добавь Review в админку с действиями «Опубликовать»/«Отклонить»
и в очередь модерации из задачи 6.3.

Тесты:
- отзыв самому себе → 400;
- второй отзыв тому же продавцу → 409;
- pending-отзыв не виден в публичном списке и не влияет на рейтинг;
- публикация отзыва пересчитывает rating и reviews_count;
- удаление отзыва пересчитывает их обратно;
- аноним видит маскированный телефон продавца;
- 31-е раскрытие телефона за час → 429.
```

---

## ФАЗА 9. Качество, эксплуатация, безопасность

---

### Задача 9.1. Тесты, фикстуры и нагрузочная проверка

**Цель.** Покрытие, которому можно доверять при рефакторинге.

**Требования.**

- Покрытие ≥ 80 % по строкам, ≥ 95 % для `apps/billing` (деньги).
- Фабрики на все модели, `conftest.py` с фикстурами: `api_client`, `auth_client`, `pro_client`, `admin_client`, `listing`, `wallet_with_balance`.
- Отдельный набор тестов на конкурентность в биллинге (параллельные списания).
- Контрактные тесты: сгенерированная OpenAPI-схема проверяется на обратную совместимость с предыдущей версией (`schemathesis` или сравнение схем в CI).
- Smoke-нагрузка: `locust`-сценарий на каталог (список + карточка + фильтр), критерий — p95 < 300 мс при 100 RPS на 50 000 объявлений.

**Промпт:**

```
Доведи тестовое покрытие бэкенда до продакшен-уровня.

1. conftest.py в корне tests/ с фикстурами:
   api_client (APIClient), auth_client (обычный пользователь + JWT в заголовке),
   pro_client (is_pro + кошелёк), admin_client (is_staff),
   listing (активное объявление с 3 фото), wallet_with_balance(balance=50000),
   district, city, tariff, promotion_package.
   Фабрики factory_boy на ВСЕ модели проекта в tests/factories.py.

2. Добейся покрытия: ≥80% по строкам для всего проекта и ≥95% для apps/billing —
   там движутся деньги, и непокрытая ветка в леджере стоит дороже всех остальных.
   Настрой в pyproject.toml пороги через --cov-fail-under и отдельную проверку для billing.

3. Тесты на конкурентность (tests/test_concurrency.py):
   - два параллельных apply_transaction на списание при балансе, которого хватает
     только на одно — ровно одно проходит, второе падает с InsufficientFundsError,
     баланс не отрицательный;
   - два параллельных webhook'а по одному платежу начисляют кирпичи один раз;
   - параллельное добавление в избранное одного объявления не ломает счётчик.
   Используй реальные параллельные соединения к БД (pytest-django с
   django_db(transaction=True) и threading), а не моки.

4. Контрактные тесты OpenAPI:
   - тест, проверяющий, что схема генерируется без ошибок и предупреждений
     drf-spectacular;
   - сохрани текущую схему в tests/snapshots/openapi.json и добавь тест на обратную
     совместимость: удаление эндпоинта, удаление поля из ответа или ужесточение типа
     ломают тест. Обновление снапшота — осознанное действие через отдельную make-цель.

5. Нагрузочный сценарий на locust (loadtest/locustfile.py):
   - 70% запросов — GET /api/v1/listings/ со случайными фильтрами;
   - 20% — GET /api/v1/listings/{slug}/;
   - 10% — GET /api/v1/listings/count/.
   Плюс management-команда generate_load_data --count=50000, наполняющая БД
   объявлениями для нагрузочного теста.
   Задокументируй в README целевые показатели: p95 < 300 мс при 100 RPS.

6. Добавь в Makefile: test, test-cov, test-billing, test-concurrency, loadtest.

Запусти весь набор и убедись, что он зелёный и пороги покрытия достигнуты.
```

---

### Задача 9.2. Безопасность, ПДн и наблюдаемость

**Цель.** Продакшен-готовность: защита данных, аудит, мониторинг. С учётом обязательств по защите персональных данных в законодательстве КР.

**Требования.**

- Rate limiting на все чувствительные эндпоинты (аутентификация, загрузка медиа, раскрытие контактов, платежи).
- Структурированные логи (JSON, `structlog`) с `request_id`; ПДн (телефон, ИИН) в логах маскируются на уровне процессора логгера, а не по договорённости.
- `AuditLog` на действия с деньгами, модерацию, изменение ролей: кто, что, когда, с какого IP.
- Sentry для ошибок, `django-prometheus` для метрик, `/metrics/` за внутренней сетью.
- Экспорт и удаление данных пользователя: `POST /api/v1/users/me/export/` (Celery готовит JSON-архив, ссылка приходит уведомлением), `DELETE /api/v1/users/me/` (уже есть, но должно чистить и медиа).
- Согласия: модель `UserConsent` (тип согласия, версия документа, дата, IP) — на обработку ПДн и на маркетинговые рассылки.
- Шифрование ИИН в БД (`django-cryptography` или `pgcrypto`).
- Заголовки безопасности, HTTPS-only cookies, CSP для админки, ограничение админки по IP.

**Промпт:**

```
Приведи бэкенд к продакшен-уровню по безопасности, работе с персональными данными
и наблюдаемости. Проект работает с ПДн граждан Кыргызстана (телефоны, ИИН), поэтому
требования к защите данных здесь не формальность.

1. Rate limiting (apps/common/throttling.py), поверх Redis:
   - /auth/otp/request/: 1/минуту и 5/час на номер, 20/час на IP
   - /auth/password/login/: 10/час на номер, 30/час на IP
   - /listings/{slug}/contact/: 30/час на пользователя
   - загрузка медиа: 100 файлов/час на пользователя
   - /wallet/topup/: 10/час на пользователя
   - общий anon-throttle 100/минуту, user-throttle 300/минуту
   Ответ при превышении — формат ошибок проекта с details.retry_after.

2. Структурированное логирование (structlog):
   - JSON-логи, у каждой записи request_id (middleware, генерирует UUID или берёт
     из заголовка X-Request-ID), user_id, path, method, status, duration_ms;
   - процессор маскирования ПДн: любое значение, похожее на телефон (+996...),
     ИИН (14 цифр), токен или email, маскируется ДО записи в лог.
     Это должно работать на уровне процессора structlog, а не на дисциплине
     разработчиков — иначе ПДн рано или поздно утекут в логи;
   - разные уровни для local (консоль, читаемо) и production (JSON).

3. Модель AuditLog (apps/common):
   actor (FK User, null), action (CharField), target_type/target_id, changes (JSONField),
   ip_address, user_agent, created_at.
   Пиши в него: все операции с кошельком, решения модерации, изменение is_staff/is_pro/
   is_trusted, удаление аккаунта, изменение цены объявления, вход по паролю.
   Реализуй сервис audit(actor, action, target, changes, request) и вызывай явно —
   не через сигналы.

4. Персональные данные:
   - Шифрование ИИН в БД: используй pgcrypto или django-cryptography, ключ — из env.
     Существующие данные мигрируй.
   - Модель UserConsent: user, consent_type (personal_data, marketing, cookies),
     document_version, granted (bool), ip_address, created_at. Согласие на обработку ПДн
     обязательно при регистрации — эндпоинт verify возвращает 400, если в теле нет
     accepted_terms_version.
   - POST /api/v1/users/me/export/ — Celery-задача собирает все данные пользователя
     (профиль, объявления, избранное, история, транзакции) в JSON, кладёт в приватное
     хранилище со ссылкой на 24 часа и шлёт уведомление. Не более одного экспорта в сутки.
   - DELETE /api/v1/users/me/ дополнительно ставит Celery-задачу удаления медиафайлов
     пользователя из хранилища и анонимизации записей в леджере (сами транзакции остаются
     для бухгалтерии, но обезличиваются).

5. Наблюдаемость:
   - Sentry (sentry-sdk с интеграциями Django и Celery), DSN из env,
     traces_sample_rate из env, send_default_pii=False;
   - django-prometheus, эндпоинт /metrics/ доступен только из внутренней сети
     (проверка по IP в middleware или на уровне nginx);
   - кастомные метрики: количество публикаций объявлений, сумма пополнений, число
     неуспешных платежей, длина очереди модерации, время обработки медиа.

6. Заголовки и настройки безопасности в production.py:
   SECURE_HSTS_SECONDS=31536000 с preload и include_subdomains, SECURE_SSL_REDIRECT,
   SESSION_COOKIE_SECURE, CSRF_COOKIE_SECURE, SECURE_CONTENT_TYPE_NOSNIFF,
   X_FRAME_OPTIONS="DENY", Referrer-Policy, CSP для админки (django-csp).
   Админка: доступна только с IP из ALLOWED_ADMIN_IPS (env), путь из env
   (не /admin/ по умолчанию), обязательная 2FA для staff (django-otp).

7. Проверка зависимостей: добавь в CI шаг pip-audit и ruff с правилом S (bandit).

Тесты:
- превышение лимита OTP возвращает 429 с retry_after;
- телефон и ИИН не появляются в логах (перехвати вывод логгера в тесте);
- ИИН в БД хранится зашифрованным (проверь сырым SQL-запросом);
- AuditLog создаётся при списании с кошелька и при решении модератора;
- /metrics/ недоступен с внешнего IP;
- регистрация без accepted_terms_version отклоняется.
```

---

### Задача 9.3. Docker, CI/CD и деплой

**Цель.** Воспроизводимая сборка и автоматический деплой.

**Требования.**

- Production `Dockerfile`: многостадийный, non-root, `gunicorn` + `uvicorn`-воркеры, healthcheck.
- `docker-compose.prod.yml`: `web`, `celery`, `celery-beat`, `nginx`, `postgres`, `redis`; тома для медиа и бэкапов.
- GitHub Actions: линт → тесты → сборка образа → пуш в registry → деплой на сервер по SSH; миграции применяются отдельным шагом до перезапуска web.
- Бэкапы PostgreSQL: ежедневный `pg_dump` в S3, retention 30 дней, задокументированная процедура восстановления с проверкой.
- Zero-downtime: миграции пишутся обратно совместимо (добавление полей — nullable, удаление — в два релиза).
- `.env.production.example`, инструкция по первому развёртыванию в `docs/deploy.md`.

**Промпт:**

```
Настрой продакшен-сборку и автоматический деплой бэкенда.

1. docker/Dockerfile.prod — многостадийный:
   - стадия builder: установка зависимостей в venv (poetry export или uv)
   - финальная стадия: python:3.12-slim, копирование venv, non-root пользователь app,
     collectstatic на этапе сборки, HEALTHCHECK на /api/v1/health/
   - запуск: gunicorn с uvicorn-воркерами (config.asgi:application),
     число воркеров из переменной окружения, graceful timeout 30с

2. docker-compose.prod.yml: web, celery (2 воркера), celery-beat, nginx, postgres:16,
   redis:7. Тома для media, static, postgres-data, backups. Все сервисы с restart: unless-stopped
   и healthcheck. Nginx: отдача static/media, gzip, client_max_body_size 200M
   (видео объявлений), проксирование на web, rate limit на /api/v1/auth/.

3. GitHub Actions (.github/workflows/ci.yml):
   - job lint: ruff check + ruff format --check + mypy
   - job test: поднимает postgres и redis сервисами, прогоняет pytest с покрытием,
     публикует отчёт, падает при покрытии ниже порога
   - job security: pip-audit
   - job build (только на main): сборка образа, тег по SHA и latest, пуш в GHCR
   - job deploy (только на main, после build): SSH на сервер, docker compose pull,
     ОТДЕЛЬНЫМ шагом `docker compose run --rm web python manage.py migrate`,
     затем docker compose up -d, затем smoke-проверка /api/v1/health/ с откатом
     на предыдущий тег при неудаче

4. Бэкапы: скрипт docker/backup.sh — pg_dump | gzip | загрузка в S3 с именем по дате,
   удаление копий старше 30 дней. Cron-контейнер или systemd-таймер на хосте — раз в сутки
   в 03:00 Asia/Bishkek. Скрипт restore.sh для восстановления.
   В docs/deploy.md опиши процедуру восстановления ПОШАГОВО и добавь пункт «проверять
   восстановление раз в квартал» — бэкап, который ни разу не восстанавливали,
   бэкапом не является.

5. Правила миграций (запиши в CLAUDE.md):
   - только обратно совместимые изменения: новое поле — nullable или с default;
   - удаление поля — в два релиза (сначала перестать использовать, потом удалить);
   - переименование — через добавление нового поля + копирование данных + удаление старого;
   - тяжёлые индексы — CREATE INDEX CONCURRENTLY через SeparateDatabaseAndState;
   - каждая миграция должна применяться на копии продакшен-базы за разумное время.

6. .env.production.example со всеми переменными и docs/deploy.md: первое развёртывание,
   выпуск TLS-сертификата (certbot), настройка S3, подключение Sentry, чек-лист
   перед первым релизом.

Проверь, что docker compose -f docker-compose.prod.yml up собирается и поднимается локально.
```

---

## ФАЗА 10. Перспективные функции

> Эти задачи не входят в MVP. Планируйте их после запуска, когда накопятся данные.

---

### Задача 10.1. Ипотечный калькулятор

**Промпт:**

```
В новом приложении apps/mortgage реализуй ипотечный калькулятор под банки Кыргызстана.

Модели:
  Bank: name, slug, logo, is_active, order
  MortgageProgram: bank (FK), name, program_type (choices: standard, state_support,
    military, young_family, islamic), min_rate/max_rate (Decimal, годовых),
    min_down_payment_percent, max_term_months, min_amount/max_amount, currency,
    requirements (JSONField), property_kinds (список типов недвижимости, ArrayField),
    is_active, valid_from/valid_to
  MortgageApplication: user, listing (nullable), program, amount, down_payment, term_months,
    monthly_income, status (draft/submitted/contacted), created_at

Эндпоинты:
  GET  /api/v1/mortgage/banks/
  GET  /api/v1/mortgage/programs/?property_kind=apartment&amount=100000
       — программы, подходящие под параметры, отсортированные по ставке
  POST /api/v1/mortgage/calculate/
       Тело: {"price": 100000, "currency": "USD", "down_payment": 20000,
              "term_months": 180, "program_id": 3}
       Ответ: {"monthly_payment", "total_payment", "overpayment", "effective_rate",
               "schedule": [первые 12 месяцев графика: {month, payment, principal,
               interest, balance}], "required_income"}
       Аннуитетный платёж по стандартной формуле; считай в Decimal с округлением до копеек,
       НЕ во float. Добавь также расчёт дифференцированного платежа отдельным параметром
       payment_type.
  POST /api/v1/mortgage/compare/  — сравнение до 5 программ по одним параметрам
  POST /api/v1/mortgage/applications/  — заявка на консультацию (уходит менеджеру
       уведомлением, персональные данные заявителя — по тем же правилам, что и везде)

Интеграция с каталогом: GET /api/v1/listings/{slug}/mortgage/ — подходящие программы
и примерный платёж для цены этого объекта, кэш 1 час.

Тесты: расчёт аннуитета сверен с эталонными значениями (несколько кейсов посчитай
вручную и зафиксируй как ожидаемые); нулевая ставка не даёт деления на ноль; первоначальный
взнос ниже минимального по программе отклоняется; вся арифметика в Decimal.
```

---

### Задача 10.2. Аналитика цен по районам

**Промпт:**

```
В apps/analytics реализуй статистику цен по районам — «сколько стоит квадрат в Асанбае».

Модель DistrictPriceStat:
  district (FK), property_kind, rooms (nullable), period (date, первое число месяца)
  median_price_usd, median_price_per_sqm_usd, avg_price_per_sqm_usd,
  min_price, max_price, listings_count, sold_count
  Meta: unique_together (district, property_kind, rooms, period)

Celery Beat раз в сутки пересчитывает статистику за текущий месяц по активным и проданным
объявлениям. Периоды с числом объявлений меньше 5 помечай флагом is_reliable=False и
не показывай как надёжные — статистика по трём квартирам не статистика.

Эндпоинты (AllowAny):
  GET /api/v1/analytics/districts/?kind=apartment&rooms=2
      Список районов с медианной ценой за м², изменением за месяц и за год в процентах,
      числом объявлений. Сортировка по цене или по динамике.
  GET /api/v1/analytics/districts/{slug}/
      Детально по району: динамика за 24 месяца (для графика), разбивка по комнатности
      и типу, топ застройщиков, среднее время экспозиции.
  GET /api/v1/analytics/price-index/
      Сводный индекс цен по городу помесячно за 24 месяца.
  GET /api/v1/listings/{slug}/price-analysis/
      Для конкретного объекта: как его цена за м² соотносится с медианой района
      («на 12% ниже средней по Асанбаю»), позиция в перцентилях, оценка адекватности цены.
      Именно этот ответ питает бейдж «ниже рынка» — переведи флаг below_market
      с ручного проставления на расчётный (ниже медианы района на 10% и более
      при is_reliable=True).

Management-команда backfill_price_stats --months=24 для расчёта истории по имеющимся данным.

Кэш: все аналитические эндпоинты — Redis на 6 часов, инвалидация после пересчёта.

Тесты: медиана считается верно на контрольном наборе; период с 3 объявлениями помечается
ненадёжным; price-analysis корректно определяет отклонение от медианы; below_market
проставляется автоматически.
```

---

### Задача 10.3. Антифрод

**Промпт:**

```
В apps/antifraud реализуй систему выявления мошеннических объявлений и аккаунтов.
Мошенничество на рынке аренды и продажи жилья — основная причина, по которой люди
перестают доверять площадке, поэтому проверки должны быть заметными, но не мешать
добросовестным продавцам.

Модель RiskSignal: subject_type (listing/user), subject_id, signal_code, severity
  (low/medium/high), details (JSONField), created_at, is_resolved
Модель RiskScore: subject_type, subject_id, score (0–100), level (low/medium/high/critical),
  calculated_at, signals_snapshot (JSONField)

Сигналы (каждый — отдельная функция в apps/antifraud/signals/, возвращает RiskSignal
или None):
  Для объявлений:
  - price_too_low: цена ниже медианы района более чем на 40% (классическая приманка)
  - stock_photos: фото найдено в других объявлениях по phash или имеет признаки
    стокового изображения (метаданные, соотношение сторон, водяной знак)
  - contacts_in_description: контакты в тексте (переиспользуй проверку из модерации)
  - rapid_posting: пользователь опубликовал больше 10 объявлений за час
  - description_reuse: описание совпадает с другим объявлением более чем на 90%
    (difflib или триграммы)
  - no_media_variety: все фото загружены в одну секунду (признак пачки из интернета)
  Для пользователей:
  - new_account_activity: аккаунт младше 24 часов и уже публикует платное продвижение
  - many_reports: 3+ жалобы за 7 дней
  - device_sharing: один FCM-токен у 5+ аккаунтов
  - phone_churn: частая смена контактного телефона в объявлениях

Расчёт риска: взвешенная сумма сигналов, веса — в настройках (JSON в БД, редактируется
в админке, без релиза). Пересчёт — Celery-задачей при публикации объявления и при
появлении нового сигнала.

Реакции по уровню (настраиваемые):
  low     — ничего
  medium  — объявление уходит на ручную модерацию с пометкой
  high    — объявление скрывается из выдачи до решения модератора, автор уведомляется
  critical— автоматическая блокировка публикаций аккаунта, задача модератору с приоритетом

Эндпоинты (IsAdminUser):
  GET  /api/v1/antifraud/queue/?level=high      — очередь на разбор
  GET  /api/v1/antifraud/subjects/{type}/{id}/  — карточка риска: все сигналы, история,
       связанные аккаунты
  POST /api/v1/antifraud/subjects/{type}/{id}/resolve/  — решение модератора
       {"action": "clear|block|warn", "comment": "..."}, действие пишется в AuditLog

ВАЖНО: ни один сигнал не должен приводить к автоматическому необратимому действию —
блокировка всегда обратима и всегда сопровождается уведомлением пользователю с указанием,
как оспорить. Ложные срабатывания неизбежны, и цена ошибки для добросовестного продавца
высока.

Тесты: каждый сигнал по отдельности на синтетических данных; расчёт score;
объявление с level=high скрывается из публичной выдачи; решение модератора снимает
ограничение и пишется в аудит.
```

---

### Задача 10.4. AI-подбор объектов

**Промпт:**

```
В apps/recommendations реализуй персональный подбор объектов.

Этап 1 — рекомендации на поведении (без внешних AI-сервисов):
  Модель UserPreferenceVector: user, vector (JSONField или ArrayField(FloatField)),
  updated_at. Вектор собирается из поведения: просмотры (вес 1), избранное (вес 3),
  сохранённые фильтры (вес 5), раскрытие контактов (вес 4).
  Признаки: район (one-hot), тип, комнатность, диапазон цены, площадь, вторичка/новостройка.

  Celery Beat раз в сутки пересчитывает векторы активных пользователей.

  GET /api/v1/recommendations/  (IsAuthenticated)
     Топ-20 объектов по косинусной близости к вектору пользователя, исключая уже
     просмотренные и избранные. При недостатке данных (меньше 5 действий) — популярные
     объекты в районах, которые пользователь смотрел; если и этого нет — просто популярные.
     Кэш 1 час, инвалидация при новом значимом действии.

  GET /api/v1/listings/{slug}/similar/ — улучши существующий эндпоинт: добавь к текущей
     эвристике (район/тип/цена) близость по вектору признаков самого объекта.

Этап 2 — поиск на естественном языке:
  POST /api/v1/search/natural/
    Тело: {"query": "двушка в Асанбае до 80 тысяч, не первый этаж, с ремонтом"}
    Через LLM (провайдер абстрагирован интерфейсом NlSearchProvider; ключ из env)
    разбирает запрос в структурированные параметры ListingFilterSet и возвращает
    {"parsed_filters": {...}, "explanation": "Ищу 2-комнатные в Асанбае до 80 000$,
     этаж от 2", "results": [...]}
    ОБЯЗАТЕЛЬНО: результат LLM валидируется через ListingFilterSet перед применением —
    модель не должна иметь возможности подставить произвольный запрос к БД. Неразобранные
    части запроса возвращай отдельным полем unparsed, чтобы пользователь видел, что учтено.
    Кэшируй разбор одинаковых запросов на 24 часа. Таймаут к LLM — 5 секунд, при ошибке
    падай обратно на обычный полнотекстовый поиск, а не на 500.
    Throttle: 20 запросов в час на пользователя (запросы к LLM стоят денег).

  Логируй в модели NaturalSearchLog: query, parsed_filters, results_count, user,
  latency_ms — по этим данным потом видно, что люди на самом деле ищут.

Тесты: вектор пользователя обновляется после действий; рекомендации не содержат
просмотренного; при пустой истории отдаются популярные; разбор естественного запроса
с подставленным моком LLM даёт корректные фильтры; невалидный ответ LLM не приводит
к ошибке и откатывается на обычный поиск.
```

---

# §3. Порядок работы и приёмка

## 3.1. Рекомендуемый порядок

| Этап | Задачи | Результат |
|---|---|---|
| Неделя 1 | 0.1, 0.2, 0.3, 1.1, 1.2 | Проект поднимается, вход по SMS работает |
| Неделя 2 | 1.3, 2.1, 2.2, 2.3 | Каталог отдаёт данные, Flutter можно переключать с моков |
| Неделя 3 | 3.1, 3.2, 4.1, 4.2 | Поиск, фильтры, избранное, уведомления |
| Неделя 4 | 5.1, 5.2, 6.1, 6.2 | Кошелёк, платежи, подача объявлений |
| Неделя 5 | 6.3, 7.1, 7.2, 8.1 | Модерация, продвижение, подписки, профили |
| Неделя 6 | 9.2, 1.4, 9.1, 9.3 | Безопасность и аудит, KYC, тесты, деплой |
| После запуска | 10.1–10.4 | Калькулятор, аналитика, антифрод, AI |

Задача 1.4 (KYC) намеренно вынесена из первой фазы и стоит **после** 9.2: она опирается на приватное хранилище и `AuditLog`, которые появляются там. Делать приём фотографий паспортов раньше, чем заработает аудит доступа к ним, нельзя.

## 3.2. Определение готовности задачи (Definition of Done)

Задача считается закрытой, когда:

1. Код написан, миграции созданы и применяются на чистой БД.
2. Все перечисленные в задаче тесты написаны и проходят.
3. `make lint` не выдаёт замечаний.
4. Эндпоинты видны в Swagger с описаниями и примерами.
5. Новые переменные окружения добавлены в `.env.example`.
6. Изменения в соглашениях отражены в `CLAUDE.md`.

## 3.3. Что нужно уточнить до старта

Эти вопросы блокируют отдельные задачи — решите их заранее:

- **Задача 5.2:** какой платёжный шлюз используется (MBank, О!Деньги, Элсом, «Оптима», агрегатор)? Нужны документация и тестовые учётные данные. До этого работает `MockPaymentProvider`.
- **Задача 1.2:** какой SMS-провайдер (Nikita.kg, SMS.kg, другой)? Нужны API-ключ и подтверждённое имя отправителя.
- **Задача 4.2:** нужен проект Firebase и service-account JSON для FCM.
- **Задача 7.1–7.2:** финальные цены пакетов продвижения и тарифов подписки. В коде они в справочниках, но начальные значения нужно задать.
- **Задача 9.2:** актуальная редакция политики обработки персональных данных и текст пользовательского соглашения — на них ссылается модель согласий.
- **Задача 1.4:** отдельный приватный бакет под KYC и решение, кто из сотрудников получает право просматривать документы. Также нужно юридическое основание для обработки — оно указывается в политике ПДн.
- **Задача 10.4:** какой LLM-провайдер и бюджет на запросы.
- **Экран `proTasks` (`/pro/tasks`, кадр 38)** — в прототипе его назначение не определено. Пока в ТЗ он не покрыт: нужно решить, что это (заявки клиентов исполнителю? задания на съёмку? квесты, за которые начисляются бонусные кирпичи, — в истории кошелька есть строка «бонус за квест»). После уточнения добавляется отдельной задачей.
- **Экран `adPreview` (`/ad/preview`)** отдельного эндпоинта не требует: предпросмотр рисуется из ответа `GET /listings/{slug}/` для черновика. Если предпросмотр должен показывать, как объявление выглядит в выдаче, добавьте в ответ черновика краткое представление карточки.

## 3.4. Контракт с Flutter-приложением

Значения перечислений (`PropertyKind`, `SellerKind`, `WalletEntryKind`), формат отображения баланса (`16.700`), лимит 20 медиафайлов и стоимость продвижения 780 кирпичей/день взяты напрямую из кода приложения. **Изменение любого из них требует согласованного релиза бэкенда и мобильного клиента.**

Рекомендуемый порядок интеграции: после задачи 2.3 фронтенд-разработчик заменяет `kListings` из `lib/data/listings.dart` на запрос к API, оставив ту же структуру данных на уровне модели `Listing` в Dart. Дальнейшие фазы подключаются по мере готовности — экраны, для которых бэкенд ещё не готов, продолжают работать на локальном `AppState`.
