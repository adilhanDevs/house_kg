"""Эндпоинты кошелька и пополнения."""

import logging
from decimal import Decimal
from typing import Any

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.db.models import QuerySet
from django.shortcuts import get_object_or_404
from django_filters import rest_framework as filters
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import status
from rest_framework.exceptions import NotFound, PermissionDenied
from rest_framework.generics import GenericAPIView, ListAPIView, RetrieveAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.billing.models import (
    Payment,
    PaymentLogDirection,
    PaymentProviderConfig,
    PaymentStatus,
    Promotion,
    Tariff,
    Wallet,
    WalletTransaction,
)
from apps.billing.payments import (
    create_topup,
    credit_payment,
    log_payment,
    payment_intent,
    process_webhook_result,
)
from apps.billing.promotions import build_pricing, listing_promotions, promote_listing
from apps.billing.providers import WebhookSignatureError, get_payment_provider
from apps.billing.serializers import (
    ListingStatsSerializer,
    PaymentStatusSerializer,
    PromoteRequestSerializer,
    PromoteResponseSerializer,
    PromotionPricingSerializer,
    PromotionSerializer,
    SubscribeRequestSerializer,
    SubscriptionSerializer,
    SubscriptionStateSerializer,
    TariffSerializer,
    TopupRequestSerializer,
    TopupResponseSerializer,
    WalletHistorySerializer,
    WalletSerializer,
    WalletTransactionSerializer,
)
from apps.billing.services import get_wallet
from apps.billing.subscriptions import (
    FREE_TARIFF_CODE,
    cancel_subscription,
    current_subscription,
    subscribe,
    subscription_state,
)
from apps.common.dates import date_label, local_day, today_local
from apps.common.enums import WalletEntryKind
from apps.common.exceptions import ApiValidationError
from apps.common.pagination import DefaultCursorPagination
from apps.common.serializers import ErrorSerializer
from apps.common.throttling import TopupThrottle

logger = logging.getLogger(__name__)

# Обязательный заголовок для операций, меняющих баланс.
IDEMPOTENCY_HEADER = "Idempotency-Key"
IDEMPOTENCY_KEY_MAX_LENGTH = 64

# Границы срока продвижения и глубины статистики.
MAX_PROMOTION_DAYS = 90
STATS_DEFAULT_DAYS = 30
STATS_MAX_DAYS = 365


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


class TopupView(GenericAPIView):
    """POST /api/v1/wallet/topup/ — счёт на пополнение кошелька."""

    permission_classes = [IsAuthenticated]
    serializer_class = TopupRequestSerializer
    # Десять счетов в час: больше — это перебор карт, а не пополнение.
    throttle_classes = [TopupThrottle]

    @extend_schema(
        operation_id="wallet_topup",
        summary="Пополнить кошелёк",
        description=(
            "Создаёт счёт и возвращает ссылку на оплату с QR-кодом.\n\n"
            "Заголовок `Idempotency-Key` обязателен: повторный запрос с тем же "
            "ключом в течение суток возвращает тот же счёт, а не создаёт второй."
        ),
        parameters=[
            OpenApiParameter(
                "Idempotency-Key",
                str,
                location=OpenApiParameter.HEADER,
                required=True,
                description="Уникальный ключ операции, до 64 символов.",
            )
        ],
        responses={
            status.HTTP_201_CREATED: TopupResponseSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
        },
    )
    def post(self, request: Request) -> Response:
        idempotency_key = (request.headers.get(IDEMPOTENCY_HEADER) or "").strip()
        if not idempotency_key:
            raise ApiValidationError(
                f"Заголовок {IDEMPOTENCY_HEADER} обязателен для операций с балансом."
            )
        if len(idempotency_key) > IDEMPOTENCY_KEY_MAX_LENGTH:
            raise ApiValidationError(
                f"Заголовок {IDEMPOTENCY_HEADER} длиннее {IDEMPOTENCY_KEY_MAX_LENGTH} символов."
            )

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        payment = create_topup(
            user=request.user,
            amount_kgs=Decimal(serializer.validated_data["amount_kgs"]),
            provider_code=serializer.validated_data.get("provider") or settings.PAYMENT_PROVIDER,
            idempotency_key=idempotency_key,
            return_url=request.query_params.get("return_url", ""),
        )

        return Response(
            build_topup_response(payment, request),
            status=status.HTTP_201_CREATED,
        )


