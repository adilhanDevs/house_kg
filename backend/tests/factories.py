"""Фабрики для всех моделей проекта.

Правило: фабрика создаёт валидный минимум и ничего не знает о конкретном
тесте. Всё, что тесту нужно сверх минимума, он задаёт сам — иначе фабрики
обрастают флагами и перестают быть читаемыми.
"""

import uuid
from datetime import timedelta
from decimal import Decimal

import factory
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import make_password
from django.utils import timezone
from factory.django import DjangoModelFactory

from apps.billing.models import (
    Payment,
    PaymentLog,
    PaymentLogDirection,
    PaymentProviderConfig,
    PaymentStatus,
    Promotion,
    PromotionOption,
    PromotionPackage,
    PromotionStatus,
    Subscription,
    SubscriptionStatus,
    Tariff,
    Wallet,
    WalletTransaction,
)
from apps.catalog.enums import (
    Currency,
    ListingStatus,
    MediaKind,
    MediaStatus,
    ModerationStatus,
    PropertyKind,
    ReportReason,
    SellerKind,
)
from apps.catalog.models import (
    Builder,
    City,
    District,
    ExchangeRate,
    HouseSeries,
    Listing,
    ListingDailyStat,
    ListingMedia,
    ListingReport,
    ModerationTask,
    RejectReason,
)
from apps.common.enums import WalletEntryKind
from apps.common.models import AppConfig as AppConfigModel
from apps.common.models import AuditLog, OnboardingSlide, StaticPage, SupportTicket
from apps.engagement.models import (
    Collection,
    CollectionItem,
    Favourite,
    SavedFilter,
    ViewHistory,
)
from apps.messaging.models import Conversation, Message
from apps.notifications.models import (
    DevicePlatform,
    DeviceToken,
    Notification,
    NotificationSettings,
    NotificationType,
)
from apps.users.models import (
    ConsentType,
    ContactEvent,
    DataExport,
    DataExportStatus,
    IdentityVerification,
    OtpCode,
    OtpPurpose,
    Review,
    ReviewStatus,
    SellerProfile,
    SellerVerification,
    UserConsent,
    VerificationStatus,
)

DEFAULT_PASSWORD = "test12345"


class UserFactory(DjangoModelFactory):
    """Пользователь с валидным кыргызским номером."""

    class Meta:
        model = get_user_model()
        skip_postgeneration_save = True

    phone = factory.Sequence(lambda n: f"+99670012{n:04d}")
    name = factory.Sequence(lambda n: f"Пользователь {n}")
    is_pro = False

    class Params:
        # UserFactory(pro=True) — исполнитель с заполненным ИИН.
        pro = factory.Trait(
            is_pro=True,
            iin="20101199001234",
            seller_kind=SellerKind.REALTOR,
        )

    @factory.post_generation
    def password(obj, create: bool, extracted: str | None, **kwargs: object) -> None:  # noqa: N805
        if not create:
            return
        obj.set_password(extracted or DEFAULT_PASSWORD)
        obj.save(update_fields=["password"])


class CityFactory(DjangoModelFactory):
    class Meta:
        model = City
        django_get_or_create = ("slug",)

    name = factory.Sequence(lambda n: f"Город {n}")
    slug = factory.Sequence(lambda n: f"city-{n}")


class DistrictFactory(DjangoModelFactory):
    class Meta:
        model = District
        django_get_or_create = ("city", "slug")

    city = factory.SubFactory(CityFactory)
    name = factory.Sequence(lambda n: f"Район {n}")
    slug = factory.Sequence(lambda n: f"district-{n}")


class BuilderFactory(DjangoModelFactory):
    class Meta:
        model = Builder
        django_get_or_create = ("slug",)

    name = factory.Sequence(lambda n: f"Застройщик {n}")
    slug = factory.Sequence(lambda n: f"builder-{n}")


class HouseSeriesFactory(DjangoModelFactory):
    class Meta:
        model = HouseSeries
        django_get_or_create = ("code",)

    code = factory.Sequence(lambda n: f"1{n:02d}")
    name = factory.LazyAttribute(lambda obj: f"{obj.code} серия")


class ListingFactory(DjangoModelFactory):
    class Meta:
        model = Listing

    owner = factory.SubFactory(UserFactory)
    district = factory.SubFactory(DistrictFactory)
    # Город всегда тот же, что у района.
    city = factory.SelfAttribute("district.city")
    kind = PropertyKind.APARTMENT
    seller_kind = SellerKind.OWNER
    price = Decimal("100000.00")
    area = Decimal("80.00")
    rooms = 3
    floor = 5
    floors = 9
    status = ListingStatus.ACTIVE


