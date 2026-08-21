"""Вспомогательные операции для миграций каталога."""

from typing import Any

from django.db import migrations


class PostgresOnlyAddIndex(migrations.AddIndex):
    """AddIndex, который выполняется только на PostgreSQL.

    GIN-индексы (полнотекстовый поиск, pg_trgm) — фича Postgres. Целевая БД
    проекта — Postgres 16, но локальный прогон тестов идёт на SQLite, который
    «CREATE INDEX ... USING gin» не понимает. В состояние миграций индекс
    попадает всегда, в схему — только там, где он поддерживается.
    """

    def database_forwards(self, app_label: str, schema_editor: Any, *args: Any) -> None:
        if schema_editor.connection.vendor != "postgresql":
            return
        super().database_forwards(app_label, schema_editor, *args)

    def database_backwards(self, app_label: str, schema_editor: Any, *args: Any) -> None:
        if schema_editor.connection.vendor != "postgresql":
            return
        super().database_backwards(app_label, schema_editor, *args)
