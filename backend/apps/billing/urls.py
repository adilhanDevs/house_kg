"""URL-маршруты кошелька."""

from django.urls import path

from apps.billing.views import (
    CancelSubscriptionView,
    CurrentSubscriptionView,
    ListingPromoteView,
    ListingPromotionsView,
    ListingStatsView,
    MockConfirmView,
    PaymentStatusView,
    PaymentWebhookView,
    PromotionPricingView,
    SubscriptionCreateView,
    TariffListView,
    TopupView,
    WalletTransactionListView,
    WalletView,
)

app_name = "billing"

urlpatterns = [
    path("wallet/", WalletView.as_view(), name="wallet"),
    path(
        "wallet/transactions/",
        WalletTransactionListView.as_view(),
        name="wallet-transactions",
    ),
    path("wallet/topup/", TopupView.as_view(), name="wallet-topup"),
    path(
        "wallet/topup/<uuid:payment_id>/",
        PaymentStatusView.as_view(),
        name="wallet-topup-status",
    ),
    path(
        "wallet/topup/<uuid:payment_id>/mock-confirm/",
        MockConfirmView.as_view(),
        name="wallet-topup-mock-confirm",
    ),
    path(
        "webhooks/payments/<slug:provider>/",
        PaymentWebhookView.as_view(),
        name="payments-webhook",
    ),
    # Продвижение объявлений.
    path("promotions/pricing/", PromotionPricingView.as_view(), name="promotions-pricing"),
    path(
        "listings/<slug:slug>/promote/",
        ListingPromoteView.as_view(),
        name="listing-promote",
    ),
    path(
        "listings/<slug:slug>/promotions/",
        ListingPromotionsView.as_view(),
        name="listing-promotions",
    ),
    path("listings/<slug:slug>/stats/", ListingStatsView.as_view(), name="listing-stats"),
    # Тарифы и подписки. current/cancel объявлены до корневого пути, чтобы
    # порядок чтения совпадал с порядком в схеме.
    path("tariffs/", TariffListView.as_view(), name="tariffs"),
    path(
        "subscriptions/current/",
        CurrentSubscriptionView.as_view(),
        name="subscription-current",
    ),
    path(
        "subscriptions/cancel/",
        CancelSubscriptionView.as_view(),
        name="subscription-cancel",
    ),
    path("subscriptions/", SubscriptionCreateView.as_view(), name="subscriptions"),
]