class ListingMediaFactory(DjangoModelFactory):
    class Meta:
        model = ListingMedia

    listing = factory.SubFactory(ListingFactory)
    kind = MediaKind.PHOTO
    # Уже обработанный файл: тесты, которым обработка не важна, работают с ним
    # как с готовым.
    status = MediaStatus.READY
    order = factory.Sequence(lambda n: n)
    is_cover = False
    file = factory.django.FileField(filename="photo.jpg", data=b"fake-photo-bytes")


class FavouriteFactory(DjangoModelFactory):
    class Meta:
        model = Favourite
        django_get_or_create = ("user", "listing")

    user = factory.SubFactory(UserFactory)
    listing = factory.SubFactory(ListingFactory)


# ---------------------------------------------------------------------------
# Диалоги и сообщения
# ---------------------------------------------------------------------------


class ConversationFactory(DjangoModelFactory):
    class Meta:
        model = Conversation

    listing = factory.SubFactory(ListingFactory)
    buyer = factory.SubFactory(UserFactory)
    seller = factory.SelfAttribute("listing.owner")
    listing_slug = factory.SelfAttribute("listing.slug")
    listing_title = "Объявление"
    listing_price = factory.SelfAttribute("listing.price")
    listing_currency = factory.SelfAttribute("listing.currency")
    listing_cover_url = ""


class MessageFactory(DjangoModelFactory):
    class Meta:
        model = Message

    conversation = factory.SubFactory(ConversationFactory)
    sender = factory.SelfAttribute("conversation.buyer")
    text = "Здравствуйте! Объявление актуально?"
    client_message_id = factory.LazyFunction(uuid.uuid4)


# ---------------------------------------------------------------------------
# Каталог: медиа, статистика, модерация
# ---------------------------------------------------------------------------


class ListingDailyStatFactory(DjangoModelFactory):
    class Meta:
        model = ListingDailyStat
        django_get_or_create = ("listing", "date")

    listing = factory.SubFactory(ListingFactory)
    date = factory.LazyFunction(timezone.localdate)
    impressions = 0
    views = 0
    favourites = 0
    phone_reveals = 0


class RejectReasonFactory(DjangoModelFactory):
    class Meta:
        model = RejectReason
        django_get_or_create = ("code",)

    code = factory.Sequence(lambda n: f"reason-{n}")
    title = factory.Sequence(lambda n: f"Причина {n}")
    description = "Пояснение для владельца объявления."


class ModerationTaskFactory(DjangoModelFactory):
    class Meta:
        model = ModerationTask

    listing = factory.SubFactory(ListingFactory)
    status = ModerationStatus.OPEN
    checks = factory.Dict({})
    priority = 0


class ListingReportFactory(DjangoModelFactory):
    class Meta:
        model = ListingReport
        django_get_or_create = ("listing", "reporter")

    listing = factory.SubFactory(ListingFactory)
    reporter = factory.SubFactory(UserFactory)
    reason = ReportReason.FRAUD
    comment = ""


class ExchangeRateFactory(DjangoModelFactory):
    class Meta:
        model = ExchangeRate

    currency_from = Currency.USD
    currency_to = Currency.KGS
    rate = Decimal("87.500000")


# ---------------------------------------------------------------------------
# Пользователи: OTP, профиль продавца, отзывы, верификация
# ---------------------------------------------------------------------------


class OtpCodeFactory(DjangoModelFactory):
    """Код подтверждения. Открытый код нигде не хранится — только его хеш."""

    class Meta:
        model = OtpCode

    phone = factory.Sequence(lambda n: f"+99670099{n:04d}")
    code_hash = factory.LazyFunction(lambda: make_password("1234"))
    purpose = OtpPurpose.LOGIN
    expires_at = factory.LazyFunction(lambda: timezone.now() + timedelta(minutes=5))


class SellerProfileFactory(DjangoModelFactory):
    class Meta:
        model = SellerProfile
        django_get_or_create = ("user",)

    user = factory.SubFactory(UserFactory, pro=True)
    company_name = factory.Sequence(lambda n: f"Агентство {n}")
    about = "Работаем с недвижимостью Бишкека."
    experience_years = 5
    whatsapp = factory.LazyAttribute(lambda obj: obj.user.phone)


class ReviewFactory(DjangoModelFactory):
    class Meta:
        model = Review
        django_get_or_create = ("seller", "author")

    seller = factory.SubFactory(UserFactory, pro=True)
    author = factory.SubFactory(UserFactory)
    rating = 5
    text = "Всё прошло хорошо."
    status = ReviewStatus.PENDING


