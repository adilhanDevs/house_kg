from django.conf import settings
from django.db import models
from django.utils import timezone

from apps.common.models import TimeStampedModel


class InteractionType(models.TextChoices):
    # Core catalog
    SEARCH = "search", "Search"
    VIEW_LISTING = "view", "View Listing"
    FAVORITE = "favorite", "Favorite"
    SELLER_PROFILE = "seller_profile", "View Seller Profile"
    CONTACT = "contact", "Reveal Contact"
    CHAT_STARTED = "chat", "Chat Started"

    # Reels
    REEL_IMPRESSION = "reel_impression", "Reel Impression"
    REEL_WATCH = "reel_watch", "Reel Watch"
    REEL_SKIP = "reel_skip", "Immediate Skip"
    REEL_REPLAY = "reel_replay", "Reel Replay"

    # Negative
    NOT_INTERESTED = "not_interested", "Not Interested"


class RecommendationEvent(models.Model):
    """
    Unified interaction events for the recommendation engine.
    Used to build short-term session context and long-term user taste profile.
    """

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="recommendation_events",
    )
    session_id = models.CharField("Session ID", max_length=128, db_index=True)
    feed_session_id = models.CharField("Feed Session ID", max_length=128, blank=True, db_index=True)

    listing = models.ForeignKey(
        "catalog.Listing",
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="recommendation_events",
    )

    event_type = models.CharField(max_length=32, choices=InteractionType.choices, db_index=True)

    # Context data for specific events
    # e.g., watch_ratio for REEL_WATCH, or search parameters for SEARCH
    context = models.JSONField(default=dict, blank=True)

    # For idempotency from client
    client_event_id = models.UUIDField("Client Event ID", null=True, blank=True, db_index=True)

    created_at = models.DateTimeField("Created at", default=timezone.now, db_index=True)

    class Meta:
        verbose_name = "Recommendation Event"
        verbose_name_plural = "Recommendation Events"
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["client_event_id"],
                condition=models.Q(client_event_id__isnull=False),
                name="recommendation_event_unique_client_id",
            )
        ]
        indexes = [
            models.Index(fields=["user", "created_at"]),
            models.Index(fields=["session_id", "created_at"]),
            models.Index(fields=["listing", "created_at"]),
            models.Index(fields=["event_type", "created_at"]),
        ]

    def __str__(self) -> str:
        identifier = self.user if self.user_id else self.session_id
        return f"{identifier} -> {self.event_type} on {self.listing_id or 'none'}"


class UserTasteProfile(TimeStampedModel):
    """
    Materialized/Cached taste profile for a user.
    Can be recomputed periodically or on demand.
    """

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="taste_profile"
    )
    # E.g. {"sale": 0.9, "rent": 0.1}
    deal_type_weights = models.JSONField(default=dict, blank=True)
    # E.g. {"apartment": 0.8, "house": 0.2}
    property_type_weights = models.JSONField(default=dict, blank=True)
    # E.g. {"1": 0.1, "2": 0.5, "3": 0.4}
    rooms_distribution = models.JSONField(default=dict, blank=True)
    # E.g. {"district_slug": 0.5}
    district_weights = models.JSONField(default=dict, blank=True)
    # Soft price preferences
    price_p25 = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    price_p75 = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)

    # System metadata
    last_computed_at = models.DateTimeField(null=True, blank=True)
    version = models.CharField(max_length=32, default="v1")

    class Meta:
        verbose_name = "User Taste Profile"
        verbose_name_plural = "User Taste Profiles"

    def __str__(self) -> str:
        return f"Taste profile for {self.user}"