class PaymentStatusView(APIView):
    """GET /api/v1/wallet/topup/{payment_id}/ — поллинг статуса."""

    permission_classes = [IsAuthenticated]

    @extend_schema(
        operation_id="wallet_topup_status",
        summary="Статус пополнения",
        responses={
            status.HTTP_200_OK: PaymentStatusSerializer,
            status.HTTP_404_NOT_FOUND: ErrorSerializer,
        },
    )
    def get(self, request: Request, payment_id: str) -> Response:
        payment = get_object_or_404(Payment, pk=payment_id, user=request.user)

        # Если платёж ожидает оплаты и не истёк — сверяем статус с провайдером
        if payment.status == PaymentStatus.PENDING and not payment.is_expired:
            try:
                provider = get_payment_provider(payment.provider)
                reconcile_result = (
                    provider.reconcile_payment(payment)
                    if hasattr(provider, "reconcile_payment")
                    else None
                )
                if reconcile_result and reconcile_result.status == "succeeded":
                    process_webhook_result(
                        payment.provider, reconcile_result, f"reconcile:{payment.provider}"
                    )
                    payment.refresh_from_db()
            except Exception as e:
                logger.warning("Ошибка авто-сверки статуса платежа %s: %s", payment_id, e)

        wallet = get_wallet(request.user)

        credited = payment.total_bricks if payment.status == PaymentStatus.SUCCEEDED else 0
        return Response(
            {
                "status": payment.status,
                "balance": wallet.balance,
                "credited_bricks": credited,
            }
        )


class PaymentWebhookView(APIView):
    """POST /api/v1/webhooks/payments/{provider}/ — уведомление провайдера."""

    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(
        operation_id="payments_webhook",
        summary="Вебхук платёжного провайдера",
        description=(
            "Подпись обязательна. Повторный вебхук по уже оплаченному счёту "
            "возвращает 200 и ничего не начисляет."
        ),
        request=None,
        responses={
            status.HTTP_200_OK: None,
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
            status.HTTP_404_NOT_FOUND: ErrorSerializer,
        },
        auth=[],
    )
    def post(self, request: Request, provider: str) -> Response:
        endpoint = f"webhook:{provider}"

        try:
            payment_provider = get_payment_provider(provider)
        except ImproperlyConfigured as exc:
            raise NotFound("Неизвестный платёжный провайдер.") from exc

        try:
            result = payment_provider.verify_webhook(request)
        except WebhookSignatureError:
            # Тело всё равно пишем в журнал — по нему разбирают инциденты.
            log_payment(
                payment=None,
                direction=PaymentLogDirection.IN,
                endpoint=endpoint,
                payload=getattr(request, "data", {}),
                status_code=403,
            )
            logger.warning("Вебхук %s отклонён: подпись не совпала", provider)
            raise PermissionDenied("Подпись вебхука не совпала.") from None

        status_code, payload = process_webhook_result(provider, result, endpoint)
        return Response(payload, status=status_code)


class MockConfirmView(APIView):
    """POST /api/v1/wallet/topup/{payment_id}/mock-confirm/ — только для разработки."""

    permission_classes = [IsAuthenticated]

    @extend_schema(exclude=True)
    def post(self, request: Request, payment_id: str) -> Response:
        # Эндпоинт начисляет кирпичи без оплаты, поэтому доступен только там,
        # где платежей и нет: DEBUG плюс mock-провайдер. Одного DEBUG мало —
        # на боевом стенде его иногда оставляют включённым.
        if not settings.DEBUG or settings.PAYMENT_PROVIDER != "mock":
            raise NotFound()

        payment = get_object_or_404(Payment, pk=payment_id, user=request.user)
        if payment.status == PaymentStatus.PENDING and not payment.is_expired:
            credit_payment(payment)

        payment.refresh_from_db()
        return Response(
            {
                "status": payment.status,
                "balance": get_wallet(request.user).balance,
                "credited_bricks": payment.total_bricks
                if payment.status == PaymentStatus.SUCCEEDED
                else 0,
            }
        )


