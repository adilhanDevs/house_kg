"""Скрипт для заполнения новых полей (комнаты, мебель, ключевые места, координаты, описание)

Запуск:
    python fill_listing_details.py
или на PythonAnywhere в консоли bash:
    cd /home/adilhan1234/house_kg/backend && python fill_listing_details.py
"""

import os
import sys
from decimal import Decimal

import django

# Настройка Django окружения
base_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, base_dir)

if "DJANGO_SETTINGS_MODULE" not in os.environ:
    try:
        os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.local")
        django.setup()
    except Exception:
        os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings.production"
        django.setup()
else:
    django.setup()

from apps.catalog.enums import MediaKind, MediaStatus
from apps.catalog.models import Listing, ListingRoom, ListingMedia
from django.core.files.base import ContentFile


def fill_listings():
    listings = Listing.all_objects.all()
    count = listings.count()
    print(f"Найдено {count} объявлений для обновления...")

    if count == 0:
        print("В базе нет объявлений. Запустите сначала populate_seller_data.py")
        return

    updated_count = 0

    for l in listings:
        district_name = l.district.name.lower() if l.district else ""
        slug_lower = l.slug.lower()

        # 1. Ключевые места (landmarks)
        if not l.landmarks:
            if "асанбай" in district_name or "asanbay" in slug_lower:
                l.landmarks = ["Парк Асанбай", "Гипермаркет Globus", "Школа Газпром"]
            elif "технопарк" in district_name or "technopark" in slug_lower:
                l.landmarks = ["Школа 56", "Магистраль-Бакаева", "Клиника Эскулап"]
            elif "южн" in district_name or "yuzhn" in slug_lower:
                l.landmarks = ["Парк Победы", "Магистраль", "ТРЦ Ала-Арча"]
            elif "центр" in district_name or "center" in slug_lower:
                l.landmarks = ["Площадь Ала-Тоо", "ЦУМ Айчүрөк", "Парк Панфилова"]
            else:
                l.landmarks = ["Школа 56", "Магистраль-Бакаева", "Клиника Эскулап"]

        # 2. Координаты (latitude, longitude)
        if not l.latitude or not l.longitude:
            if "асанбай" in district_name or "asanbay" in slug_lower:
                l.latitude = Decimal("42.815200")
                l.longitude = Decimal("74.623100")
            elif "технопарк" in district_name or "technopark" in slug_lower:
                l.latitude = Decimal("42.825632")
                l.longitude = Decimal("74.587321")
            elif "южн" in district_name or "yuzhn" in slug_lower:
                l.latitude = Decimal("42.818900")
                l.longitude = Decimal("74.605400")
            elif "центр" in district_name or "center" in slug_lower:
                l.latitude = Decimal("42.874600")
                l.longitude = Decimal("74.603700")
            else:
                l.latitude = Decimal("42.825632")
                l.longitude = Decimal("74.587321")

        # 3. Адрес
        if not l.address or l.address.strip() == "":
            if "асанбай" in district_name or "asanbay" in slug_lower:
                l.address = "Бишкек, мкр. Асанбай, \nул. Аалы Токомбаева 21"
            elif "технопарк" in district_name or "technopark" in slug_lower:
                l.address = "Бишкек, Октябрьский район, \nул.Бакаева 178/4"
            elif "южн" in district_name or "yuzhn" in slug_lower:
                l.address = "Бишкек, \nул. Байтик Баатыра 180"
            else:
                l.address = "Бишкек, Октябрьский район, \nул.Бакаева 178/4"

        # 4. Описание
        if not l.description or len(l.description.strip()) < 10 or "Сатурн" in l.description:
            if "асанбай" in district_name or "asanbay" in slug_lower:
                l.description = "Роскошная квартира в ЖК Премиум класса. Дизайнерский ремонт, панорамные окна, вся мебель и техника остаются. Рядом парк, школы и супермаркеты."
            elif "технопарк" in district_name or "technopark" in slug_lower:
                l.description = "Отличная квартира в районе Технопарка. Развитая инфраструктура, свежий евроремонт, новые трубы и проводка. Отличный вид из окон."
            elif "дом" in l.kind.lower() or "house" in slug_lower:
                l.description = "Просторный дом в тихом престижном районе. Участок 6 соток, ландшафтный дизайн, навес на 3 авто, зона барбекю."
            else:
                l.description = "Светлая и просторная квартира с панорамными окнами и видом на горы. Дизайнерский ремонт, качественные европейские материалы. В шаговой доступности школы, детские сады, парковые зоны и торговые центры."

        # 5. Мебель
        if not l.furniture:
            l.furniture = "Полностью"

        # 6. Варианты покупки
        l.has_direct_sale = True
        l.has_mortgage = True

        # 7. Квадратуры комнат
        total_sqm = float(l.area) if l.area else 92.0

        if not l.living_room_area:
            if "асанбай" in district_name or "asanbay" in slug_lower or total_sqm >= 110:
                l.living_room_area = Decimal("42.0")
                l.hall_area = Decimal("20.0")
                l.kitchen_area = Decimal("18.0")
                l.bedroom_area = Decimal("24.0")
                l.bedroom_2_area = Decimal("16.0")
                l.balcony_area = Decimal("8.0")
                l.bathroom_area = Decimal("11.0")
            elif "технопарк" in district_name or "technopark" in slug_lower or (80 <= total_sqm < 110):
                l.living_room_area = Decimal("35.0")
                l.hall_area = Decimal("23.0")
                l.kitchen_area = Decimal("17.0")
                l.bedroom_area = Decimal("25.0")
                l.bedroom_2_area = Decimal("15.0")
                l.balcony_area = Decimal("7.0")
                l.bathroom_area = Decimal("10.0")
            else:
                l.living_room_area = Decimal(str(round(total_sqm * 0.35, 1)))
                l.kitchen_area = Decimal(str(round(total_sqm * 0.18, 1)))
                l.hall_area = Decimal(str(round(total_sqm * 0.15, 1)))
                l.bedroom_area = Decimal(str(round(total_sqm * 0.22, 1)))
                l.bedroom_2_area = Decimal(str(round(total_sqm * 0.14, 1))) if total_sqm > 55 else None
                l.bathroom_area = Decimal(str(round(total_sqm * 0.08, 1)))
                l.balcony_area = Decimal(str(round(total_sqm * 0.06, 1)))

        l.save()

        # 8. Создание комнат (экспликация)
        if not l.rooms_data.exists():
            if "асанбай" in district_name or "asanbay" in slug_lower:
                rooms_def = [
                    ("Гостинная", Decimal("42.0")),
                    ("Холл", Decimal("20.0")),
                    ("Кухня", Decimal("18.0")),
                    ("Спальная", Decimal("24.0")),
                    ("Спальная 2", Decimal("16.0")),
                    ("Балкон", Decimal("8.0")),
                    ("Сан.узел", Decimal("11.0")),
                ]
            elif "технопарк" in district_name or "technopark" in slug_lower:
                rooms_def = [
                    ("Гостинная", Decimal("35.0")),
                    ("Холл", Decimal("23.0")),
                    ("Кухня", Decimal("17.0")),
                    ("Спальная", Decimal("25.0")),
                    ("Спальная 2", Decimal("15.0")),
                    ("Балкон", Decimal("7.0")),
                    ("Сан.узел", Decimal("10.0")),
                ]
            elif "дом" in l.kind.lower() or "house" in slug_lower:
                rooms_def = [
                    ("Гостинная", Decimal("60.0")),
                    ("Холл", Decimal("35.0")),
                    ("Кухня", Decimal("28.0")),
                    ("Спальная", Decimal("30.0")),
                    ("Спальная 2", Decimal("25.0")),
                    ("Гардеробная", Decimal("12.0")),
                    ("Терраса", Decimal("18.0")),
                    ("Сан.узел", Decimal("15.0")),
                ]
            else:
                rooms_def = [
                    ("Гостинная", Decimal("35.0")),
                    ("Кухня", Decimal("17.0")),
                    ("Спальная", Decimal("22.0")),
                    ("Сан.узел", Decimal("8.0")),
                ]
            for order, (r_name, r_area) in enumerate(rooms_def, 1):
                ListingRoom.objects.create(
                    listing=l,
                    name=r_name,
                    area=r_area,
                    order=order,
                )

        # 9. Видеообзоры с названиями и превью
        if l.media.filter(kind=MediaKind.VIDEO).count() < 3:
            video_defs = [
                ("Обзор квартиры", "video_1.mp4", "92b0d143df96c511.jpg"),
                ("Обзор местности", "video_2.mp4", "b76192aa900c610a.jpg"),
                ("Инфраструктура района", "video_3.mp4", "e267d094d7f9a8fc.jpg"),
            ]
            assets_video_dir = os.path.join(os.path.dirname(__file__), "..", "flutter_app", "assets", "videos_obzor")
            assets_img_dir = os.path.join(os.path.dirname(__file__), "..", "flutter_app", "assets", "figma")
            existing_count = l.media.filter(kind=MediaKind.VIDEO).count()
            for v_idx in range(existing_count, 3):
                v_title, v_file_name, v_thumb_name = video_defs[v_idx]
                v_path = os.path.join(assets_video_dir, v_file_name)
                t_path = os.path.join(assets_img_dir, v_thumb_name)
                if os.path.exists(v_path):
                    with open(v_path, "rb") as vf:
                        v_content = vf.read()
                    vm = ListingMedia(
                        listing=l,
                        kind=MediaKind.VIDEO,
                        title=v_title,
                        status=MediaStatus.READY,
                        order=10 + v_idx,
                    )
                    vm.file.save(f"video_{l.id}_{v_idx}.mp4", ContentFile(v_content), save=False)
                    if os.path.exists(t_path):
                        with open(t_path, "rb") as tf:
                            t_content = tf.read()
                        vm.thumbnail.save(f"thumb_{l.id}_{v_idx}.jpg", ContentFile(t_content), save=False)
                    vm.save()
                    print(f"   🎥 Добавлено видео #{v_idx + 1}: {v_title}")

        updated_count += 1
        print(f"✅ Обновлено объявление [{l.slug}]:")
        print(f"   - Адрес: {l.address.replace(chr(10), ' ')}")
        print(f"   - Координаты: {l.latitude}, {l.longitude}")
        print(f"   - Ключевые места: {l.landmarks}")
        print(f"   - Комнаты: {[f'{r.name}: {r.area}м²' for r in l.rooms_data.all()]}")
        videos_info = [f"{v.title or 'Видео'} (превью={bool(v.thumbnail)})" for v in l.media.filter(kind=MediaKind.VIDEO)]
        print(f"   - Видео: {videos_info}")
        print(f"   - Мебель: {l.furniture}, Покупка: Прямая={l.has_direct_sale}, Ипотека={l.has_mortgage}")

    print(f"\n🎉 Успешно обновлено {updated_count} объявлений!")


if __name__ == "__main__":
    fill_listings()
