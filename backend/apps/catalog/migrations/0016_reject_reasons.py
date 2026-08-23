"""Начальный справочник причин отклонения.

Причины заводятся миграцией, а не сидером: без них модератор не может
отклонить ни одно объявление, поэтому они нужны и на проде.
"""

from django.db import migrations

REASONS = [
    (
        "contacts",
        "Контакты в описании",
        "Телефон, ссылка или мессенджер в тексте объявления. Контакты "
        "показываются покупателю через приложение — уберите их из описания.",
    ),
    (
        "wrong_price",
        "Недостоверная цена",
        "Цена не соответствует объекту или указана для привлечения внимания. "
        "Укажите реальную стоимость.",
    ),
    (
        "duplicate",
        "Дубликат объявления",
        "Этот объект уже размещён на площадке. Повторные объявления удаляются.",
    ),
    (
        "bad_photos",
        "Плохое качество фото",
        "Фотографии нечёткие, тёмные или не показывают объект. Добавьте "
        "снимки, по которым видно помещение.",
    ),
    (
        "wrong_category",
        "Не соответствует категории",
        "Объект размещён не в той категории. Выберите подходящий тип "
        "недвижимости.",
    ),
    (
        "fraud",
        "Подозрение на мошенничество",
        "Объявление содержит признаки мошенничества. Обратитесь в поддержку, "
        "если считаете, что это ошибка.",
    ),
]


def create_reasons(apps_registry, schema_editor):
    model = apps_registry.get_model("catalog", "RejectReason")
    for order, (code, title, description) in enumerate(REASONS):
        model.objects.update_or_create(
            code=code,
            defaults={
                "title": title,
                "description": description,
                "order": order,
                "is_active": True,
            },
        )


def drop_reasons(apps_registry, schema_editor):
    model = apps_registry.get_model("catalog", "RejectReason")
    model.objects.filter(code__in=[code for code, _, _ in REASONS]).delete()


class Migration(migrations.Migration):
    dependencies = [("catalog", "0015_moderation")]

    operations = [migrations.RunPython(create_reasons, drop_reasons)]
