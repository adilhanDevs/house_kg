"""Модерация объявлений: автопроверки, очередь, решения и жалобы."""

from decimal import Decimal

import pytest
from django.urls import reverse
from rest_framework_simplejwt.tokens import RefreshToken

from apps.catalog.enums import ListingStatus, MediaKind, ModerationStatus, ReportReason
from apps.catalog.models import ListingReport, ModerationTask, RejectReason
from apps.catalog.moderation import checks
from apps.catalog.services import publish_listing
from tests.factories import (
    DistrictFactory,
    ListingFactory,
    ListingMediaFactory,
    UserFactory,
)

pytestmark = pytest.mark.django_db


@pytest.fixture
def moderator():
    return UserFactory(is_staff=True)


@pytest.fixture
def moderator_client(api_client, moderator):
    token = RefreshToken.for_user(moderator)
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token.access_token}")
    return api_client


def client_for(user):
    """Отдельный клиент на пользователя.

    Именно отдельный: `api_client` — общая фикстура, и переиспользование её
    объекта незаметно перелогинивало бы модератора в очередного жалобщика.
    """
    from rest_framework.test import APIClient

    client = APIClient()
    token = RefreshToken.for_user(user)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {token.access_token}")
    return client


# -- 1. Контакты в тексте ----------------------------------------------------


def test_phone_in_description_is_flagged():
    listing = ListingFactory(description="Срочно, звоните 0555123456")

    result = checks.contacts_in_text(listing)

    assert result.triggered is True
    assert result.details["phones"]


def test_plain_text_without_contacts_is_not_flagged():
    listing = ListingFactory(description="Звоните мне, покажу квартиру в любой день")

    assert checks.contacts_in_text(listing).triggered is False


@pytest.mark.parametrize(
    "text",
    [
        "тел 0 555 12 34 56",
        "+996(555)123-456",
        "пишите в WhatsApp",
        "мой телеграм @kvartira_bishkek",
        "подробности на example.kg",
        "звоните ноль пятьсот пятьдесят пять сто двадцать три",
    ],
)
def test_contact_variants_are_flagged(text: str):
    assert checks.contacts_in_text(ListingFactory(description=text)).triggered is True


@pytest.mark.parametrize(
    "text",
    [
        "Квартира 80 кв м, 3 комнаты, 5 этаж из 9",
        "Дом 2019 года постройки, участок 6 соток",
        "Рядом школа №61 и детский сад",
    ],
)
def test_ordinary_numbers_do_not_trigger(text: str):
    """Площадь, этажность и год постройки — не телефоны."""
    assert checks.contacts_in_text(ListingFactory(description=text)).triggered is False


def test_contacts_are_searched_in_address_too():
    listing = ListingFactory(description="", address="Асанбай 12, звонить 0700112233")

    assert checks.contacts_in_text(listing).triggered is True


# -- 2. Выброс по цене -------------------------------------------------------


def make_peers(district, count: int, price: str = "100000.00") -> None:
    """Соседи по району: активные, с ценой и площадью."""
    from django.utils import timezone

    for index in range(count):
        ListingFactory(
            district=district,
            city=district.city,
            status=ListingStatus.ACTIVE,
            published_at=timezone.now(),
            price=Decimal(price),
            price_usd=Decimal(price) + index,  # немного разброса, иначе сигма нулевая
            area=Decimal("80.00"),
        )


def test_price_ten_times_median_is_flagged():
    district = DistrictFactory()
    make_peers(district, 12)
    listing = ListingFactory(
        district=district,
        city=district.city,
        price=Decimal("1000000.00"),
        price_usd=Decimal("1000000.00"),
        area=Decimal("80.00"),
    )

    result = checks.price_outlier(listing)

    assert result.triggered is True
    assert result.details["deviation"] > 3
    assert result.details["peers"] == 12


