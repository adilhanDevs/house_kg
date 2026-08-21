"""Пересчёт полнотекстового индекса объявлений."""

from typing import Any

from django.core.management.base import BaseCommand, CommandParser

from apps.catalog.enums import ListingStatus
from apps.catalog.models import Listing
from apps.catalog.search import is_postgres, update_search_vectors


class Command(BaseCommand):
    help = "Пересобирает search_vector у объявлений (только PostgreSQL)."

    def add_arguments(self, parser: CommandParser) -> None:
        parser.add_argument(
            "--active-only",
            action="store_true",
            help="Пересчитать только опубликованные объявления.",
        )

    def handle(self, *args: Any, **options: Any) -> None:
        if not is_postgres():
            self.stdout.write(
                self.style.WARNING(
                    "Полнотекстовый поиск работает только на PostgreSQL — нечего пересчитывать."
                )
            )
            return

        queryset = Listing.objects.all()
        if options["active_only"]:
            queryset = queryset.filter(status=ListingStatus.ACTIVE)

        updated = update_search_vectors(queryset)
        self.stdout.write(self.style.SUCCESS(f"Обновлено объявлений: {updated}"))
