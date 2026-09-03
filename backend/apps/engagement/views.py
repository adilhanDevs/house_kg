"""Эндпоинты сохранённых фильтров и подборок."""

from typing import Any

from django.db.models import Count, QuerySet
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import status
from rest_framework.generics import ListAPIView, ListCreateAPIView, RetrieveUpdateDestroyAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.serializers import BaseSerializer
from rest_framework.utils.urls import replace_query_param
from rest_framework.views import APIView

from apps.catalog.models import Listing
from apps.catalog.views import ListingCursorPagination, ListingListView
from apps.common.pagination import DefaultCursorPagination
from apps.common.serializers import ErrorSerializer
from apps.engagement.models import Collection, SavedFilter
from apps.engagement.serializers import (
    CollectionSerializer,
    FavouriteStateSerializer,
    SavedFilterCreateSerializer,
    SavedFilterSerializer,
    SavedFilterUpdateSerializer,
    ViewedListingSerializer,
    ViewHistoryDeleteSerializer,
    ViewHistoryPageSerializer,
)
from apps.engagement.services import (
    add_favourite,
    clear_view_history,
    collection_listings,
    create_saved_filter,
    favourite_listings,
    filtered_listings,
    group_view_history,
    remove_favourite,
)


class FavouritesPagination(DefaultCursorPagination):
    """Избранное листается по времени добавления записи, а не публикации объекта."""

    ordering = ("-favourited_at",)


class ManualCollectionPagination(DefaultCursorPagination):
    """Порядок в ручной подборке задаёт редактор — по нему и листаем."""

    ordering = ("item_order",)


@extend_schema_view(
    get=extend_schema(
        operation_id="saved_filters_list",
        summary="Сохранённые фильтры пользователя",
        responses={status.HTTP_200_OK: SavedFilterSerializer(many=True)},
    ),
    post=extend_schema(
        operation_id="saved_filters_create",
        summary="Сохранить фильтр",
        description=(
            "Параметры проверяются тем же `ListingFilterSet`, что и каталог: "
            "неизвестный ключ или негодное значение — 400. Больше 20 фильтров "
            "на пользователя — 409."
        ),
        request=SavedFilterCreateSerializer,
        responses={
            status.HTTP_201_CREATED: SavedFilterSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
        },
    ),
)
class SavedFilterListCreateView(ListCreateAPIView):
    """GET / POST /api/v1/saved-filters/"""

    permission_classes = [IsAuthenticated]
    pagination_class = None
    queryset = SavedFilter.objects.none()  # для генератора схемы

    def get_queryset(self) -> QuerySet[SavedFilter]:
        if not self.request.user.is_authenticated:  # pragma: no cover - генерация схемы
            return SavedFilter.objects.none()
        return SavedFilter.objects.filter(user=self.request.user)

    def get_serializer_class(self) -> type[BaseSerializer]:
        if self.request.method == "POST":
            return SavedFilterCreateSerializer
        return SavedFilterSerializer

    def create(self, request: Request, *args: Any, **kwargs: Any):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        saved_filter = create_saved_filter(
            user=request.user,
            name=serializer.validated_data["name"],
            params=serializer.validated_data["params"],
            notify_on_new=serializer.validated_data.get("notify_on_new", True),
        )

        from rest_framework.response import Response

        return Response(
            SavedFilterSerializer(saved_filter, context=self.get_serializer_context()).data,
            status=status.HTTP_201_CREATED,
        )


@extend_schema_view(
    get=extend_schema(operation_id="saved_filters_retrieve", summary="Сохранённый фильтр"),
    patch=extend_schema(
        operation_id="saved_filters_update",
        summary="Переименовать фильтр или переключить уведомления",
        request=SavedFilterUpdateSerializer,
        responses={status.HTTP_200_OK: SavedFilterSerializer},
    ),
    delete=extend_schema(
        operation_id="saved_filters_delete",
        summary="Удалить фильтр",
        responses={status.HTTP_204_NO_CONTENT: None},
    ),
)
class SavedFilterDetailView(RetrieveUpdateDestroyAPIView):
    """GET / PATCH / DELETE /api/v1/saved-filters/{id}/"""

    permission_classes = [IsAuthenticated]
    http_method_names = ["get", "patch", "delete", "head", "options"]
    queryset = SavedFilter.objects.none()  # для генератора схемы

    def get_queryset(self) -> QuerySet[SavedFilter]:
        if not self.request.user.is_authenticated:  # pragma: no cover - генерация схемы
            return SavedFilter.objects.none()
        # Чужие фильтры не видны: для их владельца это 404, а не 403.
        return SavedFilter.objects.filter(user=self.request.user)

    def get_serializer_class(self) -> type[BaseSerializer]:
        if self.request.method == "PATCH":
            return SavedFilterUpdateSerializer
        return SavedFilterSerializer

    def update(self, request: Request, *args: Any, **kwargs: Any):
        from rest_framework.response import Response

        super().update(request, *args, **kwargs)
        instance = self.get_object()
        instance.refresh_from_db()
        return Response(SavedFilterSerializer(instance, context=self.get_serializer_context()).data)


