"""Расширение pg_trgm и переименования полей объявления.

Переименования идут отдельной миграцией, чтобы не потерять данные: `builder`
из строки превращается в связь со справочником (перенос — в 0008), а
`agent_name` становится `contact_name`.
"""

from django.contrib.postgres.operations import TrigramExtension
from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0005_finalize_district_city"),
    ]

    operations = [
        # На не-PostgreSQL операция ничего не делает.
        TrigramExtension(),
        migrations.RenameField(
            model_name="listing",
            old_name="agent_name",
            new_name="contact_name",
        ),
        migrations.RenameField(
            model_name="listing",
            old_name="builder",
            new_name="builder_legacy",
        ),
    ]
