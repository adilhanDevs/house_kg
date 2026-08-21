"""Перечисления каталога.

Значения совпадают с enum'ами Flutter-прототипа (`lib/data/listings.dart`) —
на них завязан клиент, переименовывать нельзя. Меняться могут только подписи.
"""

from django.db import models


class PropertyKind(models.TextChoices):
    """Тип недвижимости — категории «Главной» и чипы «Фильтра»."""

    HOUSE = "house", "Дома"
    APARTMENT = "apartment", "Квартиры"
    PLOT = "plot", "Участки"
    NEW_BUILDING = "new_building", "Новостройки"
    ROOM = "room", "Комната"
    COMMERCIAL = "commercial", "Коммерция"


class SellerKind(models.TextChoices):
    """Кто продаёт — три тумблера «Продавца» в «Фильтре»."""

    OWNER = "owner", "Только собственник"
    REALTOR = "realtor", "Риелторы"
    AGENCY = "agency", "Агентство недвижимости"


class ListingStatus(models.TextChoices):
    """Жизненный цикл объявления."""

    DRAFT = "draft", "Черновик"
    PENDING = "pending", "На модерации"
    ACTIVE = "active", "Опубликовано"
    REJECTED = "rejected", "Отклонено"
    ARCHIVED = "archived", "В архиве"
    SOLD = "sold", "Продано"


class MediaKind(models.TextChoices):
    """Тип файла, приложенного к объявлению."""

    PHOTO = "photo", "photo"
    VIDEO = "video", "video"


class Currency(models.TextChoices):
    USD = "USD", "USD"
    KGS = "KGS", "KGS"
