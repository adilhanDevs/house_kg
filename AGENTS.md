# AGENTS.md

Контекст проекта для Codex. Раздел «Общий контекст проекта» ниже —
дословная копия §1 из [flutter_app/BACKEND_TZ.md](flutter_app/BACKEND_TZ.md);
при правках ТЗ обновляйте оба файла.

**Где что лежит в этом репозитории:**

- `backend/` — Django-проект (см. [backend/README.md](backend/README.md)).
- `flutter_app/` — Flutter-клиент и ТЗ на бэкенд (`BACKEND_TZ.md`).
- `flutter_app/lib/data/listings.dart` — прототипные данные каталога,
  источник правды для сидера `manage.py seed_demo`.

**Команды бэкенда** (из каталога `backend/`): `make up`, `make migrate`,
`make seed`, `make test`, `make lint`, `make format`.

---

# §1. Общий контекст проекта

> Этот раздел целиком копируется в `AGENTS.md` в корне бэкенд-репозитория.

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
└── AGENTS.md
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

