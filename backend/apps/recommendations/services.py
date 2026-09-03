import math
from dataclasses import dataclass
from datetime import timedelta
from decimal import Decimal
from typing import List, Optional, Dict, Any, Tuple

from django.db import models
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
    feed_session_id: str = "default"
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
        """Generate base pool of valid listings."""
        base_qs = Listing.objects.filter(status=ListingStatus.ACTIVE)
        
        if self.context.require_video:
            base_qs = base_qs.filter(media__kind="video").distinct()
            
        if self.context.user:
            base_qs = base_qs.exclude(owner=self.context.user)
            
        # Exclude seen or rejected items in this specific feed session
        # This guarantees stable sequencing without duplicates if client requests page 2
        # Or across the broader session for NOT_INTERESTED/SKIPS
        excluded_ids = set()
        
        # 1. Broad session exclusions (skips, not interested)
        q_session = models.Q(session_id=self.context.session_id)
        if self.context.user:
            q_session |= models.Q(user=self.context.user)
            
        excluded_ids.update(
            RecommendationEvent.objects.filter(
                q_session,
                event_type__in=[InteractionType.NOT_INTERESTED, InteractionType.REEL_SKIP],
                listing__isnull=False
            ).values_list('listing_id', flat=True)
        )
        
        # 2. Feed session specific seen
        if self.context.feed_session_id and self.context.feed_session_id != "default":
            excluded_ids.update(
                RecommendationEvent.objects.filter(
                    feed_session_id=self.context.feed_session_id,
                    event_type__in=[InteractionType.REEL_IMPRESSION, InteractionType.VIEW_LISTING],
                    listing__isnull=False
                ).values_list('listing_id', flat=True)
            )
            
        if excluded_ids:
            base_qs = base_qs.exclude(id__in=excluded_ids)
            
        # Fetch fresh and bumped items
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
            
        # Popularity (Saturated)
        if hasattr(listing, 'views') and listing.views:
            features.popularity_score = math.log1p(listing.views) / 10.0 # Normalize roughly
            if features.popularity_score > 1.0:
                features.popularity_score = 1.0
                
        # Personal Match Features
        # Price Match
        pref_prices = self.user_profile.get("prices_by_kind", {}).get(listing.kind, [])
        if pref_prices and listing.price_usd:
            avg_price = sum(pref_prices) / len(pref_prices)
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
    Adds explicit deterministic exploration candidates.
    """
    def apply(self, ranked_features: List[ListingFeatures], limit: int, context: RecommendationContext) -> List[ListingFeatures]:
        import hashlib
        
        result = []
        exploration_slots = int(limit * constants.EXPLORATION_RATIO)
        core_limit = limit - exploration_slots
        
        seller_counts = {}
        district_counts = {}
        
        exploration_pool = []
        core_pool = []
        
        # Split ranked features roughly by score threshold or top N
        top_n = max(core_limit * 2, len(ranked_features) // 3)
        core_candidates = ranked_features[:top_n]
        exploration_candidates = ranked_features[top_n:]
        
        # Select core
        for feat in core_candidates:
            if len(core_pool) >= core_limit:
                break
                
            seller_id = feat.listing.owner_id
            district_id = feat.listing.district_id
            
            s_count = seller_counts.get(seller_id, 0)
            d_count = district_counts.get(district_id, 0)
            
            if s_count >= constants.DIVERSITY_SELLER_STREAK_LIMIT:
                continue
                
            if d_count >= constants.DIVERSITY_DISTRICT_STREAK_LIMIT:
                continue
                
            seller_counts[seller_id] = s_count + 1
            district_counts[district_id] = d_count + 1
            core_pool.append(feat)
            
        # Select exploration deterministically
        if exploration_candidates:
            seed_str = f"{context.user.id if context.user else 'anon'}:{context.feed_session_id}"
            seed = int(hashlib.md5(seed_str.encode()).hexdigest()[:8], 16)
            
            # Sort deterministically using the seed and listing id
            exploration_candidates.sort(
                key=lambda f: (hashlib.md5(f"{seed}:{f.listing.id}".encode()).hexdigest(), f.total_score),
                reverse=True
            )
            
            for feat in exploration_candidates:
                if len(exploration_pool) >= exploration_slots:
                    break
                    
                seller_id = feat.listing.owner_id
                district_id = feat.listing.district_id
                
                s_count = seller_counts.get(seller_id, 0)
                d_count = district_counts.get(district_id, 0)
                
                if s_count >= constants.DIVERSITY_SELLER_STREAK_LIMIT:
                    continue
                    
                if d_count >= constants.DIVERSITY_DISTRICT_STREAK_LIMIT:
                    continue
                    
                seller_counts[seller_id] = s_count + 1
                district_counts[district_id] = d_count + 1
                exploration_pool.append(feat)
        
        # Mix them
        result = core_pool + exploration_pool
        
        # We might have less than limit, if so fill from remaining
        if len(result) < limit:
            seen_ids = {f.listing.id for f in result}
            for feat in ranked_features:
                if len(result) >= limit:
                    break
                if feat.listing.id not in seen_ids:
                    result.append(feat)
                    seen_ids.add(feat.listing.id)
                    
        return result


class TasteProfileService:
    @staticmethod
    def build_profile(context: RecommendationContext) -> Dict[str, Any]:
        """
        Builds a lightweight in-memory taste profile from recent events.
        """
        profile = {
            "prices_by_kind": {},
            "districts": {},
            "rooms": {},
            "types": {},
            "skipped_listings": set()
        }
        
        # Fetch events
        from apps.engagement.models import Favourite, ViewHistory
        
        event_qs = RecommendationEvent.objects.all()
        if context.user:
            event_qs = event_qs.filter(
                models.Q(user=context.user) | models.Q(session_id=context.session_id)
            )
        else:
            event_qs = event_qs.filter(session_id=context.session_id)
            
        # Get raw events
        events = event_qs.select_related('listing', 'listing__district').order_by('-created_at')[:500]
        
        # Aggregate real domain signals for users
        domain_favorites = []
        domain_views = []
        if context.user:
            # Add canonical favorites
            domain_favorites = list(Favourite.objects.filter(user=context.user).select_related('listing', 'listing__district')[:100])
            # Add canonical views
            domain_views = list(ViewHistory.objects.filter(user=context.user).select_related('listing', 'listing__district').order_by('-viewed_at')[:100])
            
        import math
        from django.utils import timezone
        
        now = timezone.now()
        
        def _get_decayed_weight(base_w, dt, half_life_days=constants.DECAY_HALF_LIFE_DAYS):
            if not dt:
                return base_w
            days_old = (now - dt).total_seconds() / 86400.0
            if days_old < 0:
                days_old = 0
            decay = math.pow(0.5, days_old / half_life_days)
            return base_w * decay
            
        for fav in domain_favorites:
            listing = fav.listing
            weight = _get_decayed_weight(float(constants.WEIGHT_FAVORITE), fav.created_at)
            if listing.price_usd:
                profile["prices_by_kind"].setdefault(listing.kind, []).append(float(listing.price_usd))
            
            d_id = listing.district_id
            if d_id:
                profile["districts"][d_id] = profile["districts"].get(d_id, 0) + weight
                
            r = listing.rooms
            if r:
                profile["rooms"][r] = profile["rooms"].get(r, 0) + weight
                
            profile["types"][listing.kind] = profile["types"].get(listing.kind, 0) + weight
            
        for view in domain_views:
            listing = view.listing
            weight = _get_decayed_weight(float(constants.WEIGHT_VIEW_LISTING), view.viewed_at)
            if listing.price_usd:
                profile["prices_by_kind"].setdefault(listing.kind, []).append(float(listing.price_usd))
            
            d_id = listing.district_id
            if d_id:
                profile["districts"][d_id] = profile["districts"].get(d_id, 0) + weight
                
            r = listing.rooms
            if r:
                profile["rooms"][r] = profile["rooms"].get(r, 0) + weight
                
            profile["types"][listing.kind] = profile["types"].get(listing.kind, 0) + weight
            
        # Process session events
        for ev in events:
            weight = 1.0
            if ev.event_type == InteractionType.SEARCH:
                weight = float(constants.WEIGHT_SEARCH_MATCH)
                filters = ev.context.get("filters", {})
                
                # Apply time decay
                is_current_session = (ev.session_id == context.session_id)
                half_life_days = constants.SESSION_HALF_LIFE_MINUTES / 1440.0 if is_current_session else constants.DECAY_HALF_LIFE_DAYS
                weight = _get_decayed_weight(weight, ev.created_at, half_life_days=half_life_days)
                
                if "district" in filters:
                    d_id = filters["district"]
                    profile["districts"][d_id] = profile["districts"].get(d_id, 0) + weight
                if "rooms" in filters:
                    r = filters["rooms"]
                    profile["rooms"][r] = profile["rooms"].get(r, 0) + weight
                if "price_min" in filters and "price_max" in filters:
                    avg_p = (float(filters["price_min"]) + float(filters["price_max"])) / 2.0
                    kind = filters.get("property_type", "apartment") # fallback
                    profile["prices_by_kind"].setdefault(kind, []).append(avg_p)
                if "property_type" in filters:
                    kind = filters["property_type"]
                    profile["types"][kind] = profile["types"].get(kind, 0) + weight
                continue
                
            if ev.event_type == InteractionType.FAVORITE:
                weight = float(constants.WEIGHT_FAVORITE)
            elif ev.event_type == InteractionType.CHAT_STARTED:
                weight = float(constants.WEIGHT_CHAT_STARTED)
            elif ev.event_type == InteractionType.CONTACT:
                weight = float(constants.WEIGHT_CONTACT)
            elif ev.event_type == InteractionType.VIEW_LISTING:
                weight = float(constants.WEIGHT_VIEW_LISTING)
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
                
            # Apply time decay
            is_current_session = (ev.session_id == context.session_id)
            if is_current_session:
                half_life_days = constants.SESSION_HALF_LIFE_MINUTES / 1440.0
            else:
                half_life_days = constants.DECAY_HALF_LIFE_DAYS
                
            weight = _get_decayed_weight(weight, ev.created_at, half_life_days=half_life_days)
            
            if ev.listing:
                if ev.listing.price_usd and weight > 0:
                    profile["prices_by_kind"].setdefault(ev.listing.kind, []).append(float(ev.listing.price_usd))
                    
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
    final = diversifier.apply(scored, context.limit, context)
    
    # Cursor logic: since we exclude seen items in CandidateGenerator for the feed session,
    # we don't need offset.
    next_cursor = None
    if len(final) == context.limit:
        next_cursor = "next"
        
    return final, next_cursor
