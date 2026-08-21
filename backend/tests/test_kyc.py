"""Тесты верификации личности исполнителя.

Отдельно проверяется всё, что связано с защитой сканов документов: приватное
хранилище без публичных URL, аудит каждой выдачи ссылки, точечное право на
просмотр и удаление файлов после решения.
"""

from datetime import timedelta
from io import BytesIO
from pathlib import Path

import pytest
from django.conf import settings
from django.contrib.auth.models import Permission
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from PIL import Image
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.common.models import AuditLog
from apps.common.storages import private_storage
from apps.users.models import (
    DocumentType,
    IdentityVerification,
    SellerProfile,
    User,
    VerificationStatus,
)
from apps.users.tasks import purge_identity_files
from tests.factories import UserFactory

SUBMIT_URL = "/api/v1/verification/identity/"
QUEUE_URL = "/api/v1/verification/queue/"
REVIEW_URL = "/api/v1/verification/identity/{pk}/review/"

EXIF_CAMERA = "HouseKGZ TestCam"


def make_photo(name: str = "selfie.jpg", *, with_exif: bool = False) -> SimpleUploadedFile:
    """Снимок, проходящий по разрешению (минимум 800×600)."""
    image = Image.new("RGB", (900, 700), (120, 60, 30))
    buffer = BytesIO()

    if with_exif:
        exif = Image.Exif()
        exif[0x010F] = EXIF_CAMERA  # Make
        exif[0x0110] = "Model X"  # Model
        image.save(buffer, format="JPEG", exif=exif)
    else:
        image.save(buffer, format="JPEG")

    return SimpleUploadedFile(name, buffer.getvalue(), content_type="image/jpeg")


def client_for(user: User) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {RefreshToken.for_user(user).access_token}")
    return client


def submit_payload(**overrides: object) -> dict[str, object]:
    data: dict[str, object] = {
        "selfie": make_photo("selfie.jpg"),
        "document_front": make_photo("front.jpg"),
        "document_type": DocumentType.PASSPORT,
    }
    data.update(overrides)
    return data


@pytest.fixture
def pro_user(db) -> User:
    return UserFactory(pro=True)


@pytest.fixture
def pro_client(pro_user: User) -> APIClient:
    return client_for(pro_user)


@pytest.fixture
def plain_staff(db) -> User:
    """Сотрудник без права проверять документы."""
    return UserFactory(is_staff=True)


@pytest.fixture
def reviewer(db) -> User:
    staff = UserFactory(is_staff=True)
    staff.user_permissions.add(Permission.objects.get(codename="can_review_identity"))
    return User.objects.get(pk=staff.pk)


@pytest.fixture
def verification(pro_client: APIClient, pro_user: User) -> IdentityVerification:
    pro_client.post(SUBMIT_URL, submit_payload(), format="multipart")
    return IdentityVerification.objects.get(user=pro_user)


# -- хранилище ---------------------------------------------------------------


@pytest.mark.django_db
def test_kyc_file_is_not_reachable_without_signature(
    pro_client: APIClient, verification: IdentityVerification
) -> None:
    """Прямого URL у файла KYC нет: хранилище его просто не выдаёт."""
    storage = private_storage()

    with pytest.raises(ValueError):
        storage.url(verification.selfie.name)

    # Файл лежит в отдельном дереве, а не рядом с публичными медиа.
    stored = Path(verification.selfie.path).resolve()
    assert stored.is_relative_to(Path(settings.PRIVATE_MEDIA_ROOT).resolve())
    assert not stored.is_relative_to(Path(settings.MEDIA_ROOT).resolve())
    assert str(settings.PRIVATE_MEDIA_ROOT) != str(settings.MEDIA_ROOT)


@pytest.mark.django_db
def test_submit_response_has_no_file_links(pro_client: APIClient) -> None:
    response = pro_client.post(SUBMIT_URL, submit_payload(), format="multipart")

    assert response.status_code == 201
    body = response.json()
    assert set(body) == {"id", "status", "submitted_at"}
    assert body["status"] == VerificationStatus.PENDING
    assert "selfie" not in response.content.decode()


@pytest.mark.django_db
def test_own_status_does_not_expose_files(
    pro_client: APIClient, verification: IdentityVerification
) -> None:
    response = pro_client.get(SUBMIT_URL)

    assert response.status_code == 200
    assert set(response.json()) == {"status", "reject_reason", "reviewed_at", "can_resubmit"}


@pytest.mark.django_db
def test_status_without_submissions(pro_client: APIClient) -> None:
    body = pro_client.get(SUBMIT_URL).json()

    assert body["status"] == "not_submitted"
    assert body["can_resubmit"] is True


# -- права -------------------------------------------------------------------


