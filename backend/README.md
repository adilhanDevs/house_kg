# house_kgz — backend

REST API мобильного приложения-агрегатора недвижимости.

**Стек:** Python 3.12 · Django 5 · Django REST Framework · PostgreSQL 16 · Redis 7 ·
Celery (+ Beat) · MinIO/S3 · Docker Compose.

Каркас проекта (настройки, единый формат ошибок, пагинация, документация API,
health-check) плюс доменные модели, необходимые сидеру демо-данных:
пользователи, каталог объявлений и кошелёк. API-эндпоинтов каталога пока нет —
они появятся в фазах 1–6 ТЗ ([flutter_app/BACKEND_TZ.md](../flutter_app/BACKEND_TZ.md)).

---

## Быстрый старт (Docker)

```bash
cd backend
cp .env.example .env      # при необходимости поправьте значения
make up                   # соберёт образы и поднимет всё окружение
```

Что поднимается:

| Сервис        | Адрес                      | Назначение                          |
|---------------|----------------------------|-------------------------------------|
| `web`         | http://localhost:8000      | Django + DRF                        |
| `db`          | localhost:5432             | PostgreSQL 16 (healthcheck)         |
| `redis`       | localhost:6379             | кэш + брокер Celery                 |
| `celery`      | —                          | воркер, очередь `default`           |
| `celery-beat` | —                          | планировщик (django-celery-beat)    |
| `minio`       | http://localhost:9001      | консоль S3-хранилища (minioadmin)   |
| `minio-init`  | —                          | разово создаёт бакет и открывает его |

Миграции применяются автоматически при старте `web` (`RUN_MIGRATIONS=true`).

Проверить, что всё живо:

```bash
curl http://localhost:8000/api/v1/health/
```

Ответ: `{"status": "ok", "db": true, "redis": true}` (503, если БД или Redis недоступны).

Дальше:

```bash
make superuser            # создать администратора
make seed                 # демо-данные по прототипу Flutter
make seed ARGS=--flush    # то же, но сначала очистить доменные таблицы
make logs                 # логи (make logs SERVICE=celery — по одному сервису)
make down                 # остановить
```

### Демо-данные

`make seed` (`python manage.py seed_demo`) наполняет БД данными прототипа:

| Что | Сколько |
|---|---|
| Пользователи | 3: `+996700000001` (клиент), `+996700000002` (риелтор, pro), `+996700000003` (агентство, pro); пароль `demo12345` |
| Районы Бишкека | 15 (Технопарк, Асанбай, Джал, Восток-5, Кок-Жар, Юг-2, Центр, Орто-Сай, Байтик, Чуй-Манаса, …) |
| Серии домов | 6 (103, 104, 105, 106, Индивидуальная, Элитка) |
| Объявления | 50 = 10 «якорных» (точная копия `kListings` из `flutter_app/lib/data/listings.dart`) + 40 сгенерированных |
| Медиа | 3–5 фото на объявление, рисуются Pillow'ом на лету (район / цена) |
| Кошельки | у обоих pro — 16 700 кирпичей и история операций экрана «История пополнения и трат» |

Команда идемпотентна: повторный запуск ничего не дублирует (`get_or_create`
по slug / телефону / ключу идемпотентности). `--flush` предварительно чистит
доменные таблицы и удаляет сгенерированные файлы.

### Полезные адреса

| Что                    | URL                                |
|------------------------|------------------------------------|
| Health-check           | `/api/v1/health/`                  |
| Конфиг приложения      | `/api/v1/app/config/`              |
| Онбординг              | `/api/v1/app/onboarding/`          |
| Статические страницы   | `/api/v1/app/pages/{slug}/`        |
| Обращение в поддержку  | `POST /api/v1/support/tickets/`    |
| Профиль пользователя   | `/api/v1/users/me/`                |
| Верификация личности   | `/api/v1/verification/identity/`   |
| Каталог объявлений     | `/api/v1/listings/`                |
| Счётчик под фильтром   | `/api/v1/listings/count/`          |
| Кошелёк                | `/api/v1/wallet/`                  |
| Уведомления            | `/api/v1/notifications/`           |
| Устройства для push    | `/api/v1/devices/`                 |
| Избранное              | `/api/v1/favourites/`              |
| История просмотров     | `/api/v1/view-history/`            |
| Сохранённые фильтры    | `/api/v1/saved-filters/`           |
| Подборки               | `/api/v1/collections/`             |
| Справочники каталога   | `/api/v1/catalog/cities|districts|builders/` |
| Опции фильтра          | `/api/v1/catalog/filter-options/`  |
| Вход по SMS-коду       | `POST /api/v1/auth/otp/request|verify/` |
| OpenAPI-схема          | `/api/v1/schema/`                  |
| Swagger UI             | `/api/v1/docs/`                    |
| ReDoc                  | `/api/v1/redoc/`                   |
| Админка                | `/admin/`                          |

---

## Локальный запуск без Docker

Нужен Python 3.12+ (и запущенные Postgres с Redis, либо `DATABASE_URL` на SQLite).

```bash
cd backend
make install                 # создаст .venv и поставит зависимости (uv, если он есть)
cp .env.example .env         # укажите localhost вместо db/redis/minio в URL-ах
.venv/bin/python manage.py migrate
.venv/bin/python manage.py runserver
```

---

