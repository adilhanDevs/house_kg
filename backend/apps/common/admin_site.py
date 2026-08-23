"""Админка с обязательным вторым фактором.

Доступ в админку — это доступ к персональным данным граждан: телефонам,
ИИН, документам верификации. Одного пароля для этого мало: он утекает
вместе с любым другим сервисом, где сотрудник использовал тот же.

Требование включается настройкой `ADMIN_REQUIRE_OTP`: локально его удобно
выключить, на проде оно включено по умолчанию (см. production.py).

Наследуемся от обычного `AdminSite`, а не от `OTPAdminSite`: последний
тянет модели django_otp на этапе импорта настроек, когда реестр приложений
ещё не готов. Всё, что нужно, — проверка `is_verified()` и форма входа с
полем токена; и то и другое подключается лениво.
"""

from typing import Any

from django.conf import settings
from django.contrib.admin.apps import AdminConfig
from django.contrib.admin.sites import AdminSite
from django.http import HttpRequest


class HouseAdminSite(AdminSite):
    """Админка проекта: пароль плюс второй фактор."""

    site_header = "house_kgz"
    site_title = "house_kgz"
    index_title = "Управление"

    @property
    def login_form(self) -> Any:  # type: ignore[override]
        """Форма входа с полем одноразового кода — импорт ленивый."""
        if not getattr(settings, "ADMIN_REQUIRE_OTP", False):
            from django.contrib.admin.forms import AdminAuthenticationForm

            return AdminAuthenticationForm

        from django_otp.forms import OTPAuthenticationForm

        return OTPAuthenticationForm

    @login_form.setter
    def login_form(self, value: Any) -> None:
        """AdminSite.__init__ присваивает атрибут — принимаем и игнорируем."""

    def has_permission(self, request: HttpRequest) -> bool:
        if not super().has_permission(request):
            return False

        if not getattr(settings, "ADMIN_REQUIRE_OTP", False):
            return True

        # is_verified() добавляет OTPMiddleware: True только когда сотрудник
        # подтвердил одноразовый код в этой сессии.
        is_verified = getattr(request.user, "is_verified", None)
        return bool(is_verified and is_verified())


class HouseAdminConfig(AdminConfig):
    """Подменяет стандартный admin.site на наш."""

    default_site = "apps.common.admin_site.HouseAdminSite"

    def ready(self) -> None:
        super().ready()

        # Устройства второго фактора регистрируются здесь: сотрудник должен
        # уметь завести себе токен, не выходя из админки.
        from django.contrib import admin
        from django_otp.plugins.otp_static.admin import StaticDeviceAdmin
        from django_otp.plugins.otp_static.models import StaticDevice
        from django_otp.plugins.otp_totp.admin import TOTPDeviceAdmin
        from django_otp.plugins.otp_totp.models import TOTPDevice

        for model, admin_class in (
            (TOTPDevice, TOTPDeviceAdmin),
            (StaticDevice, StaticDeviceAdmin),
        ):
            if model not in admin.site._registry:
                admin.site.register(model, admin_class)
