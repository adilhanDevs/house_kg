"""Сериализаторы сохранённых фильтров и подборок."""

from typing import Any

from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.catalog.serializers import ListingListSerializer, absolute_file_url
from apps.engagement.models import Collection, SavedFilter
from apps.engagement.services import normalize_filter_params


class SavedFilterSerializer(serializers.ModelSerializer):
    """Сохранённый фильтр в списке."""

    class Meta:
        model = SavedFilter
        fields = [
            "id",
            "name",
            "params",
            "notify_on_new",
            "matches_count",
            "last_notified_at",
            "created_at",
        ]
        read_only_fields = ["id", "matches_count", "last_notified_at", "created_at"]


class SavedFilterCreateSerializer(serializers.ModelSerializer):
    """Создание фильтра: параметры проверяются через ListingFilterSet."""

    params = serializers.DictField(default=dict)

    class Meta:
        model = SavedFilter
        fields = ["name", "params", "notify_on_new"]

    def validate_params(self, value: Any) -> dict[str, str]:
        return normalize_filter_params(value, self.context.get("request"))


class SavedFilterUpdateSerializer(serializers.ModelSerializer):
    """Правка фильтра: переименование и переключение уведомлений.

    Параметры не меняются — для другого набора создаётся другой фильтр,
    иначе `last_notified_at` относился бы к прошлому запросу.
    """

    class Meta:
        model = SavedFilter
        fields = ["name", "notify_on_new"]


class CollectionSerializer(serializers.ModelSerializer):
    """Редакционная подборка для экрана «Подборки»."""

    cover_url = serializers.SerializerMethodField()
    listings_count = serializers.SerializerMethodField()

    class Meta:
        model = Collection
        fields = [
            "id",
            "title",
            "subtitle",
            "slug",
            "cover_url",
            "description",
            "mode",
            "listings_count",
        ]
        read_only_fields = fields

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_cover_url(self, obj: Collection) -> str | None:
        return absolute_file_url(obj.cover, self.context.get("request"))

    @extend_schema_field(serializers.IntegerField(allow_null=True))
    def get_listings_count(self, obj: Collection) -> int | None:
        """Для ручных подборок — размер списка; для фильтра считать заранее незачем."""
        return getattr(obj, "items_count", None) if obj.is_manual else None


class FavouriteStateSerializer(serializers.Serializer):
    """Ответ переключателя избранного."""

    is_favourite = serializers.BooleanField()
    favourites_count = serializers.IntegerField()


class ViewedListingSerializer(ListingListSerializer):
    """Карточка в истории просмотров — с временем просмотра."""

    viewed_at = serializers.DateTimeField(read_only=True)

    class Meta(ListingListSerializer.Meta):
        fields = [*ListingListSerializer.Meta.fields, "viewed_at"]
        read_only_fields = fields


class ViewHistoryDaySerializer(serializers.Serializer):
    """Группа истории за один день."""

    day = serializers.CharField()
    day_label = serializers.CharField()
    items = ViewedListingSerializer(many=True)


class ViewHistoryPageSerializer(serializers.Serializer):
    """Страница истории: целые дни и курсор на следующую."""

    results = ViewHistoryDaySerializer(many=True)
    next = serializers.URLField(allow_null=True)


class ViewHistoryDeleteSerializer(serializers.Serializer):
    """Что удалить из истории: перечисленные объявления или всё."""

    listing_slugs = serializers.ListField(
        child=serializers.SlugField(), required=False, allow_empty=True
    )
    all = serializers.BooleanField(required=False, default=False)