class SavedFilterListingsView(ListingListView):
    """GET /api/v1/saved-filters/{id}/listings/ — каталог по сохранённым параметрам."""

    permission_classes = [IsAuthenticated]
    # Отбор берём из сохранённого фильтра, а не из query string.
    filter_backends: list = []

    def saved_filter(self) -> SavedFilter:
        if not hasattr(self, "_saved_filter"):
            self._saved_filter = get_object_or_404(
                SavedFilter, pk=self.kwargs["pk"], user=self.request.user
            )
        return self._saved_filter

    def get_ordering(self, request: Request) -> str:
        # Поисковый запрос тоже может быть частью сохранённых параметров.
        params = dict(request.query_params)
        if self.saved_filter().params.get("search"):
            params.setdefault("search", "")
        return super().get_ordering(request)

    def get_queryset(self) -> QuerySet[Listing]:
        return filtered_listings(self.saved_filter().params, self.request.user)

    @extend_schema(
        operation_id="saved_filters_listings",
        summary="Объявления по сохранённому фильтру",
        responses={status.HTTP_200_OK: ListingListView.serializer_class(many=True)},
    )
    def get(self, request: Request, *args: Any, **kwargs: Any):
        return super().get(request, *args, **kwargs)


class CollectionListView(ListAPIView):
    """GET /api/v1/collections/ — активные подборки."""

    permission_classes = [AllowAny]
    authentication_classes: list = []
    serializer_class = CollectionSerializer
    pagination_class = None

    def get_queryset(self) -> QuerySet[Collection]:
        return (
            Collection.objects.filter(is_active=True)
            .annotate(items_count=Count("items", distinct=True))
            .order_by("order", "-created_at")
        )

    @extend_schema(
        operation_id="collections_list",
        summary="Подборки",
        responses={status.HTTP_200_OK: CollectionSerializer(many=True)},
        auth=[],
    )
    def get(self, request: Request, *args: Any, **kwargs: Any):
        return super().get(request, *args, **kwargs)


class CollectionListingsView(ListingListView):
    """GET /api/v1/collections/{slug}/listings/ — объекты подборки."""

    permission_classes = [AllowAny]
    filter_backends: list = []

    def collection(self) -> Collection:
        if not hasattr(self, "_collection"):
            self._collection = get_object_or_404(
                Collection, slug=self.kwargs["slug"], is_active=True
            )
        return self._collection

    @property
    def paginator(self):
        """Ручная подборка листается по своему порядку, а не по продвижению."""
        if not hasattr(self, "_paginator_instance"):
            pagination_class = (
                ManualCollectionPagination
                if self.collection().is_manual
                else ListingCursorPagination
            )
            self._paginator_instance = pagination_class()
        return self._paginator_instance

    def get_queryset(self) -> QuerySet[Listing]:
        return collection_listings(self.collection(), self.request.user)

    @extend_schema(
        operation_id="collections_listings",
        summary="Объявления подборки",
        description=(
            "Для подборки в режиме «Ручной список» порядок задаёт редактор, "
            "для режима «По фильтру» действуют правила каталога."
        ),
        responses={status.HTTP_200_OK: ListingListView.serializer_class(many=True)},
    )
    def get(self, request: Request, *args: Any, **kwargs: Any):
        return super().get(request, *args, **kwargs)