## Тесты и линтеры

```bash
make test        # pytest + покрытие (--reuse-db)
make lint        # ruff check + ruff format --check
make format      # автофиксы и форматирование
make typecheck   # mypy
```

Тесты используют `config.settings.test`: по умолчанию in-memory SQLite и локальный
кэш вместо Redis, поэтому `make test` работает без поднятого docker. Если задать
`DATABASE_URL` / `REDIS_URL`, тесты пойдут по ним — так же, как в CI на Postgres.

---

## Что где лежит

Соглашения проекта — в [CLAUDE.md](../CLAUDE.md) в корне репозитория (копия §1 ТЗ).

```
backend/
├── config/                     # конфигурация проекта
│   ├── settings/
│   │   ├── base.py             # общая база: приложения, DRF, Celery, логи
│   │   ├── local.py            # разработка: DEBUG, CORS «всем», debug-toolbar
│   │   ├── production.py       # прод: HSTS, SSL-редирект, secure-куки, CORS из env
│   │   └── test.py             # тесты: SQLite + locmem, eager-Celery
│   ├── urls.py                 # корневые маршруты, /api/v1/, schema/docs, JSON 404/500
│   ├── celery.py               # Celery-приложение, очередь default, автодискавери
│   ├── asgi.py / wsgi.py       # точки входа
│   └── __init__.py             # экспорт celery_app
├── apps/
│   ├── common/                 # общие абстракции + конфиг клиента
│   │   ├── models.py           # TimeStampedModel, UUIDModel, AppConfig, OnboardingSlide,
│   │   │                       #   StaticPage, SupportTicket, AuditLog
│   │   ├── storages.py         # приватное хранилище без публичных URL
│   │   ├── audit.py            # запись обращений к чувствительным данным
│   │   ├── enums.py            # PropertyKind, SellerKind, ListingStatus, WalletEntryKind…
│   │   ├── pagination.py       # DefaultCursorPagination
│   │   ├── exceptions.py       # единый формат ошибок, ConflictError, InsufficientFundsError
│   │   ├── permissions.py      # IsOwnerOrReadOnly
│   │   ├── serializers.py      # схемы health/ошибок для OpenAPI
│   │   ├── views.py            # health-check, /app/*, поддержка, JSON-обработчики 404/500
│   │   ├── services.py         # сборка и кэширование ответов /app/*, письма поддержке
│   │   ├── http.py             # ETag и 304 Not Modified
│   │   ├── semver.py           # сравнение версий клиента
│   │   ├── signals.py          # инвалидация кэша при правках в админке
│   │   ├── throttling.py       # лимит обращений в поддержку
│   │   └── management/commands/seed_demo.py
│   ├── users/                  # User, вход по SMS-коду, профиль /users/me/
│   │   ├── models.py           # User, UserManager, OtpCode, маскирование ИИН
│   │   ├── phone.py            # нормализация к E.164 (phonenumbers, регион KG)
│   │   ├── sms.py              # SmsProvider: Console / Http (ретраи, таймаут)
│   │   ├── tasks.py            # отправка SMS, ночная чистка кодов
│   │   ├── kyc.py              # проверка документов, снятие EXIF, подписанные ссылки
│   │   ├── permissions.py      # IsProUser, CanReviewIdentity
│   │   ├── throttling.py       # лимиты запроса кода, входа и подачи документов
│   │   ├── services.py         # выдача и проверка кода, мягкое удаление
│   │   └── serializers.py      # UserMeSerializer, OTP-сериализаторы
│   ├── catalog/                # City, District, HouseSeries, Builder, Listing, ListingMedia
│   │   ├── enums.py            # PropertyKind, SellerKind, ListingStatus, MediaKind, Currency
│   │   ├── constants.py        # лимиты медиа и параметры слага
│   │   ├── filters.py          # ListingFilterSet: все параметры экрана фильтра
│   │   ├── search.py           # полнотекстовый поиск и триграммы
│   │   ├── rates.py            # курсы валют и приведение цены к USD
│   │   ├── tasks.py            # курс НБКР, пересборка поискового индекса
│   │   ├── services.py         # опции фильтра, счётчики, добавление медиа
│   │   ├── signals.py          # инвалидация кэша справочников
│   │   └── migrations_utils.py # AddIndex только для PostgreSQL
│   ├── engagement/             # избранное, история просмотров,
│   │   │                       #   сохранённые фильтры, подборки
│   │   ├── services.py         # валидация params, выборки подборок
│   │   └── tasks.py            # почасовая рассылка по сохранённым фильтрам
│   ├── billing/                # кошелёк и леджер операций («кирпичи»)
│   │   ├── models.py           # Wallet (баланс ≥ 0), WalletTransaction (append-only)
│   │   └── services.py         # apply_transaction — единственный способ менять баланс
│   └── notifications/          # уведомления, настройки, устройства, push
│       ├── services.py         # notify() — единственная точка создания
│       ├── push.py             # FCM: multicast, чистка мёртвых токенов
│       └── tasks.py            # отправка push, слежение за ценой
├── tests/                      # pytest: conftest.py + smoke-тесты
├── docker/                     # Dockerfile (multi-stage, non-root) и entrypoint.sh
├── docker-compose.yml
├── Makefile
├── pyproject.toml              # зависимости, ruff, pytest, mypy
└── .env.example                # все переменные окружения с комментариями
```

