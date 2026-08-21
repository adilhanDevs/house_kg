#!/bin/sh
# Точка входа контейнера: по флагам прогоняет миграции/collectstatic и
# передаёт управление команде сервиса.
set -e

if [ "${RUN_MIGRATIONS:-false}" = "true" ]; then
    echo "==> Применяю миграции"
    python manage.py migrate --noinput
fi

if [ "${COLLECT_STATIC:-false}" = "true" ]; then
    echo "==> Собираю статику"
    python manage.py collectstatic --noinput
fi

exec "$@"