def test_price_check_is_skipped_with_few_peers():
    """На девяти объектах медиана района ничего не значит."""
    district = DistrictFactory()
    make_peers(district, 9)
    listing = ListingFactory(
        district=district,
        city=district.city,
        price=Decimal("1000000.00"),
        price_usd=Decimal("1000000.00"),
        area=Decimal("80.00"),
    )

    result = checks.price_outlier(listing)

    assert result.triggered is False
    assert result.details["skipped"] == "мало объектов в районе"
    assert result.details["peers"] == 9


def test_normal_price_is_not_flagged():
    district = DistrictFactory()
    make_peers(district, 12)
    listing = ListingFactory(
        district=district,
        city=district.city,
        price=Decimal("101000.00"),
        price_usd=Decimal("101000.00"),
        area=Decimal("80.00"),
    )

    assert checks.price_outlier(listing).triggered is False


# -- 3. Дубликат объявления --------------------------------------------------


def test_same_object_from_another_user_is_flagged():
    district = DistrictFactory()
    original = ListingFactory(
        district=district,
        city=district.city,
        status=ListingStatus.ACTIVE,
        price=Decimal("100000.00"),
        area=Decimal("80.00"),
    )
    copy = ListingFactory(
        district=district,
        city=district.city,
        price=Decimal("101000.00"),  # +1 %, попадает в допуск ±3 %
        area=Decimal("81.00"),  # +1 м², попадает в допуск ±2 м²
        rooms=original.rooms,
        floor=original.floor,
    )

    result = checks.duplicate_listing(copy)

    assert result.triggered is True
    assert original.slug in result.details["listings"]


def test_own_second_listing_is_not_a_duplicate():
    """Совпадение у одного владельца — правка, а не переклейка."""
    district = DistrictFactory()
    owner = UserFactory()
    first = ListingFactory(
        owner=owner,
        district=district,
        city=district.city,
        status=ListingStatus.ACTIVE,
        price=Decimal("100000.00"),
        area=Decimal("80.00"),
    )
    second = ListingFactory(
        owner=owner,
        district=district,
        city=district.city,
        price=Decimal("100000.00"),
        area=Decimal("80.00"),
        rooms=first.rooms,
        floor=first.floor,
    )

    assert checks.duplicate_listing(second).triggered is False


# -- 4. Дубликат фотографий --------------------------------------------------


def test_same_photo_in_two_listings_is_flagged():
    phash = "805d447f40775577"
    stranger = ListingFactory(status=ListingStatus.ACTIVE)
    ListingMediaFactory(listing=stranger, phash=phash, kind=MediaKind.PHOTO)

    listing = ListingFactory()
    ListingMediaFactory(listing=listing, phash=phash, kind=MediaKind.PHOTO)

    result = checks.duplicate_photos(listing)

    assert result.triggered is True
    assert result.details["matches"][0]["listing"] == stranger.slug
    assert result.details["matches"][0]["distance"] == 0


def test_different_photos_are_not_flagged():
    ListingMediaFactory(
        listing=ListingFactory(status=ListingStatus.ACTIVE), phash="0000000000000000"
    )
    listing = ListingFactory()
    ListingMediaFactory(listing=listing, phash="ffffffffffffffff")

    assert checks.duplicate_photos(listing).triggered is False


def test_own_photo_reused_is_not_flagged():
    owner = UserFactory()
    phash = "805d447f40775577"
    ListingMediaFactory(
        listing=ListingFactory(owner=owner, status=ListingStatus.ACTIVE), phash=phash
    )
    listing = ListingFactory(owner=owner)
    ListingMediaFactory(listing=listing, phash=phash)

    assert checks.duplicate_photos(listing).triggered is False


def test_hamming_distance():
    assert checks.hamming_distance("00", "00") == 0
    assert checks.hamming_distance("00", "01") == 1
    assert checks.hamming_distance("0f", "00") == 4
    # Несравнимые значения не должны выглядеть как совпадение.
    assert checks.hamming_distance("", "00") == 64
    assert checks.hamming_distance("zz", "00") == 64