class IdentityVerificationFactory(DjangoModelFactory):
    class Meta:
        model = IdentityVerification

    user = factory.SubFactory(UserFactory, pro=True)
    selfie = factory.django.FileField(filename="selfie.jpg", data=b"fake-selfie")
    status = VerificationStatus.PENDING


class SellerVerificationFactory(DjangoModelFactory):
    class Meta:
        model = SellerVerification

    seller = factory.SubFactory(UserFactory, pro=True)
    documents = factory.List([factory.Dict({"path": "sellers/verification/doc.pdf"})])
    status = VerificationStatus.PENDING


class UserConsentFactory(DjangoModelFactory):
    class Meta:
        model = UserConsent

    user = factory.SubFactory(UserFactory)
    consent_type = ConsentType.PERSONAL_DATA
    document_version = "1"
    granted = True
    ip_address = "127.0.0.1"


class DataExportFactory(DjangoModelFactory):
    class Meta:
        model = DataExport

    user = factory.SubFactory(UserFactory)
    status = DataExportStatus.PENDING


class ContactEventFactory(DjangoModelFactory):
    class Meta:
        model = ContactEvent

    listing = factory.SubFactory(ListingFactory)
    user = factory.SubFactory(UserFactory)
    ip_address = "127.0.0.1"


# ---------------------------------------------------------------------------
# Вовлечение: история, фильтры, подборки
# ---------------------------------------------------------------------------


class ViewHistoryFactory(DjangoModelFactory):
    class Meta:
        model = ViewHistory
        django_get_or_create = ("user", "listing")

    user = factory.SubFactory(UserFactory)
    listing = factory.SubFactory(ListingFactory)


class SavedFilterFactory(DjangoModelFactory):
    class Meta:
        model = SavedFilter

    user = factory.SubFactory(UserFactory)
    name = factory.Sequence(lambda n: f"Фильтр {n}")
    params = factory.Dict({"kind": PropertyKind.APARTMENT})
    notify_on_new = True


class CollectionFactory(DjangoModelFactory):
    class Meta:
        model = Collection
        django_get_or_create = ("slug",)

    title = factory.Sequence(lambda n: f"Подборка {n}")
    slug = factory.Sequence(lambda n: f"collection-{n}")
    is_active = True


class CollectionItemFactory(DjangoModelFactory):
    class Meta:
        model = CollectionItem
        django_get_or_create = ("collection", "listing")

    collection = factory.SubFactory(CollectionFactory)
    listing = factory.SubFactory(ListingFactory)
    order = factory.Sequence(lambda n: n)


# ---------------------------------------------------------------------------
# Биллинг: кошелёк, платежи, продвижение, подписки
# ---------------------------------------------------------------------------


class WalletFactory(DjangoModelFactory):
    """Кошелёк заводится сигналом на пользователя — здесь get_or_create."""

    class Meta:
        model = Wallet
        django_get_or_create = ("user",)

    user = factory.SubFactory(UserFactory)
    balance = 0


class WalletTransactionFactory(DjangoModelFactory):
    """Операция леджера.

    `balance_after` считается от текущего баланса кошелька: запись в леджер
    без него противоречила бы самой идее append-only истории.
    """

    class Meta:
        model = WalletTransaction

    wallet = factory.SubFactory(WalletFactory)
    amount = 1000
    kind = WalletEntryKind.TOPUP
    label = factory.LazyAttribute(lambda obj: f"{obj.amount:+d} кирпичей")
    balance_after = factory.LazyAttribute(lambda obj: obj.wallet.balance + obj.amount)


class PaymentProviderConfigFactory(DjangoModelFactory):
    class Meta:
        model = PaymentProviderConfig
        django_get_or_create = ("code",)

    code = factory.Sequence(lambda n: f"provider-{n}")
    name = factory.Sequence(lambda n: f"Банк {n}")
    is_active = True


class PaymentFactory(DjangoModelFactory):
    class Meta:
        model = Payment

    user = factory.SubFactory(UserFactory)
    amount_kgs = Decimal("12000.00")
    bricks = 12000
    bonus_bricks = 1200
    provider = "mock"
    status = PaymentStatus.PENDING
    idempotency_key = factory.Sequence(lambda n: f"payment-key-{n}")


class PaymentLogFactory(DjangoModelFactory):
    class Meta:
        model = PaymentLog

    payment = factory.SubFactory(PaymentFactory)
    direction = PaymentLogDirection.OUT
    endpoint = "/pay"
    payload = factory.Dict({})


