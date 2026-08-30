import os
import sys
import django
import urllib.request
from decimal import Decimal

# Настройка Django окружения
if "DJANGO_SETTINGS_MODULE" not in os.environ:
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.local")
django.setup()

from django.core.files.base import ContentFile
from django.utils import timezone
from apps.users.models import User, SellerProfile
from apps.catalog.models import City, District, HouseSeries, Builder, Listing, ListingMedia
from apps.catalog.enums import PropertyKind, SellerKind, ListingStatus, MediaKind, MediaStatus, Currency

def run():
    print("🚀 Начинаем создание данных продавца и объявлений...")

    # 1. Создаем или обновляем пользователя-продавца
    phone = "+996555444333"
    user, created = User.objects.get_or_create(phone=phone)
    user.name = "Адилхан Сатымкулов"
    user.is_pro = True
    user.seller_kind = SellerKind.REALTOR
    user.is_staff = True
    user.is_superuser = True
    user.set_password("1234")
    user.save()
    print(f"✅ Пользователь-продавец создан/обновлен: {user.phone} (пароль: 1234, is_pro: True)")

    # 2. Создаем или обновляем Профиль Продавца
    profile, p_created = SellerProfile.objects.get_or_create(user=user)
    profile.company_name = "KG Real Estate"
    profile.about = "Ведущее агентство недвижимости. Продажа элитных квартир и домов в Бишкеке."
    profile.experience_years = 12
    profile.whatsapp = "+996555444333"
    profile.telegram = "adilhan_realtor"
    profile.is_verified = True
    profile.verified_at = timezone.now()
    profile.rating = Decimal("4.95")
    profile.reviews_count = 34
    profile.save()
    print("✅ Профиль продавца (SellerProfile) настроен")

    # 3. Справочники: Город и Районы
    city, _ = City.objects.get_or_create(
        slug="bishkek",
        defaults={"name": "Бишкек", "is_default": True}
    )

    districts_data = [
        ("Асанбай", "asanbay"),
        ("Технопарк", "technopark"),
        ("Южные ворота", "yuzhnye-vorota"),
        ("Центр", "center"),
    ]
    districts = []
    for d_name, d_slug in districts_data:
        d, _ = District.objects.get_or_create(city=city, slug=d_slug, defaults={"name": d_name})
        districts.append(d)
        profile.work_districts.add(d)

    # 4. Серии и Застройщики
    series_elita, _ = HouseSeries.objects.get_or_create(code="elita", defaults={"name": "Элитка"})
    series_105, _ = HouseSeries.objects.get_or_create(code="105", defaults={"name": "105 серия"})
    builder, _ = Builder.objects.get_or_create(slug="elite-house", defaults={"name": "Elite House"})

    # 5. Фотографии и Видео из интернета
    sample_photos = [
        "https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=1200&q=80",
        "https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=1200&q=80",
        "https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=1200&q=80",
        "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=1200&q=80",
        "https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=1200&q=80",
    ]
    
    # Общедоступное тестовое видео интерьера/архитектуры (MP4)
    sample_video_url = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"

    # 6. Создаем тестовые объявления
    listings_info = [
        {
            "title": "3-комн. премиум квартира с видом на горы",
            "kind": PropertyKind.APARTMENT,
            "district": districts[0], # Асанбай
            "address": "ул. Аалы Токомбаева, 21",
            "price": Decimal("145000"),
            "old_price": Decimal("155000"),
            "rooms": 3,
            "area": Decimal("118.5"),
            "floor": 8,
            "floors": 14,
            "series": series_elita,
            "builder": builder,
            "living_room_area": Decimal("35.0"),
            "hall_area": Decimal("23.0"),
            "kitchen_area": Decimal("17.0"),
            "bedroom_area": Decimal("25.0"),
            "bedroom_2_area": Decimal("15.0"),
            "balcony_area": Decimal("7.0"),
            "bathroom_area": Decimal("10.0"),
            "furniture": "Полностью",
            "landmarks": ["Школа 56", "Магистраль-Бакаева", "Клиника Эскулап"],
            "latitude": Decimal("42.825632"),
            "longitude": Decimal("74.587321"),
            "has_direct_sale": True,
            "has_mortgage": True,
            "description": "Роскошная квартира в ЖК Премиум класса. Дизайнерский ремонт, панорамные окна, вся мебель и техника остаются. Рядом парк, школы и супермаркеты.",
        },
        {
            "title": "Уютный 2-этажный дом с садом",
            "kind": PropertyKind.HOUSE,
            "district": districts[2], # Южные ворота
            "address": "ул. Байтик Баатыра, 180",
            "price": Decimal("280000"),
            "old_price": Decimal("295000"),
            "rooms": 5,
            "area": Decimal("240.0"),
            "floor": 1,
            "floors": 2,
            "series": None,
            "builder": None,
            "living_room_area": Decimal("60.0"),
            "hall_area": Decimal("35.0"),
            "kitchen_area": Decimal("28.0"),
            "bedroom_area": Decimal("30.0"),
            "bedroom_2_area": Decimal("25.0"),
            "balcony_area": Decimal("12.0"),
            "bathroom_area": Decimal("15.0"),
            "furniture": "Полностью",
            "landmarks": ["Парк Победы", "Магистраль", "ТРЦ Ала-Арча"],
            "latitude": Decimal("42.818900"),
            "longitude": Decimal("74.605400"),
            "has_direct_sale": True,
            "has_mortgage": True,
            "description": "Просторный дом в тихом престижном районе. Участок 6 соток, ландшафтный дизайн, навес на 3 авто, зона барбекю.",
        },
        {
            "title": "2-комнатная квартира с евроремонтом",
            "kind": PropertyKind.APARTMENT,
            "district": districts[1], # Технопарк
            "address": "ул. Горького, 1",
            "price": Decimal("82000"),
            "old_price": Decimal("87000"),
            "rooms": 2,
            "area": Decimal("92.0"),
            "floor": 8,
            "floors": 12,
            "series": series_105,
            "builder": None,
            "living_room_area": Decimal("35.0"),
            "hall_area": Decimal("23.0"),
            "kitchen_area": Decimal("17.0"),
            "bedroom_area": Decimal("25.0"),
            "bedroom_2_area": Decimal("15.0"),
            "balcony_area": Decimal("7.0"),
            "bathroom_area": Decimal("10.0"),
            "furniture": "Полностью",
            "landmarks": ["Школа 56", "Магистраль-Бакаева", "Клиника Эскулап"],
            "latitude": Decimal("42.825632"),
            "longitude": Decimal("74.587321"),
            "has_direct_sale": True,
            "has_mortgage": True,
            "description": "Отличная квартира в районе Технопарка. Развитая инфраструктура, свежий евроремонт, новые трубы и проводка.",
        }
    ]

    for idx, data in enumerate(listings_info, 1):
        listing = Listing.objects.create(
            owner=user,
            kind=data["kind"],
            seller_kind=SellerKind.REALTOR,
            city=city,
            district=data["district"],
            address=data["address"],
            price=data["price"],
            currency=Currency.USD,
            price_usd=data["price"],
            old_price=data["old_price"],
            rooms=data["rooms"],
            area=data["area"],
            living_room_area=data.get("living_room_area"),
            hall_area=data.get("hall_area"),
            kitchen_area=data.get("kitchen_area"),
            bedroom_area=data.get("bedroom_area"),
            bedroom_2_area=data.get("bedroom_2_area"),
            balcony_area=data.get("balcony_area"),
            bathroom_area=data.get("bathroom_area"),
            furniture=data.get("furniture", "Полностью"),
            landmarks=data.get("landmarks", []),
            latitude=data.get("latitude"),
            longitude=data.get("longitude"),
            has_direct_sale=data.get("has_direct_sale", True),
            has_mortgage=data.get("has_mortgage", True),
            floor=data["floor"],
            floors=data["floors"],
            series=data["series"],
            builder=data["builder"],
            description=data["description"],
            status=ListingStatus.ACTIVE,
            published_at=timezone.now(),
            views_count=45 + idx * 17,
            favourites_count=12 + idx * 3,
            contact_name=user.name,
            contact_phone=user.phone,
        )
        print(f"🏠 Создано объявление #{listing.id}: {data['title']}")

        # Добавляем 2-3 фото к объявлению
        for photo_idx in range(3):
            photo_url = sample_photos[(idx + photo_idx) % len(sample_photos)]
            try:
                req = urllib.request.Request(photo_url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=10) as resp:
                    content = resp.read()
                    media = ListingMedia(
                        listing=listing,
                        kind=MediaKind.PHOTO,
                        order=photo_idx,
                        is_cover=(photo_idx == 0),
                        status=MediaStatus.READY,
                    )
                    media.file.save(f"photo_{listing.id}_{photo_idx}.jpg", ContentFile(content), save=False)
                    media.url_original.save(f"photo_{listing.id}_{photo_idx}_orig.jpg", ContentFile(content), save=False)
                    media.url_medium.save(f"photo_{listing.id}_{photo_idx}_med.jpg", ContentFile(content), save=False)
                    media.url_thumb.save(f"photo_{listing.id}_{photo_idx}_thumb.jpg", ContentFile(content), save=False)
                    media.save()
                    print(f"   📸 Добавлено фото {photo_idx + 1}")
            except Exception as err:
                print(f"   ⚠️ Не удалось загрузить фото: {err}")

        # Добавляем видео к объявлению
        try:
            video_content = None
            local_video_paths = [
                os.path.join(os.path.dirname(__file__), "sample_videos", "sample_video.mp4"),
                os.path.join(os.path.dirname(__file__), "..", "flutter_app", "assets", "videos_obzor", "video_3.mp4"),
                os.path.join(os.path.dirname(__file__), "..", "flutter_app", "assets", "videos_obzor", f"video_{idx}.mp4"),
            ]
            for v_path in local_video_paths:
                if os.path.exists(v_path):
                    with open(v_path, "rb") as f:
                        video_content = f.read()
                    print(f"   🎬 Использован локальный видеофайл: {os.path.basename(v_path)} ({len(video_content)} байт)")
                    break

            if not video_content:
                # Fallback download URLs
                urls = [
                    "https://raw.githubusercontent.com/intel-iot-devkit/sample-videos/master/person-bicycle-car-detection.mp4",
                    "https://archive.org/download/BigBuckBunny_328/BigBuckBunny_512kb.mp4",
                ]
                for u in urls:
                    try:
                        req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
                        with urllib.request.urlopen(req, timeout=10) as resp:
                            video_content = resp.read()
                            print(f"   🎬 Видео успешно скачано ({len(video_content)} байт)")
                            break
                    except Exception:
                        continue

            if video_content:
                v_media = ListingMedia(
                    listing=listing,
                    kind=MediaKind.VIDEO,
                    order=10,
                    is_cover=False,
                    status=MediaStatus.READY,
                    duration_seconds=15,
                )
                v_media.file.save(f"video_{listing.id}.mp4", ContentFile(video_content), save=False)
                v_media.url_original.save(f"video_{listing.id}.mp4", ContentFile(video_content), save=False)
                v_media.save()
                print(f"   ✅ Видео успешно прикреплено к объявлению #{idx}!")
        except Exception as err:
            print(f"   ⚠️ Ошибка при сохранении видео: {err}")

    print("\n🎉 Все данные успешно созданы и готовы к работе!")
    print("👤 Логин продавца: +996555444333")
    print("🔑 Пароль: 1234")

if __name__ == "__main__":
    run()
