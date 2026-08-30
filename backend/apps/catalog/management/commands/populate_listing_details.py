from decimal import Decimal
from django.core.management.base import BaseCommand
from apps.catalog.models import Listing, ListingRoom


class Command(BaseCommand):
    help = "Заполняет новые поля (комнаты, мебель, ключевые места, координаты, описание) для всех объявлений"

    def handle(self, *args, **options):
        listings = Listing.all_objects.all()
        count = listings.count()
        self.stdout.write(f"Найдено {count} объявлений для обновления...")

        if count == 0:
            self.stdout.write(self.style.WARNING("В базе нет объявлений."))
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

            l.save()

            # 7. Создание комнат (экспликация)
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

            updated_count += 1
            self.stdout.write(f"Обновлено: [{l.slug}] ({l.rooms_data.count()} комнат)")

        self.stdout.write(self.style.SUCCESS(f"Успешно обновлено {updated_count} объявлений!"))

