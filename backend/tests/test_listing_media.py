"""Загрузка и обработка медиафайлов объявления.

Главное, что проверяется здесь, — приватность: EXIF с GPS-координатами
квартиры не должен пережить обработку, а подменённый тип файла не должен
попасть в хранилище.
"""

import shutil
import subprocess
import tempfile
from fractions import Fraction
from io import BytesIO
from pathlib import Path

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from django.urls import reverse
from PIL import Image, UnidentifiedImageError

from apps.catalog.enums import MediaKind, MediaStatus
from apps.catalog.models import ListingMedia
from apps.catalog.tasks import process_media
from tests.factories import ListingFactory, ListingMediaFactory, UserFactory

pytestmark = pytest.mark.django_db

HAS_FFMPEG = shutil.which("ffmpeg") is not None


# -- вспомогательное ---------------------------------------------------------


def make_jpeg(width: int = 1200, height: int = 900, *, with_exif: bool = False) -> bytes:
    """JPEG заданного размера, при необходимости — с GPS и моделью телефона."""
    image = Image.new("RGB", (width, height))
    # Шум, чтобы phash разных картинок отличался, а JPEG не сжимался в ничто.
    image.putdata(
        [((x * 7) % 256, (y * 5) % 256, (x + y) % 256) for y in range(height) for x in range(width)]
    )

    buffer = BytesIO()
    if with_exif:
        exif = Image.Exif()
        exif[0x010F] = "Apple"
        exif[0x0110] = "iPhone 15 Pro"
        exif[0x9003] = "2026:07:14 09:30:00"
        exif[0x8825] = {
            1: "N",
            2: (Fraction(42), Fraction(52), Fraction(30)),
            3: "E",
            4: (Fraction(74), Fraction(36), Fraction(15)),
        }
        image.save(buffer, format="JPEG", quality=92, exif=exif.tobytes())
    else:
        image.save(buffer, format="JPEG", quality=92)
    return buffer.getvalue()


def upload_file(data: bytes, name: str = "photo.jpg", content_type: str = "image/jpeg"):
    return SimpleUploadedFile(name, data, content_type=content_type)


def make_video(seconds: int) -> bytes:
    """Крошечный mp4 нужной длительности (1 кадр в секунду, 64×64)."""
    path = Path(tempfile.mkdtemp()) / "clip.mp4"
    subprocess.run(
        [
            "ffmpeg",
            "-v",
            "error",
            "-y",
            "-f",
            "lavfi",
            "-i",
            f"color=c=black:s=64x64:r=1:d={seconds}",
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-preset",
            "ultrafast",
            str(path),
        ],
        check=True,
        capture_output=True,
    )
    return path.read_bytes()


def media_url(listing) -> str:
    return reverse("catalog:listing-media", args=[listing.slug])


@pytest.fixture
def owner_client(api_client):
    """Клиент владельца объявления и само объявление."""
    from rest_framework_simplejwt.tokens import RefreshToken

    owner = UserFactory()
    listing = ListingFactory(owner=owner)
    token = RefreshToken.for_user(owner)
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token.access_token}")
    return api_client, listing


@pytest.fixture
def upload(django_capture_on_commit_callbacks):
    """Загрузка файлов с выполнением отложенных задач.

    Обработка ставится в очередь через `transaction.on_commit`, а в тестах
    коммита не происходит — задачу запускает capture-фикстура.
    """

    def _upload(client, listing, files, kind=MediaKind.PHOTO):
        payload: dict = {"files": files, "kind": kind}
        with django_capture_on_commit_callbacks(execute=True):
            return client.post(media_url(listing), payload, format="multipart")

    return _upload


# -- EXIF --------------------------------------------------------------------