class PromotionPackageFactory(DjangoModelFactory):
    class Meta:
        model = PromotionPackage
        django_get_or_create = ("code",)

    code = "standard"
    name = "Продвижение объявления"
    price_per_day_bricks = 780
    is_active = True


class PromotionOptionFactory(DjangoModelFactory):
    class Meta:
        model = PromotionOption
        django_get_or_create = ("code",)

    code = factory.Sequence(lambda n: f"option-{n}")
    name = factory.Sequence(lambda n: f"Опция {n}")
    price_per_day_bricks = 300
    is_active = True


class PromotionFactory(DjangoModelFactory):
    class Meta:
        model = Promotion

    listing = factory.SubFactory(ListingFactory)
    package = factory.SubFactory(PromotionPackageFactory)
    days = 3
    options = factory.List([])
    cost_bricks = factory.LazyAttribute(lambda obj: obj.days * obj.package.price_per_day_bricks)
    starts_at = factory.LazyFunction(timezone.now)
    ends_at = factory.LazyAttribute(lambda obj: obj.starts_at + timedelta(days=obj.days))
    status = PromotionStatus.ACTIVE


class TariffFactory(DjangoModelFactory):
    class Meta:
        model = Tariff
        django_get_or_create = ("code",)

    code = "realtor"
    name = "Риелтор"
    price_bricks_per_month = 4900
    listings_limit = 20
    features = factory.Dict(
        {
            "priority_in_search": True,
            "advanced_stats": True,
            "verified_badge": False,
            "auto_bump_daily": True,
            "support_priority": False,
        }
    )
    is_active = True


class SubscriptionFactory(DjangoModelFactory):
    class Meta:
        model = Subscription

    user = factory.SubFactory(UserFactory, pro=True)
    tariff = factory.SubFactory(TariffFactory)
    starts_at = factory.LazyFunction(timezone.now)
    ends_at = factory.LazyAttribute(lambda obj: obj.starts_at + timedelta(days=30))
    status = SubscriptionStatus.ACTIVE
    is_auto_renew = True


# ---------------------------------------------------------------------------
# Уведомления
# ---------------------------------------------------------------------------


class NotificationFactory(DjangoModelFactory):
    class Meta:
        model = Notification

    user = factory.SubFactory(UserFactory)
    type = NotificationType.SYSTEM
    title = factory.Sequence(lambda n: f"Уведомление {n}")
    body = "Текст уведомления"
    payload = factory.Dict({})


class DeviceTokenFactory(DjangoModelFactory):
    class Meta:
        model = DeviceToken
        django_get_or_create = ("token",)

    user = factory.SubFactory(UserFactory)
    token = factory.Sequence(lambda n: f"fcm-token-{n}")
    platform = DevicePlatform.ANDROID
    is_active = True


class NotificationSettingsFactory(DjangoModelFactory):
    """Настройки заводятся сигналом — здесь get_or_create."""

    class Meta:
        model = NotificationSettings
        django_get_or_create = ("user",)

    user = factory.SubFactory(UserFactory)


# ---------------------------------------------------------------------------
# Общие модели: конфиг, статика, поддержка, аудит
# ---------------------------------------------------------------------------


class AppConfigFactory(DjangoModelFactory):
    """Синглтон: любая запись уходит в pk=1."""

    class Meta:
        model = AppConfigModel
        django_get_or_create = ("pk",)

    pk = AppConfigModel.SINGLETON_ID
    min_supported_version = "1.0.0"
    recommended_version = "1.0.0"


class OnboardingSlideFactory(DjangoModelFactory):
    class Meta:
        model = OnboardingSlide

    title = factory.Sequence(lambda n: f"Слайд {n}")
    text = "Текст слайда"
    order = factory.Sequence(lambda n: n)
    is_active = True


class StaticPageFactory(DjangoModelFactory):
    class Meta:
        model = StaticPage
        django_get_or_create = ("slug",)

    slug = StaticPage.Slug.TERMS
    title = "Пользовательское соглашение"
    content = "# Соглашение"
    version = "1"


class SupportTicketFactory(DjangoModelFactory):
    class Meta:
        model = SupportTicket

    user = factory.SubFactory(UserFactory)
    subject = factory.Sequence(lambda n: f"Обращение {n}")
    message = "Не работает кнопка"
    platform = SupportTicket.Platform.ANDROID


class AuditLogFactory(DjangoModelFactory):
    class Meta:
        model = AuditLog

    actor = factory.SubFactory(UserFactory)
    target_user = factory.SubFactory(UserFactory)
    action = AuditLog.Action.KYC_URL_ISSUED
    extra = factory.Dict({})
