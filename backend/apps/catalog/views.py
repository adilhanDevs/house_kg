"""Эндпоинты справочников и опций фильтра. Всё только на чтение."""

from typing import Any

from django.apps import apps
from django.core.cache import cache
from django.db.models import (
    Case,
    Count,
    F,
    IntegerField,
    OuterRef,
    Prefetch,
    Q,
    QuerySet,
    Subquery,
    Value,
    When,
)
from django.db.models.functions import Coalesce
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import status
from rest_framework.generics import (
    GenericAPIView,
    ListAPIView,
    RetrieveUpdateDestroyAPIView,
)
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.enums import ListingStatus, ModerationStatus
from apps.catalog.filters import ListingFilterSet
from apps.catalog.models import (
    Builder,
    City,
    District,
    Listing,
    ListingMedia,
    ModerationTask,
    RejectReason,
)
from apps.catalog.moderation.services import (
    approve_task,
    assign_task,
    reject_task,
    rejection_history,
    report_listing,
)
from apps.catalog.permissions import IsListingOwner, IsModerator
from apps.catalog.serializers import (
    BuilderSerializer,
    CitySerializer,
    DistrictSerializer,
    FeaturedSerializer,
    FilterOptionsSerializer,
    ListingCountSerializer,
    ListingDetailSerializer,
    ListingDraftSerializer,
    ListingListSerializer,
    ListingMediaSerializer,
    ListingReportSerializer,
    ListingUpdateSerializer,
    ListingViewResponseSerializer,
    MediaReorderSerializer,
    MediaUploadResultSerializer,
    MediaUploadSerializer,
    ModerationRejectSerializer,
    ModerationTaskSerializer,
    MyListingSerializer,
    RejectReasonSerializer,
)
from apps.catalog.services import (
    FEATURED_CACHE_TTL,
    LISTINGS_COUNT_CACHE_TTL,
    archive_listing,
    build_featured,
    bump_listing,
    delete_listing_media,
    featured_cache_key,
    get_filter_options,
    get_or_create_draft,
    listing_queryset,
    listings_count_cache_key,
    mark_listing_sold,
    normalize_language,
    publish_listing,
    register_listing_view,
    reorder_listing_media,
    restore_listing,
    set_media_cover,
    similar_listings,
    soft_delete_listing,
    update_listing,
    upload_listing_media,
)
from apps.catalog.stats import buffer_impressions
from apps.common.audit import client_ip
from apps.common.http import conditional_response
from apps.common.pagination import DefaultCursorPagination
from apps.common.serializers import ErrorSerializer
from apps.common.throttling import MediaUploadThrottle

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
        return ("-promoted_rank", "-priority_rank", view.get_ordering(request), "-id")


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

    def paginate_queryset(self, queryset: QuerySet[Listing]) -> list[Any] | None:
        """Считает показы страницы одним махом.

        Двадцать карточек — двадцать событий; писать их по одному UPDATE
        нельзя, поэтому id уходят в буфер Redis, а в БД их переносит задача
        `catalog.flush_impressions` раз в пять минут.
        """
        page = super().paginate_queryset(queryset)
        if page:
            buffer_impressions([item.pk for item in page])
        return page

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