@pytest.mark.django_db
def test_staff_without_permission_cannot_see_queue(
    plain_staff: User, verification: IdentityVerification
) -> None:
    client = client_for(plain_staff)

    queue = client.get(QUEUE_URL)
    review = client.post(REVIEW_URL.format(pk=verification.pk), {"action": "approve"})

    assert queue.status_code == 403
    assert queue.json()["error"]["code"] == "permission_denied"
    assert review.status_code == 403
    assert AuditLog.objects.count() == 0


@pytest.mark.django_db
def test_regular_user_cannot_see_queue(pro_client: APIClient) -> None:
    assert pro_client.get(QUEUE_URL).status_code == 403


@pytest.mark.django_db
def test_reviewer_sees_queue_with_signed_links(
    reviewer: User, verification: IdentityVerification
) -> None:
    response = client_for(reviewer).get(QUEUE_URL)

    assert response.status_code == 200
    item = response.json()["results"][0]
    assert item["id"] == verification.pk
    assert set(item["files"]) == {"selfie", "document_front"}
    assert item["files"]["selfie"].startswith("http")


@pytest.mark.django_db
def test_non_pro_cannot_submit(db) -> None:
    client = client_for(UserFactory())

    response = client.post(SUBMIT_URL, submit_payload(), format="multipart")

    assert response.status_code == 403
    assert IdentityVerification.objects.count() == 0


# -- аудит -------------------------------------------------------------------


@pytest.mark.django_db
def test_every_signed_url_is_audited(reviewer: User, verification: IdentityVerification) -> None:
    client = client_for(reviewer)

    client.get(QUEUE_URL)

    issued = AuditLog.objects.filter(action=AuditLog.Action.KYC_URL_ISSUED)
    assert issued.count() == 2  # селфи и лицевая сторона документа
    entry = issued.first()
    assert entry.actor == reviewer
    assert entry.target_user == verification.user
    assert entry.ip_address
    assert entry.extra["field"] in IdentityVerification.FILE_FIELDS
    # Ни ссылок, ни имён файлов в журнале нет.
    assert verification.selfie.name not in str(entry.extra)

    client.get(QUEUE_URL)
    assert AuditLog.objects.filter(action=AuditLog.Action.KYC_URL_ISSUED).count() == 4


@pytest.mark.django_db
def test_signed_link_serves_file_and_is_audited(
    reviewer: User, verification: IdentityVerification
) -> None:
    client = client_for(reviewer)
    url = client.get(QUEUE_URL).json()["results"][0]["files"]["selfie"]

    response = client.get(url)

    assert response.status_code == 200
    assert AuditLog.objects.filter(action=AuditLog.Action.KYC_FILE_DOWNLOADED).count() == 1


@pytest.mark.django_db
def test_signed_link_is_bound_to_the_staff_member(
    reviewer: User, verification: IdentityVerification, db
) -> None:
    """Переслать ссылку коллеге не получится — токен привязан к сотруднику."""
    url = client_for(reviewer).get(QUEUE_URL).json()["results"][0]["files"]["selfie"]

    other = UserFactory(is_staff=True)
    other.user_permissions.add(Permission.objects.get(codename="can_review_identity"))

    assert client_for(User.objects.get(pk=other.pk)).get(url).status_code == 404


# -- подача ------------------------------------------------------------------


@pytest.mark.django_db
def test_second_submission_while_pending_returns_409(
    pro_client: APIClient, verification: IdentityVerification
) -> None:
    response = pro_client.post(SUBMIT_URL, submit_payload(), format="multipart")

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "conflict"
    assert IdentityVerification.objects.count() == 1


@pytest.mark.django_db
def test_fourth_submission_per_day_is_throttled(pro_client: APIClient) -> None:
    for _ in range(3):
        assert pro_client.post(SUBMIT_URL, submit_payload(), format="multipart").status_code in (
            201,
            409,
        )

    response = pro_client.post(SUBMIT_URL, submit_payload(), format="multipart")

    assert response.status_code == 429
    assert response.json()["error"]["details"]["retry_after"] > 0


@pytest.mark.django_db
def test_small_image_is_rejected(pro_client: APIClient) -> None:
    tiny = Image.new("RGB", (200, 100), (10, 10, 10))
    buffer = BytesIO()
    tiny.save(buffer, format="JPEG")
    small = SimpleUploadedFile("selfie.jpg", buffer.getvalue(), content_type="image/jpeg")

    response = pro_client.post(SUBMIT_URL, submit_payload(selfie=small), format="multipart")

    assert response.status_code == 400
    assert "selfie" in response.json()["error"]["details"]


