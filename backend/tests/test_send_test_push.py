"""Проверочная команда push: она не должна врать об отправке."""

from io import StringIO

import pytest
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import override_settings

from apps.notifications.models import DeviceToken, Notification
from tests.factories import UserFactory


@pytest.mark.django_db
@override_settings(PUSH_ENABLED=False)
def test_disabled_mode_creates_nothing() -> None:
    """С выключенным транспортом записи быть не должно — проверки не было."""
    user = UserFactory()
    DeviceToken.objects.create(user=user, token="token-1", platform="android")

    out = StringIO()
    call_command("send_test_push", f"--user-id={user.pk}", stdout=out)

    assert "PUSH_ENABLED=0" in out.getvalue()
    assert Notification.objects.count() == 0


@pytest.mark.django_db
@override_settings(PUSH_ENABLED=True)
def test_requires_active_device() -> None:
    """Без устройства отправлять некуда — честная ошибка вместо тихого успеха."""
    user = UserFactory()

    with pytest.raises(CommandError, match="нет активных устройств"):
        call_command("send_test_push", f"--user-id={user.pk}")

    assert Notification.objects.count() == 0


@pytest.mark.django_db
@override_settings(PUSH_ENABLED=True)
def test_unknown_user_is_an_error() -> None:
    with pytest.raises(CommandError, match="не найден"):
        call_command("send_test_push", "--user-id=999999999")


@pytest.mark.django_db
def test_user_id_is_required() -> None:
    """Команда шлёт push живому человеку: «кому-нибудь» здесь недопустимо."""
    with pytest.raises(CommandError):
        call_command("send_test_push")


@pytest.mark.django_db
@override_settings(PUSH_ENABLED=True)
def test_creates_exactly_one_notification() -> None:
    user = UserFactory()
    DeviceToken.objects.create(user=user, token="token-1", platform="android")

    out = StringIO()
    call_command("send_test_push", f"--user-id={user.pk}", stdout=out)

    assert Notification.objects.filter(user=user).count() == 1
    assert Notification.objects.get(user=user).payload["kind"] == "test_push"
