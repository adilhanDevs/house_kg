"""Сериализаторы кошелька."""

from rest_framework import serializers

from apps.billing.models import Wallet, WalletTransaction

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