@pytest.mark.django_db
def test_pdf_disguised_as_photo_is_rejected(pro_client: APIClient) -> None:
    fake = SimpleUploadedFile("selfie.jpg", b"%PDF-1.7\n%fake", content_type="image/jpeg")

    response = pro_client.post(SUBMIT_URL, submit_payload(selfie=fake), format="multipart")

    assert response.status_code == 400


# -- обработка файлов --------------------------------------------------------


@pytest.mark.django_db
def test_exif_is_stripped_from_selfie(
    pro_client: APIClient, pro_user: User, django_capture_on_commit_callbacks
) -> None:
    original = make_photo("selfie.jpg", with_exif=True)
    assert Image.open(BytesIO(original.read())).getexif()  # в исходнике EXIF есть
    original.seek(0)

    with django_capture_on_commit_callbacks(execute=True):
        response = pro_client.post(SUBMIT_URL, submit_payload(selfie=original), format="multipart")

    assert response.status_code == 201
    verification = IdentityVerification.objects.get(user=pro_user)
    verification.refresh_from_db()

    with verification.selfie.open("rb") as stored:
        stored_exif = Image.open(BytesIO(stored.read())).getexif()

    assert dict(stored_exif) == {}
    assert EXIF_CAMERA not in verification.selfie.name


# -- решение модератора ------------------------------------------------------


@pytest.mark.django_db
def test_approve_sets_verified_profile_and_purge_after(
    reviewer: User, verification: IdentityVerification
) -> None:
    response = client_for(reviewer).post(
        REVIEW_URL.format(pk=verification.pk),
        {"action": "approve", "comment": "Документы в порядке"},
    )

    assert response.status_code == 200
    assert response.json()["status"] == VerificationStatus.APPROVED

    verification.refresh_from_db()
    assert verification.status == VerificationStatus.APPROVED
    assert verification.reviewed_by == reviewer
    assert verification.reviewed_at is not None

    expected_purge = timezone.now() + timedelta(days=settings.KYC_PURGE_AFTER_DAYS)
    assert abs((verification.purge_after - expected_purge).total_seconds()) < 60

    profile = SellerProfile.objects.get(user=verification.user)
    assert profile.is_verified is True
    assert profile.verified_at is not None

    assert AuditLog.objects.filter(action=AuditLog.Action.KYC_REVIEWED).count() == 1


@pytest.mark.django_db
def test_reject_requires_reason(reviewer: User, verification: IdentityVerification) -> None:
    client = client_for(reviewer)

    without_reason = client.post(REVIEW_URL.format(pk=verification.pk), {"action": "reject"})
    assert without_reason.status_code == 400

    rejected = client.post(
        REVIEW_URL.format(pk=verification.pk),
        {"action": "reject", "reason": "Фото документа нечитаемо"},
    )

    assert rejected.status_code == 200
    body = rejected.json()
    assert body["status"] == VerificationStatus.REJECTED
    assert body["reject_reason"] == "Фото документа нечитаемо"
    assert body["can_resubmit"] is True

    verification.refresh_from_db()
    assert verification.purge_after is not None
    assert SellerProfile.objects.count() == 0


@pytest.mark.django_db
def test_second_review_returns_409(reviewer: User, verification: IdentityVerification) -> None:
    client = client_for(reviewer)
    client.post(REVIEW_URL.format(pk=verification.pk), {"action": "approve"})

    again = client.post(REVIEW_URL.format(pk=verification.pk), {"action": "approve"})

    assert again.status_code == 409


# -- удаление файлов ---------------------------------------------------------


@pytest.mark.django_db
def test_purge_identity_files_removes_files_but_keeps_record(
    reviewer: User, verification: IdentityVerification
) -> None:
    client_for(reviewer).post(REVIEW_URL.format(pk=verification.pk), {"action": "approve"})
    verification.refresh_from_db()

    selfie_path = Path(verification.selfie.path)
    document_path = Path(verification.document_front.path)
    assert selfie_path.exists()

    # Срок хранения вышел.
    IdentityVerification.objects.filter(pk=verification.pk).update(
        purge_after=timezone.now() - timedelta(days=1)
    )

    assert purge_identity_files() == 1

    verification.refresh_from_db()
    assert not selfie_path.exists()
    assert not document_path.exists()
    assert not verification.selfie
    assert not verification.document_front

    # Факт проверки остаётся.
    assert verification.status == VerificationStatus.APPROVED
    assert verification.document_type == DocumentType.PASSPORT
    assert verification.reviewed_at is not None
    assert verification.user_id is not None


@pytest.mark.django_db
def test_purge_skips_fresh_verifications(verification: IdentityVerification) -> None:
    assert purge_identity_files() == 0

    verification.refresh_from_db()
    assert verification.selfie
