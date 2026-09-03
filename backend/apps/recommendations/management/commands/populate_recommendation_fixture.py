import random
from datetime import timedelta
from decimal import Decimal
from django.core.management.base import BaseCommand
from django.utils import timezone
from apps.users.models import User
from apps.catalog.models import Listing, City, District, HouseSeries, Builder, ListingMedia
from apps.catalog.enums import ListingStatus, PropertyKind, Currency, MediaKind, MediaStatus

class Command(BaseCommand):
    help = "Populate golden dataset for recommendations"

    def handle(self, *args, **kwargs):
        self.stdout.write("Populating golden dataset...")
        
        # Ensure we have a user
        user, _ = User.objects.get_or_create(phone="+996555123456", defaults={"name": "TestUser"})
        owner1, _ = User.objects.get_or_create(phone="+996555111111", defaults={"name": "Seller1"})
        owner2, _ = User.objects.get_or_create(phone="+996555222222", defaults={"name": "Seller2"})
        
        city, _ = City.objects.get_or_create(name="Бишкек", slug="bishkek", is_active=True)
        district_asanbay, _ = District.objects.get_or_create(city=city, name="Асанбай", slug="asanbay", latitude=42.8, longitude=74.6)
        district_center, _ = District.objects.get_or_create(city=city, name="Центр", slug="center", latitude=42.87, longitude=74.59)
        
        now = timezone.now()
        
        # Create 50 listings
        for i in range(50):
            owner = owner1 if i % 2 == 0 else owner2
            dist = district_asanbay if i % 3 == 0 else district_center
            kind = PropertyKind.APARTMENT if i % 5 != 0 else PropertyKind.HOUSE
            rooms = 2 if i % 2 == 0 else (3 if i % 3 == 0 else 1)
            
            base_price = 80000 + (i * 1000)
            
            listing = Listing.objects.create(
                owner=owner,
                kind=kind,
                city=city,
                district=dist,
                price=Decimal(str(base_price)),
                currency=Currency.USD,
                rooms=rooms,
                status=ListingStatus.ACTIVE,
                published_at=now - timedelta(days=i % 10),
                promoted_until=now + timedelta(days=1) if i % 7 == 0 else None
            )
            
            # Add media (video for Reels test)
            if i % 2 == 0:
                ListingMedia.objects.create(
                    listing=listing,
                    kind=MediaKind.VIDEO,
                    status=MediaStatus.READY,
                    file="test_video.mp4",
                    order=1
                )
            ListingMedia.objects.create(
                listing=listing,
                kind=MediaKind.PHOTO,
                status=MediaStatus.READY,
                file="test_photo.jpg",
                is_cover=True,
                order=0
            )
            
        self.stdout.write("Created 50 listings.")
