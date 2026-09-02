"""Публичный профиль продавца, отзывы и подтверждение агентства.

Рейтинг денормализован в `SellerProfile.rating`, но пересчитывается только
явным вызовом `recalc_seller_rating` — сигналом на каждое сохранение Review
он бы пересчитывался и на черновиках, и на отклонённых отзывах, и на любом
служебном touch записи.
"""

import logging
from decimal import ROUND_HALF_UP, Decimal
from typing import Any

from django.db import IntegrityError, transaction
from django.db.models import Avg, Count, Q
from django.utils import timezone

from apps.catalog.enums import ListingStatus
from apps.common.exceptions import ApiValidationError, ConflictError
from apps.users.models import (
    Review,
    ReviewStatus,
    SellerProfile,
    SellerVerification,
    User,
    VerificationStatus,
)

logger = logging.getLogger(__name__)

RATING_QUANT = Decimal("0.01")


def get_seller_profile(user: Any) -> SellerProfile:
    """Профиль продавца. Создаётся при первом обращении для pro-аккаунта."""
    profile, created = SellerProfile.objects.get_or_create(user=user)
    if created:
        logger.info("Заведён профиль продавца для пользователя %s", user.pk)
    return profile


def recalc_seller_rating(seller: Any) -> SellerProfile:
    """Пересчитывает рейтинг и число отзывов по опубликованным отзывам.

    Единственное место, где меняются `rating` и `reviews_count`: и публикация,
    и правка, и удаление отзыва зовут именно его.
    """
    profile = get_seller_profile(seller)

    aggregate = Review.objects.filter(seller=seller, status=ReviewStatus.PUBLISHED).aggregate(
        average=Avg("rating"),
        total=Count("pk"),
    )
    average = aggregate["average"] or 0
    profile.rating = Decimal(str(average)).quantize(RATING_QUANT, rounding=ROUND_HALF_UP)
    profile.reviews_count = aggregate["total"]
    profile.save(update_fields=["rating", "reviews_count", "updated_at"])

    logger.info(
        "Рейтинг продавца %s: %s по %s отзывам",
        getattr(seller, "pk", seller),
        profile.rating,
        profile.reviews_count,
    )
    return profile


@transaction.atomic
def create_review(
    seller: User,
    author: User,
    rating: int,
    text: str = "",
    listing: Any = None,
) -> Review:
    """Создаёт отзыв со статусом `pending` и ставит его в очередь модерации."""
    if seller.pk == author.pk:
        raise ApiValidationError("Нельзя оставить отзыв самому себе.")

    try:
        review = Review.objects.create(
            seller=seller,
            author=author,
            listing=listing,
            rating=rating,
            text=text,
            status=ReviewStatus.PENDING,
        )
    except IntegrityError as exc:
        # Уникальная пара (seller, author): менять свой отзыв нужно через PATCH.
        raise ConflictError(
            "Вы уже оставляли отзыв этому продавцу. Измените существующий."
        ) from exc

    from apps.catalog.moderation.services import enqueue_review_moderation

    enqueue_review_moderation(review)
    return review


@transaction.atomic
def update_review(review: Review, rating: int | None = None, text: str | None = None) -> Review:
    """Правка своего отзыва возвращает его на модерацию.

    Опубликованный текст нельзя подменить задним числом: иначе модерация
    проверяла бы одно, а читатели видели другое.
    """
    if rating is not None:
        review.rating = rating
    if text is not None:
        review.text = text

    was_published = review.is_published
    review.status = ReviewStatus.PENDING
    review.save(update_fields=["rating", "text", "status", "updated_at"])

    if was_published:
        # Отзыв ушёл из публикации — рейтинг пересчитываем сразу.
        recalc_seller_rating(review.seller)

    from apps.catalog.moderation.services import enqueue_review_moderation

    enqueue_review_moderation(review)
    return review


@transaction.atomic
def delete_review(review: Review) -> None:
    """Удаляет отзыв и возвращает рейтинг к состоянию без него."""
    seller = review.seller
    review.delete()
    recalc_seller_rating(seller)


