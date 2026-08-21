"""Троттлинг запросов SMS-кода: по номеру и по IP.

Счётчики живут в Redis (кэш по умолчанию), поэтому лимит общий для всех воркеров.
"""

from rest_framework.request import Request
from rest_framework.throttling import SimpleRateThrottle
from rest_framework.views import APIView

from apps.users.phone import normalize_phone


class PhoneScopedThrottle(SimpleRateThrottle):
    """Общий предок: ключ — нормализованный номер из тела запроса."""

    def get_cache_key(self, request: Request, view: APIView) -> str | None:
        raw = (request.data or {}).get("phone") if hasattr(request, "data") else None
        if not raw:
            return None
        try:
            phone = normalize_phone(str(raw))
        except Exception:
            # Невалидный номер отсеет сериализатор — считать его не за что.
            return None
        return self.cache_format % {"scope": self.scope, "ident": phone}


class OtpPhoneResendThrottle(PhoneScopedThrottle):
    """Не чаще одного кода в минуту на номер."""

    scope = "otp_phone_resend"


class OtpPhoneHourlyThrottle(PhoneScopedThrottle):
    """Не больше пяти кодов в час на номер."""

    scope = "otp_phone_hourly"


class IpScopedThrottle(SimpleRateThrottle):
    """Общий предок: ключ — IP клиента."""

    def get_cache_key(self, request: Request, view: APIView) -> str:
        return self.cache_format % {"scope": self.scope, "ident": self.get_ident(request)}


class OtpIpThrottle(IpScopedThrottle):
    """Не больше двадцати запросов кода в час с одного IP."""

    scope = "otp_ip"


class PasswordLoginPhoneThrottle(PhoneScopedThrottle):
    """Не больше десяти попыток входа по паролю в час на номер."""

    scope = "password_login_phone"


class PasswordLoginIpThrottle(IpScopedThrottle):
    """Не больше тридцати попыток входа по паролю в час с одного IP."""

    scope = "password_login_ip"


class KycSubmitThrottle(SimpleRateThrottle):
    """Не больше трёх подач документов в сутки на пользователя."""

    scope = "kyc_submit"

    def get_cache_key(self, request: Request, view: APIView) -> str | None:
        user = request.user
        if not (user and user.is_authenticated):
            return None
        return self.cache_format % {"scope": self.scope, "ident": user.pk}