def test_exif_with_gps_is_stripped_completely(owner_client, upload):
    """В EXIF лежат GPS и модель телефона — после обработки не должно остаться ничего."""
    client, listing = owner_client
    source = make_jpeg(with_exif=True)

    # Исходник действительно с метаданными — иначе тест ничего не проверяет.
    with Image.open(BytesIO(source)) as raw:
        assert dict(raw.getexif()), "в исходнике нет EXIF, тест бессмысленен"
        assert dict(raw.getexif().get_ifd(0x8825)), "в исходнике нет GPS"

    response = upload(client, listing, [upload_file(source)])
    assert response.status_code == 201, response.data

    media = ListingMedia.objects.get(pk=response.data["media"][0]["id"])
    assert media.status == MediaStatus.READY

    for field in ("url_thumb", "url_medium", "url_original"):
        variant = getattr(media, field)
        variant.open("rb")
        try:
            with Image.open(BytesIO(variant.read())) as processed:
                assert not dict(processed.getexif()), f"{field}: EXIF пережил обработку"
                assert not processed.info.get("exif")
        finally:
            variant.close()


# -- проверка типа по содержимому --------------------------------------------


def test_pdf_disguised_as_jpg_is_rejected(owner_client, upload):
    """Расширение и Content-Type задаёт клиент — верить можно только содержимому."""
    client, listing = owner_client
    pdf = b"%PDF-1.7\n%\xe2\xe3\xcf\xd3\n1 0 obj\n<< /Type /Catalog >>\nendobj\n" + b"\x00" * 4096

    response = upload(client, listing, [upload_file(pdf, name="photo.jpg")])

    assert response.status_code == 400
    assert response.data["error"]["code"] == "validation_error"
    assert "JPEG" in response.data["error"]["message"]
    assert ListingMedia.objects.filter(listing=listing).count() == 0


def test_too_small_photo_is_rejected(owner_client, upload):
    client, listing = owner_client

    response = upload(client, listing, [upload_file(make_jpeg(320, 240))])

    assert response.status_code == 400
    assert "600×400" in response.data["error"]["message"]


# -- лимиты ------------------------------------------------------------------


def test_twenty_first_photo_is_rejected_with_free_slots(owner_client, upload):
    """20 фото уже есть — 21-е не влезает, ответ говорит сколько слотов осталось."""
    client, listing = owner_client
    ListingMediaFactory.create_batch(20, listing=listing, kind=MediaKind.PHOTO)

    response = upload(client, listing, [upload_file(make_jpeg())])

    assert response.status_code == 400
    details = response.data["error"]["details"]
    assert details["free_slots"] == 0
    assert details["message"] == "Достигнут лимит 20 фото"
    assert ListingMedia.objects.filter(listing=listing).count() == 20


def test_batch_takes_what_fits_and_reports_the_rest(owner_client, upload):
    """18 загружено, прислали 5: берём 2, отклоняем 3 — как AppState._append."""
    client, listing = owner_client
    ListingMediaFactory.create_batch(18, listing=listing, kind=MediaKind.PHOTO)

    files = [upload_file(make_jpeg(), name=f"photo-{index}.jpg") for index in range(5)]
    response = upload(client, listing, files)

    assert response.status_code == 201, response.data
    assert response.data["accepted"] == 2
    assert response.data["rejected"] == 3
    assert response.data["reason"] == "Достигнут лимит 20 фото"
    assert response.data["free_slots"] == 0
    assert len(response.data["media"]) == 2
    assert [item["file_index"] for item in response.data["rejected_details"]] == ["2", "3", "4"]
    assert ListingMedia.objects.filter(listing=listing).count() == 20


# -- видео -------------------------------------------------------------------


def test_long_video_is_rejected_without_ffprobe(owner_client, upload, monkeypatch):
    """Длительность выше лимита — отказ. ffprobe подменён, чтобы тест не зависел от него."""
    from apps.catalog import media as media_module

    client, listing = owner_client
    monkeypatch.setattr(media_module, "probe_video", lambda path: {"duration_seconds": 240})

    # Заголовок ISO-BMFF с брендом isom — по нему файл опознаётся как mp4.
    payload = b"\x00\x00\x00\x18ftypisom" + b"\x00" * 8192

    response = upload(
        client,
        listing,
        [upload_file(payload, name="clip.mp4", content_type="video/mp4")],
        MediaKind.VIDEO,
    )

    assert response.status_code == 400
    assert "длиннее 3 минут" in response.data["error"]["message"]
    assert ListingMedia.objects.filter(listing=listing).count() == 0