Модель пользователя — своя (`AUTH_USER_MODEL = "users.User"`), вход по телефону
в формате E.164, `USERNAME_FIELD = "phone"`.

### Новое приложение

```bash
mkdir -p apps/listings && .venv/bin/python manage.py startapp listings apps/listings
```

Затем в `apps/listings/apps.py` укажите `name = "apps.listings"` и добавьте приложение
в `LOCAL_APPS` в `config/settings/base.py`.

---

## Соглашения API

**Версионирование.** Всё API живёт под `/api/v1/` (`URLPathVersioning`, `DEFAULT_VERSION="v1"`).

**Аутентификация.** JWT (`djangorestframework-simplejwt`) — заголовок
`Authorization: Bearer <access>`. По умолчанию права — `AllowAny`;
каждая вьюха обязана объявлять `permission_classes` явно.

**Пагинация.** Курсорная, по умолчанию 20 объектов, максимум 100
(`?page_size=50&cursor=...`). Формат ответа:

```json
{"results": [], "next": "https://.../?cursor=cD0y", "previous": null, "count": 128}
```

Курсор сортирует по `-created_at`, поэтому пагинируемые модели должны наследовать
`TimeStampedModel` (или переопределять `ordering` у своего класса пагинации).

**Ошибки.** Любая ошибка приходит в одном формате:

```json
{
  "error": {
    "code": "validation_error",
    "message": "Проверьте правильность заполнения полей.",
    "details": {"price": ["Обязательное поле."]}
  }
}
```

| HTTP | code                    | Когда                                    |
|------|-------------------------|------------------------------------------|
| 400  | `validation_error`      | не прошла валидация                      |
| 401  | `authentication_failed` | нет/протух токен                         |
| 402  | `insufficient_funds`    | не хватает средств (`InsufficientFundsError`) |
| 403  | `permission_denied`     | нет прав                                 |
| 404  | `not_found`             | объекта или адреса нет                   |
| 409  | `conflict`              | дубликат / гонка (`ConflictError`)       |
| 429  | `throttled`             | превышен лимит запросов                  |
| 500  | `server_error`          | непойманная ошибка (пишется в лог)       |

---

## Конфигурация мобильного клиента

Всё, что должно меняться без релиза приложения, живёт в админке и отдаётся
четырьмя эндпоинтами (все `AllowAny`):

| Эндпоинт | Что отдаёт |
|---|---|
| `GET /api/v1/app/config/?platform=android&version=1.0.3` | версии, `force_update`, ссылку на стор, режим обслуживания, фича-флаги, константы, ссылки на документы |
| `GET /api/v1/app/onboarding/` | активные слайды онбординга по порядку |
| `GET /api/v1/app/pages/{slug}/` | `terms`, `privacy`, `about`, `faq`, `support` — markdown и версия текста |
| `POST /api/v1/support/tickets/` | обращение в поддержку, не более 5 в час на аккаунт или IP |

- **`force_update`** считается сравнением семвера, а не строк: `1.0.9 < 1.0.10`.
  Если клиент не прислал `version`, принудительное обновление не включается.
- **Кэш** — Redis, 15 минут (`apps/common/services.py`). Инвалидируется сигналами
  `post_save`/`post_delete` на `AppConfig`, `OnboardingSlide`, `StaticPage`,
  поэтому правка в админке видна сразу.
- **ETag.** Ответы `/app/*` содержат `ETag` (md5 тела) и `Cache-Control: public, max-age=900`.
  Клиент шлёт `If-None-Match` и получает `304` без тела — конфиг дёргается на каждом старте.
- **`StaticPage.version`** увеличивается вручную при правке текста соглашений: по ней
  запрашивается новое согласие пользователя (задача 9.2 ТЗ).
- **Константы** (`topup_bonus_rate`, `promotion_price_per_day`, `max_photos`,
  `max_videos`, `free_active_listings`) читаются клиентом из конфига, а не хардкодятся.

Письма о новых обращениях уходят на `SUPPORT_NOTIFY_EMAILS` (или на `ADMINS`)
Celery-задачей `common.notify_support_ticket`; если брокер недоступен, письмо
отправляется синхронно.

---

## Аутентификация: телефон + SMS-код → JWT

| Метод | Путь | Что делает |
|---|---|---|
| POST | `/api/v1/auth/otp/request/` | `{"phone", "purpose"}` → `{"expires_in": 300, "resend_after": 60, "is_new_user": bool}` |
| POST | `/api/v1/auth/otp/verify/` | `{"phone", "code", "name"}` → `{"access", "refresh", "user", "is_new_user"}` |
| POST | `/api/v1/auth/pro/register/` | `{"phone", "name", "password", "iin", "whatsapp"}` → `{"expires_in", "resend_after"}` |
| POST | `/api/v1/auth/password/login/` | `{"phone", "password"}` → та же пара токенов, только для `is_pro` |
| POST | `/api/v1/auth/refresh/` | стандартный `TokenRefreshView` SimpleJWT |
| POST | `/api/v1/auth/logout/` | `{"refresh"}` → `204`, токен уходит в blacklist |

- **Код** — 4 цифры из `secrets.randbelow`, живёт 5 минут. В БД лежит только хеш
  (`django.contrib.auth.hashers`). Открытый код не попадает ни в ответ API, ни в логи —
  единственное исключение — `ConsoleSmsProvider` при `DEBUG=True`.