@transaction.atomic
def publish_review(review: Review, moderator: Any = None, comment: str = "") -> Review:
    """Публикует отзыв и пересчитывает рейтинг продавца."""
    review.status = ReviewStatus.PUBLISHED
    review.moderator_comment = comment
    review.save(update_fields=["status", "moderator_comment", "updated_at"])

    recalc_seller_rating(review.seller)
    logger.info("Отзыв %s опубликован модератором %s", review.pk, getattr(moderator, "pk", None))
    return review


@transaction.atomic
def reject_review(review: Review, moderator: Any = None, comment: str = "") -> Review:
    """Отклоняет отзыв. Если он был опубликован — рейтинг пересчитывается."""
    was_published = review.is_published
    review.status = ReviewStatus.REJECTED
    review.moderator_comment = comment
    review.save(update_fields=["status", "moderator_comment", "updated_at"])

    if was_published:
        recalc_seller_rating(review.seller)

    logger.info("Отзыв %s отклонён модератором %s", review.pk, getattr(moderator, "pk", None))
    return review


def published_reviews(seller: Any) -> Any:
    """Отзывы, которые видит публика."""
    return (
        Review.objects.filter(seller=seller, status=ReviewStatus.PUBLISHED)
        .select_related("author", "listing")
        .order_by("-created_at")
    )


# -- публичная карточка продавца ---------------------------------------------


def active_listings_count(seller: Any) -> int:
    from apps.catalog.models import Listing

    return Listing.objects.filter(owner=seller, status=ListingStatus.ACTIVE).count()


def sold_listings_count(seller: Any) -> int:
    from apps.catalog.models import Listing

    return Listing.objects.filter(owner=seller, status=ListingStatus.SOLD).count()


def seller_listings(seller: Any, viewer: Any = None) -> Any:
    """Активные объявления продавца — тот же queryset, что и в каталоге."""
    from apps.catalog.services import listing_queryset

    return listing_queryset(viewer).filter(owner=seller)


def seller_card(seller: User, viewer: Any = None) -> dict[str, Any]:
    """Данные публичной карточки продавца.

    Контакты отдаются полностью только авторизованному: иначе страница
    продавца превращается в готовую выгрузку номеров.
    """
    from apps.users.phone import mask_public_phone

    profile = getattr(seller, "seller_profile", None)
    authenticated = bool(viewer and viewer.is_authenticated)

    return {
        "id": seller.pk,
        "name": seller.name,
        "company_name": profile.company_name if profile else "",
        "seller_kind": seller.seller_kind,
        "logo": profile.logo if profile else None,
        "avatar": seller.avatar,
        "profile_cover": seller.profile_cover,
        "about": profile.about if profile else "",
        "experience_years": profile.experience_years if profile else 0,
        "is_verified": bool(profile and profile.is_verified),
        "rating": profile.rating if profile else Decimal("0"),
        "reviews_count": profile.reviews_count if profile else 0,
        "active_listings_count": active_listings_count(seller),
        "sold_listings_count": sold_listings_count(seller),
        "member_since": seller.date_joined,
        "work_districts": list(profile.work_districts.all()) if profile else [],
        "working_hours": profile.working_hours if profile else {},
        "contacts": {
            "phone": seller.phone if authenticated else mask_public_phone(seller.phone),
            "whatsapp": (profile.whatsapp if profile else "") if authenticated else "",
            "telegram": (profile.telegram if profile else "") if authenticated else "",
            "instagram": profile.instagram if profile else "",
        },
    }


def public_sellers() -> Any:
    """Продавцы, чью страницу можно открыть.

    Удалённый аккаунт страницы не имеет — на неё ведут ссылки из старых
    объявлений, но показывать там нечего.
    """
    return User.objects.filter(is_active=True).select_related("seller_profile")


# -- подтверждение агентства -------------------------------------------------

MAX_VERIFICATION_DOCUMENTS = 10


