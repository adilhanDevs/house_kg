from django.db import migrations

def update_options(apps, schema_editor):
    PromotionOption = apps.get_model("billing", "PromotionOption")
    mapping = {
        "exact_targeting": "use_exact_promotion",
        "client_base": "use_client_database",
        "whatsapp_base": "use_whatsapp_database"
    }
    for old_code, new_code in mapping.items():
        PromotionOption.objects.filter(code=old_code).update(code=new_code)

class Migration(migrations.Migration):
    dependencies = [
        ("billing", "0010_tariffs"),
    ]

    operations = [
        migrations.RunPython(update_options, migrations.RunPython.noop),
    ]