- **Тестовые номера.** При `DEBUG=True` или для номеров из `OTP_TEST_PHONES` код всегда
  `OTP_DEBUG_CODE` (`0000`) и SMS не отправляется — для ревью в сторах и автотестов.
- **Лимиты** (`apps/users/throttling.py`, счётчики в Redis): 1 код в минуту и 5 в час на
  номер, 20 в час на IP. Превышение — `429` с `details.retry_after`.
- **Неверный код**: `400`, сообщение «Неверный код», `details.attempts_left`. После пяти
  неудачных попыток код сжигается (`is_used=True`) — нужен новый.
- **SMS** уходит Celery-задачей `users.send_otp_sms` (3 ретрая). Провайдер выбирается
  настройкой `SMS_PROVIDER`: `console` (лог) или `http` (POST на `SMS_API_URL`,
  таймаут 10 с, 2 ретрая с экспоненциальной задержкой).
- **Токены**: access 15 минут, refresh 30 дней, ротация с занесением старого refresh
  в blacklist (`rest_framework_simplejwt.token_blacklist`).
- **Чистка**: Celery Beat раз в сутки (03:15) запускает `users.purge_old_otp_codes` —
  удаляет коды старше `OTP_RETENTION_DAYS` (7 дней).

### Регистрация исполнителя (pro)

Экран `pro_signup_page`: телефон, WhatsApp, имя, пароль, ИИН.

1. `POST /auth/pro/register/` — валидирует ИИН (`apps/users/validators.py`: ровно 14 цифр)
   и пароль (`AUTH_PASSWORD_VALIDATORS`, минимум 8 символов), создаёт **или дозаполняет**
   аккаунт с тем же телефоном (второго не появляется), сохраняет `whatsapp_phone`
   и высылает код с `purpose=pro_register`. `is_pro` пока остаётся `False`.
2. `POST /auth/otp/verify/` с `purpose=pro_register` — включает `is_pro=True`
   и заводит кошелёк (`billing.Wallet`, идемпотентно).

`409 conflict` возвращается, когда ИИН занят другим аккаунтом или у номера уже указан
другой ИИН. ИИН защищён и на уровне БД: `UniqueConstraint` с условием `iin != ""`.

Вход по паролю (`/auth/password/login/`) доступен только подтверждённым исполнителям.
Любая неудача — `401` с одним и тем же текстом «Неверный номер телефона или пароль»,
чтобы по ответу нельзя было проверить, зарегистрирован ли номер. Лимиты: 10 попыток
в час на номер и 30 — с одного IP.

## Фильтрация и поиск

`ListingFilterSet` ([filters.py](apps/catalog/filters.py)) подключён и к `/listings/`,
и к `/listings/count/`. Мультивыбор передаётся через запятую и внутри параметра
объединяется по ИЛИ, разные параметры — по И.

| Параметр | Поведение |
|---|---|
| `search` | полнотекстовый поиск (см. ниже) |
| `kind`, `district`, `seller_kind`, `series` | мультивыбор: `?kind=apartment,house` |
| `city`, `builder` | по слагу |
| `rooms` | мультивыбор; `5` означает «5 и более» |
| `area_min`, `area_max`, `area_ranges` | `?area_ranges=35-45,65-75`; диапазоны — по ИЛИ между собой **и по ИЛИ с ручной вилкой** |
| `price_min`, `price_max`, `currency` | сравнение по `price_usd`; при `currency=KGS` порог конвертируется в доллары |
| `floor_min`, `floor_max`, `not_first_floor`, `not_last_floor` | `not_last_floor` — `floor < floors` |
| `is_secondary`, `below_market`, `red_book`, `has_video` | флаги; `has_video` — подзапрос `Exists` |

`GET /api/v1/listings/count/` принимает те же параметры и отдаёт `{"count": 137}`
для кнопки «Показать N объектов»: без пагинации и сериализации, только `COUNT(*)`.
Результат кэшируется на 60 секунд по хешу нормализованной строки параметров
(порядок параметров и `page_size`/`cursor`/`ordering` на ключ не влияют).

### Полнотекстовый поиск

Поле `Listing.search_vector` собирается из района (вес A), адреса и застройщика (B)
и описания (C) с конфигурацией `russian`. Обновляется тремя путями: задачей
`catalog.update_listing_search_vector` после публикации, действием «Опубликовать»
в админке (одним `UPDATE` на пачку) и командой полного пересчёта:

```bash
docker compose exec web python manage.py rebuild_search_index --active-only
```

Запрос идёт через `SearchQuery(search_type="websearch")` с сортировкой по `SearchRank`;
если точных совпадений нет — включается поиск по триграммам (`pg_trgm`, порог 0.3),
чтобы «технпарк» с опечаткой находил «Технопарк». При активном `search` и без явного
`?ordering=` выдача сортируется по релевантности.

> Всё это — возможности PostgreSQL. На SQLite (локальный прогон тестов) поиск
> деградирует до `icontains`, а два теста про триграммы и ранжирование помечены
> `skipif` и выполняются только на Postgres.

### Валюты

