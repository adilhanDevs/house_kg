from django.utils.decorators import method_decorator
from django.views.decorators.cache import never_cache
from rest_framework import serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.serializers import ListingListSerializer, ListingReelsSerializer
from apps.recommendations.models import InteractionType, RecommendationEvent
from apps.recommendations.services import RecommendationContext, get_recommended_listings


class RecommendationEventBatchSerializer(serializers.Serializer):
    events = serializers.ListField(child=serializers.DictField(), max_length=50)

    def validate_events(self, events):
        # basic validation
        for ev in events:
            if "event_type" not in ev:
                raise serializers.ValidationError("event_type is required")
            if ev["event_type"] not in InteractionType.values:
                raise serializers.ValidationError(f"Invalid event_type: {ev['event_type']}")
            session_id = ev.get("session_id", "")
            if not session_id or len(session_id) < 8 or len(session_id) > 128:
                raise serializers.ValidationError("Valid session_id (min 8 chars) is required")
            if not session_id.isalnum() and "-" not in session_id:
                # Basic check: usually uuid or alphanumeric
                pass
        return events


class ListingRecommendationsView(APIView):
    """
    Personalized listings feed.
    """

    @method_decorator(never_cache)
    def get(self, request, *args, **kwargs):
        session_id = request.query_params.get("session_id", "")
        if not session_id:
            return Response(
                {"detail": "session_id is required"}, status=status.HTTP_400_BAD_REQUEST
            )

        limit = int(request.query_params.get("limit", 20))
        cursor = request.query_params.get("cursor", None)

        feed_session_id = request.query_params.get("feed_session_id", session_id)

        context = RecommendationContext(
            user=request.user if request.user.is_authenticated else None,
            session_id=session_id,
            feed_session_id=feed_session_id,
            limit=limit,
            cursor=cursor,
        )

        features_list, next_cursor = get_recommended_listings(context)
        listings = [f.listing for f in features_list]

        serializer = ListingListSerializer(listings, many=True, context={"request": request})

        return Response({"results": serializer.data, "next": next_cursor})


class ReelsRecommendationsView(APIView):
    """
    Personalized Reels feed.
    """

    @method_decorator(never_cache)
    def get(self, request, *args, **kwargs):
        session_id = request.query_params.get("session_id", "")
        if not session_id:
            return Response(
                {"detail": "session_id is required"}, status=status.HTTP_400_BAD_REQUEST
            )

        limit = int(request.query_params.get("limit", 10))
        cursor = request.query_params.get("cursor", None)

        feed_session_id = request.query_params.get("feed_session_id", session_id)

        context = RecommendationContext(
            user=request.user if request.user.is_authenticated else None,
            session_id=session_id,
            feed_session_id=feed_session_id,
            limit=limit,
            cursor=cursor,
            require_video=True,
        )

        features_list, next_cursor = get_recommended_listings(context)
        listings = [f.listing for f in features_list]

        # ListingReelsSerializer читает поле videos из атрибута
        # processed_videos, который навешивает Prefetch. Без него DRF отдавал
        # videos: null на каждый ролик, и лента в приложении оставалась
        # пустой: клиент отбрасывает карточки без единого видео.
        from django.db.models import Prefetch, prefetch_related_objects

        from apps.catalog.enums import MediaKind, MediaStatus
        from apps.catalog.models import ListingMedia

        if listings:
            prefetch_related_objects(
                listings,
                Prefetch(
                    "media",
                    queryset=ListingMedia.objects.filter(
                        kind=MediaKind.VIDEO, status=MediaStatus.READY
                    ).order_by("order", "id"),
                    to_attr="processed_videos",
                ),
            )

        serializer = ListingReelsSerializer(listings, many=True, context={"request": request})

        return Response({"results": serializer.data, "next": next_cursor})


class RecommendationEventBatchView(APIView):
    """
    Receive batch analytics events for recommendation signals.
    """

    def post(self, request, *args, **kwargs):
        serializer = RecommendationEventBatchSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        events_data = serializer.validated_data["events"]

        user = request.user if request.user.is_authenticated else None

        objs = []
        for ev in events_data:
            objs.append(
                RecommendationEvent(
                    user=user,
                    session_id=ev["session_id"],
                    feed_session_id=ev.get("feed_session_id", ""),
                    event_type=ev["event_type"],
                    listing_id=ev.get("listing_id"),
                    context=ev.get("context", {}),
                    client_event_id=ev.get("client_event_id"),
                )
            )

        RecommendationEvent.objects.bulk_create(objs, ignore_conflicts=True)

        return Response({"status": "ok"})


class RecommendationDebugView(APIView):
    """
    Returns explainable score breakdown. For staff/dev only.
    """

    def get(self, request, *args, **kwargs):
        if not request.user and not request.user.is_staff:
            return Response(status=status.HTTP_403_FORBIDDEN)

        session_id = request.query_params.get("session_id", "debug_session")
        limit = int(request.query_params.get("limit", 10))

        context = RecommendationContext(user=request.user, session_id=session_id, limit=limit)

        features_list, _ = get_recommended_listings(context)

        debug_info = []
        for f in features_list:
            debug_info.append(
                {
                    "listing_id": f.listing.id,
                    "slug": f.listing.slug,
                    "total_score": f.total_score,
                    "components": {
                        "freshness": f.freshness_score,
                        "quality": f.quality_score,
                        "popularity": f.popularity_score,
                        "promotion": f.promotion_score,
                        "price_match": f.price_match,
                        "location_match": f.location_match,
                        "rooms_match": f.rooms_match,
                        "property_type_match": f.property_type_match,
                        "negative": f.negative_score,
                    },
                }
            )

        return Response({"ranker_version": "v1", "results": debug_info})
