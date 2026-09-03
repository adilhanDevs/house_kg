from django.urls import path
from apps.recommendations.views import (
    ListingRecommendationsView,
    ReelsRecommendationsView,
    RecommendationEventBatchView,
    RecommendationDebugView,
)

app_name = "recommendations"

urlpatterns = [
    path("recommendations/listings/", ListingRecommendationsView.as_view(), name="listing-recommendations"),
    path("recommendations/reels/", ReelsRecommendationsView.as_view(), name="reels-recommendations"),
    path("recommendations/events/", RecommendationEventBatchView.as_view(), name="recommendation-events"),
    path("recommendations/debug/", RecommendationDebugView.as_view(), name="recommendation-debug"),
]