`ExchangeRate` хранит историю курсов. Celery Beat в 09:00 по Asia/Bishkek запускает
`catalog.fetch_exchange_rates`: тянет XML НБКР, сохраняет курс USD/KGS, сбрасывает
кэш и пересчитывает `Listing.price_usd` одним `UPDATE`. Если источник недоступен —
задача пишет предупреждение в лог и оставляет прошлый курс, не падая. Пока курсов
нет вовсе, используется `FALLBACK_USD_KGS_RATE`.

`price_usd` — денормализация: заполняется в `Listing.save()` и пересчитывается
пачкой при обновлении курса. Все фильтры и сортировки по цене идут по нему,
иначе объявления в сомах выпадали бы из ценового диапазона.

## Публичные эндпоинты каталога

| Метод | Путь | Что делает |
|---|---|---|
| GET | `/api/v1/listings/` | лента активных объявлений, курсорная пагинация, `?ordering=` |
| GET | `/api/v1/listings/{slug}/` | полная карточка объекта с медиа и продавцом |
| POST | `/api/v1/listings/{slug}/view/` | отметка просмотра → `{"views_count": 1043}` |
| GET | `/api/v1/listings/featured/` | подборки главного экрана по типам, кэш 5 минут |
| GET | `/api/v1/listings/{slug}/similar/` | шесть похожих объектов |

Всё `AllowAny`; от аутентификации зависят только `is_favourite` и телефон продавца.

- **Продвинутые вперёд.** Объявления с `promoted_until` в будущем всегда выше
  остальных при любой сортировке (`("-promoted_rank", <ordering>, "-id")`).
  `?ordering=` принимает `-published_at` (по умолчанию), `price`, `-price`,
  `-views_count`, `area`; всё остальное игнорируется.
- **Телефон продавца**: полный только авторизованным, анониму — маска
  `+996 7XX XXX XX6` (код страны, первая цифра оператора, последняя цифра).
- **Отметка просмотра** дедуплицируется ключом Redis `view:{slug}:{user|ip}` с TTL
  30 минут (`cache.add` — атомарно). Счётчик растёт через `F()`, история просмотров
  обновляется через `update_or_create`.
- **Запросы**: список — **3 SQL** для анонима и 4 для авторизованного, независимо от
  размера страницы (COUNT + выборка + prefetch обложек; `is_favourite` — подзапрос
  `Exists`, обложки — `Prefetch(to_attr=...)`, всё остальное — `select_related`).
  Карточка и «похожие» — по 3 запроса.

> Оговорка про курсор: DRF строит позицию курсора по **первому** полю сортировки,
> а у нас это флаг продвижения с двумя значениями. Внутри блока непродвинутых
> объявлений курсор вырождается в offset, который упирается в `offset_cutoff = 1000`
> (≈50 страниц по 20). Для мобильной ленты этого достаточно; если понадобится
> листать глубже — продвинутые объявления нужно отдавать отдельным блоком на первой
> странице, а не смешивать с общей сортировкой.

## Кошелёк и «кирпичи»

| Метод | Путь | Что отдаёт |
|---|---|---|
| GET | `/api/v1/wallet/` | `{"balance": 16700, "balance_display": "16.700", "currency": "brick"}` |
| GET | `/api/v1/wallet/transactions/?kind=topup\|spend\|bonus` | историю, сгруппированную по дням |

- **`apply_transaction()` — единственный способ изменить баланс**
  ([services.py](apps/billing/services.py)). Внутри: `transaction.atomic`,
  `select_for_update` на строке кошелька, проверка овердрафта, запись в леджер
  с `balance_after`. Прямых присваиваний `wallet.balance` в остальном коде нет —
  проверяется грепом по репозиторию.
- **Леджер append-only**: `save()` при наличии `pk` и `delete()` поднимают
  `RuntimeError`. Ошибочная операция компенсируется обратной, а не правкой —
  история должна оставаться тем, что действительно произошло.
- **Идемпотентность** по `idempotency_key`: повторный вызов возвращает уже
  созданную операцию, не трогая баланс. На этом же ключе строится повторная
  обработка платёжного вебхука.
- **Минус невозможен на трёх уровнях**: проверка в сервисе, блокировка строки
  и `CheckConstraint(balance >= 0)` в самой БД как последний рубеж.
- **Нехватка средств** — `402` с `details`: `{"required": 780, "available": 300}`,
  чтобы приложение сразу предложило пополнение на недостающую сумму.
- **Формат баланса** как в макете: `16700 → "16.700"`, `1200000 → "1.200.000"`.
- Кошелёк создаётся сигналом при регистрации пользователя.

## Уведомления и push

| Метод | Путь | Что делает |
|---|---|---|
| GET | `/api/v1/notifications/?is_read=false&type=price_drop` | лента, курсорная пагинация |
| GET | `/api/v1/notifications/unread-count/` | `{"count": 7}` для бейджа |
| POST | `/api/v1/notifications/read/` | `{"ids": [...]}` или `{"all": true}` → новый `unread_count` |
| DELETE | `/api/v1/notifications/{id}/` | удалить своё уведомление |
| GET/PATCH | `/api/v1/notifications/settings/` | флаги push: общий и на каждый тип |
| POST | `/api/v1/devices/` | upsert устройства по токену |
| DELETE | `/api/v1/devices/{token}/` | деактивировать при выходе из аккаунта |

