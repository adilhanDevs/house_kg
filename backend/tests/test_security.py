"""Безопасность, персональные данные и наблюдаемость.

Проверки здесь не про фичи, а про обещания, которые проект даёт гражданам,
чьи телефоны и ИИН он хранит: лимиты не обходятся, ПДн не текут в логи,
ИИН лежит в БД зашифрованным, каждое действие с деньгами и правами
остаётся в журнале.
"""

import json
import logging
from decimal import Decimal

import pytest
from django.core.cache import cache
from django.db import connection
from django.urls import reverse

from apps.billing.services import apply_transaction
from apps.catalog.enums import ListingStatus, ModerationStatus
from apps.catalog.models import ModerationTask
from apps.common.enums import WalletEntryKind
from apps.common.logging import mask_pii, mask_text
from apps.common.models import AuditLog
from apps.users.models import User, UserConsent
from tests.factories import ListingFactory, ListingMediaFactory, UserFactory

pytestmark = pytest.mark.django_db

OTP_REQUEST_URL = "/api/v1/auth/otp/request/"
VERIFY_URL = "/api/v1/auth/otp/verify/"
PHONE = "+996700555111"
DEBUG_CODE = "0000"
IIN = "20101199001234"


# -- 1. Ограничение частоты --------------------------------------------------


def test_otp_request_is_throttled_per_phone(api_client, throttle_rates):
    """Пятый код за час — последний: SMS стоят денег, а перебор кодов дешевеет."""
    # Минутный лимит здесь не мешает — проверяем именно часовой.
    throttle_rates(otp_phone_resend="100/hour", otp_phone_hourly="5/hour")

    for _ in range(5):
        assert api_client.post(OTP_REQUEST_URL, {"phone": PHONE}).status_code == 200

    blocked = api_client.post(OTP_REQUEST_URL, {"phone": PHONE})

    assert blocked.status_code == 429
    error = blocked.json()["error"]
    assert error["code"] == "throttled"
    assert error["details"]["retry_after"] > 0


def test_otp_throttle_is_per_phone_not_global(api_client, throttle_rates):
    """Лимит одного номера не должен мешать другому человеку войти."""
    throttle_rates(otp_phone_resend="1/min", otp_phone_hourly="5/hour")

    assert api_client.post(OTP_REQUEST_URL, {"phone": PHONE}).status_code == 200
    assert api_client.post(OTP_REQUEST_URL, {"phone": PHONE}).status_code == 429
    # Другой номер — свой счётчик.
    assert api_client.post(OTP_REQUEST_URL, {"phone": "+996700555222"}).status_code == 200


def test_throttle_normalizes_the_phone(api_client, throttle_rates):
    """«0700 555 111» и «+996700555111» — один номер, один счётчик."""
    throttle_rates(otp_phone_resend="1/min")

    assert api_client.post(OTP_REQUEST_URL, {"phone": "+996700555111"}).status_code == 200
    assert api_client.post(OTP_REQUEST_URL, {"phone": "0700 555 111"}).status_code == 429


def test_media_upload_throttle_counts_files_not_requests(pro_user, throttle_rates):
    """Лимит на файлы, а не на запросы: в одном запросе их до двадцати."""
    from apps.common.throttling import MediaUploadThrottle

    throttle_rates(media_upload="3/hour")
    throttle = MediaUploadThrottle()

    class FakeRequest:
        def __init__(self, count: int) -> None:
            self.user = pro_user
            self.FILES = _FakeFiles(count)

    class _FakeFiles:
        def __init__(self, count: int) -> None:
            self._count = count

        def getlist(self, key: str) -> list:
            return [object()] * self._count

    # Два файла за раз съедают две единицы лимита из трёх; на вторую пачку
    # из двух остался один слот — значит, пачка не проходит целиком.
    assert throttle.allow_request(FakeRequest(2), None) is True
    assert MediaUploadThrottle().allow_request(FakeRequest(2), None) is False
    # Одиночный файл в оставшийся слот проходит.
    assert MediaUploadThrottle().allow_request(FakeRequest(1), None) is True


def test_general_anon_throttle_is_configured(settings):
    """Общий потолок должен быть задан: без него любой обход упирается только в БД."""
    rates = settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]

    assert rates["anon"] == "100/min"
    assert rates["user"] == "300/min"


