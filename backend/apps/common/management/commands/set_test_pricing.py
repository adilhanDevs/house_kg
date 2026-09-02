"""Тестовые цены: всё платное стоит один сом (один кирпич).

Нужна, чтобы гонять настоящие платежи Finik, не расставаясь с деньгами:
пополнение на 1 сом даёт 1 кирпич, и этого хватает и на подписку, и на день
продвижения.

    python manage.py set_test_pricing              # всё по 1
    python manage.py set_test_pricing --price 5    # всё по 5
    python manage.py set_test_pricing --dry-run    # только показать, что изменится

Команда печатает прежние значения строкой «было → стало»: по этому же выводу
цены возвращаются обратно, когда тестовый режим больше не нужен. Боевые цены
из миграций для справки: продвижение — 780 кирпичей за день, опции — 300 и
250, тарифы «Риелтор» и «Агентство» — 4 900 и 14 900 кирпичей в месяц.
"""

from typing import Any

from django.core.management.base import BaseCommand, CommandParser
from django.db import transaction

from apps.billing.models import PromotionOption, PromotionPackage, Tariff
from apps.common.models import AppConfig


class Command(BaseCommand):
    help = "Ставит цену 1 сом (кирпич) на продвижение, опции и тарифы — для тестов оплаты"

    def add_arguments(self, parser: CommandParser) -> None:
        parser.add_argument(
            "--price",
            type=int,
            default=1,
            help="Цена, которую выставить везде (по умолчанию 1).",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Показать изменения, ничего не записывая.",
        )

    def handle(self, *args: Any, **options: Any) -> None:
        price = int(options["price"])
        dry_run = bool(options["dry_run"])

        if price < 0:
            self.stderr.write("Цена не может быть отрицательной.")
            return

        with transaction.atomic():
            self._section("Пакеты продвижения")
            for package in PromotionPackage.objects.order_by("order", "code"):
                self._apply(package, "price_per_day_bricks", price, dry_run)

            self._section("Опции продвижения")
            for option in PromotionOption.objects.order_by("order", "code"):
                self._apply(option, "price_per_day_bricks", price, dry_run)

            # Бесплатный тариф остаётся бесплатным: это лимит по умолчанию,
            # а не покупка, и платить за него не за что.
            self._section("Тарифы")
            for tariff in Tariff.objects.order_by("order", "code"):
                if tariff.price_bricks_per_month == 0:
                    self.stdout.write(f"  {tariff.code}: 0 (бесплатный, не трогаем)")
                    continue
                self._apply(tariff, "price_bricks_per_month", price, dry_run)

            self._section("Конфигурация приложения")
            config = AppConfig.get_solo()
            constants = dict(config.constants or {})
            was = constants.get("promotion_price_per_day")
            self.stdout.write(f"  promotion_price_per_day: {was} → {price}")
            if not dry_run and was != price:
                constants["promotion_price_per_day"] = price
                config.constants = constants
                config.save(update_fields=["constants", "updated_at"])

            if dry_run:
                transaction.set_rollback(True)

        tail = " (ничего не записано, --dry-run)" if dry_run else ""
        self.stdout.write(self.style.SUCCESS(f"Готово: цена {price}{tail}"))

    def _section(self, title: str) -> None:
        self.stdout.write(self.style.MIGRATE_HEADING(title))

    def _apply(self, obj: Any, field: str, price: int, dry_run: bool) -> None:
        was = getattr(obj, field)
        self.stdout.write(f"  {obj.code}: {was} → {price}")
        if dry_run or was == price:
            return
        setattr(obj, field, price)
        obj.save(update_fields=[field, "updated_at"])
