import pytest
from decimal import Decimal
from django.utils import timezone
from datetime import timedelta

from apps.recommendations.services import RecommendationContext, get_recommended_listings, TasteProfileService
from apps.recommendations.models import RecommendationEvent, InteractionType
from apps.users.models import User
from apps.catalog.models import Listing, City, District
from apps.catalog.enums import ListingStatus, PropertyKind, Currency

@pytest.mark.django_db
def test_new_user_feed_is_diverse_and_fresh():
    # Setup base data
    user, _ = User.objects.get_or_create(phone="+996555000000", defaults={"name": "Tester"})
    owner, _ = User.objects.get_or_create(phone="+996555111111", defaults={"name": "Owner"})
    city, _ = City.objects.get_or_create(slug="bishkek", defaults={"name": "Bishkek", "is_active": True})
    dist1, _ = District.objects.get_or_create(city=city, name="D1", slug="d1")
    dist2, _ = District.objects.get_or_create(city=city, name="D2", slug="d2")
    
    # Create 10 listings from dist1, 10 from dist2
    for i in range(20):
        Listing.objects.create(
            owner=owner,
            kind=PropertyKind.APARTMENT,
            district=dist1 if i % 2 == 0 else dist2,
            price=Decimal("100000"),
            currency=Currency.USD,
            status=ListingStatus.ACTIVE,
            published_at=timezone.now() - timedelta(days=i)
        )
        
    context = RecommendationContext(user=user, session_id="sess1", limit=10)
    features, _ = get_recommended_listings(context)
    
    assert len(features) == 10
    # Top ones should be fresher (lower i)
    # And there should be a mix of D1 and D2 due to diversifier limits
    d1_count = sum(1 for f in features if f.listing.district == dist1)
    d2_count = sum(1 for f in features if f.listing.district == dist2)
    
    # With streak limits (3), we expect almost equal distribution
    assert d1_count >= 3
    assert d2_count >= 3

@pytest.mark.django_db
def test_reels_watch_improves_score():
    user, _ = User.objects.get_or_create(phone="+996555000000", defaults={"name": "Tester"})
    city, _ = City.objects.get_or_create(slug="bishkek", defaults={"name": "Bishkek", "is_active": True})
    dist1, _ = District.objects.get_or_create(city=city, name="Asanbay", slug="asanbay")
    dist2, _ = District.objects.get_or_create(city=city, name="Center", slug="center")
    
    # User watched a reel for Asanbay 2-room
    listing_asanbay = Listing.objects.create(
        owner=user, district=dist1, rooms=2, kind=PropertyKind.APARTMENT, price=100000, status=ListingStatus.ACTIVE, published_at=timezone.now()
    )
    
    RecommendationEvent.objects.create(
        user=user, session_id="sess1", event_type=InteractionType.REEL_WATCH,
        listing=listing_asanbay, context={"watch_ratio": 0.95}
    )
    
    context = RecommendationContext(user=user, session_id="sess1", limit=5)
    profile = TasteProfileService.build_profile(context)
    
    assert dist1.id in profile["districts"]
    assert profile["districts"][dist1.id] > 0
    assert 2 in profile["rooms"]

@pytest.mark.django_db
def test_immediate_skip_negative_penalty():
    user, _ = User.objects.get_or_create(phone="+996555000000", defaults={"name": "Tester"})
    owner, _ = User.objects.get_or_create(phone="+996555111111", defaults={"name": "Owner"})
    city, _ = City.objects.get_or_create(slug="bishkek", defaults={"name": "Bishkek", "is_active": True})
    
    listing_skipped = Listing.objects.create(
        owner=owner, rooms=2, kind=PropertyKind.HOUSE, price=250000, status=ListingStatus.ACTIVE, published_at=timezone.now()
    )
    listing_other = Listing.objects.create(
        owner=owner, rooms=2, kind=PropertyKind.APARTMENT, price=100000, status=ListingStatus.ACTIVE, published_at=timezone.now()
    )
    
    RecommendationEvent.objects.create(
        user=user, session_id="sess1", event_type=InteractionType.REEL_SKIP,
        listing=listing_skipped
    )
    
    context = RecommendationContext(user=user, session_id="sess1", limit=5)
    features, _ = get_recommended_listings(context)
    
    scores = {f.listing.id: f.total_score for f in features}
    # Skipped listing should have much lower score due to negative penalty
    assert scores[listing_skipped.id] < scores[listing_other.id]
