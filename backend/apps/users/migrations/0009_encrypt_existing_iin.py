"""Шифрование уже сохранённых ИИН.

Поле стало EncryptedCharField, но данные, записанные до этого, лежат
открытым текстом. Здесь они перечитываются и записываются обратно уже
через шифрующий дескриптор.

Обратная миграция расшифровывает: без неё откат оставил бы в базе
нечитаемый шифротекст.
"""

from django.db import migrations

from apps.common.fields import PREFIX, decrypt_value, encrypt_value

BATCH_SIZE = 500


def encrypt_existing(apps_registry, schema_editor):
    """Перезаписывает открытые значения зашифрованными."""
    model = apps_registry.get_model("users", "User")

    # Историческая модель отдаёт поле как обычный CharField, поэтому
    # шифруем и пишем значение руками — дескриптор здесь не сработает.
    rows = model.objects.exclude(iin="").exclude(iin__startswith=PREFIX).only("pk", "iin")

    for row in rows.iterator(chunk_size=BATCH_SIZE):
        model.objects.filter(pk=row.pk).update(iin=encrypt_value(row.iin))


def decrypt_existing(apps_registry, schema_editor):
    model = apps_registry.get_model("users", "User")

    rows = model.objects.filter(iin__startswith=PREFIX).only("pk", "iin")
    for row in rows.iterator(chunk_size=BATCH_SIZE):
        model.objects.filter(pk=row.pk).update(iin=decrypt_value(row.iin))


class Migration(migrations.Migration):
    dependencies = [("users", "0008_encrypt_iin")]

    operations = [migrations.RunPython(encrypt_existing, decrypt_existing)]