@pytest.mark.skipif(not HAS_FFMPEG, reason="ffmpeg не установлен")
def test_four_minute_video_is_rejected(owner_client, upload):
    """Настоящий ролик на 4 минуты — ffprobe читает длительность до сохранения."""
    client, listing = owner_client

    response = upload(
        client,
        listing,
        [upload_file(make_video(240), "clip.mp4", "video/mp4")],
        MediaKind.VIDEO,
    )

    assert response.status_code == 400
    assert response.data["error"]["code"] == "validation_error"
    assert ListingMedia.objects.filter(listing=listing).count() == 0


@pytest.mark.skipif(not HAS_FFMPEG, reason="ffmpeg не установлен")
def test_short_video_is_accepted_and_gets_poster(owner_client, upload):
    """Короткое видео принимается: длительность и кадр-превью заполняются задачей."""
    client, listing = owner_client

    response = upload(
        client,
        listing,
        [upload_file(make_video(5), "clip.mp4", "video/mp4")],
        MediaKind.VIDEO,
    )

    assert response.status_code == 201, response.data
    media = ListingMedia.objects.get(pk=response.data["media"][0]["id"])
    assert media.status == MediaStatus.READY
    assert media.duration_seconds == 5
    assert media.thumbnail, "кадр-превью не сохранён"


# -- обработка ---------------------------------------------------------------


def test_processing_fills_variants_and_phash(owner_client, upload):
    client, listing = owner_client

    response = upload(client, listing, [upload_file(make_jpeg(3000, 2000))])
    assert response.status_code == 201, response.data

    media = ListingMedia.objects.get(pk=response.data["media"][0]["id"])
    assert media.status == MediaStatus.READY
    assert media.phash, "перцептивный хеш не посчитан"
    assert media.size_bytes

    sizes = {}
    for variant in ("thumb", "medium", "original"):
        field = getattr(media, f"url_{variant}")
        assert field, f"нет варианта {variant}"
        assert getattr(media, f"url_{variant}_jpeg"), f"нет JPEG-фолбэка {variant}"

        field.open("rb")
        try:
            with Image.open(BytesIO(field.read())) as image:
                assert image.format == "WEBP"
                sizes[variant] = max(image.size)
        finally:
            field.close()

    assert sizes["thumb"] == 400
    assert sizes["medium"] == 1080
    assert sizes["original"] == 2560


def test_storage_key_has_no_user_filename(owner_client, upload):
    """Имя файла с телефона может содержать ПДн — в ключ оно не попадает."""
    client, listing = owner_client

    response = upload(
        client, listing, [upload_file(make_jpeg(), name="паспорт_Иванов_Асанбай.jpg")]
    )

    media = ListingMedia.objects.get(pk=response.data["media"][0]["id"])
    assert "Иванов" not in media.file.name
    assert media.file.name.startswith(f"listings/{listing.uuid}/")
    assert media.url_medium.name == f"listings/{listing.uuid}/{media.uuid}_medium.webp"


def test_failed_processing_marks_media(owner_client):
    """Битый файл в хранилище: запись не теряется, статус — failed."""
    client, listing = owner_client
    media = ListingMediaFactory(listing=listing, status=MediaStatus.PROCESSING)

    # В eager-режиме исключение прокидывается наружу; в проде его поймает
    # Celery и повторит задачу. Запись при этом уже помечена как failed.
    with pytest.raises(UnidentifiedImageError):
        process_media(media.pk)

    media.refresh_from_db()
    assert media.status == MediaStatus.FAILED
    assert media.processing_error


# -- порядок -----------------------------------------------------------------