def test_every_throttle_scope_has_a_rate(settings):
    """Scope без ставки — молча выключенный лимит."""
    from apps.common.throttling import throttle_scopes

    rates = settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]
    missing = sorted(scope for scope in throttle_scopes() if scope not in rates)

    assert not missing, f"нет ставок для scope: {missing}"


def test_message_send_throttle_has_product_rate(settings):
    """Чат ограничен отдельно от общего пользовательского трафика."""
    rates = settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]

    assert rates["message_send"] == "30/min"


# -- 2. Маскирование ПДн в логах ---------------------------------------------


def test_phone_and_iin_never_reach_the_logs(caplog):
    """Главная гарантия: маскирование работает на уровне обработчика.

    Логгер здесь самый обычный — именно в этом и смысл: разработчик не
    обязан помнить про ПДн, за него помнит фильтр.
    """
    logger = logging.getLogger("tests.pii")

    with caplog.at_level(logging.INFO):
        logger.info("Пользователь %s с ИИН %s вошёл", PHONE, IIN)
        logger.warning("Ошибка у %s: iin=%s, email=user@example.kg", PHONE, IIN)

    assert PHONE not in caplog.text
    assert IIN not in caplog.text
    assert "user@example.kg" not in caplog.text
    # Маска сохраняет узнаваемость: по логам всё ещё можно разбирать инциденты.
    assert "+996 7XX XXX XX1" in caplog.text


def test_structured_logger_masks_fields():
    """Именованные поля маскируются по значению и по имени ключа."""
    masked = mask_pii(
        None,
        "info",
        {
            "event": "login",
            "phone": PHONE,
            "iin": IIN,
            "token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signature",
            "password": "hunter2",
            "request_id": "0123456789abcdef0123456789abcdef",
            "listing_price": 100000,
        },
    )

    assert masked["phone"] == "+996 7XX XXX XX1"
    assert masked["iin"] == "***"
    assert masked["token"] == "***"
    assert masked["password"] == "***"
    # Идентификатор запроса не ПДн: без него логи невозможно связать.
    assert masked["request_id"] == "0123456789abcdef0123456789abcdef"
    # Цена — не телефон.
    assert masked["listing_price"] == 100000


def test_masking_does_not_touch_ordinary_numbers():
    """Площадь, этаж и год постройки маской не портятся."""
    text = "Квартира 80 кв м, 3 комнаты, 5 этаж из 9, 2019 года, цена 100000"

    assert mask_text(text) == text


def test_mask_text_survives_all_zero_digit_runs():
    """Строка из одних нулей роняла маску телефона, а с ней и логгер."""
    text = "paymentId 00000000-0000-0000-0000-000000000000 не совпал"

    assert mask_text(text)  # не падает
    assert "00000000-0000-0000-0000-000000000000" not in mask_text(text)


def test_nested_structures_are_masked():
    masked = mask_pii(
        None,
        "info",
        {"payload": {"user": {"phone": PHONE, "contacts": [PHONE, "0700111222"]}}},
    )

    dumped = json.dumps(masked, ensure_ascii=False)
    assert PHONE not in dumped
    assert "0700111222" not in dumped


def test_request_id_appears_in_response_header(api_client):
    """request_id возвращается клиенту — его прикладывают к обращению в поддержку."""
    response = api_client.get(reverse("catalog:listings"))

    assert response.headers["X-Request-ID"]


def test_incoming_request_id_is_sanitized(api_client):
    """X-Request-ID приходит снаружи: класть его в лог как есть — инъекция."""
    response = api_client.get(
        reverse("catalog:listings"),
        HTTP_X_REQUEST_ID='bad"\n{"event":"поддельная строка"}',
    )

    returned = response.headers["X-Request-ID"]
    assert '"' not in returned
    assert "\n" not in returned


# -- 3. Шифрование ИИН -------------------------------------------------------


@pytest.fixture
def encryption_key(settings):
    settings.FIELD_ENCRYPTION_KEY = "9iXo8pPdpL3VWoyZlLUGWu517hQbs80SdWVC6m3e4aY="
    return settings.FIELD_ENCRYPTION_KEY