- **Единственная точка создания — `notify()`** ([services.py](apps/notifications/services.py)):
  создаёт `Notification` и ставит задачу push после коммита. Для рассылок есть
  `notify_many()` — тот же контракт, но одним `INSERT` (почасовая рассылка по
  сохранённым фильтрам не должна делать по запросу на пользователя). Модерация,
  кошелёк и фильтры вызывают только их.
- **Push — всегда через Celery** (`notifications.send_push`), синхронно из вьюх не шлём.
- **Настройки уважаются на отправке**: `push_enabled` и флаг конкретного типа. При
  выключенном push уведомление всё равно создаётся — оно видно в ленте.
- **Мёртвые токены гасятся**: если FCM ответил `UNREGISTERED` или `INVALID_ARGUMENT`,
  устройство помечается `is_active=False`. Отправка идёт multicast-батчами по 500,
  порядок токенов фиксирован — по нему ответы сопоставляются с устройствами.
- **Токен принадлежит устройству, а не аккаунту**: если на телефоне сменился
  пользователь, `POST /devices/` переносит токен на текущего — иначе push уходил бы
  прежнему владельцу.
- **Креды FCM** — из `FCM_CREDENTIALS_FILE` или `FCM_CREDENTIALS_BASE64`. Не заданы —
  push молча отключён, всё остальное работает.
- **`notifications.notify_price_drop`** (Beat, 10:00 Asia/Bishkek) сравнивает
  `Listing.price_usd` с `Favourite.price_at_add`; при падении ≥ 3% шлёт уведомление
  «Цена снизилась на 5%: Технопарк, 3-комн. — 97 000$» и обновляет отметку цены,
  чтобы о том же снижении не написать дважды.

## Избранное и история просмотров

| Метод | Путь | Что делает |
|---|---|---|
| POST/DELETE | `/api/v1/listings/{slug}/favourite/` | переключатель избранного, оба вызова идемпотентны |
| GET | `/api/v1/favourites/` | избранное в порядке добавления |
| GET | `/api/v1/view-history/` | история, сгруппированная по дням |
| DELETE | `/api/v1/view-history/` | удалить перечисленные записи или всю историю |

- **Идемпотентность.** Повторный `POST` не создаёт дубль и не двигает счётчик;
  `DELETE` несуществующей записи отвечает `200`, а `favourites_count` не уходит
  ниже нуля. Счётчик меняется `F()`-выражением в одной транзакции с записью.
- **Снятые с публикации объявления остаются** и в избранном, и в истории, но
  приходят с `is_available: false` — карточка показывается неактивной, а не исчезает.
- **Сортировка избранного** — по времени добавления записи, а не публикации объекта:
  курсор идёт по аннотации `favourited_at`.
- **История группируется по дням в Asia/Bishkek** (не по UTC-суткам сервера): `today`,
  `yesterday`, дальше `2026-08-18` / «18 августа». Группировка — один проход по
  отсортированной выборке, без запроса на каждый день. Пагинация тоже по дням:
  страница отдаёт целые дни, курсор указывает на последний из них.
- **Очистка**: `engagement.purge_view_history` в Beat раз в сутки удаляет записи
  старше `VIEW_HISTORY_RETENTION_DAYS` (90 дней).

Сервис `note_view(user, listing)` вызывается из `POST /listings/{slug}/view/`
(`update_or_create` по паре пользователь-объявление) и ничего не пишет для анонимов.

## Сохранённые фильтры и подборки

| Метод | Путь | Кто | Что делает |
|---|---|---|---|
| GET/POST | `/api/v1/saved-filters/` | авторизованный | список своих фильтров / сохранить новый |
| PATCH/DELETE | `/api/v1/saved-filters/{id}/` | владелец | переименовать, переключить уведомления, удалить |
| GET | `/api/v1/saved-filters/{id}/listings/` | владелец | каталог по сохранённым параметрам |
| GET | `/api/v1/collections/` | все | активные подборки по `order` |
| GET | `/api/v1/collections/{slug}/listings/` | все | объекты подборки |

- **Параметры проверяются тем же `ListingFilterSet`, что и каталог**: неизвестный ключ
  или негодное значение — `400 validation_error`, в базу попадает только нормализованный
  вид (значения строками, списки через запятую, пустые отброшены, ключи отсортированы).
  Одинаковые фильтры разных пользователей дают побайтово одинаковый `params` — на этом
  строится группировка в рассылке.
- **Лимит 20 фильтров** на пользователя, 21-й — `409 conflict`; повтор названия — тоже 409.
- **Чужие фильтры не видны**: для их владельца это `404`, а не `403`.
- **`PATCH` не меняет `params`** — иначе `last_notified_at` относился бы к прошлому
  запросу и пользователь пропустил бы новинки. Для другого набора создаётся другой фильтр.

### Рассылка по фильтрам

`engagement.notify_saved_filters` (Celery Beat, каждый час в :10) считает объявления,
опубликованные после `COALESCE(last_notified_at, created_at)`, и создаёт одно
уведомление `saved_filter_match` на фильтр. Фильтры обрабатываются пачками по 200
и группируются по одинаковым `params`: на группу приходится один `COUNT` и один запрос
за отметками публикации, дальше счёт идёт в памяти (`bisect`). После прогона
`last_notified_at` сдвигается на «сейчас», поэтому повторный запуск ничего не создаёт.

### Подборки

