"""Сериализаторы справочников каталога."""

from typing import Any

from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.catalog.constants import MAX_FILES_PER_REQUEST
from apps.catalog.covers import cover_detail_file, listing_cover, listing_cover_file
from apps.catalog.enums import ListingStatus, MediaKind
from apps.catalog.field_rules import strip_inapplicable
from apps.catalog.models import (
    Builder,
    City,
    District,
    HouseSeries,
    Listing,
    ListingMedia,
    ListingReport,
    ListingRoom,
    ModerationTask,
    RejectReason,
)
from apps.users.phone import mask_public_phone


def absolute_file_url(file_field: Any, request: Any) -> str | None:
    """Абсолютный URL файла или None, если файла нет."""
    if not file_field:
        return None
    url = file_field.url
    if url.startswith("/media/"):
        url = "/api/v1" + url
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
    plot_purposes = ChoiceOptionSerializer(many=True)
    commercial_purposes = ChoiceOptionSerializer(many=True)
    building_lines = ChoiceOptionSerializer(many=True)
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
    """Файл объявления во всех вариантах размеров.

    `url` отдаётся всегда: пока обработка не закончилась (`status` != `ready`),
    в нём лежит оригинал, и экран не ждёт конвертации.
    """

    url = serializers.SerializerMethodField()
    thumbnail_url = serializers.SerializerMethodField()
    url_thumb = serializers.SerializerMethodField()
    url_medium = serializers.SerializerMethodField()
    url_original = serializers.SerializerMethodField()
    url_thumb_jpeg = serializers.SerializerMethodField()
    url_medium_jpeg = serializers.SerializerMethodField()
    url_original_jpeg = serializers.SerializerMethodField()

    class Meta:
        model = ListingMedia
        fields = [
            "id",
            "kind",
            "status",
            "title",
            "description",
            "url",
            "thumbnail_url",
            "url_thumb",
            "url_medium",
            "url_original",
            "url_thumb_jpeg",
            "url_medium_jpeg",
            "url_original_jpeg",
            "order",
            "is_cover",
            "width",
            "height",
            "duration_seconds",
            "size_bytes",
        ]
        read_only_fields = fields

    def _url(self, file_field: Any) -> str | None:
        return absolute_file_url(file_field, self.context.get("request"))

    @extend_schema_field(serializers.URLField())
    def get_url(self, obj: ListingMedia) -> str | None:
        return self._url(obj.display_file())

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_thumbnail_url(self, obj: ListingMedia) -> str | None:
        if obj.thumbnail:
            return self._url(obj.thumbnail)
        if obj.url_thumb:
            return self._url(obj.url_thumb)
        if obj.kind == MediaKind.VIDEO:
            # Кадр-обложку присылает приложение при загрузке. Не прислало —
            # показываем обложку объявления. Раньше здесь запускался ffmpeg,
            # то есть обычный GET каталога перекодировал видео.
            return self._url(self._listing_cover(obj))
        return None

    @staticmethod
    def _listing_cover(obj: ListingMedia) -> Any:
        """Обложка объявления. Идём по уже загруженным media, без запроса."""
        return listing_cover_file(obj.listing)

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_url_thumb(self, obj: ListingMedia) -> str | None:
        return self._url(obj.url_thumb)

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_url_medium(self, obj: ListingMedia) -> str | None:
        return self._url(obj.url_medium)

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_url_original(self, obj: ListingMedia) -> str | None:
        return self._url(obj.url_original)

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_url_thumb_jpeg(self, obj: ListingMedia) -> str | None:
        return self._url(obj.url_thumb_jpeg)

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_url_medium_jpeg(self, obj: ListingMedia) -> str | None:
        return self._url(obj.url_medium_jpeg)

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_url_original_jpeg(self, obj: ListingMedia) -> str | None:
        return self._url(obj.url_original_jpeg)


