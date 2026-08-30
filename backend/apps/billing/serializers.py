"""Сериализаторы кошелька и продвижения."""

from django.conf import settings
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.billing.models import (
    Promotion,
    PromotionOption,
    PromotionPackage,
    Subscription,
    Tariff,
    Wallet,
    WalletTransaction,
    format_bricks,
)

BRICK_CURRENCY = "brick"


class WalletSerializer(serializers.ModelSerializer):
    """Баланс кошелька."""

    balance_display = serializers.CharField(read_only=True)
    currency = serializers.SerializerMethodField()

    class Meta:
        model = Wallet
        fields = ["balance", "balance_display", "currency"]
        read_only_fields = fields

    def get_currency(self, obj: Wallet) -> str:
        return BRICK_CURRENCY


class WalletTransactionSerializer(serializers.ModelSerializer):
    """Операция в истории пополнений и трат."""

    amount_display = serializers.CharField(read_only=True)

    class Meta:
        model = WalletTransaction
        fields = [
            "id",
            "amount",
            "amount_display",
            "kind",
            "label",
            "balance_after",
            "created_at",
        ]
        read_only_fields = fields


class WalletTransactionDaySerializer(serializers.Serializer):
    """Операции за один день."""

    day_label = serializers.CharField()
    items = WalletTransactionSerializer(many=True)


class WalletHistorySerializer(serializers.Serializer):
    """Страница истории операций."""

    results = WalletTransactionDaySerializer(many=True)
    next = serializers.URLField(allow_null=True)
    previous = serializers.URLField(allow_null=True)
    count = serializers.IntegerField()


class TopupRequestSerializer(serializers.Serializer):
    """Запрос на пополнение кошелька."""

    amount_kgs = serializers.IntegerField(
        min_value=settings.PAYMENT_MIN_AMOUNT,
        max_value=settings.PAYMENT_MAX_AMOUNT,
        help_text=(
            f"Целое число сомов от {settings.PAYMENT_MIN_AMOUNT} до {settings.PAYMENT_MAX_AMOUNT}."
        ),
    )
    provider = serializers.SlugField(max_length=32, required=False, default="")


class PaymentProviderSerializer(serializers.Serializer):
    """Банк на экране выбора способа оплаты."""

    code = serializers.CharField()
    name = serializers.CharField()
    logo_url = serializers.URLField(allow_null=True)
    deeplink = serializers.CharField(allow_blank=True)


class TopupResponseSerializer(serializers.Serializer):
    """Ответ на создание счёта."""

    payment_id = serializers.UUIDField()
    amount_kgs = serializers.CharField()
    bricks = serializers.IntegerField()
    bonus_bricks = serializers.IntegerField()
    total_bricks = serializers.IntegerField()
    payment_url = serializers.CharField(allow_blank=True)
    qr_code_url = serializers.CharField(allow_blank=True)
    expires_at = serializers.DateTimeField(allow_null=True)
    providers = PaymentProviderSerializer(many=True)


class PaymentStatusSerializer(serializers.Serializer):
    """Ответ поллинга статуса платежа."""

    status = serializers.CharField()
    balance = serializers.IntegerField()
    credited_bricks = serializers.IntegerField()


class PromotionPackageSerializer(serializers.ModelSerializer):
    class Meta:
        model = PromotionPackage
        fields = ["code", "name", "price_per_day_bricks", "description", "order"]
        read_only_fields = fields


class PromotionOptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = PromotionOption
        fields = ["code", "name", "price_per_day_bricks", "description", "order"]
        read_only_fields = fields


class PricingOptionSerializer(serializers.Serializer):
    """Опция в разложении цены — уже с посчитанной стоимостью за все дни."""

    code = serializers.CharField()
    name = serializers.CharField()
    price_per_day_bricks = serializers.IntegerField()
    cost = serializers.IntegerField()


class PromotionPricingSerializer(serializers.Serializer):
    """Предрасчёт стоимости для экрана продвижения."""

    days = serializers.IntegerField()
    package = serializers.CharField()
    base_cost = serializers.IntegerField()
    options = PricingOptionSerializer(many=True)
    options_cost = serializers.IntegerField()
    total_cost = serializers.IntegerField()
    balance = serializers.IntegerField()
    is_affordable = serializers.BooleanField()
    promoted_until_after = serializers.DateTimeField()
    packages = PromotionPackageSerializer(many=True)
    available_options = PromotionOptionSerializer(many=True)


