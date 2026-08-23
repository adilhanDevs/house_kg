# ============================================================================
# house_kgz backend — команды разработки.
#   up/down/logs/migrate/... работают через docker compose;
#   lint/format/test запускаются локально в .venv (docker для них не нужен).
# ============================================================================

COMPOSE ?= docker compose
SERVICE ?= web

# Пороги покрытия. Для биллинга он выше: непокрытая ветка в леджере стоит
# дороже любой другой.
COV_MIN         ?= 80
COV_MIN_BILLING ?= 95

# Параметры нагрузочного прогона.
HOST       ?= http://localhost:8000
USERS      ?= 100
RATE       ?= 10
TIME       ?= 3m
LOAD_COUNT ?= 50000
VENV    ?= .venv
PY      ?= $(VENV)/bin/python
PIP     ?= $(VENV)/bin/pip
RUFF    ?= $(VENV)/bin/ruff
PYTEST  ?= $(VENV)/bin/pytest
MYPY    ?= $(VENV)/bin/mypy

.DEFAULT_GOAL := help
.PHONY: help venv install up down logs migrate makemigrations shell test test-cov \
        test-billing test-concurrency schema-update loadtest loaddata lint format \
        audit security \
        typecheck superuser seed build ps restart clean

help: ## Показать список команд
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Локальное окружение
# ---------------------------------------------------------------------------
venv: ## Создать виртуальное окружение (Python 3.12+; uv, если он есть)
	@if command -v uv >/dev/null 2>&1; then \
		uv venv --python 3.12 $(VENV); \
	else \
		python3 -m venv $(VENV); \
	fi

install: venv ## Установить зависимости (включая dev)
	@if command -v uv >/dev/null 2>&1; then \
		VIRTUAL_ENV=$(VENV) uv pip install -e ".[dev]"; \
	else \
		$(PIP) install --upgrade pip && $(PIP) install -e ".[dev]"; \
	fi

# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------
up: ## Поднять всё окружение (web, db, redis, celery, beat, minio)
	$(COMPOSE) up -d --build

down: ## Остановить окружение
	$(COMPOSE) down

build: ## Пересобрать образы
	$(COMPOSE) build

ps: ## Статус контейнеров
	$(COMPOSE) ps

restart: ## Перезапустить web/celery
	$(COMPOSE) restart web celery celery-beat

logs: ## Логи всех сервисов (make logs SERVICE=celery — по одному)
	$(COMPOSE) logs -f --tail=200 $(SERVICE)

clean: ## Остановить и удалить тома (данные БД и файлы пропадут!)
	$(COMPOSE) down -v

# ---------------------------------------------------------------------------
# Django
# ---------------------------------------------------------------------------
migrate: ## Применить миграции
	$(COMPOSE) exec $(SERVICE) python manage.py migrate

makemigrations: ## Создать миграции
	$(COMPOSE) exec $(SERVICE) python manage.py makemigrations

shell: ## Django shell внутри контейнера
	$(COMPOSE) exec $(SERVICE) python manage.py shell

superuser: ## Создать суперпользователя
	$(COMPOSE) exec $(SERVICE) python manage.py createsuperuser

seed: ## Наполнить БД демо-данными (make seed ARGS=--flush — с очисткой)
	$(COMPOSE) exec $(SERVICE) python manage.py seed_demo $(ARGS)

# ---------------------------------------------------------------------------
# Качество кода
# ---------------------------------------------------------------------------
test: ## Прогнать тесты (быстро, без порога покрытия)
	$(PYTEST) --no-cov

test-cov: ## Тесты с покрытием и порогом 80 % по проекту
	$(PYTEST) --cov-fail-under=$(COV_MIN)

test-billing: ## Покрытие apps/billing с порогом 95 % — там движутся деньги
	# addopts обнуляется: иначе --cov=apps из pyproject подмешался бы к --cov=apps/billing
	# и порог считался бы по всему проекту.
	$(PYTEST) tests -o addopts="" --reuse-db --strict-markers \
		--cov=apps/billing --cov-report=term-missing \
		--cov-fail-under=$(COV_MIN_BILLING)

test-concurrency: ## Тесты гонок (нужен PostgreSQL, иначе пропускаются)
	$(PYTEST) tests/test_concurrency.py --no-cov -rs

audit: ## Аудит зависимостей на известные уязвимости
	# --skip-editable пропускает сам проект (его нет на PyPI). Найденная
	# уязвимость всё равно завершает команду ненулевым кодом.
	$(VENV)/bin/pip-audit --desc --skip-editable

security: lint audit ## Полная проверка безопасности: ruff (S/bandit) + pip-audit

schema-update: ## Пересобрать снапшот OpenAPI (осознанное действие!)
	$(PY) scripts/update_schema_snapshot.py

loadtest: ## Нагрузочный прогон locust (HOST/USERS/RATE/TIME переопределяются)
	$(VENV)/bin/locust -f loadtest/locustfile.py \
		--host $(HOST) --users $(USERS) --spawn-rate $(RATE) \
		--run-time $(TIME) --headless \
		--html loadtest/report.html

loaddata: ## Наполнить БД объявлениями для нагрузочного теста
	$(PY) manage.py generate_load_data --count=$(LOAD_COUNT)

lint: ## Проверить код (ruff check + ruff format --check)
	$(RUFF) check .
	$(RUFF) format --check .

format: ## Отформатировать код и починить импорты
	$(RUFF) check --fix .
	$(RUFF) format .

typecheck: ## Проверить типы (mypy)
	$(MYPY) apps config