# -- очередь и решения -------------------------------------------------------


def publishable_listing(**kwargs):
    """Объявление, готовое к публикации: заполнено и с фотографией."""
    listing = ListingFactory(status=ListingStatus.DRAFT, **kwargs)
    ListingMediaFactory(listing=listing, kind=MediaKind.PHOTO, is_cover=True)
    return listing


def test_publish_creates_moderation_task(django_capture_on_commit_callbacks):
    listing = publishable_listing(description="Звоните 0555123456")

    with django_capture_on_commit_callbacks(execute=True):
        publish_listing(listing)

    listing.refresh_from_db()
    task = ModerationTask.objects.get(listing=listing)
    assert listing.status == ListingStatus.PENDING
    assert task.status == ModerationStatus.OPEN
    # Автопроверки отработали и подняли приоритет.
    assert task.checks["contacts_in_text"]["triggered"] is True
    assert task.priority >= 1


def test_rejected_listing_is_absent_from_catalog(api_client, moderator_client, moderator):
    listing = publishable_listing()
    publish_listing(listing)
    task = ModerationTask.objects.get(listing=listing)

    response = moderator_client.post(
        reverse("catalog:moderation-reject", args=[task.pk]),
        {"reason_code": "contacts", "comment": "Уберите телефон из описания"},
        format="json",
    )
    assert response.status_code == 200, response.data

    listing.refresh_from_db()
    assert listing.status == ListingStatus.REJECTED
    assert "Контакты в описании" in listing.rejection_reason
    assert "Уберите телефон" in listing.rejection_reason

    api_client.credentials()
    catalog = api_client.get(reverse("catalog:listings"))
    assert listing.slug not in [item["slug"] for item in catalog.data["results"]]


def test_resubmission_creates_new_task(moderator_client):
    """Исправленное объявление уходит на новую проверку, старая остаётся историей."""
    listing = publishable_listing(description="Звоните 0555123456")
    publish_listing(listing)
    first = ModerationTask.objects.get(listing=listing)

    moderator_client.post(
        reverse("catalog:moderation-reject", args=[first.pk]),
        {"reason_code": "contacts", "comment": ""},
        format="json",
    )

    # Владелец правит описание и подаёт заново.
    owner_client = client_for(listing.owner)
    patched = owner_client.patch(
        reverse("catalog:listing-detail", args=[listing.slug]),
        {"description": "Светлая квартира, рядом парк"},
        format="json",
    )
    assert patched.status_code == 200, patched.data

    listing.refresh_from_db()
    publish_listing(listing)

    tasks = ModerationTask.objects.filter(listing=listing).order_by("pk")
    assert tasks.count() == 2
    assert tasks[0].status == ModerationStatus.REJECTED
    assert tasks[1].status == ModerationStatus.OPEN


def test_approve_publishes_and_notifies(moderator_client, moderator):
    from apps.notifications.models import Notification, NotificationType

    listing = publishable_listing()
    publish_listing(listing)
    task = ModerationTask.objects.get(listing=listing)

    response = moderator_client.post(reverse("catalog:moderation-approve", args=[task.pk]))

    assert response.status_code == 200, response.data
    listing.refresh_from_db()
    task.refresh_from_db()
    assert listing.status == ListingStatus.ACTIVE
    assert listing.published_at is not None
    assert (listing.expires_at - listing.published_at).days == 30
    assert task.status == ModerationStatus.APPROVED
    assert task.resolved_by_id == moderator.pk

    notification = Notification.objects.get(user=listing.owner)
    assert notification.type == NotificationType.LISTING_MODERATED
    assert notification.payload["result"] == "approved"