class MediaUploadSerializer(serializers.Serializer):
    """Пачка файлов из галереи телефона.

    Для видео приложение прикладывает кадр-обложку и метаданные ролика: оно
    и так открывает файл в плеере, а серверу это экономит запуск ffmpeg на
    каждую загрузку.
    """

    files = serializers.ListField(
        child=serializers.FileField(),
        allow_empty=False,
        max_length=MAX_FILES_PER_REQUEST,
        help_text="Несколько файлов одним запросом — пользователь выбирает их скопом.",
    )
    kind = serializers.ChoiceField(choices=MediaKind.choices, default=MediaKind.PHOTO)
    title = serializers.CharField(max_length=100, required=False, allow_blank=True)
    description = serializers.CharField(required=False, allow_blank=True)

    thumbnail = serializers.ImageField(
        required=False,
        help_text="Кадр-обложка ролика, снятый приложением. Только для kind=video.",
    )
    duration_seconds = serializers.IntegerField(
        required=False,
        min_value=0,
        help_text="Длительность ролика в секундах — из плеера приложения.",
    )
    width = serializers.IntegerField(required=False, min_value=0)
    height = serializers.IntegerField(required=False, min_value=0)

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        is_video = attrs.get("kind", MediaKind.PHOTO) == MediaKind.VIDEO

        if not is_video and attrs.get("thumbnail") is not None:
            raise serializers.ValidationError(
                {"thumbnail": "Обложка прикладывается только к видео."}
            )

        # Обложка и длительность описывают один ролик, поэтому вместе с пачкой
        # файлов они бессмысленны: непонятно, к какому из них относятся.
        if attrs.get("thumbnail") is not None and len(attrs.get("files") or []) > 1:
            raise serializers.ValidationError(
                {"thumbnail": "Обложка передаётся вместе с одним файлом."}
            )

        return attrs


class ListingMediaUpdateSerializer(serializers.ModelSerializer):
    """Обновление метаданных медиафайла."""

    class Meta:
        model = ListingMedia
        fields = ["title", "description"]


class RejectedFileSerializer(serializers.Serializer):
    """Почему конкретный файл из пачки не взяли."""

    file_index = serializers.CharField()
    reason = serializers.CharField()


class MediaUploadResultSerializer(serializers.Serializer):
    """Ответ загрузки: сколько взяли, сколько отклонили и почему."""

    accepted = serializers.IntegerField()
    rejected = serializers.IntegerField()
    reason = serializers.CharField(allow_blank=True)
    free_slots = serializers.IntegerField()
    media = ListingMediaSerializer(many=True)
    # Разбивка по файлам: форма подсвечивает именно те, что не прошли.
    rejected_details = RejectedFileSerializer(many=True)


class MediaReorderSerializer(serializers.Serializer):
    """Новый порядок файлов: список id от первого к последнему."""

    order = serializers.ListField(child=serializers.IntegerField(), allow_empty=False)


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
    cover_media_id = serializers.SerializerMethodField()
    photos_count = serializers.IntegerField(read_only=True)
    series_code = serializers.CharField(source="series.code", default=None, read_only=True)
    is_promoted = serializers.SerializerMethodField()
    is_favourite = serializers.SerializerMethodField()
    is_available = serializers.SerializerMethodField()
    owner_id = serializers.IntegerField(read_only=True)

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
            "land_area",
            "floor",
            "floors",
            "cover_url",
            "cover_media_id",
            "photos_count",
            "is_secondary",
            "series_code",
            "below_market",
            "red_book",
            "seller_kind",
            "owner_id",
            "is_promoted",
            "is_favourite",
            "is_available",
            "status",
            "published_at",
        ]
        read_only_fields = fields

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_cover_url(self, obj: Listing) -> str | None:
        # Кандидаты приходят из Prefetch(to_attr=...) — без запроса на объект.
        # Правило выбора общее для всего каталога, см. apps/catalog/covers.py.
        return absolute_file_url(listing_cover_file(obj), self.context.get("request"))

    @extend_schema_field(serializers.IntegerField(allow_null=True))
    def get_cover_media_id(self, obj: Listing) -> int | None:
        """id медиа, которое сервер выбрал обложкой.

        Клиенту он нужен, чтобы не гадать по URL, какое из `media[]` уже
        показано как обложка: у одного и того же снимка в ответе разные
        варианты размера и, значит, разные адреса.
        """
        cover = listing_cover(obj)
        return cover.pk if cover is not None else None

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


class ListingReelsSerializer(ListingListSerializer):
    """Карточка объявления в ленте видеообзоров (Reels)."""

    videos = ListingMediaSerializer(source="processed_videos", many=True, read_only=True)

    class Meta(ListingListSerializer.Meta):
        fields = ListingListSerializer.Meta.fields + ["videos"]
        read_only_fields = fields


class ListingRoomSerializer(serializers.ModelSerializer):
    """Помещение / комната в объекте (чтение)."""

    class Meta:
        model = ListingRoom
        fields = ["id", "name", "area", "order"]
        read_only_fields = fields


class ListingRoomWriteSerializer(serializers.ModelSerializer):
    """Комната в форме объявления.

    Набор комнат у каждого объекта свой: у одной квартиры есть холл и две
    спальни, у другой — только кухня и балкон. Поэтому это список, который
    владелец собирает сам, а не фиксированный набор полей.
    """

    class Meta:
        model = ListingRoom
        fields = ["name", "area", "order"]
        extra_kwargs = {"order": {"required": False}}


