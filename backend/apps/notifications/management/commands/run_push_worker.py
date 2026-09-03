"""Долгоживущий процесс доставки push из очереди в базе.

Заменяет связку Redis + Celery: на сервере 458 МБ памяти, и они вдвоём не
помещаются в остаток до порога безопасности. Здесь один процесс, который
спит, пока очередь пуста.
"""

import signal
import time
from typing import Any

from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Разбирает очередь push-уведомлений из PostgreSQL."

    def add_arguments(self, parser: Any) -> None:
        parser.add_argument(
            "--once",
            action="store_true",
            help="Один проход вместо цикла — для проверки и для systemd-таймера.",
        )
        parser.add_argument("--batch-size", type=int, default=None)
        parser.add_argument("--sleep", type=float, default=None)

    def handle(self, *args: Any, **options: Any) -> None:
        from apps.notifications import push_outbox

        batch = options["batch_size"] or push_outbox.BATCH_SIZE
        idle = options["sleep"] if options["sleep"] is not None else push_outbox.IDLE_SLEEP_SECONDS

        if options["once"]:
            handled = push_outbox.process_once(batch)
            self.stdout.write(f"обработано строк: {handled}")
            return

        # Останавливаемся по сигналу, а не по убийству посреди отправки:
        # строка в processing иначе ждала бы истечения таймаута зависших.
        self._running = True

        def stop(signum: int, frame: Any) -> None:
            self._running = False
            self.stdout.write("получен сигнал остановки, завершаю текущий проход")

        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)

        self.stdout.write(f"воркер push запущен: пачка {batch}, пауза {idle}s")
        while self._running:
            try:
                handled = push_outbox.process_once(batch)
            except Exception as exc:  # noqa: BLE001 - воркер не должен умирать от одной ошибки
                self.stderr.write(f"проход не удался: {type(exc).__name__}: {exc}")
                handled = 0

            if handled == 0 and self._running:
                time.sleep(idle)

        self.stdout.write("воркер push остановлен")