def build_topup_response(payment: Payment, request: Request) -> dict[str, Any]:
    """Ответ на создание счёта — тот же и при повторе с прежним ключом."""
    intent = payment_intent(payment)
    payment_url = intent.get("payment_url", "")

    providers = [
        {
            "code": config.code,
            "name": config.name,
            "logo_url": (request.build_absolute_uri(config.logo.url) if config.logo else None),
            "deeplink": config.build_deeplink(
                payment_url, payment.provider_ref or "", payment.amount_kgs
            ),
        }
        for config in PaymentProviderConfig.objects.filter(is_active=True)
    ]

    return {
        "payment_id": str(payment.pk),
        "amount_kgs": f"{payment.amount_kgs:.2f}",
        "bricks": payment.bricks,
        "bonus_bricks": payment.bonus_bricks,
        "total_bricks": payment.total_bricks,
        "payment_url": payment_url,
        # provider_ref у Finik — это и есть item_id созданного счёта.
        "provider_item_id": payment.provider_ref or "",
        "qr_code_url": intent.get("qr_code_url", ""),
        # Строка для отрисовки QR на клиенте. Если провайдер её не дал —
        # кодируем саму ссылку на оплату.
        "qr_data": intent.get("qr_data", "") or payment_url,
        "expires_at": payment.expires_at,
        "providers": providers,
    }


def require_idempotency_key(request: Request) -> str:
    """Ключ идемпотентности из заголовка. Без него операции с балансом нельзя."""
    key = (request.headers.get(IDEMPOTENCY_HEADER) or "").strip()

    if not key:
        raise ApiValidationError(
            f"Заголовок {IDEMPOTENCY_HEADER} обязателен для операций с балансом."
        )
    if len(key) > IDEMPOTENCY_KEY_MAX_LENGTH:
        raise ApiValidationError(
            f"Заголовок {IDEMPOTENCY_HEADER} длиннее {IDEMPOTENCY_KEY_MAX_LENGTH} символов."
        )
    return key


def owned_listing(request: Request, slug: str) -> Any:
    """Объявление текущего пользователя.

    Правила те же, что в каталоге: чужое опубликованное объявление даёт 403
    (владение не секрет), чужой черновик — 404, он отсекается queryset'ом.
    """
    from apps.catalog.views import owned_listing_queryset

    listing = get_object_or_404(owned_listing_queryset(request.user), slug=slug)
    if listing.owner_id != request.user.pk:
        raise PermissionDenied("Управлять объявлением может только его владелец.")
    return listing


class PromotionPricingView(APIView):
    """GET /api/v1/promotions/pricing/ — предрасчёт без списания."""

    permission_classes = [IsAuthenticated]

    @extend_schema(
        operation_id="promotions_pricing",
        summary="Стоимость продвижения",
        description=(
            "Считает цену для экрана продвижения и отдаёт справочники пакетов "
            "и опций — экран рисует их из этого ответа. Ничего не списывает."
        ),
        parameters=[
            OpenApiParameter("days", int, description="Количество дней, по умолчанию 1."),
            OpenApiParameter("options", str, description="Коды опций через запятую."),
            OpenApiParameter("listing", str, description="Слаг объявления для продления."),
        ],
        responses={
            status.HTTP_200_OK: PromotionPricingSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
        },
    )
    def get(self, request: Request) -> Response:
        raw_days = request.query_params.get("days", "1")
        try:
            days = int(raw_days)
        except (TypeError, ValueError):
            raise ApiValidationError(
                "Параметр days должен быть числом.", {"days": raw_days}
            ) from None

        if not 1 <= days <= MAX_PROMOTION_DAYS:
            raise ApiValidationError(
                f"Продвижение покупается на срок от 1 до {MAX_PROMOTION_DAYS} дней.",
                {"days": days},
            )

        option_codes = [
            code.strip()
            for code in (request.query_params.get("options") or "").split(",")
            if code.strip()
        ]

        listing = None
        slug = request.query_params.get("listing")
        if slug:
            # Продление считается от остатка, поэтому объявление нужно знать.
            listing = owned_listing(request, slug)

        pricing = build_pricing(request.user, days, option_codes, listing)
        return Response(PromotionPricingSerializer(pricing).data)


