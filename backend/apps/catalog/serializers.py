"""Сериализаторы справочников каталога."""

from typing import Any

from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.catalog.enums import ListingStatus
from apps.catalog.models import Builder, City, District, Listing, ListingMedia
from apps.users.phone import mask_public_phone


def absolute_file_url(file_field: Any, request: Any) -> str | None:
    """Абсолютный URL файла или None, если файла нет."""
    if not file_field:
        return None
    url = file_field.url
    return request.build_absolute_uri(url) if request else url


class CitySerializer(serializers.ModelSerializer):
    class Meta:
        model = City
        fields = ["id", "name", "slug", "is_default"]
        read_only_fields = fields


class DistrictSerializer(serializers.ModelSerializer):
    city = serializers.SlugRelatedField(slug_field="slug", read_only=True)

    class Meta:
        model = District
        fields = ["id", "name", "slug", "city", "latitude", "longitude"]
        read_only_fields = fields


class BuilderSerializer(serializers.ModelSerializer):
    logo_url = serializers.SerializerMethodField()

    class Meta:
        model = Builder
        fields = ["id", "name", "slug", "logo_url"]
        read_only_fields = fields

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_logo_url(self, obj: Builder) -> str | None:
        if not obj.logo:
            return None
        request = self.context.get("request")
        return request.build_absolute_uri(obj.logo.url) if request else obj.logo.url


# -- опции фильтра (описание ответа для схемы) -------------------------------


class ChoiceOptionSerializer(serializers.Serializer):
    value = serializers.CharField()
    label = serializers.CharField()


class AreaRangeSerializer(serializers.Serializer):
    """Диапазон площади. Поле `from` — ключевое слово Python, объявляем вручную."""

    to = serializers.IntegerField()
    label = serializers.CharField()

    def get_fields(self) -> dict[str, Any]:
        fields = super().get_fields()
        fields["from"] = serializers.IntegerField()
        return fields


class HouseSeriesOptionSerializer(serializers.Serializer):
    code = serializers.CharField()
    name = serializers.CharField()


class PriceRangeSerializer(serializers.Serializer):
    currency = serializers.CharField()
    min = serializers.IntegerField()
    max = serializers.IntegerField()


class FilterOptionsSerializer(serializers.Serializer):
    """Всё, что нужно экрану фильтра, одним ответом."""

    property_kinds = ChoiceOptionSerializer(many=True)
    seller_kinds = ChoiceOptionSerializer(many=True)
    rooms = serializers.ListField(child=serializers.IntegerField())
    area_ranges = AreaRangeSerializer(many=True)
    series = HouseSeriesOptionSerializer(many=True)
    districts = DistrictSerializer(many=True)
    price_range = PriceRangeSerializer()


# -- объявления --------------------------------------------------------------


class DistrictBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = District
        fields = ["id", "name", "slug"]
        read_only_fields = fields


class BuilderBriefSerializer(serializers.ModelSerializer):
    class Meta:
        model = Builder
        fields = ["id", "name", "slug"]
        read_only_fields = fields


class ListingMediaSerializer(serializers.ModelSerializer):
    url = serializers.SerializerMethodField()
    thumbnail_url = serializers.SerializerMethodField()

    class Meta:
        model = ListingMedia
        fields = [
            "id",
            "kind",
            "url",
            "thumbnail_url",
            "order",
            "is_cover",
            "width",
            "height",
            "duration_seconds",
        ]
        read_only_fields = fields

    @extend_schema_field(serializers.URLField())
    def get_url(self, obj: ListingMedia) -> str | None:
        return absolute_file_url(obj.file, self.context.get("request"))

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_thumbnail_url(self, obj: ListingMedia) -> str | None:
        return absolute_file_url(obj.thumbnail, self.context.get("request"))


class SellerSerializer(serializers.Serializer):
    """Продавец в карточке объекта."""

    id = serializers.IntegerField()
    name = serializers.CharField()
    kind = serializers.CharField()
    phone = serializers.CharField()
    avatar_url = serializers.URLField(allow_null=True)
    listings_count = serializers.IntegerField()
    member_since = serializers.DateTimeField()


