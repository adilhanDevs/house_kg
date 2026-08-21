"""Эндпоинты справочников и опций фильтра. Всё только на чтение."""

from typing import Any

from django.apps import apps
from django.core.cache import cache
from django.db.models import Count, IntegerField, OuterRef, QuerySet, Subquery
from django.db.models.functions import Coalesce
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import status
from rest_framework.generics import GenericAPIView, ListAPIView, RetrieveAPIView
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.enums import ListingStatus
from apps.catalog.filters import ListingFilterSet
from apps.catalog.models import Builder, City, District, Listing
from apps.catalog.serializers import (
    BuilderSerializer,
    CitySerializer,
    DistrictSerializer,
    FeaturedSerializer,
    FilterOptionsSerializer,
    ListingCountSerializer,
    ListingDetailSerializer,
    ListingListSerializer,
    ListingViewResponseSerializer,
)
from apps.catalog.services import (
    FEATURED_CACHE_TTL,
    LISTINGS_COUNT_CACHE_TTL,
    build_featured,
    featured_cache_key,
    get_filter_options,
    listing_queryset,
    listings_count_cache_key,
    normalize_language,
    register_listing_view,
    similar_listings,
)
from apps.common.audit import client_ip
from apps.common.http import conditional_response
from apps.common.pagination import DefaultCursorPagination
from apps.common.serializers import ErrorSerializer

# Разрешённые значения ?ordering= — всё остальное игнорируем.
ALLOWED_LISTING_ORDERINGS = (
    "-published_at",
    "price",
    "-price",
    "-views_count",
    "area",
)
DEFAULT_LISTING_ORDERING = "-published_at"

# У /listings/ параметры фильтра описывает сам django-filter; у /listings/count/
# генератор схемы этого не делает (эндпоинт не списочный), поэтому собираем их
# из того же FilterSet — чтобы документация не разъезжалась.
LISTING_FILTER_PARAMETERS = [
    OpenApiParameter(name, str, description=str(filter_field.label or ""))
    for name, filter_field in ListingFilterSet.base_filters.items()
]

CITY_PARAMETER = OpenApiParameter(
    "city",
    str,
    description="Слаг города; по умолчанию — город с флагом is_default.",
)


class DictionaryListView(ListAPIView):
    """Справочники короткие — отдаём их списком, без пагинации."""

    permission_classes = [AllowAny]
    authentication_classes: list = []
    pagination_class = None


