from decimal import Decimal

# Weights for different interaction events
WEIGHT_SEARCH_MATCH = Decimal("1.0")
WEIGHT_IMPRESSION = Decimal("0.1")
WEIGHT_VIEW_LISTING = Decimal("2.0")
WEIGHT_LONG_DWELL = Decimal("3.0")
WEIGHT_REEL_WATCH_HALF = Decimal("2.0")
WEIGHT_REEL_WATCH_FULL = Decimal("4.0")
WEIGHT_REEL_REPLAY = Decimal("4.0")
WEIGHT_FAVORITE = Decimal("6.0")
WEIGHT_SELLER_PROFILE = Decimal("4.0")
WEIGHT_CONTACT = Decimal("7.0")
WEIGHT_CHAT_STARTED = Decimal("10.0")

WEIGHT_REEL_SKIP = Decimal("-3.0")
WEIGHT_NOT_INTERESTED = Decimal("-10.0")
WEIGHT_SAME_SELLER_PENALTY = Decimal("-2.0")

# Content qualities
WEIGHT_FRESHNESS = Decimal("2.0")
WEIGHT_QUALITY = Decimal("1.5")
WEIGHT_POPULARITY = Decimal("0.5")
WEIGHT_PROMOTION = Decimal("1.0")

# Similarity matches
WEIGHT_PRICE_MATCH = Decimal("2.0")
WEIGHT_LOCATION_MATCH = Decimal("3.0")
WEIGHT_ROOMS_MATCH = Decimal("2.0")
WEIGHT_PROPERTY_TYPE = Decimal("4.0")

# Decay
# Half-life in days for long-term profile
DECAY_HALF_LIFE_DAYS = 14
# Half-life in minutes for short-term session intent
SESSION_HALF_LIFE_MINUTES = 30

# Bounds
MAX_CANDIDATES = 200
DIVERSITY_SELLER_STREAK_LIMIT = 2
DIVERSITY_DISTRICT_STREAK_LIMIT = 3
EXPLORATION_RATIO = 0.15
