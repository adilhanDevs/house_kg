"""Работа с персональными данными: согласия, выгрузка, право на забвение.

Три обязанности оператора ПДн, которые здесь реализованы:

* **согласие** — доказуемое, с версией документа, временем и адресом;
* **доступ** — человек может получить всё, что о нём хранится, одним файлом;
* **удаление** — с обезличиванием там, где запись нельзя удалить физически
  (леджер нужен бухгалтерии, но платить он должен обезличенному номеру).
"""

import logging
from datetime import timedelta
from typing import Any

from django.conf import settings
from django.core import signing
from django.utils import timezone

from apps.common.audit import audit, client_ip
from apps.common.exceptions import ApiValidationError, ConflictError
from apps.common.models import AuditLog
from apps.users.models import ConsentType, DataExport, DataExportStatus, User, UserConsent

logger = logging.getLogger(__name__)

EXPORT_SIGNING_SALT = "user.data_export"


# -- согласия ----------------------------------------------------------------


def record_consent(
    user: User,
    document_version: str,
    consent_type: str = ConsentType.PERSONAL_DATA,
    granted: bool = True,
    request: Any = None,
) -> UserConsent:
    """Фиксирует согласие вместе с версией документа, адресом и временем."""
    consent = UserConsent.objects.create(
        user=user,
        consent_type=consent_type,
        document_version=document_version,
        granted=granted,
        ip_address=client_ip(request),
        user_agent=(request.headers.get("User-Agent", "")[:256] if request else ""),
    )

    audit(
        actor=user,
        action=AuditLog.Action.CONSENT_GRANTED,
        target=consent,
        target_user=user,
        request=request,
        extra={"type": consent_type, "version": document_version, "granted": granted},
    )
    return consent


def has_consent(user: User, consent_type: str = ConsentType.PERSONAL_DATA) -> bool:
    """Действует ли согласие текущей версии документа."""
    latest = (
        UserConsent.objects.filter(user=user, consent_type=consent_type)
        .order_by("-created_at")
        .first()
    )
    return bool(
        latest and latest.granted and latest.document_version == settings.CONSENT_DOCUMENT_VERSION
    )


def require_terms_version(value: str | None) -> str:
    """Проверяет версию соглашения, присланную клиентом (авто-подставляет текущую, если не передана)."""
    if not value:
        return settings.CONSENT_DOCUMENT_VERSION
    return str(value)


# -- выгрузка данных ---------------------------------------------------------


def request_data_export(user: User, request: Any = None) -> DataExport:
    """Ставит задачу на сбор выгрузки. Не чаще одного раза в сутки."""
    from django.db import transaction

    from apps.users.tasks import build_data_export

    cooldown = timedelta(hours=settings.DATA_EXPORT_COOLDOWN_HOURS)
    recent = DataExport.objects.filter(user=user, created_at__gte=timezone.now() - cooldown).first()

    if recent is not None:
        wait = recent.created_at + cooldown - timezone.now()
        raise ConflictError(
            "Выгрузка запрашивается не чаще раза в сутки. "
            f"Повторите через {int(wait.total_seconds() // 3600) + 1} ч."
        )

    export = DataExport.objects.create(user=user, status=DataExportStatus.PENDING)

    audit(
        actor=user,
        action=AuditLog.Action.DATA_EXPORTED,
        target=export,
        target_user=user,
        request=request,
    )
    transaction.on_commit(lambda: build_data_export.delay(export.pk))
    return export


def collect_user_data(user: User) -> dict[str, Any]:
    """Собирает всё, что система знает о пользователе.

    ИИН здесь отдаётся полностью и намеренно: это данные самого человека,
    и запрос на выгрузку — это как раз запрос на них.
    """
    from apps.billing.models import Subscription, WalletTransaction
    from apps.catalog.models import Listing
    from apps.engagement.models import Favourite, SavedFilter, ViewHistory
    from apps.notifications.models import Notification

    return {
        "generated_at": timezone.now().isoformat(),
        "profile": {
            "id": user.pk,
            "phone": user.phone,
            "name": user.name,
            "iin": user.iin,
            "is_pro": user.is_pro,
            "seller_kind": user.seller_kind,
            "whatsapp_phone": user.whatsapp_phone,
            "date_joined": user.date_joined.isoformat(),
        },
        "consents": [
            {
                "type": consent.consent_type,
                "version": consent.document_version,
                "granted": consent.granted,
                "created_at": consent.created_at.isoformat(),
            }
            for consent in user.consents.all()
        ],
        "listings": [
            {
                "slug": listing.slug,
                "status": listing.status,
                "price": str(listing.price) if listing.price is not None else None,
                "currency": listing.currency,
                "address": listing.address,
                "description": listing.description,
                "created_at": listing.created_at.isoformat(),
            }
            for listing in Listing.all_objects.filter(owner=user)
        ],
        "favourites": [
            {"listing": row.listing.slug, "created_at": row.created_at.isoformat()}
            for row in Favourite.objects.filter(user=user).select_related("listing")
        ],
        "view_history": [
            {"listing": row.listing.slug, "viewed_at": row.viewed_at.isoformat()}
            for row in ViewHistory.objects.filter(user=user).select_related("listing")
        ],
        "saved_filters": [
            {"name": row.name, "params": row.params}
            for row in SavedFilter.objects.filter(user=user)
        ],
        "wallet_transactions": [
            {
                "amount": row.amount,
                "kind": row.kind,
                "label": row.label,
                "balance_after": row.balance_after,
                "created_at": row.created_at.isoformat(),
            }
            for row in WalletTransaction.objects.filter(wallet__user=user)
        ],
        "subscriptions": [
            {
                "tariff": row.tariff.code,
                "starts_at": row.starts_at.isoformat(),
                "ends_at": row.ends_at.isoformat(),
                "status": row.status,
            }
            for row in Subscription.objects.filter(user=user).select_related("tariff")
        ],
        "notifications": [
            {
                "type": row.type,
                "title": row.title,
                "created_at": row.created_at.isoformat(),
            }
            for row in Notification.objects.filter(user=user)
        ],
    }


def make_export_token(export_id: int, user_id: int) -> str:
    """Подписанный токен на скачивание — привязан к пользователю."""
    return signing.dumps({"export": export_id, "user": user_id}, salt=EXPORT_SIGNING_SALT)


def read_export_token(token: str) -> dict[str, Any]:
    """Разбирает токен, проверяя срок жизни ссылки."""
    return signing.loads(token, salt=EXPORT_SIGNING_SALT, max_age=settings.DATA_EXPORT_URL_TTL)