def test_second_decision_on_closed_task_is_conflict(moderator_client):
    listing = publishable_listing()
    publish_listing(listing)
    task = ModerationTask.objects.get(listing=listing)

    moderator_client.post(reverse("catalog:moderation-approve", args=[task.pk]))
    again = moderator_client.post(reverse("catalog:moderation-approve", args=[task.pk]))

    assert again.status_code == 409


def test_reject_with_unknown_reason_is_400(moderator_client):
    listing = publishable_listing()
    publish_listing(listing)
    task = ModerationTask.objects.get(listing=listing)

    response = moderator_client.post(
        reverse("catalog:moderation-reject", args=[task.pk]),
        {"reason_code": "no-such-reason"},
        format="json",
    )

    assert response.status_code == 400
    assert response.data["error"]["details"]["reason_code"] == "no-such-reason"


def test_queue_is_ordered_by_priority(moderator_client):
    quiet = publishable_listing(description="Светлая квартира")
    noisy = publishable_listing(description="Звоните 0555123456, есть WhatsApp")
    publish_listing(quiet)
    publish_listing(noisy)

    from apps.catalog.tasks import run_moderation_checks

    for listing in (quiet, noisy):
        run_moderation_checks(listing.pk)

    response = moderator_client.get(reverse("catalog:moderation-queue"))

    assert response.status_code == 200
    slugs = [item["listing"]["slug"] for item in response.data["results"]]
    assert slugs.index(noisy.slug) < slugs.index(quiet.slug)


def test_queue_filters_by_triggers(moderator_client):
    quiet = publishable_listing(description="Светлая квартира")
    noisy = publishable_listing(description="Звоните 0555123456")
    publish_listing(quiet)
    publish_listing(noisy)

    from apps.catalog.tasks import run_moderation_checks

    for listing in (quiet, noisy):
        run_moderation_checks(listing.pk)

    response = moderator_client.get(reverse("catalog:moderation-queue"), {"has_triggers": "true"})

    slugs = [item["listing"]["slug"] for item in response.data["results"]]
    assert slugs == [noisy.slug]


def test_queue_shows_author_rejection_history(moderator_client):
    owner = UserFactory()
    first = publishable_listing(owner=owner, description="Звоните 0555123456")
    publish_listing(first)
    task = ModerationTask.objects.get(listing=first)
    moderator_client.post(
        reverse("catalog:moderation-reject", args=[task.pk]),
        {"reason_code": "contacts", "comment": "Первый раз"},
        format="json",
    )

    second = publishable_listing(owner=owner)
    publish_listing(second)

    response = moderator_client.get(reverse("catalog:moderation-queue"))

    entry = next(
        item for item in response.data["results"] if item["listing"]["slug"] == second.slug
    )
    assert entry["author_rejections"][0]["reason_code"] == "contacts"
    assert entry["author_rejections"][0]["listing_slug"] == first.slug


def test_assign_takes_the_task(moderator_client, moderator):
    listing = publishable_listing()
    publish_listing(listing)
    task = ModerationTask.objects.get(listing=listing)

    response = moderator_client.post(reverse("catalog:moderation-assign", args=[task.pk]))

    assert response.status_code == 200
    task.refresh_from_db()
    assert task.assigned_to_id == moderator.pk


def test_regular_user_gets_403_on_moderation(auth_client):
    listing = publishable_listing()
    publish_listing(listing)
    task = ModerationTask.objects.get(listing=listing)

    for url in (
        reverse("catalog:moderation-queue"),
        reverse("catalog:moderation-assign", args=[task.pk]),
        reverse("catalog:moderation-approve", args=[task.pk]),
        reverse("catalog:moderation-reject", args=[task.pk]),
        reverse("catalog:moderation-reject-reasons"),
    ):
        response = (
            auth_client.get(url)
            if "queue" in url or "reasons" in url
            else (auth_client.post(url, {}, format="json"))
        )
        assert response.status_code == 403, url