`Collection` работает в двух режимах: `query` — параметры каталога в `params`,
`manual` — список объектов через `CollectionItem` с полем `order`. В ручном режиме
порядок задаёт редактор, поэтому и пагинация идёт по `item_order`, а не по правилам
каталога (продвинутые вперёд + сортировка). Неактивные подборки и неактивные
объявления внутри них наружу не отдаются.

## Объявления

`Listing` и `ListingMedia` ([models.py](apps/catalog/models.py)) — центральные сущности каталога.

- **Слаг** генерируется один раз при создании: `<district-slug>-<rooms>k-<8 hex>`
  (`technopark-3k-9f1c2a4b`). Дальше он не меняется — по нему строятся ссылки,
  которыми делятся пользователи.
- **Город продублирован** рядом с районом (`Listing.city`): фильтр по городу — самый
  частый запрос каталога, и джойн ради него делать не хочется.
- **Лимиты медиа** — `MAX_PHOTOS_PER_LISTING` / `MAX_VIDEOS_PER_LISTING` = 20
  ([constants.py](apps/catalog/constants.py)), как `AppState.draftMediaLimit` во Flutter.
  Проверяются и в сервисе `add_listing_media()`, и в `ListingMedia.clean()` — запись
  мимо сервиса тоже не пройдёт.
- **Обложка** — ровно одна на объявление: `UniqueConstraint` с
  `condition=Q(is_cover=True)`. Первое фото становится обложкой автоматически.
- **Счётчики** `views_count` и `favourites_count` денормализованы и меняются
  **только** сервисными функциями через `F()`-выражения (`register_view`,
  `increment_favourites`, `decrement_favourites`). Никаких сигналов в горячем пути
  и никакого read-modify-write в Python: параллельные инкременты не должны теряться.
- **Свойства**: `is_plot`, `is_promoted`, `price_display` («102 000$», неразрывный
  пробел как в макете), `discount_percent`.
- **Индексы**: `(status, -published_at)`, `(status, district, kind)`, `(status, price)`,
  GIN по `search_vector` и GIN + `gin_trgm_ops` по `address` (расширение `pg_trgm`
  включается миграцией `0006`).

Перечисления вынесены в [enums.py](apps/catalog/enums.py): `PropertyKind`,
`SellerKind`, `ListingStatus`, `MediaKind`, `Currency`. **Значения совпадают с
enum'ами Flutter** — переименовывать нельзя, меняются только подписи.

> GIN-индексы и `pg_trgm` — фичи PostgreSQL. Целевая БД проекта — Postgres 16,
> но локальный прогон тестов идёт на SQLite, поэтому эти индексы создаются
> операцией `PostgresOnlyAddIndex` ([migrations_utils.py](apps/catalog/migrations_utils.py)):
> в состояние миграций они попадают всегда, в схему — только на Postgres.

## Справочники каталога и фильтр

| Метод | Путь | Что отдаёт |
|---|---|---|
| GET | `/api/v1/catalog/cities/` | `[{id, name, slug, is_default}]` |
| GET | `/api/v1/catalog/districts/?city=<slug>` | `[{id, name, slug, city, latitude, longitude}]` |
| GET | `/api/v1/catalog/builders/` | `[{id, name, slug, logo_url}]` |
| GET | `/api/v1/catalog/filter-options/?city=<slug>` | всё, что нужно экрану фильтра, одним ответом |

Все справочники (`City`, `District`, `HouseSeries`, `Builder`) имеют `is_active`
и `order` — порядок и видимость настраиваются в админке прямо в списке.
Неактивные записи в API не попадают. Списки короткие, поэтому отдаются массивом,
без пагинации.

`filter-options` содержит `property_kinds`, `seller_kinds`, `rooms`, `area_ranges`,
`series`, `districts` и `price_range`. **Значения `property_kinds` и `seller_kinds`
совпадают с enum'ами Flutter** (`lib/data/listings.dart`) — переименовывать их нельзя.
`price_range` — агрегат `MIN/MAX` по активным объявлениям выбранного города
(при их отсутствии — `CATALOG_DEFAULT_PRICE_MIN/MAX`).

Ответ кэшируется на 10 минут; ключ учитывает город и `Accept-Language`.
Инвалидация — сигналами `post_save`/`post_delete` на `District`, `HouseSeries`,
`Listing` и `City` через счётчик версии в ключе: сбрасывать нужно все города сразу,
а перечислять их в сигнале — лишние запросы к БД. При попадании в кэш эндпоинт
**не делает ни одного SQL-запроса** (город резолвится только при промахе).
Сбой Redis не ломает сохранение объектов: ошибка инвалидации только логируется.

## Верификация личности исполнителя (KYC)

Экраны загрузки селфи и фото документа. Это самые чувствительные данные системы,
поэтому режим обращения с ними строже, чем с остальными файлами.

| Метод | Путь | Кто | Что делает |
|---|---|---|---|
| POST | `/api/v1/verification/identity/` | pro | подать селфи и фото документа (multipart) |
| GET | `/api/v1/verification/identity/` | любой авторизованный | статус своей последней заявки |
| GET | `/api/v1/verification/queue/` | staff + `users.can_review_identity` | очередь заявок с подписанными ссылками |
| POST | `/api/v1/verification/identity/{id}/review/` | staff + `users.can_review_identity` | `approve` / `reject` |

