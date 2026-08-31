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


class PlotPurpose(models.TextChoices):
    """Назначение участка — показывается только для kind=plot."""

    IHS = "ihs", "ИЖС"
    GARDEN = "garden", "Садовый"
    AGRICULTURAL = "agricultural", "Сельхозназначение"
    COMMERCIAL = "commercial", "Коммерческий"


class CommercialPurpose(models.TextChoices):
    """Назначение помещения — показывается только для kind=commercial."""

    OFFICE = "office", "Офис"
    SHOP = "shop", "Магазин"
    WAREHOUSE = "warehouse", "Склад"
    PRODUCTION = "production", "Производство"
    CATERING = "catering", "Общепит"
    FREE = "free", "Свободного назначения"


class BuildingLine(models.TextChoices):
    """Расположение относительно дороги — важно для торговых помещений."""

    FIRST = "first", "Первая линия"
    SECOND = "second", "Вторая линия"
    INSIDE = "inside", "Внутри квартала"


class ListingCondition(models.TextChoices):
    """Состояние и ремонт. Коды совпадают с теми, что уже шлёт ad_edit_page."""

    EURO = "euro", "Евроремонт"
    GOOD = "good", "Хорошее состояние"
    SHELL = "shell", "Под самоотделку"
    MEDIUM = "medium", "Среднее состояние"
    NONE = "none", "Без ремонта"


class HeatingKind(models.TextChoices):
    """Тип отопления."""

    CENTRAL = "central", "Центральное"
    GAS = "gas", "Газовое"
    ELECTRIC = "electric", "Электрическое"
    AUTONOMOUS = "autonomous", "Автономное"


class FurnitureKind(models.TextChoices):
    """Меблировка.

    Раньше поле хранило свободный текст («Полностью»), а клиент слал коды —
    на детальной странице у части объявлений в графе «Мебель» стояло `full`.
    """

    FULL = "full", "Полностью меблирована"
    PARTIAL = "partial", "Частично с мебелью"
    NONE = "none", "Без мебели"


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


class MediaStatus(models.TextChoices):
    """Стадия обработки файла.

    Клиент показывает файл сразу после загрузки: пока статус не `ready`,
    отдаётся URL оригинала, а экран не ждёт конвертации.
    """

    UPLOADING = "uploading", "Загружается"
    PROCESSING = "processing", "Обрабатывается"
    READY = "ready", "Готово"
    FAILED = "failed", "Ошибка обработки"


class ModerationStatus(models.TextChoices):
    """Состояние задачи модерации."""

    OPEN = "open", "В очереди"
    APPROVED = "approved", "Одобрено"
    REJECTED = "rejected", "Отклонено"


class ReportReason(models.TextChoices):
    """За что пользователь жалуется на объявление."""

    FRAUD = "fraud", "Мошенничество"
    SOLD = "sold", "Объект уже продан"
    WRONG_INFO = "wrong_info", "Недостоверная информация"
    DUPLICATE = "duplicate", "Дубликат"
    SPAM = "spam", "Спам"


class Currency(models.TextChoices):
    USD = "USD", "USD"
    KGS = "KGS", "KGS"
