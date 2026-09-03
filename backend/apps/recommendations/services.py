import math
from dataclasses import dataclass
from datetime import timedelta
from decimal import Decimal
from typing import List, Optional, Dict, Any, Tuple

from django.db.models import QuerySet, Q, F, Count, ExpressionWrapper, FloatField
from django.utils import timezone
from django.contrib.auth.models import AbstractUser

from apps.catalog.models import Listing, ListingStatus, PropertyKind
from apps.recommendations.models import RecommendationEvent, InteractionType
from apps.recommendations import constants


@dataclass
class RecommendationContext:
    user: Optional[AbstractUser]
    session_id: str
    limit: int = 20
    cursor: Optional[str] = None
    # For Reels
    current_listing_id: Optional[int] = None
    # Current active search/filters if any (dict)
    active_filters: Optional[Dict[str, Any]] = None
    require_video: bool = False

    @property
    def is_anonymous(self) -> bool:
        return self.user is None or not self.user.is_authenticated


class CandidateGenerator:
    """
    Generates a bounded pool of eligible candidates.
    A. current-search matching
    B. similar-to-recently-viewed
    C. favorites-neighborhood
    D. popular/high-quality in preferred segments
    E. fresh listings
    F. exploration candidates
    """
    def __init__(self, context: RecommendationContext):
        self.context = context

    def get_candidates(self) -> QuerySet[Listing]:
        # Start with hard eligibility rules
        base_qs = Listing.objects.alive().filter(
            status=ListingStatus.ACTIVE
        )
        
        if self.context.require_video:
            base_qs = base_qs.filter(media__kind='video').distinct()
        
        # Don't show owner's own listings
        if not self.context.is_anonymous:
            base_qs = base_qs.exclude(owner=self.context.user)

        # Exclude already explicitly disliked in this session/user
        if not self.context.is_anonymous:
            disliked = RecommendationEvent.objects.filter(
                user=self.context.user,
                event_type=InteractionType.NOT_INTERESTED
            ).values_list('listing_id', flat=True)
            base_qs = base_qs.exclude(id__in=disliked)
        else:
            disliked = RecommendationEvent.objects.filter(
                session_id=self.context.session_id,
                event_type=InteractionType.NOT_INTERESTED
            ).values_list('listing_id', flat=True)
            base_qs = base_qs.exclude(id__in=disliked)

        # For V1, we get a mix of fresh listings and some popularity
        # Real candidate generation would UNION different segments.
        # Since we cannot fetch everything, we fetch N latest and some random/diverse.
        
        # Fetch fresh
        fresh_qs = base_qs.order_by('-published_at')[:constants.MAX_CANDIDATES // 2]
        
        # Fetch promoted
        now = timezone.now()
        promoted_qs = base_qs.filter(promoted_until__gt=now).order_by('-bumped_at', '-published_at')[:constants.MAX_CANDIDATES // 4]
        
        # We can also do a broad search if active_filters are provided
        # (omitted for brevity, assume fresh + promoted + popular is the base pool)
        # To avoid performance issues in V1 without vector DB, we rely on the DB ordering.
        
        # Combine them (using union or |)
        combined = (fresh_qs | promoted_qs).distinct()
        
        # If we have less than MAX_CANDIDATES, add some older ones (exploration)
        # Actually, let's just query base_qs ordered by "-created_at" up to MAX_CANDIDATES.
        # It's simple and fast enough for V1.
        qs = base_qs.order_by('-bumped_at', '-published_at')[:constants.MAX_CANDIDATES]
        
        return qs.select_related('district', 'city', 'owner', 'series').prefetch_related('media')


@dataclass
class ListingFeatures:
    listing: Listing
    freshness_score: float = 0.0
    quality_score: float = 0.0
    promotion_score: float = 0.0
    popularity_score: float = 0.0
    
    # Personal matches
    price_match: float = 0.0
    location_match: float = 0.0
    rooms_match: float = 0.0
    property_type_match: float = 0.0
    
    # Negative
    negative_score: float = 0.0

    @property
    def total_score(self) -> float:
        content_score = self.quality_score * float(constants.WEIGHT_QUALITY) + \
                        self.freshness_score * float(constants.WEIGHT_FRESHNESS) + \
                        self.popularity_score * float(constants.WEIGHT_POPULARITY)
                        
        personal_score = self.price_match * float(constants.WEIGHT_PRICE_MATCH) + \
                         self.location_match * float(constants.WEIGHT_LOCATION_MATCH) + \
                         self.rooms_match * float(constants.WEIGHT_ROOMS_MATCH) + \
                         self.property_type_match * float(constants.WEIGHT_PROPERTY_TYPE)
                         
        business_score = self.promotion_score * float(constants.WEIGHT_PROMOTION)
        
        return content_score + personal_score + business_score + self.negative_score


class FeatureBuilder:
    """
    Extracts features for candidates based on user profile.
    """
    def __init__(self, context: RecommendationContext, user_profile: Dict[str, Any]):
        self.context = context
        self.user_profile = user_profile

    def build_features(self, listing: Listing) -> ListingFeatures:
        features = ListingFeatures(listing=listing)
        
        # Content features
        now = timezone.now()
        age_days = (now - (listing.published_at or listing.created_at)).days
        # Decay freshness
        features.freshness_score = math.exp(-age_days / 7.0) 
        
        # Quality
        q_score = 0.0
        if listing.description and len(listing.description) > 50:
            q_score += 0.5
        if listing.latitude and listing.longitude:
            q_score += 0.5
        features.quality_score = q_score
        
        # Promotion
        if listing.is_promoted:
            features.promotion_score = 1.0
            
        # Personal Match Features
        # Price Match
        pref_prices = self.user_profile.get("prices", [])
        if pref_prices and listing.price_usd:
            avg_price = sum(pref_prices) / len(pref_prices)
            # Soft distance: if distance is 0, score is 1. If distance is large, score is 0.
            distance = abs(float(listing.price_usd) - avg_price) / avg_price
            features.price_match = max(0.0, 1.0 - distance)
            
        # District Match
        pref_districts = self.user_profile.get("districts", {})
        if listing.district_id and listing.district_id in pref_districts:
            features.location_match = pref_districts[listing.district_id]
            
        # Rooms Match
        pref_rooms = self.user_profile.get("rooms", {})
        if listing.rooms in pref_rooms:
            features.rooms_match = pref_rooms[listing.rooms]
            
        # Property Type Match
        pref_types = self.user_profile.get("types", {})
        if listing.kind in pref_types:
            features.property_type_match = pref_types[listing.kind]
            
        # Negative signals (skip penalty, same seller handled in diversifier)
        # We could add recent skips here.
        skips = self.user_profile.get("skipped_listings", set())
        if listing.id in skips:
            features.negative_score += float(constants.WEIGHT_REEL_SKIP)
            
        return features


class Scorer:
    """
    Ranks candidates using feature builder and constants.
    """
    def __init__(self, feature_builder: FeatureBuilder):
        self.feature_builder = feature_builder

    def score(self, candidates: QuerySet[Listing]) -> List[ListingFeatures]:
        scored = []
        for candidate in candidates:
            features = self.feature_builder.build_features(candidate)
            scored.append(features)
        
        # Sort by total score descending
        scored.sort(key=lambda x: x.total_score, reverse=True)
        return scored


class Diversifier:
    """
    Ensures diversity in the final ranked list.
    Limits streaks of same seller, district, etc.
    Adds exploration candidates.
    """
    def apply(self, ranked_features: List[ListingFeatures], limit: int) -> List[ListingFeatures]:
        result = []
        
        seller_counts = {}
        district_counts = {}
        
        exploration_slots = int(limit * constants.EXPLORATION_RATIO)
        
        for feat in ranked_features:
            if len(result) >= limit:
                break
                
            seller_id = feat.listing.owner_id
            district_id = feat.listing.district_id
            
            s_count = seller_counts.get(seller_id, 0)
            d_count = district_counts.get(district_id, 0)
            
            if s_count >= constants.DIVERSITY_SELLER_STREAK_LIMIT:
                continue
                
            if d_count >= constants.DIVERSITY_DISTRICT_STREAK_LIMIT:
                continue
                
            # Accept candidate
            result.append(feat)
            seller_counts[seller_id] = s_count + 1
            if district_id:
                district_counts[district_id] = d_count + 1
                
        # If we are short (because we skipped too many), just fill with whatever we skipped
        if len(result) < limit:
            added = set(f.listing.id for f in result)
            for feat in ranked_features:
                if len(result) >= limit:
                    break
                if feat.listing.id not in added:
                    result.append(feat)
                    
        return result


class TasteProfileService:
    @staticmethod
    def build_profile(context: RecommendationContext) -> Dict[str, Any]:
        """
        Builds a lightweight in-memory taste profile from recent events.
        """
        profile = {
            "prices": [],
            "districts": {},
            "rooms": {},
            "types": {},
            "skipped_listings": set()
        }
        
        # Fetch events
        qs = RecommendationEvent.objects.select_related('listing').order_by('-created_at')
        if not context.is_anonymous:
            qs = qs.filter(user=context.user)
        else:
            qs = qs.filter(session_id=context.session_id)
            
        # Limit to recent history to avoid heavy processing
        events = qs[:100]
        
        for ev in events:
            weight = 1.0
            if ev.event_type == InteractionType.FAVORITE:
                weight = float(constants.WEIGHT_FAVORITE)
            elif ev.event_type == InteractionType.CHAT_STARTED:
                weight = float(constants.WEIGHT_CHAT_STARTED)
            elif ev.event_type == InteractionType.REEL_WATCH:
                ratio = ev.context.get("watch_ratio", 0)
                if ratio >= 0.9:
                    weight = float(constants.WEIGHT_REEL_WATCH_FULL)
                elif ratio >= 0.5:
                    weight = float(constants.WEIGHT_REEL_WATCH_HALF)
                else:
                    weight = float(constants.WEIGHT_IMPRESSION)
            elif ev.event_type == InteractionType.REEL_SKIP:
                profile["skipped_listings"].add(ev.listing_id)
                weight = -1.0 # Will be used for negative decay
            
            if ev.listing:
                if ev.listing.price_usd and weight > 0:
                    profile["prices"].append(float(ev.listing.price_usd))
                    
                dist_id = ev.listing.district_id
                if dist_id:
                    profile["districts"][dist_id] = profile["districts"].get(dist_id, 0) + weight
                    
                rooms = ev.listing.rooms
                if rooms is not None:
                    profile["rooms"][rooms] = profile["rooms"].get(rooms, 0) + weight
                    
                kind = ev.listing.kind
                if kind:
                    profile["types"][kind] = profile["types"].get(kind, 0) + weight
                    
        # Normalize weights (softmax or simple max ratio)
        for key in ["districts", "rooms", "types"]:
            if profile[key]:
                max_val = max(profile[key].values())
                if max_val > 0:
                    for k in profile[key]:
                        profile[key][k] /= max_val
                        
        return profile


def get_recommended_listings(context: RecommendationContext) -> Tuple[List[ListingFeatures], str]:
    """
    Main entry point for fetching recommended listings.
    Returns ranked features and a cursor for next page.
    """
    profile = TasteProfileService.build_profile(context)
    
    generator = CandidateGenerator(context)
    candidates = generator.get_candidates()
    
    builder = FeatureBuilder(context, profile)
    scorer = Scorer(builder)
    
    scored = scorer.score(candidates)
    
    diversifier = Diversifier()
    final = diversifier.apply(scored, context.limit)
    
    # Cursor logic for V1: since we rerank a dynamic pool, cursor could just be offset.
    # A real cursor would probably store the seen IDs in the session.
    # For now, just offset.
    next_cursor = None
    if len(final) == context.limit:
        next_cursor = "next_page" # Dummy for now
        
    return final, next_cursor
