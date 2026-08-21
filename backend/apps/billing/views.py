"""Эндпоинты кошелька."""

from typing import Any

from django.db.models import QuerySet
from django_filters import rest_framework as filters
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import status
from rest_framework.generics import ListAPIView, RetrieveAPIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response

from apps.billing.models import Wallet, WalletTransaction
from apps.billing.serializers import (
    WalletHistorySerializer,
    WalletSerializer,
    WalletTransactionSerializer,
)
from apps.billing.services import get_wallet
from apps.common.dates import date_label, local_day, today_local
from apps.common.enums import WalletEntryKind
from apps.common.pagination import DefaultCursorPagination
from apps.common.serializers import ErrorSerializer


class WalletView(RetrieveAPIView):
    """GET /api/v1/wallet/ — баланс пользователя."""

    permission_classes = [IsAuthenticated]
    serializer_class = WalletSerializer

    def get_object(self) -> Wallet:
        return get_wallet(self.request.user)

    @extend_schema(
        operation_id="wallet_retrieve",
        summary="Баланс кошелька",
        responses={
            status.HTTP_200_OK: WalletSerializer,
            status.HTTP_401_UNAUTHORIZED: ErrorSerializer,
        },
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().get(request, *args, **kwargs)


class WalletTransactionFilterSet(filters.FilterSet):
    """Вкладки экрана истории: пополнение, списание, бонусы."""

    kind = filters.ChoiceFilter(choices=WalletEntryKind.choices)

    class Meta:
        model = WalletTransaction
        fields = ["kind"]


class WalletHistoryPagination(DefaultCursorPagination):
    """Курсор по времени операции."""

    ordering = ("-created_at",)


class WalletTransactionListView(ListAPIView):
    """GET /api/v1/wallet/transactions/ — история пополнений и трат."""

    permission_classes = [IsAuthenticated]
    serializer_class = WalletTransactionSerializer
    pagination_class = WalletHistoryPagination
    filterset_class = WalletTransactionFilterSet
    queryset = WalletTransaction.objects.none()  # для генератора схемы

    def get_queryset(self) -> QuerySet[WalletTransaction]:
        if not self.request.user.is_authenticated:  # pragma: no cover - генерация схемы
            return WalletTransaction.objects.none()
        return WalletTransaction.objects.filter(wallet__user=self.request.user)

    @extend_schema(
        operation_id="wallet_transactions",
        summary="История пополнений и трат",
        description=(
            "Операции сгруппированы по дням в таймзоне Asia/Bishkek. Без параметра "
            "`kind` — вкладка «Все операции»."
        ),
        parameters=[
            OpenApiParameter("kind", str, description="topup | spend | bonus"),
        ],
        responses={
            status.HTTP_200_OK: WalletHistorySerializer,
            status.HTTP_401_UNAUTHORIZED: ErrorSerializer,
        },
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        queryset = self.filter_queryset(self.get_queryset())
        page = self.paginate_queryset(queryset)
        operations = page if page is not None else list(queryset)

        response = self.get_paginated_response(self._group_by_day(operations))
        return response

    def _group_by_day(self, operations: list[WalletTransaction]) -> list[dict[str, Any]]:
        """Группировка одним проходом по уже отсортированной странице."""
        today = today_local()
        groups: list[dict[str, Any]] = []

        for operation in operations:
            day = local_day(operation.created_at)
            if not groups or groups[-1]["_day"] != day:
                groups.append({"_day": day, "day_label": date_label(day, today), "items": []})
            groups[-1]["items"].append(operation)

        serializer_context = self.get_serializer_context()
        return [
            {
                "day_label": group["day_label"],
                "items": WalletTransactionSerializer(
                    group["items"], many=True, context=serializer_context
                ).data,
            }
            for group in groups
        ]