def test_iin_is_encrypted_in_the_database(encryption_key):
    """Проверка сырым SQL: дамп БД не должен содержать ИИН открытым текстом."""
    user = UserFactory(iin=IIN)

    with connection.cursor() as cursor:
        cursor.execute("SELECT iin FROM users_user WHERE id = %s", [user.pk])
        raw = cursor.fetchone()[0]

    assert IIN not in raw
    assert raw.startswith("enc:")
    # Через ORM значение читается обратно без изменений.
    assert User.objects.get(pk=user.pk).iin == IIN


def test_encryption_is_not_deterministic(encryption_key):
    """Два одинаковых ИИН дают разный шифротекст — иначе он ищется перебором."""
    first = UserFactory(iin=IIN)
    second = UserFactory(iin=IIN)

    with connection.cursor() as cursor:
        cursor.execute("SELECT iin FROM users_user WHERE id IN (%s, %s)", [first.pk, second.pk])
        values = [row[0] for row in cursor.fetchall()]

    assert values[0] != values[1]


def test_iin_is_masked_for_everyone_but_the_owner(pro_user, client_for, encryption_key):
    """Владелец видит свой ИИН целиком, посторонний — только маску."""
    pro_user.iin = IIN
    pro_user.save(update_fields=["iin"])

    own = client_for(pro_user).get(reverse("users:me")).data
    public = client_for(UserFactory()).get(reverse("users:seller-detail", args=[pro_user.pk])).data

    assert own["iin"] == IIN
    assert IIN not in json.dumps(public, ensure_ascii=False, default=str)


# -- 4. Журнал аудита --------------------------------------------------------


def test_wallet_spend_is_audited(wallet_with_balance):
    wallet = wallet_with_balance(balance=5_000)
    AuditLog.objects.all().delete()

    apply_transaction(wallet=wallet, amount=-780, kind=WalletEntryKind.SPEND, label="-780 кирпичей")

    record = AuditLog.objects.get(action=AuditLog.Action.WALLET_TRANSACTION)
    assert record.actor_id == wallet.user_id
    assert record.extra["amount"] == -780
    assert record.changes["balance"] == {"before": 5_000, "after": 4_220}


def test_moderation_decision_is_audited(admin_client, admin_user, district):
    from apps.catalog.services import publish_listing

    listing = ListingFactory(district=district, status=ListingStatus.DRAFT)
    ListingMediaFactory(listing=listing, is_cover=True)
    publish_listing(listing)
    task = ModerationTask.objects.get(listing=listing)

    response = admin_client.post(reverse("catalog:moderation-reject", args=[task.pk]))
    assert response.status_code in (200, 400)  # без reason_code — 400

    admin_client.post(
        reverse("catalog:moderation-reject", args=[task.pk]),
        {"reason_code": "contacts", "comment": "Телефон в описании"},
        format="json",
    )

    record = AuditLog.objects.get(action=AuditLog.Action.MODERATION_REJECTED)
    assert record.actor_id == admin_user.pk
    assert record.target_id == str(listing.pk)
    assert record.extra["reason_code"] == "contacts"


def test_password_login_is_audited(api_client):
    from apps.users.services import authenticate_by_password

    user = UserFactory(pro=True)
    user.set_password("s3cret-pass-99")
    user.save(update_fields=["password"])

    authenticate_by_password(user.phone, "s3cret-pass-99")

    record = AuditLog.objects.filter(action=AuditLog.Action.PASSWORD_LOGIN).latest("created_at")
    assert record.extra["result"] == "success"


def test_failed_password_login_is_audited():
    from apps.common.exceptions import InvalidCredentialsError
    from apps.users.services import authenticate_by_password

    user = UserFactory(pro=True)
    user.set_password("s3cret-pass-99")
    user.save(update_fields=["password"])

    with pytest.raises(InvalidCredentialsError):
        authenticate_by_password(user.phone, "неверный")

    record = AuditLog.objects.filter(action=AuditLog.Action.PASSWORD_LOGIN).latest("created_at")
    assert record.extra["result"] == "failed"


def test_price_change_is_audited(district):
    from apps.catalog.services import update_listing

    listing = ListingFactory(district=district, price=Decimal("100000.00"))

    update_listing(listing, {"price": Decimal("90000.00")})

    record = AuditLog.objects.get(action=AuditLog.Action.LISTING_PRICE_CHANGED)
    assert record.changes["price"] == {"before": "100000.00", "after": "90000.00"}