class PromoteRequestSerializer(serializers.Serializer):
    """Тело запроса на покупку продвижения."""

    days = serializers.IntegerField(min_value=1, max_value=90)
    package = serializers.CharField(required=False, allow_blank=True, default="")
    options = serializers.ListField(
        child=serializers.CharField(max_length=32),
        required=False,
        default=list,
    )


class PromoteResponseSerializer(serializers.Serializer):
    promotion_id = serializers.IntegerField()
    cost_bricks = serializers.IntegerField()
    promoted_until = serializers.DateTimeField()
    balance_after = serializers.IntegerField()


class PromotionSerializer(serializers.ModelSerializer):
    """Продвижение в истории объявления."""

    package = PromotionPackageSerializer(read_only=True)
    cost_display = serializers.SerializerMethodField()
    is_running = serializers.BooleanField(read_only=True)

    class Meta:
        model = Promotion
        fields = [
            "id",
            "package",
            "days",
            "options",
            "cost_bricks",
            "cost_display",
            "starts_at",
            "ends_at",
            "status",
            "is_running",
            "created_at",
        ]
        read_only_fields = fields

    @extend_schema_field(serializers.CharField())
    def get_cost_display(self, obj: Promotion) -> str:
        return f"-{format_bricks(obj.cost_bricks)}"


class DailyStatSerializer(serializers.Serializer):
    date = serializers.DateField()
    impressions = serializers.IntegerField()
    views = serializers.IntegerField()
    favourites = serializers.IntegerField()
    phone_reveals = serializers.IntegerField()


class StatTotalsSerializer(serializers.Serializer):
    """Суммы за период — целые числа."""

    impressions = serializers.IntegerField()
    views = serializers.IntegerField()
    favourites = serializers.IntegerField()
    phone_reveals = serializers.IntegerField()


class StatAveragesSerializer(serializers.Serializer):
    """Средние за сутки — дробные."""

    impressions = serializers.FloatField()
    views = serializers.FloatField()
    favourites = serializers.FloatField()
    phone_reveals = serializers.FloatField()


class PromotionEffectSerializer(serializers.Serializer):
    """Средние за сутки до продвижения и во время него."""

    promoted_days = serializers.IntegerField()
    before = StatAveragesSerializer()
    during = StatAveragesSerializer()


class ListingStatsSerializer(serializers.Serializer):
    days = serializers.IntegerField()
    series = DailyStatSerializer(many=True)
    totals = StatTotalsSerializer()
    promotion_effect = PromotionEffectSerializer(allow_null=True)


class TariffSerializer(serializers.ModelSerializer):
    """Тариф на экране «Тарифы»."""

    is_current = serializers.SerializerMethodField()
    price_display = serializers.SerializerMethodField()

    class Meta:
        model = Tariff
        fields = [
            "code",
            "name",
            "description",
            "price_bricks_per_month",
            "price_display",
            "listings_limit",
            "features",
            "order",
            "is_current",
        ]
        read_only_fields = fields

    @extend_schema_field(serializers.CharField())
    def get_price_display(self, obj: Tariff) -> str:
        return "Бесплатно" if obj.is_free else format_bricks(obj.price_bricks_per_month)

    @extend_schema_field(serializers.BooleanField())
    def get_is_current(self, obj: Tariff) -> bool:
        """Текущий тариф берётся из контекста — один запрос на весь список."""
        return obj.code == self.context.get("current_tariff_code")


class SubscribeRequestSerializer(serializers.Serializer):
    tariff_code = serializers.CharField(max_length=32)
    months = serializers.IntegerField(min_value=1, max_value=12, default=1, required=False)
    payment_method = serializers.CharField(max_length=32, required=False, default="som")


class SubscriptionSerializer(serializers.ModelSerializer):
    tariff = TariffSerializer(read_only=True)
    is_current = serializers.BooleanField(read_only=True)
    days_left = serializers.IntegerField(read_only=True)

    class Meta:
        model = Subscription
        fields = [
            "id",
            "tariff",
            "starts_at",
            "ends_at",
            "days_left",
            "is_auto_renew",
            "status",
            "is_current",
            "created_at",
        ]
        read_only_fields = fields


class SubscriptionStateSerializer(serializers.Serializer):
    """Экран «Подписки»: тариф, срок и остаток свободных слотов."""

    subscription = SubscriptionSerializer(allow_null=True)
    tariff = TariffSerializer(allow_null=True)
    listings_limit = serializers.IntegerField()
    listings_used = serializers.IntegerField()
    # null означает «без ограничений»: у тарифа агентства слотов не считают.
    listings_free = serializers.IntegerField(allow_null=True)
    scheduled = SubscriptionSerializer(allow_null=True)
