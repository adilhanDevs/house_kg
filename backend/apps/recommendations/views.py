from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import serializers, status
from django.utils.decorators import method_decorator
from django.views.decorators.cache import never_cache

from apps.catalog.serializers import ListingListSerializer, ListingReelsSerializer
from apps.recommendations.services import RecommendationContext, get_recommended_listings
from apps.recommendations.models import RecommendationEvent, InteractionType


class RecommendationEventBatchSerializer(serializers.Serializer):
    events = serializers.ListField(
        child=serializers.DictField()
    )

    def validate_events(self, events):
        # basic validation
        for ev in events:
            if 'event_type' not in ev:
                raise serializers.ValidationError("event_type is required")
            if ev['event_type'] not in InteractionType.values:
                raise serializers.ValidationError(f"Invalid event_type: {ev['event_type']}")
            if 'session_id' not in ev:
                raise serializers.ValidationError("session_id is required")
        return events


class ListingRecommendationsView(APIView):
    """
    Personalized listings feed.
    """
    @method_decorator(never_cache)
    def get(self, request, *args, **kwargs):
        session_id = request.query_params.get("session_id", "")
        if not session_id:
            return Response({"detail": "session_id is required"}, status=status.HTTP_400_BAD_REQUEST)
            
        limit = int(request.query_params.get("limit", 20))
        cursor = request.query_params.get("cursor", None)
        
        context = RecommendationContext(
            user=request.user if request.user.is_authenticated else None,
            session_id=session_id,
            limit=limit,
            cursor=cursor
        )
        
        features_list, next_cursor = get_recommended_listings(context)
        listings = [f.listing for f in features_list]
        
        serializer = ListingListSerializer(listings, many=True, context={'request': request})
        
        return Response({
            "results": serializer.data,
            "next": next_cursor
        })


class ReelsRecommendationsView(APIView):
    """
    Personalized Reels feed.
    """
    @method_decorator(never_cache)
    def get(self, request, *args, **kwargs):
        session_id = request.query_params.get("session_id", "")
        if not session_id:
            return Response({"detail": "session_id is required"}, status=status.HTTP_400_BAD_REQUEST)
            
        limit = int(request.query_params.get("limit", 10))
        cursor = request.query_params.get("cursor", None)
        
        context = RecommendationContext(
            user=request.user if request.user.is_authenticated else None,
            session_id=session_id,
            limit=limit,
            cursor=cursor,
            require_video=True
        )
        
        features_list, next_cursor = get_recommended_listings(context)
        listings = [f.listing for f in features_list]
        
        serializer = ListingReelsSerializer(listings, many=True, context={'request': request})
        
        return Response({
            "results": serializer.data,
            "next": next_cursor
        })


class RecommendationEventBatchView(APIView):
    """
    Receive batch analytics events for recommendation signals.
    """
    def post(self, request, *args, **kwargs):
        serializer = RecommendationEventBatchSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        events_data = serializer.validated_data['events']
        
        user = request.user if request.user.is_authenticated else None
        
        objs = []
        for ev in events_data:
            objs.append(RecommendationEvent(
                user=user,
                session_id=ev['session_id'],
                event_type=ev['event_type'],
                listing_id=ev.get('listing_id'),
                context=ev.get('context', {})
            ))
            
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
        
        context = RecommendationContext(
            user=request.user,
            session_id=session_id,
            limit=limit
        )
        
        features_list, _ = get_recommended_listings(context)
        
        debug_info = []
        for f in features_list:
            debug_info.append({
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
                }
            })
            
        return Response({
            "ranker_version": "v1",
            "results": debug_info
        })
