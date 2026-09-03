import time
from django.core.management.base import BaseCommand
from django.test import RequestFactory
from apps.recommendations.services import RecommendationContext, get_recommended_listings
from apps.users.models import User
from django.db import connection, reset_queries

class Command(BaseCommand):
    help = "Benchmark the recommendations endpoint performance"

    def handle(self, *args, **kwargs):
        self.stdout.write("Running benchmark for recommendations...")
        from django.conf import settings
        settings.DEBUG = True
        
        user = User.objects.first()
        context = RecommendationContext(
            user=user,
            session_id="benchmark_session",
            limit=20
        )
        
        # Warmup
        get_recommended_listings(context)
        
        # Benchmark
        timings = []
        queries = []
        
        for i in range(5):
            reset_queries()
            start = time.time()
            features, _ = get_recommended_listings(context)
            end = time.time()
            
            # Serialize
            start_ser = time.time()
            listings = [f.listing for f in features]
            # Just touch properties to simulate serialization overhead if we don't use full serializer
            from apps.catalog.serializers import ListingListSerializer
            # Use a dummy request for context
            request = RequestFactory().get('/')
            if user:
                request.user = user
            serializer = ListingListSerializer(listings, many=True, context={'request': request})
            _ = serializer.data
            end_ser = time.time()
            
            timings.append({
                "total": (end_ser - start) * 1000,
                "rank": (end - start) * 1000,
                "serialize": (end_ser - start_ser) * 1000,
                "queries": len(connection.queries)
            })
            
        for i, t in enumerate(timings):
            self.stdout.write(f"Run {i+1}: Total {t['total']:.2f}ms (Rank {t['rank']:.2f}ms, Serialize {t['serialize']:.2f}ms), Queries: {t['queries']}")