def submit_seller_verification(seller: User, documents: list[Any]) -> SellerVerification:
    """Принимает документы агентства и заводит заявку модератору."""
    if not documents:
        raise ApiValidationError("Приложите хотя бы один документ.")

    if len(documents) > MAX_VERIFICATION_DOCUMENTS:
        raise ApiValidationError(
            f"За раз можно приложить не больше {MAX_VERIFICATION_DOCUMENTS} документов.",
            {"documents": len(documents)},
        )

    pending = SellerVerification.objects.filter(
        seller=seller, status=VerificationStatus.PENDING
    ).exists()
    if pending:
        raise ConflictError("Заявка уже на проверке. Дождитесь решения модератора.")

    stored = [_store_document(seller, document) for document in documents]

    verification = SellerVerification.objects.create(seller=seller, documents=stored)
    logger.info("Заявка на подтверждение продавца %s: документов %s", seller.pk, len(stored))
    return verification


def _store_document(seller: User, upload: Any) -> dict[str, str]:
    """Кладёт файл в хранилище под безымянным ключом.

    Имя файла с телефона может содержать ПДн («устав_Иванов.pdf»), поэтому
    в ключ оно не попадает — только расширение.
    """
    import uuid
    from pathlib import Path

    from django.core.files.storage import default_storage

    extension = Path(getattr(upload, "name", "") or "").suffix.lower()[:10]
    key = f"sellers/verification/{seller.pk}/{uuid.uuid4().hex}{extension}"
    saved = default_storage.save(key, upload)

    return {"path": saved, "size": str(getattr(upload, "size", 0))}


@transaction.atomic
def review_seller_verification(
    verification: SellerVerification,
    moderator: User,
    approved: bool,
    comment: str = "",
) -> SellerVerification:
    """Решение модератора. Одобрение ставит продавцу значок проверенного."""
    verification.status = VerificationStatus.APPROVED if approved else VerificationStatus.REJECTED
    verification.comment = comment
    verification.reviewed_by = moderator
    verification.reviewed_at = timezone.now()
    verification.save(update_fields=["status", "comment", "reviewed_by", "reviewed_at"])

    if approved:
        profile = get_seller_profile(verification.seller)
        profile.is_verified = True
        profile.verified_at = timezone.now()
        profile.save(update_fields=["is_verified", "verified_at", "updated_at"])

    return verification


# -- раскрытие контактов -----------------------------------------------------


def reveal_contact(listing: Any, user: User, ip_address: str | None = None) -> dict[str, str]:
    """Фиксирует раскрытие телефона и отдаёт контакты продавца."""
    from apps.catalog.stats import bump_stat
    from apps.users.models import ContactEvent

    owner = listing.owner
    profile = getattr(owner, "seller_profile", None)

    # Свои же нажатия не считаем: владелец не должен накручивать себе статистику.
    if owner.pk != user.pk:
        ContactEvent.objects.create(listing=listing, user=user, ip_address=ip_address)
        bump_stat(listing.pk, "phone_reveals")

    return {
        "phone": listing.contact_phone or owner.phone,
        "whatsapp": (profile.whatsapp if profile else "") or listing.contact_phone or owner.phone,
        "name": listing.contact_name or owner.name,
    }


def recent_contact_count(user: User, hours: int = 1) -> int:
    """Сколько номеров пользователь раскрыл за последние часы — для антифрода."""
    from datetime import timedelta

    from apps.users.models import ContactEvent

    since = timezone.now() - timedelta(hours=hours)
    return ContactEvent.objects.filter(user=user, created_at__gte=since).count()


def seller_review_stats(seller: Any) -> dict[str, int]:
    """Распределение оценок — гистограмма на экране «Профиль агента»."""
    rows = (
        Review.objects.filter(seller=seller, status=ReviewStatus.PUBLISHED)
        .values("rating")
        .annotate(total=Count("pk"))
    )
    distribution = {str(score): 0 for score in range(1, 6)}
    for row in rows:
        distribution[str(row["rating"])] = row["total"]
    return distribution


def sellers_with_reviews() -> Any:
    """Продавцы, у которых есть опубликованные отзывы."""
    return User.objects.annotate(
        published_reviews=Count("reviews_received", filter=Q(reviews_received__status="published"))
    ).filter(published_reviews__gt=0)