def test_account_deletion_is_audited(auth_client, user):
    auth_client.delete(reverse("users:me"))

    record = AuditLog.objects.get(action=AuditLog.Action.USER_DELETED)
    assert record.target_id == str(user.pk)


def test_audit_masks_personal_data_in_changes():
    """Журнал читает персонал — телефон и там остаётся ПДн."""
    from apps.common.audit import audit

    record = audit(
        action="test.action",
        changes={"phone": {"before": PHONE, "after": "+996700999888"}},
        extra={"iin": IIN},
    )

    assert PHONE not in json.dumps(record.changes, ensure_ascii=False)
    assert record.extra["iin"] == "***"


# -- 5. Служебные эндпоинты --------------------------------------------------


def test_metrics_are_closed_from_outside(api_client):
    """/metrics/ показывает профиль нагрузки — наружу это не отдают."""
    response = api_client.get("/metrics", REMOTE_ADDR="203.0.113.7")

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "permission_denied"


def test_metrics_are_open_from_the_internal_network(api_client):
    response = api_client.get("/metrics", REMOTE_ADDR="10.0.0.5")

    assert response.status_code == 200
    assert b"python_info" in response.content


def test_metrics_respect_forwarded_for(api_client):
    """За балансировщиком настоящий адрес приходит в X-Forwarded-For."""
    response = api_client.get(
        "/metrics/", REMOTE_ADDR="10.0.0.5", HTTP_X_FORWARDED_FOR="203.0.113.7"
    )

    assert response.status_code == 403


def test_admin_is_restricted_by_ip(api_client, settings):
    """Чужому сканеру админка отвечает 404: её существование — не новость для него."""
    settings.ALLOWED_ADMIN_IPS = ["10.0.0.0/8"]

    denied = api_client.get(f"/{settings.ADMIN_URL_PATH}", REMOTE_ADDR="203.0.113.7")
    allowed = api_client.get(f"/{settings.ADMIN_URL_PATH}", REMOTE_ADDR="10.0.0.5")

    assert denied.status_code == 404
    assert allowed.status_code in (200, 302)


# -- 6. Согласие на обработку ПДн --------------------------------------------


def test_registration_without_consent_is_rejected(api_client, settings):
    """Без согласия аккаунт не заводится — это условие обработки ПДн."""
    settings.OTP_TEST_PHONES = [PHONE]
    api_client.post(OTP_REQUEST_URL, {"phone": PHONE})

    response = api_client.post(VERIFY_URL, {"phone": PHONE, "code": DEBUG_CODE})

    assert response.status_code == 400
    details = response.json()["error"]["details"]
    assert "accepted_terms_version" in details
    assert User.objects.filter(phone=PHONE).count() == 0


def test_registration_with_stale_terms_version_is_rejected(api_client, settings):
    settings.OTP_TEST_PHONES = [PHONE]
    settings.CONSENT_DOCUMENT_VERSION = "2"
    api_client.post(OTP_REQUEST_URL, {"phone": PHONE})

    response = api_client.post(
        VERIFY_URL, {"phone": PHONE, "code": DEBUG_CODE, "accepted_terms_version": "1"}
    )

    assert response.status_code == 400
    assert response.json()["error"]["details"]["current_version"] == "2"


def test_consent_is_recorded_with_version_and_ip(api_client, settings):
    settings.OTP_TEST_PHONES = [PHONE]
    api_client.post(OTP_REQUEST_URL, {"phone": PHONE})

    response = api_client.post(
        VERIFY_URL,
        {"phone": PHONE, "code": DEBUG_CODE, "accepted_terms_version": "1"},
        REMOTE_ADDR="10.1.2.3",
    )

    assert response.status_code == 200
    consent = UserConsent.objects.get(user__phone=PHONE)
    assert consent.document_version == "1"
    assert consent.granted is True
    assert consent.ip_address == "10.1.2.3"


def test_existing_user_with_consent_logs_in_without_resending_it(api_client, settings):
    """Согласие спрашивают один раз на версию, а не на каждый вход."""
    settings.OTP_TEST_PHONES = [PHONE]
    api_client.post(OTP_REQUEST_URL, {"phone": PHONE})
    api_client.post(VERIFY_URL, {"phone": PHONE, "code": DEBUG_CODE, "accepted_terms_version": "1"})

    # Счётчик «не чаще раза в минуту» мешает второму запросу кода.
    cache.clear()
    api_client.post(OTP_REQUEST_URL, {"phone": PHONE})
    again = api_client.post(VERIFY_URL, {"phone": PHONE, "code": DEBUG_CODE})

    assert again.status_code == 200
    assert UserConsent.objects.filter(user__phone=PHONE).count() == 1


