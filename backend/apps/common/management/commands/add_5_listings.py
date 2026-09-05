import random
import zlib
from io import BytesIO

from django.contrib.auth import get_user_model
from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone
from PIL import Image, ImageDraw

from apps.catalog.enums import MediaKind, PropertyKind, SellerKind
from apps.catalog.models import City, District, Listing, ListingMedia
from apps.catalog.search import update_search_vectors

PALETTE = [
    (234, 129, 46),   # orange
    (43,  100, 163),  # blue
    (110, 171, 74),   # green
    (204, 51,  51),   # red
    (142, 68,  173),  # purple
]

class Command(BaseCommand):
    help = "Добавляет 5 объявлений с 3 фотографиями каждое"

    @transaction.atomic
    def handle(self, *args, **options):
        User = get_user_model()
        user = User.objects.first()
        if not user:
            self.stdout.write(self.style.ERROR("Сначала создайте хотя бы одного пользователя."))
            return

        city = City.objects.first()
        if not city:
            city = City.objects.create(name="Бишкек", slug="bishkek")

        district = District.objects.filter(city=city).first()
        if not district:
            district = District.objects.create(city=city, name="Октябрьский", slug="oktyabrsky")

        now = timezone.now()
        kinds = [PropertyKind.APARTMENT, PropertyKind.HOUSE, PropertyKind.PLOT]
        seller_kinds = [SellerKind.OWNER, SellerKind.REALTOR, SellerKind.AGENCY]

        created_listings = []
        for i in range(5):
            kind = random.choice(kinds)
            rooms = random.randint(1, 5) if kind != PropertyKind.PLOT else 0
            area = random.randrange(30, 200) if kind != PropertyKind.PLOT else random.randrange(300, 1000)
            
            listing = Listing.objects.create(
                owner=user,
                kind=kind,
                seller_kind=random.choice(seller_kinds),
                city=city,
                district=district,
                price=random.randint(20000, 150000),
                rooms=rooms,
                area=area,
                description=f"Тестовое объявление #{i + 1}",
                published_at=now,
                status="published",
            )
            created_listings.append(listing)
            self.stdout.write(f"Создано объявление: {listing.slug}")

            # Добавляем 3 фото
            for order in range(3):
                media = ListingMedia.objects.create(
                    listing=listing,
                    order=order,
                    kind=MediaKind.PHOTO,
                    is_cover=(order == 0)
                )
                
                # Рисуем простую картинку
                width, height = 800, 600
                digest = zlib.crc32(f"{listing.slug}-{order}".encode())
                base = PALETTE[(digest) % len(PALETTE)]
                shade = 1 - order * 0.15
                background = tuple(max(0, min(255, int(channel * shade))) for channel in base)

                image = Image.new("RGB", (width, height), background)
                draw = ImageDraw.Draw(image)
                draw.rectangle([40, 40, width - 40, height - 40], outline=(255, 255, 255), width=4)

                buf = BytesIO()
                image.save(buf, format="JPEG", quality=85)
                
                media.file.save(
                    f"{listing.slug}-{order}.jpg",
                    ContentFile(buf.getvalue()),
                    save=True,
                )
        
        # Обновляем индекс полнотекстового поиска
        update_search_vectors(Listing.objects.filter(id__in=[l.id for l in created_listings]))
        
        self.stdout.write(self.style.SUCCESS("Успешно добавлено 5 объявлений с 3 фотографиями."))
