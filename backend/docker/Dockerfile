# syntax=docker/dockerfile:1
# ============================================================================
# Многостадийная сборка backend-образа house_kgz.
# Контекст сборки — каталог backend/.
# ============================================================================

# ---------------------------------------------------------------------------
# Stage 1: builder — собираем виртуальное окружение
# ---------------------------------------------------------------------------
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# Сначала только метаданные проекта — слой с зависимостями кэшируется.
COPY pyproject.toml README.md ./
COPY config ./config
COPY apps ./apps

# INSTALL_DEV=true добавляет pytest/ruff/mypy/debug-toolbar (для локалки и CI).
ARG INSTALL_DEV=false
RUN pip install --upgrade pip setuptools wheel \
    && if [ "$INSTALL_DEV" = "true" ]; then \
         pip install -e ".[dev]"; \
       else \
         pip install -e "."; \
       fi

# ---------------------------------------------------------------------------
# Stage 2: runtime — минимальный образ без компиляторов
# ---------------------------------------------------------------------------
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    DJANGO_SETTINGS_MODULE=config.settings.production

# libmagic1 нужен python-magic: тип загруженного файла определяется
# по содержимому, а не по расширению.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl libmagic1 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system app \
    && useradd --system --gid app --home-dir /app --shell /usr/sbin/nologin app

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app
COPY --chown=app:app . .

RUN chmod +x /app/docker/entrypoint.sh \
    && mkdir -p /app/media /app/staticfiles /app/private-media \
    && chown -R app:app /app

USER app

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS http://localhost:8000/api/v1/health/ || exit 1

ENTRYPOINT ["/app/docker/entrypoint.sh"]
CMD ["gunicorn", "config.wsgi:application", \
     "--bind", "0.0.0.0:8000", "--workers", "3", "--timeout", "60"]