class CityListView(DictionaryListView):
    """GET /api/v1/catalog/cities/"""

    serializer_class = CitySerializer
    queryset = City.objects.filter(is_active=True).order_by("order", "name")

    @extend_schema(
        operation_id="catalog_cities",
        summary="Города",
        responses={status.HTTP_200_OK: CitySerializer(many=True)},
        auth=[],
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().get(request, *args, **kwargs)


class DistrictListView(DictionaryListView):
    """GET /api/v1/catalog/districts/?city=<slug>"""

    serializer_class = DistrictSerializer

    def get_queryset(self) -> QuerySet[District]:
        districts = District.objects.filter(is_active=True).select_related("city")
        city_slug = self.request.query_params.get("city")
        if city_slug:
            districts = districts.filter(city__slug=city_slug)
        return districts.order_by("order", "name")

    @extend_schema(
        operation_id="catalog_districts",
        summary="Районы",
        parameters=[CITY_PARAMETER],
        responses={status.HTTP_200_OK: DistrictSerializer(many=True)},
        auth=[],
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().get(request, *args, **kwargs)


class BuilderListView(DictionaryListView):
    """GET /api/v1/catalog/builders/"""

    serializer_class = BuilderSerializer
    queryset = Builder.objects.filter(is_active=True).order_by("order", "name")

    @extend_schema(
        operation_id="catalog_builders",
        summary="Застройщики",
        responses={status.HTTP_200_OK: BuilderSerializer(many=True)},
        auth=[],
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().get(request, *args, **kwargs)


class FilterOptionsView(APIView):
    """GET /api/v1/catalog/filter-options/?city=<slug>"""

    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(
        operation_id="catalog_filter_options",
        summary="Опции экрана фильтра",
        description=(
            "Типы недвижимости, продавцы, комнаты, диапазоны площади, серии домов, "
            "районы города и границы цены — одним ответом.\n\n"
            "Значения `property_kinds` и `seller_kinds` совпадают с enum'ами Flutter. "
            "Ответ кэшируется на 10 минут с учётом города и `Accept-Language`; "
            "поддерживается ETag и 304."
        ),
        parameters=[CITY_PARAMETER],
        responses={
            status.HTTP_200_OK: FilterOptionsSerializer,
            status.HTTP_304_NOT_MODIFIED: None,
        },
        auth=[],
    )
    def get(self, request: Request) -> Response:
        language = normalize_language(request.headers.get("Accept-Language"))
        payload = get_filter_options(request.query_params.get("city"), language)
        return conditional_response(request, payload)


class ListingCursorPagination(DefaultCursorPagination):
    """Курсорная пагинация каталога: продвинутые объявления всегда сверху.

    Первое поле сортировки — флаг продвижения, а DRF строит позицию курсора
    именно по нему. У флага всего два значения, поэтому внутри блока
    «непродвинутых» курсор вырождается в offset. Это ограничение осознанное:
    лента мобильного каталога вглубь не листается, а `offset_cutoff` держит
    смещение в разумных пределах.
    """

    offset_cutoff = 1000

    def get_ordering(self, request: Request, queryset: QuerySet, view: Any) -> tuple[str, ...]:
        return ("-promoted_rank", view.get_ordering(request), "-id")


class ListingListView(ListAPIView):
    """GET /api/v1/listings/ — лента активных объявлений."""

    permission_classes = [AllowAny]
    serializer_class = ListingListSerializer
    pagination_class = ListingCursorPagination
    filterset_class = ListingFilterSet

    def get_ordering(self, request: Request) -> str:
        requested = request.query_params.get("ordering")
        if requested in ALLOWED_LISTING_ORDERINGS:
            return requested
        # При поиске без явной сортировки выше идут более релевантные совпадения.
        if request.query_params.get("search", "").strip():
            return "-search_rank"
        return DEFAULT_LISTING_ORDERING

    def get_queryset(self) -> QuerySet[Listing]:
        return listing_queryset(self.request.user)

    @extend_schema(
        operation_id="listings_list",
        summary="Каталог объявлений",
        description=(
            "Только опубликованные объявления. Продвинутые (`promoted_until` в будущем) "
            "всегда идут выше остальных, независимо от сортировки.\n\n"
            "`is_favourite` заполняется для авторизованного пользователя, для анонима "
            "всегда `false`."
        ),
        parameters=[
            OpenApiParameter(
                "ordering",
                str,
                description=f"Одно из: {', '.join(ALLOWED_LISTING_ORDERINGS)}.",
            ),
            OpenApiParameter("page_size", int, description="Размер страницы, максимум 100."),
        ],
        responses={status.HTTP_200_OK: ListingListSerializer(many=True)},
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().get(request, *args, **kwargs)


class ListingCountView(GenericAPIView):
    """GET /api/v1/listings/count/ — сколько объектов под фильтром."""

    permission_classes = [AllowAny]
    filterset_class = ListingFilterSet
    serializer_class = ListingCountSerializer
    # Лёгкая база: считать нужно строки, а не собирать карточки.
    queryset = Listing.objects.filter(status=ListingStatus.ACTIVE)

    @extend_schema(
        operation_id="listings_count",
        summary="Количество объявлений под фильтром",
        parameters=LISTING_FILTER_PARAMETERS,
        description=(
            "Принимает те же параметры, что и `/listings/`. Ничего не сериализует — "
            "только `COUNT(*)` для кнопки «Показать N объектов». Результат кэшируется "
            "на 60 секунд по нормализованной строке параметров."
        ),
        responses={status.HTTP_200_OK: ListingCountSerializer},
    )
    def get(self, request: Request) -> Response:
        key = listings_count_cache_key(request.query_params)

        count = cache.get(key)
        if count is None:
            count = self.filter_queryset(self.get_queryset()).count()
            cache.set(key, count, LISTINGS_COUNT_CACHE_TTL)

        return Response({"count": count})


class ListingDetailView(RetrieveAPIView):
    """GET /api/v1/listings/{slug}/ — карточка объекта."""

    permission_classes = [AllowAny]
    serializer_class = ListingDetailSerializer
    lookup_field = "slug"

    def get_queryset(self) -> QuerySet[Listing]:
        owner_listings = (
            Listing.objects.filter(owner_id=OuterRef("owner_id"), status=ListingStatus.ACTIVE)
            .order_by()
            .values("owner_id")
            .annotate(total=Count("pk"))
            .values("total")
        )
        return (
            listing_queryset(self.request.user)
            .prefetch_related("media")
            .annotate(
                seller_listings_count=Coalesce(
                    Subquery(owner_listings, output_field=IntegerField()), 0
                )
            )
        )

    @extend_schema(
        operation_id="listings_retrieve",
        summary="Карточка объявления",
        description=(
            "Телефон продавца отдаётся полностью только авторизованным; анониму "
            "приходит маска вида `+996 7XX XXX XX6`."
        ),
        responses={
            status.HTTP_200_OK: ListingDetailSerializer,
            status.HTTP_404_NOT_FOUND: ErrorSerializer,
        },
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().get(request, *args, **kwargs)


class ListingViewCounterView(APIView):
    """POST /api/v1/listings/{slug}/view/ — отметка просмотра."""

    permission_classes = [AllowAny]

    @extend_schema(
        operation_id="listings_register_view",
        summary="Отметить просмотр объявления",
        description=(
            "Инкрементит счётчик просмотров и обновляет историю просмотров "
            "авторизованного пользователя.\n\n"
            "Повторный вызов в течение 30 минут с того же аккаунта или IP счётчик "
            "не меняет — окно дедупликации живёт в Redis."
        ),
        request=None,
        responses={
            status.HTTP_200_OK: ListingViewResponseSerializer,
            status.HTTP_404_NOT_FOUND: ErrorSerializer,
        },
    )
    def post(self, request: Request, slug: str) -> Response:
        listing = get_object_or_404(Listing, slug=slug, status=ListingStatus.ACTIVE)
        actor = request.user.pk if request.user.is_authenticated else client_ip(request)

        views_count = register_listing_view(listing, request.user, str(actor))
        return Response({"views_count": views_count})


class FeaturedListingsView(APIView):
    """GET /api/v1/listings/featured/ — подборки главного экрана."""

    permission_classes = [AllowAny]

    @extend_schema(
        operation_id="listings_featured",
        summary="Подборки для главного экрана",
        description=(
            "По четыре самых свежих объявления каждого типа, продвинутые впереди. "
            "Кэшируется на 5 минут; `is_favourite` подставляется под текущего пользователя."
        ),
        responses={status.HTTP_200_OK: FeaturedSerializer},
    )
    def get(self, request: Request) -> Response:
        key = featured_cache_key(request.get_host())

        payload = cache.get(key)
        if payload is None:
            # В кэше лежит вариант «для анонима»: избранное у каждого своё.
            featured = build_featured(user=None)
            payload = {
                kind: ListingListSerializer(items, many=True, context={"request": request}).data
                for kind, items in featured.items()
            }
            cache.set(key, payload, FEATURED_CACHE_TTL)

        return Response(self._with_favourites(payload, request))

    def _with_favourites(self, payload: dict[str, Any], request: Request) -> dict[str, Any]:
        """Проставляет is_favourite одним запросом на весь ответ."""
        user = request.user
        if not user.is_authenticated:
            return payload

        slugs = [card["slug"] for cards in payload.values() for card in cards]
        favourite_model = apps.get_model("engagement", "Favourite")
        favourites = set(
            favourite_model.objects.filter(user=user, listing__slug__in=slugs).values_list(
                "listing__slug", flat=True
            )
        )

        return {
            kind: [{**card, "is_favourite": card["slug"] in favourites} for card in cards]
            for kind, cards in payload.items()
        }


class SimilarListingsView(ListAPIView):
    """GET /api/v1/listings/{slug}/similar/ — похожие объекты."""

    permission_classes = [AllowAny]
    serializer_class = ListingListSerializer
    pagination_class = None
    queryset = Listing.objects.none()  # для генератора схемы

    def get_queryset(self) -> QuerySet[Listing]:
        slug = self.kwargs.get("slug")
        if slug is None:  # pragma: no cover - только при генерации схемы
            return Listing.objects.none()
        listing = get_object_or_404(Listing, slug=slug)
        return similar_listings(listing, self.request.user)

    @extend_schema(
        operation_id="listings_similar",
        summary="Похожие объявления",
        description=(
            "Шесть объектов того же района или типа с ценой в пределах ±25%. "
            "Сначала совпадения по району, затем по близости цены."
        ),
        responses={status.HTTP_200_OK: ListingListSerializer(many=True)},
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().get(request, *args, **kwargs)