class ListingPromoteView(APIView):
    """POST /api/v1/listings/{slug}/promote/ — покупка продвижения."""

    permission_classes = [IsAuthenticated]

    @extend_schema(
        operation_id="listings_promote",
        summary="Продвинуть объявление",
        description=(
            "Списывает кирпичи и поднимает объявление в выдаче. Продление "
            "складывается с остатком, а не заменяет его.\n\n"
            "Заголовок `Idempotency-Key` обязателен: повторный запрос с тем же "
            "ключом возвращает уже купленное продвижение и не списывает дважды."
        ),
        parameters=[
            OpenApiParameter(
                "Idempotency-Key",
                str,
                location=OpenApiParameter.HEADER,
                required=True,
                description="Уникальный ключ операции, до 64 символов.",
            )
        ],
        request=PromoteRequestSerializer,
        responses={
            status.HTTP_201_CREATED: PromoteResponseSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_402_PAYMENT_REQUIRED: ErrorSerializer,
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
        },
    )
    def post(self, request: Request, slug: str) -> Response:
        idempotency_key = require_idempotency_key(request)
        listing = owned_listing(request, slug)

        form = PromoteRequestSerializer(data=request.data)
        form.is_valid(raise_exception=True)

        promotion = promote_listing(
            listing,
            days=form.validated_data["days"],
            package_code=form.validated_data.get("package") or None,
            option_codes=form.validated_data.get("options") or [],
            idempotency_key=idempotency_key,
        )

        listing.refresh_from_db(fields=["promoted_until"])
        # Через сериализатор, а не сырым словарём: иначе даты этого ответа
        # рендерились бы иначе, чем в предрасчёте.
        payload = PromoteResponseSerializer(
            {
                "promotion_id": promotion.pk,
                "cost_bricks": promotion.cost_bricks,
                "promoted_until": listing.promoted_until,
                "balance_after": get_wallet(request.user).balance,
            }
        ).data
        return Response(payload, status=status.HTTP_201_CREATED)