class ListingDetailSerializer(ListingListSerializer):
    """Полная карточка объекта."""

    builder = BuilderBriefSerializer(read_only=True)
    media = ListingMediaSerializer(many=True, read_only=True)
    cover_detail_url = serializers.SerializerMethodField()
    seller = serializers.SerializerMethodField()
    rooms_breakdown = ListingRoomSerializer(source="rooms_data", many=True, read_only=True)
    videos = serializers.SerializerMethodField()

    class Meta(ListingListSerializer.Meta):
        fields = [
            *ListingListSerializer.Meta.fields,
            "cover_detail_url",
            "description",
            "address",
            "latitude",
            "longitude",
            "furniture",
            "condition",
            "heating",
            "has_gas",
            "exchange_possible",
            "plot_purpose",
            "commercial_purpose",
            "has_separate_entrance",
            "building_line",
            "ceiling_height",
            "has_direct_sale",
            "has_mortgage",
            "landmarks",
            "rooms_breakdown",
            "videos",
            "builder",
            "allow_media_download",
            "views_count",
            "favourites_count",
            "media",
            "seller",
        ]
        read_only_fields = fields

    @extend_schema_field(serializers.URLField(allow_null=True))
    def get_cover_detail_url(self, obj: Listing) -> str | None:
        """Та же обложка, что и `cover_url`, но крупным вариантом.

        В сетке каталога хватает превью на 400 px, а на весь экран оно
        расплывается. Медиа то же самое — отличается только вариант размера,
        поэтому `cover_media_id` у обоих полей один.
        """
        return absolute_file_url(
            cover_detail_file(listing_cover(obj)),
            self.context.get("request"),
        )

    @extend_schema_field(ListingMediaSerializer(many=True))
    def get_videos(self, obj: Listing) -> list[dict[str, Any]]:
        video_items = [m for m in obj.media.all() if m.kind == MediaKind.VIDEO]
        return ListingMediaSerializer(video_items, many=True, context=self.context).data

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


class ListingCompletenessSerializer(serializers.Serializer):
    """Готовность черновика к публикации."""

    is_complete = serializers.BooleanField()
    missing_fields = serializers.ListField(child=serializers.CharField())


class ListingDraftSerializer(ListingDetailSerializer):
    """Черновик: карточка плюс подсказка, что ещё заполнить."""

    completeness = serializers.SerializerMethodField()

    class Meta(ListingDetailSerializer.Meta):
        fields = [*ListingDetailSerializer.Meta.fields, "status", "completeness"]
        read_only_fields = fields

    @extend_schema_field(ListingCompletenessSerializer)
    def get_completeness(self, obj: Listing) -> dict[str, Any]:
        from apps.catalog.services import listing_completeness

        return listing_completeness(obj)


class ListingUpdateSerializer(serializers.ModelSerializer):
    """Частичное обновление формы объявления.

    Все поля необязательны: клиент шлёт PATCH по мере заполнения.
    """

    district = serializers.SlugRelatedField(
        slug_field="slug", queryset=District.objects.all(), required=False, allow_null=True
    )
    city = serializers.SlugRelatedField(
        slug_field="slug", queryset=City.objects.all(), required=False, allow_null=True
    )
    series = serializers.SlugRelatedField(
        slug_field="code", queryset=HouseSeries.objects.all(), required=False, allow_null=True
    )
    builder = serializers.SlugRelatedField(
        slug_field="slug", queryset=Builder.objects.all(), required=False, allow_null=True
    )
    rooms_breakdown = ListingRoomWriteSerializer(
        many=True,
        required=False,
        help_text="Экспликация помещений. Присланный список заменяет прежний целиком.",
    )

    class Meta:
        model = Listing
        fields = [
            "kind",
            "rooms_breakdown",
            "district",
            "city",
            "address",
            "rooms",
            "area",
            "furniture",
            "condition",
            "heating",
            "has_gas",
            "exchange_possible",
            "has_direct_sale",
            "has_mortgage",
            "landmarks",
            "land_area",
            "floor",
            "floors",
            "series",
            "builder",
            "plot_purpose",
            "commercial_purpose",
            "has_separate_entrance",
            "building_line",
            "ceiling_height",
            "price",
            "currency",
            "seller_kind",
            "is_secondary",
            "description",
            "allow_media_download",
            "contact_name",
            "contact_phone",
            "latitude",
            "longitude",
        ]
        extra_kwargs = {field: {"required": False} for field in fields}

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        # Город всегда согласован с районом: клиент присылает только район.
        district = attrs.get("district")
        if district is not None and "city" not in attrs:
            attrs["city"] = district.city

        # Этаж выше этажности — не опечатка клиента, а мусор в выдаче:
        # фильтр «последний этаж» после такого перестаёт что-либо значить.
        floor = attrs.get("floor", getattr(self.instance, "floor", None))
        floors = attrs.get("floors", getattr(self.instance, "floors", None))
        if floor and floors and floor > floors:
            raise serializers.ValidationError(
                {"floor": "Этаж не может быть больше этажности дома."}
            )

        # Тип берём из запроса, а если его там нет — из уже сохранённого
        # объявления: клиент шлёт форму по частям.
        kind = attrs.get("kind") or getattr(self.instance, "kind", "")
        # Неприменимое отбрасываем молча: 400 на остаточном `rooms` от
        # предыдущего выбора типа сломал бы обычное заполнение формы.
        return strip_inapplicable(kind, attrs)