class FavouriteView(APIView):
    """POST / DELETE /api/v1/listings/{slug}/favourite/ — переключатель избранного."""

    permission_classes = [IsAuthenticated]

    def get_listing(self, slug: str) -> Listing:
        # Объявление могло уйти в архив — из избранного его убирать всё равно можно.
        return get_object_or_404(Listing, slug=slug)

    @extend_schema(
        operation_id="listings_favourite_add",
        summary="Добавить в избранное",
        description="Идемпотентно: повторный вызов не создаёт дубль и не двигает счётчик.",
        request=None,
        responses={
            status.HTTP_200_OK: FavouriteStateSerializer,
            status.HTTP_401_UNAUTHORIZED: ErrorSerializer,
            status.HTTP_404_NOT_FOUND: ErrorSerializer,
        },
    )
    def post(self, request: Request, slug: str) -> Response:
        is_favourite, count = add_favourite(request.user, self.get_listing(slug))
        return Response({"is_favourite": is_favourite, "favourites_count": count})

    @extend_schema(
        operation_id="listings_favourite_remove",
        summary="Убрать из избранного",
        description="Идемпотентно: если записи не было, ответ всё равно 200.",
        request=None,
        responses={
            status.HTTP_200_OK: FavouriteStateSerializer,
            status.HTTP_401_UNAUTHORIZED: ErrorSerializer,
            status.HTTP_404_NOT_FOUND: ErrorSerializer,
        },
    )
    def delete(self, request: Request, slug: str) -> Response:
        is_favourite, count = remove_favourite(request.user, self.get_listing(slug))
        return Response({"is_favourite": is_favourite, "favourites_count": count})


class FavouriteListView(ListingListView):
    """GET /api/v1/favourites/ — избранное пользователя."""

    permission_classes = [IsAuthenticated]
    filter_backends: list = []
    pagination_class = FavouritesPagination

    def get_queryset(self) -> QuerySet[Listing]:
        return favourite_listings(self.request.user)

    @extend_schema(
        operation_id="favourites_list",
        summary="Избранное",
        description=(
            "Сортировка — по времени добавления в избранное. Объявления отдаются "
            "в любом статусе, снятые с публикации помечены `is_available: false`."
        ),
        responses={status.HTTP_200_OK: ListingListView.serializer_class(many=True)},
    )
    def get(self, request: Request, *args: Any, **kwargs: Any):
        return super().get(request, *args, **kwargs)


class ViewHistoryView(APIView):
    """GET / DELETE /api/v1/view-history/ — история просмотров."""

    permission_classes = [IsAuthenticated]

    @extend_schema(
        operation_id="view_history_list",
        summary="История просмотров",
        description=(
            "Просмотры сгруппированы по дням в таймзоне Asia/Bishkek. Страница "
            "отдаёт целые дни, курсор указывает на последний из них."
        ),
        parameters=[
            OpenApiParameter("cursor", str, description="Дата последнего дня прошлой страницы.")
        ],
        responses={
            status.HTTP_200_OK: ViewHistoryPageSerializer,
            status.HTTP_401_UNAUTHORIZED: ErrorSerializer,
        },
    )
    def get(self, request: Request) -> Response:
        user = request.user

        groups, next_cursor = group_view_history(user, request.query_params.get("cursor"))

        serializer_context = {"request": request}
        results = [
            {
                "day": group["day"],
                "day_label": group["day_label"],
                "items": ViewedListingSerializer(
                    group["items"], many=True, context=serializer_context
                ).data,
            }
            for group in groups
        ]

        return Response({"results": results, "next": self._next_url(request, next_cursor)})

    def _next_url(self, request: Request, cursor: str | None) -> str | None:
        if not cursor:
            return None
        return replace_query_param(request.build_absolute_uri(), "cursor", cursor)

    @extend_schema(
        operation_id="view_history_delete",
        summary="Очистить историю просмотров",
        description=(
            '`{"listing_slugs": [...]}` удаляет перечисленные записи, '
            '`{"all": true}` или пустое тело — всю историю.'
        ),
        request=ViewHistoryDeleteSerializer,
        responses={
            status.HTTP_204_NO_CONTENT: None,
            status.HTTP_401_UNAUTHORIZED: ErrorSerializer,
        },
    )
    def delete(self, request: Request) -> Response:
        user = request.user

        serializer = ViewHistoryDeleteSerializer(data=request.data or {})
        serializer.is_valid(raise_exception=True)

        slugs = serializer.validated_data.get("listing_slugs") or []
        clear_all = serializer.validated_data.get("all", False)

        clear_view_history(user, None if clear_all else slugs)
        return Response(status=status.HTTP_204_NO_CONTENT)