# -- 7. Выгрузка и удаление данных -------------------------------------------


def test_data_export_is_collected(auth_client, user, django_capture_on_commit_callbacks):
    from apps.users.models import DataExport, DataExportStatus

    ListingFactory(owner=user)

    with django_capture_on_commit_callbacks(execute=True):
        response = auth_client.post(reverse("users:data-export"))

    assert response.status_code == 202
    export = DataExport.objects.get(pk=response.data["id"])
    assert export.status == DataExportStatus.READY

    export.file.open("rb")
    payload = json.loads(export.file.read())
    export.file.close()

    assert payload["profile"]["phone"] == user.phone
    assert len(payload["listings"]) == 1


def test_second_export_within_a_day_is_conflict(auth_client, django_capture_on_commit_callbacks):
    with django_capture_on_commit_callbacks(execute=True):
        first = auth_client.post(reverse("users:data-export"))
    second = auth_client.post(reverse("users:data-export"))

    assert first.status_code == 202
    assert second.status_code == 409


def test_export_link_is_signed_and_user_bound(
    auth_client, user, client_for, django_capture_on_commit_callbacks
):
    with django_capture_on_commit_callbacks(execute=True):
        response = auth_client.post(reverse("users:data-export"))

    from apps.users.models import DataExport
    from apps.users.privacy import make_export_token

    export = DataExport.objects.get(pk=response.data["id"])
    token = make_export_token(export.pk, user.pk)

    ok = auth_client.get(reverse("users:data-export-file", args=[token]))
    tampered = auth_client.get(reverse("users:data-export-file", args=["broken-token"]))

    assert ok.status_code == 200
    assert tampered.status_code == 404


def test_account_deletion_purges_media_and_anonymizes_ledger(
    auth_client, user, wallet_with_balance, django_capture_on_commit_callbacks
):
    """Операции остаются для бухгалтерии, но перестают указывать на человека."""
    from apps.billing.models import WalletTransaction
    from apps.catalog.models import ListingMedia

    wallet_with_balance(user, 5_000)
    listing = ListingFactory(owner=user)
    ListingMediaFactory(listing=listing)

    with django_capture_on_commit_callbacks(execute=True):
        response = auth_client.delete(reverse("users:me"))

    assert response.status_code == 204
    assert ListingMedia.objects.filter(listing__owner=user).count() == 0

    labels = set(
        WalletTransaction.objects.filter(wallet__user=user).values_list("label", flat=True)
    )
    assert labels == {"операция удалённого аккаунта"}
    # Сами операции никуда не делись: баланс должен сходиться.
    assert WalletTransaction.objects.filter(wallet__user=user).count() == 1


def test_deleted_account_loses_contact_data(auth_client, user, django_capture_on_commit_callbacks):

    listing = ListingFactory(owner=user, contact_phone=user.phone, contact_name="Айбек")

    with django_capture_on_commit_callbacks(execute=True):
        auth_client.delete(reverse("users:me"))

    listing.refresh_from_db()
    assert listing.contact_phone == ""
    assert listing.contact_name == ""


# -- 8. Метрики --------------------------------------------------------------


def test_business_metrics_are_exposed(api_client, wallet_with_balance):
    """Бизнес-метрики должны попадать в /metrics/, а не только считаться."""
    from apps.common.metrics import observe_topup

    observe_topup(12_000)

    response = api_client.get("/metrics", REMOTE_ADDR="127.0.0.1")

    assert response.status_code == 200
    assert b"house_topup_bricks_total" in response.content


def test_moderation_queue_gauge(district):
    from apps.catalog.services import publish_listing
    from apps.common.metrics import refresh_moderation_queue_size

    listing = ListingFactory(district=district, status=ListingStatus.DRAFT)
    ListingMediaFactory(listing=listing, is_cover=True)
    publish_listing(listing)

    sizes = refresh_moderation_queue_size()

    assert sizes["listing"] == 1
    assert sizes["review"] == 0
    assert ModerationTask.objects.filter(status=ModerationStatus.OPEN).count() == 1