class ListingListSerializer(serializers.ModelSerializer):
    """Карточка объявления в сетке каталога."""

    kind_label = serializers.CharField(source="get_kind_display", read_only=True)
    district = DistrictBriefSerializer(read_only=True)
    cover_url = serializers.SerializerMethodField()
    photos_count = serializers.IntegerField(read_only=True)
    series_code = serializers.CharField(source="series.code", default=None, read_only=True)
    is_promoted = serializers.SerializerMethodField()
    is_favourite = serializers.SerializerMethodField()
    is_available = serializers.SerializerMethodField()

    class Meta:
        model = Listing
        fields = [
            "slug",
            "kind",
            "kind_label",
            "district",
            "price",
            "currency",
            "old_price",
            "rooms",
            "area",
            "floor",
            "floors",
            "cover_url",
            "photos_count",
            "is_secondary",
            "series_code",
            "below_market",
            "red_book",
            "seller_kind",
            "is_promoted",
            "is_favourite",
            "is_available",
            "published_at",
        ]
        read_only_fields = fields

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_cover_url(self, obj: Listing) -> str | None:
        # cover_media приходит из Prefetch(to_attr=...) — без запроса на объект.
        cover = getattr(obj, "cover_media", None)
        if not cover:
            return None
        return absolute_file_url(cover[0].file, self.context.get("request"))

    @extend_schema_field(serializers.BooleanField())
    def get_is_promoted(self, obj: Listing) -> bool:
        rank = getattr(obj, "promoted_rank", None)
        return bool(rank) if rank is not None else obj.is_promoted

    @extend_schema_field(serializers.BooleanField())
    def get_is_favourite(self, obj: Listing) -> bool:
        return bool(getattr(obj, "is_favourite_flag", False))

    @extend_schema_field(serializers.BooleanField())
    def get_is_available(self, obj: Listing) -> bool:
        """В избранном и истории объявление могло уже уйти из публикации."""
        return obj.status == ListingStatus.ACTIVE


class ListingDetailSerializer(ListingListSerializer):
    """Полная карточка объекта."""

    builder = BuilderBriefSerializer(read_only=True)
    media = ListingMediaSerializer(many=True, read_only=True)
    seller = serializers.SerializerMethodField()

    class Meta(ListingListSerializer.Meta):
        fields = [
            *ListingListSerializer.Meta.fields,
            "description",
            "address",
            "latitude",
            "longitude",
            "builder",
            "allow_media_download",
            "views_count",
            "favourites_count",
            "media",
            "seller",
        ]
        read_only_fields = fields

    @extend_schema_field(SellerSerializer)
    def get_seller(self, obj: Listing) -> dict[str, Any]:
        request = self.context.get("request")
        viewer = getattr(request, "user", None)
        owner = obj.owner

        # Полный телефон — только аутентифицированным: иначе каталог
        # превращается в готовую базу номеров.
        authenticated = bool(viewer and viewer.is_authenticated)
        phone = owner.phone if authenticated else mask_public_phone(owner.phone)

        return {
            "id": owner.pk,
            "name": obj.contact_name or owner.name,
            "kind": obj.seller_kind,
            "phone": phone,
            "avatar_url": absolute_file_url(owner.avatar, request),
            "listings_count": getattr(obj, "seller_listings_count", 0),
            "member_since": owner.date_joined,
        }


class ListingViewResponseSerializer(serializers.Serializer):
    views_count = serializers.IntegerField()


class ListingCountSerializer(serializers.Serializer):
    """Ответ кнопки «Показать N объектов»."""

    count = serializers.IntegerField()


class FeaturedSerializer(serializers.Serializer):
    """Подборки главного экрана: по четыре объекта на каждый тип недвижимости."""

    apartment = ListingListSerializer(many=True)
    house = ListingListSerializer(many=True)
    new_building = ListingListSerializer(many=True)
    plot = ListingListSerializer(many=True)
    room = ListingListSerializer(many=True)
    commercial = ListingListSerializer(many=True)