class ListingDetailView(RetrieveUpdateDestroyAPIView):
    """GET (публично) / PATCH / DELETE (владелец) /api/v1/listings/{slug}/."""

    permission_classes = [AllowAny]
    serializer_class = ListingDetailSerializer
    lookup_field = "slug"
    http_method_names = ["get", "patch", "delete", "head", "options"]

    def get_permissions(self) -> list:
        if self.request.method in ("PATCH", "DELETE"):
            return [IsAuthenticated(), IsListingOwner()]
        return [AllowAny()]

    def get_serializer_class(self) -> type:
        if self.request.method == "PATCH":
            return ListingUpdateSerializer
        return ListingDetailSerializer

    def get_queryset(self) -> QuerySet[Listing]:
        if self.request.method in ("PATCH", "DELETE"):
            return owned_listing_queryset(self.request.user)
        return self.public_queryset()

    def update(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        listing = self.get_object()
        serializer = self.get_serializer(listing, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)

        update_listing(listing, serializer.validated_data)
        return Response(self._detail_data(listing))

    def destroy(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        soft_delete_listing(self.get_object())
        return Response(status=status.HTTP_204_NO_CONTENT)

    def _detail_data(self, listing: Listing) -> dict[str, Any]:
        fresh = self.public_queryset(only_active=False).get(pk=listing.pk)
        return ListingDraftSerializer(fresh, context=self.get_serializer_context()).data

    def public_queryset(self, only_active: bool = True) -> QuerySet[Listing]:
        owner_listings = (
            Listing.objects.filter(owner_id=OuterRef("owner_id"), status=ListingStatus.ACTIVE)
            .order_by()
            .values("owner_id")
            .annotate(total=Count("pk"))
            .values("total")
        )
        return (
            listing_queryset(self.request.user, only_active=only_active)
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


def owned_listing_queryset(user: Any) -> QuerySet[Listing]:
    """Объявления, к которым у пользователя есть доступ на изменение.

    Чужие черновики не видны вовсе (404), чужие опубликованные — видны,
    но правки отсекает permission (403).
    """
    return Listing.objects.select_related("district", "city", "owner").exclude(
        Q(status=ListingStatus.DRAFT) & ~Q(owner_id=getattr(user, "pk", None))
    )


class ListingDraftView(APIView):
    """POST /api/v1/listings/draft/ — черновик объявления на сервере."""

    permission_classes = [IsAuthenticated]

    @extend_schema(
        operation_id="listings_draft",
        summary="Получить или создать черновик",
        description=(
            "Черновик хранится на сервере: заполненная форма не теряется при "
            "закрытии приложения. Повторный вызов возвращает тот же черновик."
        ),
        request=None,
        responses={status.HTTP_200_OK: ListingDraftSerializer},
    )
    def post(self, request: Request) -> Response:
        draft = get_or_create_draft(request.user)
        fresh = (
            listing_queryset(request.user, only_active=False)
            .prefetch_related("media")
            .get(pk=draft.pk)
        )
        return Response(ListingDraftSerializer(fresh, context={"request": request}).data)


class ListingOwnerActionView(APIView):
    """Общий предок действий владельца над объявлением."""

    permission_classes = [IsAuthenticated, IsListingOwner]

    def get_listing(self, slug: str) -> Listing:
        listing = get_object_or_404(owned_listing_queryset(self.request.user), slug=slug)
        self.check_object_permissions(self.request, listing)
        return listing

    def render(self, listing: Listing, request: Request) -> Response:
        fresh = (
            listing_queryset(request.user, only_active=False)
            .prefetch_related("media")
            .get(pk=listing.pk)
        )
        return Response(MyListingSerializer(fresh, context={"request": request}).data)


class ListingPublishView(ListingOwnerActionView):
    """POST /api/v1/listings/{slug}/publish/"""

    @extend_schema(
        operation_id="listings_publish",
        summary="Опубликовать объявление",
        description=(
            "Проверяет обязательные поля и лимит бесплатных объявлений. "
            "Обычный пользователь получает статус `pending` (модерация), "
            "доверенный — сразу `active`."
        ),
        request=None,
        responses={
            status.HTTP_200_OK: MyListingSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
        },
    )
    def post(self, request: Request, slug: str) -> Response:
        listing = publish_listing(self.get_listing(slug))
        return self.render(listing, request)


class ListingArchiveView(ListingOwnerActionView):
    """POST /api/v1/listings/{slug}/archive/"""

    @extend_schema(
        operation_id="listings_archive",
        summary="Убрать объявление в архив",
        request=None,
        responses={status.HTTP_200_OK: MyListingSerializer},
    )
    def post(self, request: Request, slug: str) -> Response:
        return self.render(archive_listing(self.get_listing(slug)), request)


class ListingRestoreView(ListingOwnerActionView):
    """POST /api/v1/listings/{slug}/restore/"""

    @extend_schema(
        operation_id="listings_restore",
        summary="Вернуть объявление из архива",
        description="Срок публикации продлевается; лимит бесплатных объявлений действует.",
        request=None,
        responses={
            status.HTTP_200_OK: MyListingSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
        },
    )
    def post(self, request: Request, slug: str) -> Response:
        return self.render(restore_listing(self.get_listing(slug)), request)


class ListingMarkSoldView(ListingOwnerActionView):
    """POST /api/v1/listings/{slug}/mark-sold/"""

    @extend_schema(
        operation_id="listings_mark_sold",
        summary="Отметить объект проданным",
        request=None,
        responses={status.HTTP_200_OK: MyListingSerializer},
    )
    def post(self, request: Request, slug: str) -> Response:
        return self.render(mark_listing_sold(self.get_listing(slug)), request)


class ListingBumpView(ListingOwnerActionView):
    """POST /api/v1/listings/{slug}/bump/"""

    @extend_schema(
        operation_id="listings_bump",
        summary="Поднять объявление в выдаче",
        description="Бесплатно не чаще раза в сутки; иначе 429 с `retry_after`.",
        request=None,
        responses={
            status.HTTP_200_OK: MyListingSerializer,
            status.HTTP_429_TOO_MANY_REQUESTS: ErrorSerializer,
        },
    )
    def post(self, request: Request, slug: str) -> Response:
        return self.render(bump_listing(self.get_listing(slug)), request)


class MyListingsView(ListAPIView):
    """GET /api/v1/users/me/listings/ — «Мои объявления»."""

    permission_classes = [IsAuthenticated]
    serializer_class = MyListingSerializer
    pagination_class = DefaultCursorPagination
    queryset = Listing.objects.none()  # для генератора схемы

    def get_queryset(self) -> QuerySet[Listing]:
        if not self.request.user.is_authenticated:  # pragma: no cover - генерация схемы
            return Listing.objects.none()

        queryset = listing_queryset(self.request.user, only_active=False).filter(
            owner=self.request.user
        )

        requested = self.request.query_params.get("status")
        if requested in ListingStatus.values:
            queryset = queryset.filter(status=requested)

        # Черновики и отклонённые — наверх: они ждут действий владельца.
        return queryset.annotate(
            needs_attention=Case(
                When(status__in=[ListingStatus.DRAFT, ListingStatus.REJECTED], then=Value(1)),
                default=Value(0),
                output_field=IntegerField(),
            )
        ).order_by("-needs_attention", F("published_at").desc(nulls_last=True), "-created_at")

    @extend_schema(
        operation_id="users_me_listings",
        summary="Мои объявления",
        parameters=[
            OpenApiParameter(
                "status",
                str,
                description="draft | pending | active | rejected | archived | sold",
            )
        ],
        responses={status.HTTP_200_OK: MyListingSerializer(many=True)},
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().get(request, *args, **kwargs)


class ListingMediaUploadView(ListingOwnerActionView):
    """POST /api/v1/listings/{slug}/media/ — пачка файлов из галереи."""

    parser_classes = [MultiPartParser, FormParser]
    # Лимит считает файлы, а не запросы: в одном запросе их до двадцати.
    throttle_classes = [MediaUploadThrottle]

    @extend_schema(
        operation_id="listings_media_upload",
        summary="Загрузить фото или видео",
        description=(
            "Принимает несколько файлов за раз (поле `files`). Тип файла "
            "определяется по содержимому. Если файлов больше, чем свободных "
            "слотов, принимается сколько влезает — ответ говорит, сколько "
            "принято и сколько отклонено."
        ),
        request=MediaUploadSerializer,
        responses={
            status.HTTP_201_CREATED: MediaUploadResultSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
        },
    )
    def post(self, request: Request, slug: str) -> Response:
        listing = self.get_listing(slug)

        form = MediaUploadSerializer(data=request.data)
        form.is_valid(raise_exception=True)

        result = upload_listing_media(
            listing,
            form.validated_data["files"],
            form.validated_data["kind"],
        )
        payload = MediaUploadResultSerializer(result, context={"request": request}).data
        return Response(payload, status=status.HTTP_201_CREATED)


class ListingMediaReorderView(ListingOwnerActionView):
    """PATCH /api/v1/listings/{slug}/media/reorder/"""

    @extend_schema(
        operation_id="listings_media_reorder",
        summary="Переставить файлы объявления",
        description=(
            "Тело — список id от первого файла к последнему. Список должен "
            "содержать все файлы объявления; id из другого объявления — 400."
        ),
        request=MediaReorderSerializer,
        responses={
            status.HTTP_200_OK: ListingMediaSerializer(many=True),
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
        },
    )
    def patch(self, request: Request, slug: str) -> Response:
        listing = self.get_listing(slug)

        form = MediaReorderSerializer(data=request.data)
        form.is_valid(raise_exception=True)

        items = reorder_listing_media(listing, form.validated_data["order"])
        return Response(ListingMediaSerializer(items, many=True, context={"request": request}).data)


class ListingMediaObjectView(ListingOwnerActionView):
    """Общий предок действий над одним файлом.

    Файл ищется внутри объявления: id из чужого объявления даёт 404, а не
    доступ к чужому файлу.
    """

    def get_media(self, listing: Listing, media_id: int) -> ListingMedia:
        return get_object_or_404(listing.media, pk=media_id)


class ListingMediaItemView(ListingMediaObjectView):
    """DELETE /api/v1/listings/{slug}/media/{id}/"""

    @extend_schema(
        operation_id="listings_media_delete",
        summary="Удалить файл объявления",
        description=(
            "Удаляет запись и файлы всех вариантов размеров. Если удалена "
            "обложка, обложкой становится первая оставшаяся фотография."
        ),
        responses={
            status.HTTP_204_NO_CONTENT: None,
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
            status.HTTP_404_NOT_FOUND: ErrorSerializer,
        },
    )
    def delete(self, request: Request, slug: str, media_id: int) -> Response:
        listing = self.get_listing(slug)
        delete_listing_media(listing, self.get_media(listing, media_id))
        return Response(status=status.HTTP_204_NO_CONTENT)


class ListingMediaCoverView(ListingMediaObjectView):
    """POST /api/v1/listings/{slug}/media/{id}/set-cover/"""

    @extend_schema(
        operation_id="listings_media_set_cover",
        summary="Сделать файл обложкой",
        description="Снимает флаг с прежней обложки и ставит на этот файл — в одной транзакции.",
        request=None,
        responses={
            status.HTTP_200_OK: ListingMediaSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_404_NOT_FOUND: ErrorSerializer,
        },
    )
    def post(self, request: Request, slug: str, media_id: int) -> Response:
        listing = self.get_listing(slug)
        media = set_media_cover(listing, self.get_media(listing, media_id))
        return Response(ListingMediaSerializer(media, context={"request": request}).data)


class ListingReportView(APIView):
    """POST /api/v1/listings/{slug}/report/ — жалоба на объявление."""

    permission_classes = [IsAuthenticated]

    @extend_schema(
        operation_id="listings_report",
        summary="Пожаловаться на объявление",
        description=(
            "Одна жалоба от пользователя на объявление. Когда неразрешённых "
            "жалоб набирается три, активное объявление автоматически уходит "
            "на модерацию."
        ),
        request=ListingReportSerializer,
        responses={
            status.HTTP_201_CREATED: ListingReportSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
        },
    )
    def post(self, request: Request, slug: str) -> Response:
        listing = get_object_or_404(Listing.objects.exclude(status=ListingStatus.DRAFT), slug=slug)

        form = ListingReportSerializer(data=request.data)
        form.is_valid(raise_exception=True)

        report = report_listing(
            listing,
            request.user,
            form.validated_data["reason"],
            form.validated_data.get("comment", ""),
        )
        return Response(
            ListingReportSerializer(report).data,
            status=status.HTTP_201_CREATED,
        )


def moderation_queryset() -> QuerySet[ModerationTask]:
    """Очередь со всем, что нужно карточке задачи, без N+1."""
    cover_media = ListingMedia.objects.filter(is_cover=True)

    return ModerationTask.objects.select_related(
        "review",
        "listing",
        "listing__district",
        "listing__city",
        "listing__series",
        "listing__builder",
        "listing__owner",
        "reject_reason",
        "assigned_to",
    ).prefetch_related(
        "listing__media",
        Prefetch("listing__media", queryset=cover_media, to_attr="cover_media"),
    )


class ModerationQueueView(ListAPIView):
    """GET /api/v1/moderation/queue/"""

    permission_classes = [IsAuthenticated, IsModerator]
    serializer_class = ModerationTaskSerializer
    pagination_class = DefaultCursorPagination
    queryset = ModerationTask.objects.none()  # для генератора схемы

    def get_queryset(self) -> QuerySet[ModerationTask]:
        if not self.request.user.is_authenticated:  # pragma: no cover - генерация схемы
            return ModerationTask.objects.none()

        queryset = moderation_queryset()

        requested = self.request.query_params.get("status", ModerationStatus.OPEN)
        if requested in ModerationStatus.values:
            queryset = queryset.filter(status=requested)

        target = self.request.query_params.get("target")
        if target == "listing":
            queryset = queryset.filter(listing__isnull=False)
        elif target == "review":
            queryset = queryset.filter(review__isnull=False)

        has_triggers = self.request.query_params.get("has_triggers")
        if has_triggers in ("true", "1"):
            queryset = queryset.filter(priority__gt=0)
        elif has_triggers in ("false", "0"):
            queryset = queryset.filter(priority=0)

        return queryset.order_by("-priority", "created_at")

    def get_serializer_context(self) -> dict[str, Any]:
        """История отклонений подгружается пачкой на всю страницу.

        Иначе каждая карточка очереди делала бы свой запрос за историей автора.
        """
        context = super().get_serializer_context()

        page = getattr(self, "_page_for_history", None)
        if page:
            owner_ids = {task.listing.owner_id for task in page if task.listing_id}
            context["rejection_history"] = {
                owner_id: rejection_history(owner_id) for owner_id in owner_ids
            }
        return context

    def paginate_queryset(self, queryset: QuerySet[ModerationTask]) -> list[Any] | None:
        page = super().paginate_queryset(queryset)
        self._page_for_history = page
        return page

    @extend_schema(
        operation_id="moderation_queue",
        summary="Очередь модерации",
        description=(
            "Сортировка: сначала задачи с наибольшим числом сработавших "
            "автопроверок, внутри — по времени подачи."
        ),
        parameters=[
            OpenApiParameter("status", str, description="open | approved | rejected"),
            OpenApiParameter("target", str, description="listing | review"),
            OpenApiParameter(
                "has_triggers",
                bool,
                description="true — только задачи со сработавшими проверками",
            ),
        ],
        responses={
            status.HTTP_200_OK: ModerationTaskSerializer(many=True),
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
        },
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().get(request, *args, **kwargs)


class ModerationActionView(APIView):
    """Общий предок решений модератора."""

    permission_classes = [IsAuthenticated, IsModerator]

    def get_task(self, task_id: int) -> ModerationTask:
        return get_object_or_404(moderation_queryset(), pk=task_id)

    def render(self, task: ModerationTask) -> Response:
        history = {}
        if task.listing_id:
            history[task.listing.owner_id] = rejection_history(task.listing.owner_id)

        context = {"request": self.request, "rejection_history": history}
        return Response(ModerationTaskSerializer(task, context=context).data)


class ModerationAssignView(ModerationActionView):
    """POST /api/v1/moderation/{task_id}/assign/"""

    @extend_schema(
        operation_id="moderation_assign",
        summary="Взять задачу себе",
        request=None,
        responses={
            status.HTTP_200_OK: ModerationTaskSerializer,
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
        },
    )
    def post(self, request: Request, task_id: int) -> Response:
        return self.render(assign_task(self.get_task(task_id), request.user))


class ModerationApproveView(ModerationActionView):
    """POST /api/v1/moderation/{task_id}/approve/"""

    @extend_schema(
        operation_id="moderation_approve",
        summary="Одобрить объявление",
        description="Публикует объявление на LISTING_ACTIVE_DAYS дней и уведомляет владельца.",
        request=None,
        responses={
            status.HTTP_200_OK: ModerationTaskSerializer,
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
        },
    )
    def post(self, request: Request, task_id: int) -> Response:
        return self.render(approve_task(self.get_task(task_id), request.user))


class ModerationRejectView(ModerationActionView):
    """POST /api/v1/moderation/{task_id}/reject/"""

    @extend_schema(
        operation_id="moderation_reject",
        summary="Отклонить объявление",
        request=ModerationRejectSerializer,
        responses={
            status.HTTP_200_OK: ModerationTaskSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
        },
    )
    def post(self, request: Request, task_id: int) -> Response:
        form = ModerationRejectSerializer(data=request.data)
        form.is_valid(raise_exception=True)

        task = reject_task(
            self.get_task(task_id),
            request.user,
            form.validated_data["reason_code"],
            form.validated_data.get("comment", ""),
        )
        return self.render(task)


class RejectReasonListView(ListAPIView):
    """GET /api/v1/moderation/reject-reasons/ — справочник для формы отклонения."""

    permission_classes = [IsAuthenticated, IsModerator]
    serializer_class = RejectReasonSerializer
    pagination_class = None
    queryset = RejectReason.objects.filter(is_active=True)

    @extend_schema(
        operation_id="moderation_reject_reasons",
        summary="Справочник причин отклонения",
        responses={status.HTTP_200_OK: RejectReasonSerializer(many=True)},
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().get(request, *args, **kwargs)
