"""Конфигурация Celery."""

import os

from celery import Celery
from kombu import Queue

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

app = Celery("house_kgz")

# Все настройки берём из Django-конфига (переменные с префиксом CELERY_).
app.config_from_object("django.conf:settings", namespace="CELERY")

# Единственная очередь по умолчанию.
app.conf.task_default_queue = "default"
app.conf.task_queues = (Queue("default", routing_key="default"),)
app.conf.task_default_exchange = "default"
app.conf.task_default_routing_key = "default"

# Автопоиск tasks.py во всех приложениях из INSTALLED_APPS.
app.autodiscover_tasks()


@app.task(bind=True, ignore_result=True)
def debug_task(self) -> str:
    """Служебная задача для проверки, что воркер жив."""
    return f"request: {self.request!r}"