def test_reorder_changes_order(owner_client):
    client, listing = owner_client
    items = ListingMediaFactory.create_batch(4, listing=listing)
    new_order = [items[2].pk, items[0].pk, items[3].pk, items[1].pk]

    response = client.patch(
        reverse("catalog:listing-media-reorder", args=[listing.slug]),
        {"order": new_order},
        format="json",
    )

    assert response.status_code == 200, response.data
    assert [item["id"] for item in response.data] == new_order
    assert list(listing.media.order_by("order").values_list("pk", flat=True)) == new_order


def test_reorder_with_foreign_media_id_is_rejected(owner_client):
    """Чужой id в списке — 400: применять такой порядок частично нельзя."""
    client, listing = owner_client
    items = ListingMediaFactory.create_batch(2, listing=listing)
    foreign = ListingMediaFactory()

    response = client.patch(
        reverse("catalog:listing-media-reorder", args=[listing.slug]),
        {"order": [items[0].pk, foreign.pk]},
        format="json",
    )

    assert response.status_code == 400
    assert response.data["error"]["details"]["order"] == [foreign.pk]
    # Порядок не тронут.
    assert list(listing.media.order_by("order").values_list("pk", flat=True)) == [
        items[0].pk,
        items[1].pk,
    ]


# -- обложка -----------------------------------------------------------------


def test_set_cover_leaves_exactly_one_cover(owner_client):
    client, listing = owner_client
    first = ListingMediaFactory(listing=listing, is_cover=True)
    second = ListingMediaFactory(listing=listing)

    response = client.post(reverse("catalog:listing-media-cover", args=[listing.slug, second.pk]))

    assert response.status_code == 200, response.data
    assert response.data["is_cover"] is True
    assert list(listing.media.filter(is_cover=True).values_list("pk", flat=True)) == [second.pk]
    first.refresh_from_db()
    assert first.is_cover is False


def test_deleting_cover_promotes_next_photo(owner_client):
    """Карточка без обложки выглядит сломанной — обложку получает следующее фото."""
    client, listing = owner_client
    cover = ListingMediaFactory(listing=listing, is_cover=True, order=0)
    second = ListingMediaFactory(listing=listing, order=1)
    ListingMediaFactory(listing=listing, order=2)

    response = client.delete(reverse("catalog:listing-media-item", args=[listing.slug, cover.pk]))

    assert response.status_code == 204
    assert not ListingMedia.objects.filter(pk=cover.pk).exists()
    second.refresh_from_db()
    assert second.is_cover is True
    assert listing.media.filter(is_cover=True).count() == 1


def test_delete_removes_all_variants_from_storage(owner_client, upload):
    client, listing = owner_client

    response = upload(client, listing, [upload_file(make_jpeg())])
    media = ListingMedia.objects.get(pk=response.data["media"][0]["id"])
    paths = [getattr(media, name).path for name in media.FILE_FIELDS if getattr(media, name)]
    assert paths and all(Path(path).exists() for path in paths)

    deleted = client.delete(reverse("catalog:listing-media-item", args=[listing.slug, media.pk]))

    assert deleted.status_code == 204
    assert not any(Path(path).exists() for path in paths)


# -- права -------------------------------------------------------------------


def test_foreign_listing_media_upload_is_forbidden(auth_client):
    """Чужое объявление — 403: владение объектом не секрет."""
    listing = ListingFactory()

    response = auth_client.post(
        media_url(listing),
        {"files": [upload_file(make_jpeg())]},
        format="multipart",
    )

    assert response.status_code == 403
    assert ListingMedia.objects.filter(listing=listing).count() == 0


def test_media_of_another_listing_is_not_found(owner_client):
    """id файла из другого объявления — 404, а не удаление чужого файла."""
    client, listing = owner_client
    foreign = ListingMediaFactory()

    response = client.delete(reverse("catalog:listing-media-item", args=[listing.slug, foreign.pk]))

    assert response.status_code == 404
    assert ListingMedia.objects.filter(pk=foreign.pk).exists()


def test_anonymous_cannot_upload(api_client):
    listing = ListingFactory()

    response = api_client.post(
        media_url(listing),
        {"files": [upload_file(make_jpeg())]},
        format="multipart",
    )

    assert response.status_code == 401
