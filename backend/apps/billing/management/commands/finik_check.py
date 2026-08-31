"""Проверка подключения к Finik Pay.

Показывает, как разрешились настройки, и — по флагу — дёргает боевой GraphQL,
чтобы убедиться, что ключ принят и схема запросов совпадает с ожидаемой.

    python manage.py finik_check            # только настройки, без сети
    python manage.py finik_check --probe    # + запрос в Finik (ничего не создаёт)
    python manage.py finik_check --introspect  # + поля типа Item из схемы Finik
"""

import json
from typing import Any

from django.conf import settings
from django.core.management.base import BaseCommand

from apps.billing.providers.finik import (
    _GET_ITEM_QUERY,
    FinikPaymentProvider,
    FinikVerificationUnavailable,
    _finik_graphql,
    _graphql_url,
)

_INTROSPECT_ITEM = """
query IntrospectItem {
  __type(name: "Item") {
    name
    fields { name type { name kind ofType { name kind } } }
  }
}
"""


def _mask(value: str) -> str:
    if not value:
        return "(пусто)"
    if len(value) <= 8:
        return "***"
    return f"{value[:4]}…{value[-4:]}"


class Command(BaseCommand):
    help = "Проверяет настройки и доступность Finik Pay"

    def add_arguments(self, parser: Any) -> None:
        parser.add_argument(
            "--probe",
            action="store_true",
            help="Сделать запрос в Finik (ничего не создаёт, только читает).",
        )
        parser.add_argument(
            "--introspect",
            action="store_true",
            help="Показать поля типа Item из схемы Finik.",
        )

    def handle(self, *args: Any, **options: Any) -> None:
        provider = FinikPaymentProvider()

        self.stdout.write(self.style.MIGRATE_HEADING("Настройки Finik"))
        rows = [
            ("PAYMENT_PROVIDER", settings.PAYMENT_PROVIDER),
            ("FINIK_API_KEY", _mask(provider.api_key)),
            ("FINIK_ACCOUNT_ID", provider.account_id or "(пусто)"),
            ("FINIK_SECRET_KEY", _mask(str(provider.secret or ""))),
            ("FINIK_CALLBACK_URL", provider.callback_url or "(пусто)"),
            ("FINIK_BETA", str(getattr(settings, "FINIK_BETA", False))),
            ("GraphQL URL", _graphql_url()),
            ("Шаблон checkout", provider.checkout_template),
            ("Сверка колбэка", "включена" if provider.require_verification else "ВЫКЛЮЧЕНА"),
        ]
        for name, value in rows:
            self.stdout.write(f"  {name:<20} {value}")

        if settings.PAYMENT_PROVIDER != "finik":
            self.stdout.write(
                self.style.WARNING(
                    "\n  PAYMENT_PROVIDER не равен 'finik' — счета пойдут через другой шлюз."
                )
            )
        if not provider.is_configured:
            self.stdout.write(
                self.style.ERROR("\n  Нет ключа или accountId — счета выставляться не будут.")
            )
            return
        if not provider.callback_url:
            self.stdout.write(
                self.style.WARNING(
                    "\n  FINIK_CALLBACK_URL пуст — Finik не будет знать, куда слать колбэк."
                )
            )

        if options["probe"] or options["introspect"]:
            self._network_report()

        if options["introspect"]:
            self._run(
                "Схема типа Item",
                _INTROSPECT_ITEM,
                {},
                self._print_introspection,
            )

        if options["probe"]:
            # getItem по заведомо несуществующему id: проверяем не результат,
            # а то, что ключ принят и запрос совпал со схемой.
            self._run(
                "Проверка ключа (getItem)",
                _GET_ITEM_QUERY,
                {"input": {"id": "finik-check-probe", "keyType": "TRANSACTION_ID"}},
                self._print_payload,
            )

    def _network_report(self) -> None:
        """Что видно до GraphQL: прокси, DNS, TCP. Отделяет «шлюз не отвечает»
        от «наружу вообще не пускают» — например на бесплатном PythonAnywhere,
        где исходящие идут только через proxy.server и только на белый список.
        """
        import os
        import socket
        from urllib.parse import urlparse

        self.stdout.write(self.style.MIGRATE_HEADING("\nСеть"))

        proxies = {
            name: os.environ.get(name, "")
            for name in ("https_proxy", "HTTPS_PROXY", "http_proxy", "HTTP_PROXY")
        }
        active = {k: v for k, v in proxies.items() if v}
        self.stdout.write(f"  Прокси в окружении: {active or 'не заданы'}")

        host = urlparse(_graphql_url()).hostname or ""
        try:
            addresses = sorted({info[4][0] for info in socket.getaddrinfo(host, 443)})
            self.stdout.write(self.style.SUCCESS(f"  DNS {host} -> {', '.join(addresses)}"))
        except OSError as exc:
            self.stdout.write(self.style.ERROR(f"  DNS {host}: {exc}"))
            return

        try:
            with socket.create_connection((host, 443), timeout=10):
                self.stdout.write(self.style.SUCCESS(f"  TCP {host}:443 — соединение есть"))
        except OSError as exc:
            self.stdout.write(self.style.ERROR(f"  TCP {host}:443: {exc}"))
            self.stdout.write(
                "  Наружу не пускают. На бесплатном PythonAnywhere исходящие\n"
                "  разрешены только через proxy.server:3128 и только на сайты\n"
                "  из белого списка — Finik туда не входит."
            )

    def _run(self, title: str, query: str, variables: dict, printer: Any) -> None:
        self.stdout.write(self.style.MIGRATE_HEADING(f"\n{title}"))
        try:
            payload = _finik_graphql(query, variables)
        except FinikVerificationUnavailable as exc:
            self.stdout.write(self.style.ERROR(f"  Ошибка: {exc.code}"))
            if exc.provider_message:
                self.stdout.write(f"  Ответ шлюза: {exc.provider_message}")
            self.stdout.write(
                "  finik_graphql_unauthorized — ключ не принят;\n"
                "  finik_graphql_schema_mismatch — запрос не совпал со схемой Finik;\n"
                "  finik_http_* / finik_timeout — шлюз недоступен."
            )
            return
        printer(payload)

    def _print_payload(self, payload: dict) -> None:
        self.stdout.write(self.style.SUCCESS("  Ключ принят, запрос совпал со схемой."))
        self.stdout.write("  " + json.dumps(payload, ensure_ascii=False)[:600])

    def _print_introspection(self, payload: dict) -> None:
        item = (payload.get("data") or {}).get("__type")
        if not item:
            self.stdout.write("  Интроспекция закрыта на стороне Finik.")
            return
        self.stdout.write(self.style.SUCCESS(f"  Тип {item['name']}, поля:"))
        for field in item.get("fields") or []:
            type_info = field.get("type") or {}
            name = type_info.get("name") or (type_info.get("ofType") or {}).get("name")
            self.stdout.write(f"    {field['name']}: {name or type_info.get('kind')}")
