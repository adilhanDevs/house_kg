"""Конфигурация Celery."""

import os

from celery import Celery
from kombu import Queue

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

app = Celery("house_kgz")

# Все настройки берём из Django-конфига (переменные с префиксом CELERY_).
app.config_from_object("django.conf:settings", namespace="CELERY")

# Две очереди: общая и отдельная под push.
#
# Push вынесен намеренно. Его потребляет один маленький воркер на проде, и он
# не должен разгребать остальные два десятка задач — иначе доставка встаёт в
# хвост за переиндексацией и рассылками. Обратное тоже верно: зависший FCM не
# должен останавливать общую очередь.
app.conf.task_default_queue = "default"
app.conf.task_queues = (
    Queue("default", routing_key="default"),
    Queue("push", routing_key="push"),
)
app.conf.task_default_exchange = "default"
app.conf.task_default_routing_key = "default"

# Маршрут задан здесь, а не в вызовах: `.delay()` из любого места кода попадёт
# в push, и ни один callsite не сможет случайно отправить доставку в default.
app.conf.task_routes = {
    "notifications.deliver_notification_push": {"queue": "push", "routing_key": "push"},
}

# Воркер push-очереди берёт по одной задаче: он однопоточный и на проде живёт
# в паре сотен мегабайт, набирать пачку впрок ему нечем.
app.conf.worker_prefetch_multiplier = 1

# Автопоиск tasks.py во всех приложениях из INSTALLED_APPS.
app.autodiscover_tasks()


@app.task(bind=True, ignore_result=True)
def debug_task(self) -> str:
    """Служебная задача для проверки, что воркер жив."""
    return f"request: {self.request!r}"