**Отдельное приватное хранилище.** Файлы KYC не лежат рядом с медиа объявлений:
локально это каталог `PRIVATE_MEDIA_ROOT` вне `MEDIA_ROOT`, в облаке — отдельный бакет
`AWS_PRIVATE_STORAGE_BUCKET_NAME` с block-public-access и без CDN-домена. Локальный
бэкенд (`apps/common/storages.py`) вообще не умеет отдавать URL — `storage.url()`
бросает исключение, так что «случайно» получить прямую ссылку нельзя.

**Подписанные ссылки.** Единственный доступ к файлу — ссылка со сроком жизни
`KYC_SIGNED_URL_TTL` (10 минут). На S3 это presigned URL, локально — токен
`django.core.signing`, привязанный к конкретному сотруднику: переслать ссылку коллеге
не выйдет. **Каждая выдача ссылки и каждое скачивание пишутся в `AuditLog`**: кто,
чьи документы, когда и с какого IP.

**Обработка при загрузке.** Тип файла определяется по содержимому (`python-magic`,
с откатом на Pillow, если libmagic нет в системе), проверяются размер (≤ 10 МБ)
и разрешение (≥ 800×600). Фоновая задача `users.process_identity_documents`
полностью пересобирает изображение без EXIF/GPS и удаляет исходник. Публичных
превью не создаётся, в CDN эти файлы не попадают.

**Право доступа.** `is_staff` сам по себе не даёт ничего: нужно отдельное разрешение
`users.can_review_identity` (выдаётся в админке). Без него — 403 и на очередь, и на review.

**Удаление.** После решения выставляется `purge_after = now + KYC_PURGE_AFTER_DAYS`
(30 дней). Celery Beat раз в сутки (03:45) запускает `users.purge_identity_files`:
файлы удаляются из хранилища, поля очищаются, **сама запись остаётся** — факт проверки
нужен, сканы паспорта нет.

**Логи.** Имена файлов, их содержимое и подписанные ссылки в обычные логи не пишутся;
в `AuditLog.extra` попадает только имя поля (`selfie`, `document_front`).

## Пользователь и профиль

`AUTH_USER_MODEL = "users.User"`, `USERNAME_FIELD = "phone"`, пароля в обычном
сценарии нет — вход по SMS-коду.

| Метод | Путь | Что делает |
|---|---|---|
| GET | `/api/v1/users/me/` | профиль: `id`, `phone`, `name`, `is_pro`, `iin`, `avatar_url`, `date_joined`, `wallet_balance` |
| PATCH | `/api/v1/users/me/` | меняет **только** `name` и `avatar`; `phone`, `is_pro`, `iin`, `is_staff` объявлены read-only и молча игнорируются |
| DELETE | `/api/v1/users/me/` | мягкое удаление, `204` |

- **Телефон** нормализуется к E.164 через `phonenumbers` (регион по умолчанию `KG`)
  в `User.save()`: «0700 12-34-56» → `+996700123456`. Невалидный номер — `ValidationError`,
  наружу это выходит как `400 validation_error`.
- **ИИН — персональные данные.** В API отдаётся маскированным (`20101199******`);
  полное значение видят только сам владелец и staff. В `__str__`, логи и текст ошибок
  ИИН не попадает; в админке поле read-only.
- **Мягкое удаление** (`apps/users/services.py`): `is_active=False`, телефон меняется на
  `deleted-<8 hex>`, имя/ИИН/аватар стираются, пароль становится неиспользуемым,
  все объявления пользователя уходят в `archived`. Строка в БД остаётся — на неё
  ссылаются объявления, обращения и операции по кошельку.
- `wallet_balance` — вложенный объект `{"balance": <кирпичи>, "currency": "brick"}`;
  берётся из кошелька, если он заведён, иначе `0`.

---

## Celery

```bash
docker compose exec web python -c "from config.celery import debug_task; print(debug_task.delay())"
```

Воркер слушает единственную очередь `default`. Периодические задачи настраиваются
через админку (django-celery-beat, `DatabaseScheduler`) — расписание хранится в БД.
Задачи автоматически подхватываются из `tasks.py` любого приложения в `INSTALLED_APPS`.

---

## Конфигурация и секреты

Все настройки читаются из переменных окружения через `django-environ`.
В репозитории лежит только `.env.example`; `.env` в `.gitignore` и в git не попадает.
Обязательные переменные: `DJANGO_SECRET_KEY`, `DATABASE_URL`, `REDIS_URL`.
Полный список с комментариями — в [.env.example](.env.example).

Модуль настроек выбирается через `DJANGO_SETTINGS_MODULE`
(`config.settings.local` по умолчанию, `config.settings.production` в проде).

### Продакшн

`config/settings/production.py` включает `SECURE_SSL_REDIRECT`, `SECURE_HSTS_SECONDS`
(год, с subdomains и preload), `SESSION_COOKIE_SECURE`, `CSRF_COOKIE_SECURE`,
`X_FRAME_OPTIONS=DENY`; CORS-origin'ы берутся из `CORS_ALLOWED_ORIGINS`.
Образ по умолчанию запускается через gunicorn под non-root пользователем `app`;
статику собирает `COLLECT_STATIC=true`, миграции — `RUN_MIGRATIONS=true`.

Проверить перед деплоем:

```bash
DJANGO_SETTINGS_MODULE=config.settings.production python manage.py check --deploy
```