class ListingPromotionsView(ListAPIView):
    """GET /api/v1/listings/{slug}/promotions/ — история продвижений."""

    permission_classes = [IsAuthenticated]
    serializer_class = PromotionSerializer
    pagination_class = DefaultCursorPagination
    queryset = Promotion.objects.none()  # для генератора схемы

    def get_queryset(self) -> QuerySet[Promotion]:
        if not self.request.user.is_authenticated:  # pragma: no cover - генерация схемы
            return Promotion.objects.none()
        return listing_promotions(owned_listing(self.request, self.kwargs["slug"]))

    @extend_schema(
        operation_id="listings_promotions",
        summary="История продвижений объявления",
        responses={
            status.HTTP_200_OK: PromotionSerializer(many=True),
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
        },
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().get(request, *args, **kwargs)


class ListingStatsView(APIView):
    """GET /api/v1/listings/{slug}/stats/ — показатели объявления по дням."""

    permission_classes = [IsAuthenticated]

    @extend_schema(
        operation_id="listings_stats",
        summary="Статистика объявления",
        description=(
            "Показы, открытия карточки, добавления в избранное и показы "
            "телефона по дням за последние 30 суток. Если объявление "
            "продвигалось, добавляется сравнение средних до и во время."
        ),
        parameters=[OpenApiParameter("days", int, description="Глубина, по умолчанию 30.")],
        responses={
            status.HTTP_200_OK: ListingStatsSerializer,
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
        },
    )
    def get(self, request: Request, slug: str) -> Response:
        from apps.catalog.stats import daily_stats, promotion_effect, totals

        listing = owned_listing(request, slug)

        try:
            days = int(request.query_params.get("days", STATS_DEFAULT_DAYS))
        except (TypeError, ValueError):
            days = STATS_DEFAULT_DAYS
        days = max(1, min(days, STATS_MAX_DAYS))

        series = daily_stats(listing, days)
        return Response(
            ListingStatsSerializer(
                {
                    "days": days,
                    "series": series,
                    "totals": totals(series),
                    "promotion_effect": promotion_effect(listing, days),
                }
            ).data
        )


class TariffListView(ListAPIView):
    """GET /api/v1/tariffs/ — витрина тарифов."""

    permission_classes = [AllowAny]
    serializer_class = TariffSerializer
    pagination_class = None
    queryset = Tariff.objects.filter(is_active=True)

    def get_serializer_context(self) -> dict[str, Any]:
        """Текущий тариф резолвится один раз, а не на каждую карточку."""
        context = super().get_serializer_context()
        subscription = current_subscription(self.request.user)
        context["current_tariff_code"] = (
            subscription.tariff.code if subscription else FREE_TARIFF_CODE
        )
        return context

    @extend_schema(
        operation_id="tariffs_list",
        summary="Тарифы",
        description=(
            "Активные тарифы с возможностями и ценами. У тарифа текущего "
            "пользователя `is_current = true`; для анонима и пользователя без "
            "подписки это бесплатный тариф."
        ),
        responses={status.HTTP_200_OK: TariffSerializer(many=True)},
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        subscription = current_subscription(request.user)
        current_code = subscription.tariff.code if subscription else "owner"
        code_alias = {"free": "owner", "realtor": "top", "agency": "premium"}
        current_code = code_alias.get(current_code, current_code)

        tariffs_data = [
            {
                "code": "owner",
                "name": "Собственник",
                "price_som": 0,
                "price_bricks": None,
                "price_bricks_per_month": 0,
                "listings_limit": 5,
                "is_current": current_code in ("owner", "free"),
            },
            {
                "code": "top",
                "name": "TOP",
                "price_som": 1,
                "price_bricks": 1,
                "price_bricks_per_month": 1,
                "listings_limit": 15,
                "is_current": current_code in ("top", "realtor"),
            },
            {
                "code": "vip",
                "name": "VIP",
                "price_som": 1,
                "price_bricks": 1,
                "price_bricks_per_month": 1,
                "listings_limit": 20,
                "is_current": current_code == "vip",
            },
            {
                "code": "premium",
                "name": "Premium",
                "price_som": 1,
                "price_bricks": 1,
                "price_bricks_per_month": 1,
                "listings_limit": 20,
                "is_current": current_code in ("premium", "agency"),
            },
        ]
        return Response(tariffs_data, status=status.HTTP_200_OK)


class SubscriptionCreateView(APIView):
    """POST /api/v1/subscriptions/ — покупка или продление подписки."""

    permission_classes = [IsAuthenticated]

    @extend_schema(
        operation_id="subscriptions_create",
        summary="Оформить подписку",
        description=(
            "Продление того же тарифа складывает сроки. Переход на более "
            "дорогой тариф действует сразу, остаток прежнего периода "
            "засчитывается в счёт новой цены. Переход на более дешёвый "
            "вступает в силу после окончания оплаченного периода.\n\n"
            "Заголовок `Idempotency-Key` обязателен."
        ),
        parameters=[
            OpenApiParameter(
                "Idempotency-Key",
                str,
                location=OpenApiParameter.HEADER,
                required=True,
                description="Уникальный ключ операции, до 64 символов.",
            )
        ],
        request=SubscribeRequestSerializer,
        responses={
            status.HTTP_201_CREATED: SubscriptionSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_402_PAYMENT_REQUIRED: ErrorSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
        },
    )
    def post(self, request: Request) -> Response:
        idempotency_key = require_idempotency_key(request)

        form = SubscribeRequestSerializer(data=request.data)
        form.is_valid(raise_exception=True)

        subscription = subscribe(
            request.user,
            tariff_code=form.validated_data["tariff_code"],
            months=form.validated_data["months"],
            idempotency_key=idempotency_key,
        )
        return Response(
            SubscriptionSerializer(subscription).data,
            status=status.HTTP_201_CREATED,
        )


class CurrentSubscriptionView(APIView):
    """GET /api/v1/subscriptions/current/ — состояние подписки."""

    permission_classes = [IsAuthenticated]

    @extend_schema(
        operation_id="subscriptions_current",
        summary="Текущая подписка",
        description=(
            "Тариф, срок и остаток свободных слотов объявлений. "
            "`listings_free = null` означает тариф без ограничений."
        ),
        responses={status.HTTP_200_OK: SubscriptionStateSerializer},
    )
    def get(self, request: Request) -> Response:
        return Response(SubscriptionStateSerializer(subscription_state(request.user)).data)


class CancelSubscriptionView(APIView):
    """POST /api/v1/subscriptions/cancel/ — отключение автопродления."""

    permission_classes = [IsAuthenticated]

    @extend_schema(
        operation_id="subscriptions_cancel",
        summary="Отменить подписку",
        description=(
            "Отключает автопродление. Подписка продолжает действовать до конца "
            "оплаченного периода — оплаченное не отбирается; статус станет "
            "`cancelled` только по истечении."
        ),
        request=None,
        responses={
            status.HTTP_200_OK: SubscriptionSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
        },
    )
    def post(self, request: Request) -> Response:
        return Response(SubscriptionSerializer(cancel_subscription(request.user)).data)
