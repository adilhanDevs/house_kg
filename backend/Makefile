# ============================================================================
# house_kgz backend — команды разработки.
#   up/down/logs/migrate/... работают через docker compose;
#   lint/format/test запускаются локально в .venv (docker для них не нужен).
# ============================================================================

COMPOSE ?= docker compose
SERVICE ?= web
VENV    ?= .venv
PY      ?= $(VENV)/bin/python
PIP     ?= $(VENV)/bin/pip
RUFF    ?= $(VENV)/bin/ruff
PYTEST  ?= $(VENV)/bin/pytest
MYPY    ?= $(VENV)/bin/mypy

.DEFAULT_GOAL := help
.PHONY: help venv install up down logs migrate makemigrations shell test lint format \
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
test: ## Прогнать тесты с покрытием
	$(PYTEST)

lint: ## Проверить код (ruff check + ruff format --check)
	$(RUFF) check .
	$(RUFF) format --check .

format: ## Отформатировать код и починить импорты
	$(RUFF) check --fix .
	$(RUFF) format .

typecheck: ## Проверить типы (mypy)
	$(MYPY) apps config