class MyListingSerializer(ListingListSerializer):
    """Объявление в разделе «Мои объявления» — со статистикой."""

    completeness = serializers.SerializerMethodField()

    class Meta(ListingListSerializer.Meta):
        fields = [
            *ListingListSerializer.Meta.fields,
            "status",
            "rejection_reason",
            "views_count",
            "favourites_count",
            "promoted_until",
            "expires_at",
            "completeness",
        ]
        read_only_fields = fields

    @extend_schema_field(ListingCompletenessSerializer)
    def get_completeness(self, obj: Listing) -> dict[str, Any]:
        from apps.catalog.services import listing_completeness

        return listing_completeness(obj)


class RejectReasonSerializer(serializers.ModelSerializer):
    class Meta:
        model = RejectReason
        fields = ["code", "title", "description", "order"]
        read_only_fields = fields


class RejectionHistorySerializer(serializers.Serializer):
    """Прошлое отклонение автора — контекст для модератора."""

    listing_slug = serializers.CharField()
    reason_code = serializers.CharField(allow_blank=True)
    reason_title = serializers.CharField(allow_blank=True)
    comment = serializers.CharField(allow_blank=True)
    resolved_at = serializers.DateTimeField(allow_null=True)


class ModerationReviewSerializer(serializers.Serializer):
    """Отзыв в карточке задачи модерации."""

    id = serializers.IntegerField()
    rating = serializers.IntegerField()
    text = serializers.CharField(allow_blank=True)
    status = serializers.CharField()
    seller_id = serializers.IntegerField()
    author_id = serializers.IntegerField()
    created_at = serializers.DateTimeField()


class ModerationTaskSerializer(serializers.ModelSerializer):
    """Задача в очереди: объект целиком, автопроверки и история автора."""

    listing = ListingDetailSerializer(read_only=True)
    review = ModerationReviewSerializer(read_only=True)
    reject_reason = RejectReasonSerializer(read_only=True)
    triggered_checks = serializers.SerializerMethodField()
    author_rejections = serializers.SerializerMethodField()
    assigned_to = serializers.SerializerMethodField()
    target_kind = serializers.CharField(read_only=True)

    class Meta:
        model = ModerationTask
        fields = [
            "id",
            "target_kind",
            "listing",
            "review",
            "status",
            "checks",
            "triggered_checks",
            "priority",
            "assigned_to",
            "reject_reason",
            "comment",
            "resolved_at",
            "created_at",
            "author_rejections",
        ]
        read_only_fields = fields

    @extend_schema_field(serializers.ListField(child=serializers.CharField()))
    def get_triggered_checks(self, obj: ModerationTask) -> list[str]:
        return obj.triggered_checks

    @extend_schema_field(serializers.CharField(allow_null=True))
    def get_assigned_to(self, obj: ModerationTask) -> str | None:
        return obj.assigned_to.get_username() if obj.assigned_to_id else None

    @extend_schema_field(RejectionHistorySerializer(many=True))
    def get_author_rejections(self, obj: ModerationTask) -> list[dict[str, Any]]:
        """История берётся из контекста — иначе это запрос на каждую задачу."""
        if not obj.listing_id:
            return []
        history = self.context.get("rejection_history") or {}
        return history.get(obj.listing.owner_id, [])


class ModerationRejectSerializer(serializers.Serializer):
    """Решение об отклонении."""

    reason_code = serializers.CharField(max_length=32)
    comment = serializers.CharField(allow_blank=True, required=False, default="")


class ListingReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = ListingReport
        fields = ["id", "reason", "comment", "is_resolved", "created_at"]
        read_only_fields = ["id", "is_resolved", "created_at"]
