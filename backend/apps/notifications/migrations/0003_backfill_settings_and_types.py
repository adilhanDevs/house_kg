"""Настройки уведомлений существующим пользователям и переезд старых типов."""

from django.db import migrations

# Старые значения типа -> новые из закрытого списка ТЗ.
TYPE_REPLACEMENTS = {
    "listing_moderation": "listing_moderated",
    "identity_verification": "system",
}


def forwards(apps, schema_editor):
    User = apps.get_model("users", "User")
    NotificationSettings = apps.get_model("notifications", "NotificationSettings")
    Notification = apps.get_model("notifications", "Notification")

    existing = set(NotificationSettings.objects.values_list("user_id", flat=True))
    NotificationSettings.objects.bulk_create(
        [
            NotificationSettings(user_id=user_id)
            for user_id in User.objects.exclude(pk__in=existing).values_list("pk", flat=True)
        ],
        batch_size=500,
    )

    for old, new in TYPE_REPLACEMENTS.items():
        Notification.objects.filter(type=old).update(type=new)


def backwards(apps, schema_editor):
    # Настройки удалять не нужно: они безвредны и восстановятся сигналом.
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("notifications", "0002_devicetoken_notificationsettings_and_more"),
        ("users", "0005_sellerprofile_identityverification"),
    ]

    operations = [
        migrations.RunPython(forwards, backwards),
    ]
