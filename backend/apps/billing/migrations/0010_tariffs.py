"""Начальные тарифы.

Заводятся миграцией, а не сидером: бесплатный тариф — это лимит публикации
по умолчанию, без него не работает ни один экран подписки и на проде.
"""

from django.db import migrations

# code, name, описание, цена/мес, лимит объявлений (0 = без ограничений), фичи
TARIFFS = [
    (
        "free",
        "Бесплатный",
        "Базовые возможности: до трёх активных объявлений одновременно.",
        0,
        3,
        {
            "priority_in_search": False,
            "advanced_stats": False,
            "verified_badge": False,
            "auto_bump_daily": False,
            "support_priority": False,
        },
        0,
    ),
    (
        "realtor",
        "Риелтор",
        "Для частного риелтора: больше объявлений, приоритет в поиске "
        "и ежедневный автоподъём.",
        4900,
        20,
        {
            "priority_in_search": True,
            "advanced_stats": True,
            "verified_badge": False,
            "auto_bump_daily": True,
            "support_priority": False,
        },
        1,
    ),
    (
        "agency",
        "Агентство",
        "Для агентства недвижимости: без ограничений по объявлениям, "
        "значок проверенного продавца и приоритетная поддержка.",
        14900,
        0,
        {
            "priority_in_search": True,
            "advanced_stats": True,
            "verified_badge": True,
            "auto_bump_daily": True,
            "support_priority": True,
        },
        2,
    ),
]


def create_tariffs(apps_registry, schema_editor):
    model = apps_registry.get_model("billing", "Tariff")
    for code, name, description, price, limit, features, order in TARIFFS:
        model.objects.update_or_create(
            code=code,
            defaults={
                "name": name,
                "description": description,
                "price_bricks_per_month": price,
                "listings_limit": limit,
                "features": features,
                "order": order,
                "is_active": True,
            },
        )


def drop_tariffs(apps_registry, schema_editor):
    apps_registry.get_model("billing", "Tariff").objects.filter(
        code__in=[code for code, *_ in TARIFFS]
    ).delete()


class Migration(migrations.Migration):
    dependencies = [("billing", "0009_subscriptions")]

    operations = [migrations.RunPython(create_tariffs, drop_tariffs)]