def test_reject_reasons_are_seeded():
    codes = set(RejectReason.objects.values_list("code", flat=True))

    assert codes == {
        "contacts",
        "wrong_price",
        "duplicate",
        "bad_photos",
        "wrong_category",
        "fraud",
    }


# -- жалобы ------------------------------------------------------------------


def test_three_reports_send_listing_to_moderation():
    listing = ListingFactory(status=ListingStatus.ACTIVE)
    url = reverse("catalog:listing-report", args=[listing.slug])

    for index in range(3):
        client = client_for(UserFactory())
        response = client.post(url, {"reason": ReportReason.FRAUD, "comment": ""}, format="json")
        assert response.status_code == 201, response.data

        listing.refresh_from_db()
        expected = ListingStatus.PENDING if index == 2 else ListingStatus.ACTIVE
        assert listing.status == expected

    task = ModerationTask.objects.get(listing=listing)
    assert task.priority == 10
    assert task.checks["user_reports"]["triggered"] is True
    assert task.checks["user_reports"]["details"]["count"] == 3
    # Причины схлопнуты: три одинаковые жалобы дают одну запись.
    assert task.checks["user_reports"]["details"]["reasons"] == ["fraud"]


def test_second_report_from_same_user_is_conflict(user):
    listing = ListingFactory(status=ListingStatus.ACTIVE)
    url = reverse("catalog:listing-report", args=[listing.slug])
    client = client_for(user)

    first = client.post(url, {"reason": ReportReason.SPAM}, format="json")
    second = client.post(url, {"reason": ReportReason.SPAM}, format="json")

    assert first.status_code == 201
    assert second.status_code == 409
    assert ListingReport.objects.filter(listing=listing).count() == 1


def test_cannot_report_own_listing():
    listing = ListingFactory(status=ListingStatus.ACTIVE)
    client = client_for(listing.owner)

    response = client.post(
        reverse("catalog:listing-report", args=[listing.slug]),
        {"reason": ReportReason.SPAM},
        format="json",
    )

    assert response.status_code == 400
    assert ListingReport.objects.count() == 0


def test_approve_resolves_reports(moderator_client):
    listing = ListingFactory(status=ListingStatus.ACTIVE)
    url = reverse("catalog:listing-report", args=[listing.slug])
    for _ in range(3):
        client_for(UserFactory()).post(url, {"reason": ReportReason.SPAM}, format="json")

    task = ModerationTask.objects.get(listing=listing)
    moderator_client.post(reverse("catalog:moderation-approve", args=[task.pk]))

    listing.refresh_from_db()
    assert listing.status == ListingStatus.ACTIVE
    assert ListingReport.objects.filter(listing=listing, is_resolved=False).count() == 0


def test_anonymous_cannot_report(api_client):
    listing = ListingFactory(status=ListingStatus.ACTIVE)

    response = api_client.post(
        reverse("catalog:listing-report", args=[listing.slug]),
        {"reason": ReportReason.SPAM},
        format="json",
    )

    assert response.status_code == 401


def test_queue_does_not_scale_queries_with_page_size(moderator_client):
    """Число запросов не должно расти с размером страницы очереди.

    В карточке задачи лежит объявление целиком с медиа и историей автора —
    без пакетной загрузки это был бы запрос на каждую строку очереди.
    """
    from django.db import connection
    from django.test.utils import CaptureQueriesContext

    from apps.catalog.tasks import run_moderation_checks

    owner = UserFactory()
    for index in range(6):
        listing = publishable_listing(owner=owner, description=f"Звоните 055512345{index}")
        publish_listing(listing)
        run_moderation_checks(listing.pk)

    url = reverse("catalog:moderation-queue")

    with CaptureQueriesContext(connection) as small:
        assert moderator_client.get(url, {"page_size": 2}).status_code == 200

    with CaptureQueriesContext(connection) as large:
        assert moderator_client.get(url, {"page_size": 6}).status_code == 200

    assert len(large.captured_queries) == len(small.captured_queries)
