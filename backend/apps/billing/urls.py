"""URL-маршруты кошелька."""

from django.urls import path

from apps.billing.views import WalletTransactionListView, WalletView

app_name = "billing"

urlpatterns = [
    path("wallet/", WalletView.as_view(), name="wallet"),
    path(
        "wallet/transactions/",
        WalletTransactionListView.as_view(),
        name="wallet-transactions",
    ),
]
