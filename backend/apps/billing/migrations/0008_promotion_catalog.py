"""Начальные пакеты и опции продвижения.

Заводятся миграцией, а не сидером: без пакета экран продвижения не откроется
и на проде. Цена базового пакета — 780 кирпичей за день, как `AppState.promoCost`
во Flutter.
"""

from django.db import migrations

PACKAGES = [
    (
        "standard",
        "Продвижение объявления",
        780,
        "Объявление показывается выше остальных в каталоге и в результатах поиска.",
        0,
    ),
]

OPTIONS = [
    (
        "exact_targeting",
        "Использовать точное продвижение",
        300,
        "Показ тем, кто уже искал похожие объекты в этом районе.",
        0,
    ),
    (
        "client_base",
        "Использовать клиентскую базу",
        250,
        "Рассылка по базе клиентов, подписанных на этот тип недвижимости.",
        1,
    ),
    (
        "whatsapp_base",
        "Использовать Whatsapp базу",
        250,
        "Рассылка объявления по базе WhatsApp.",
        2,
    ),
]


def create_catalog(apps_registry, schema_editor):
    package_model = apps_registry.get_model("billing", "PromotionPackage")
    for code, name, price, description, order in PACKAGES:
        package_model.objects.update_or_create(
            code=code,
            defaults={
                "name": name,
                "price_per_day_bricks": price,
                "description": description,
                "order": order,
                "is_active": True,
            },
        )

    option_model = apps_registry.get_model("billing", "PromotionOption")
    for code, name, price, description, order in OPTIONS:
        option_model.objects.update_or_create(
            code=code,
            defaults={
                "name": name,
                "price_per_day_bricks": price,
                "description": description,
                "order": order,
                "is_active": True,
            },
        )


def drop_catalog(apps_registry, schema_editor):
    apps_registry.get_model("billing", "PromotionPackage").objects.filter(
        code__in=[code for code, *_ in PACKAGES]
    ).delete()
    apps_registry.get_model("billing", "PromotionOption").objects.filter(
        code__in=[code for code, *_ in OPTIONS]
    ).delete()


class Migration(migrations.Migration):
    dependencies = [("billing", "0007_promotions")]

    operations = [migrations.RunPython(create_catalog, drop_catalog)]
