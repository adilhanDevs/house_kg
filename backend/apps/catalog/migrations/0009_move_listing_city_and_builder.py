"""Переносит город и застройщика объявления в связи со справочниками."""

from django.db import migrations


def forwards(apps, schema_editor):
    Listing = apps.get_model("catalog", "Listing")
    Builder = apps.get_model("catalog", "Builder")

    # Город берём у района — до сих пор он был доступен только через джойн.
    for listing in Listing.objects.select_related("district").iterator():
        if listing.city_id is None and listing.district_id:
            listing.city_id = listing.district.city_id
            listing.save(update_fields=["city"])

    # Текстовое название застройщика превращаем в ссылку на справочник.
    builders = {builder.name: builder for builder in Builder.objects.all()}
    names = set(Listing.objects.exclude(builder_legacy="").values_list("builder_legacy", flat=True))

    for index, name in enumerate(sorted(names - set(builders))):
        builders[name] = Builder.objects.create(
            name=name,
            slug=f"builder-{index + 1}-{abs(hash(name)) % 10_000}",
            order=100 + index,
        )

    for name, builder in builders.items():
        Listing.objects.filter(builder_legacy=name).update(builder=builder)


def backwards(apps, schema_editor):
    Listing = apps.get_model("catalog", "Listing")
    for listing in Listing.objects.select_related("builder").iterator():
        listing.builder_legacy = listing.builder.name if listing.builder_id else ""
        listing.save(update_fields=["builder_legacy"])


class Migration(migrations.Migration):
    dependencies = [
        ("catalog", "0008_listing_media_fields_and_indexes"),
    ]

    operations = [
        migrations.RunPython(forwards, backwards),
    ]
