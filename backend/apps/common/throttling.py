"""Ограничение частоты запросов.

Счётчики живут в Redis (кэш по умолчанию), поэтому лимит общий для всех
воркеров: с четырьмя процессами gunicorn лимит «5 в час» должен оставаться
пятью, а не двадцатью.

Три вида ключей, и они решают разные задачи:

* **по номеру телефона** — против перебора кодов и рассылки SMS за чужой счёт;
  ключ берётся из тела запроса до всякой аутентификации;
* **по IP** — против массового обхода с одной машины;
* **по пользователю** — против выгрузки данных уже залогиненным аккаунтом.

Ответ при превышении собирает общий обработчик ошибок: `429` с
`details.retry_after` — клиент знает, через сколько секунд повторить.
"""

from typing import TYPE_CHECKING, Any

from rest_framework.request import Request
from rest_framework.throttling import AnonRateThrottle, SimpleRateThrottle, UserRateThrottle

if TYPE_CHECKING:  # pragma: no cover - только для аннотаций
    # Импорт rest_framework.views на уровне модуля даёт цикл: DRF резолвит
    # DEFAULT_THROTTLE_CLASSES ещё до того, как views догрузится.
    from rest_framework.views import APIView


class PhoneScopedThrottle(SimpleRateThrottle):
    """Ключ — нормализованный номер из тела запроса.

    Нормализация обязательна: «0555 12 34 56» и «+996555123456» — один и тот
    же номер, и считать их отдельно значит не считать вовсе.
    """

    def get_cache_key(self, request: Request, view: "APIView") -> str | None:
        from apps.users.phone import normalize_phone

        raw = (request.data or {}).get("phone") if hasattr(request, "data") else None
        if not raw:
            return None
        try:
            phone = normalize_phone(str(raw))
        except Exception:
            # Невалидный номер отсеет сериализатор — считать его не за что.
            return None
        return self.cache_format % {"scope": self.scope, "ident": phone}


class IpScopedThrottle(SimpleRateThrottle):
    """Ключ — IP клиента (с учётом обратного прокси)."""

    def get_cache_key(self, request: Request, view: "APIView") -> str:
        return self.cache_format % {"scope": self.scope, "ident": self.get_ident(request)}


class UserScopedThrottle(SimpleRateThrottle):
    """Ключ — идентификатор пользователя. Аноним не считается вовсе."""

    def get_cache_key(self, request: Request, view: "APIView") -> str | None:
        user = request.user
        if not (user and user.is_authenticated):
            return None
        return self.cache_format % {"scope": self.scope, "ident": user.pk}


class UserOrIpThrottle(SimpleRateThrottle):
    """Пользователь, если он есть, иначе IP."""

    def get_cache_key(self, request: Request, view: "APIView") -> str:
        user = request.user
        ident = user.pk if user and user.is_authenticated else self.get_ident(request)
        return self.cache_format % {"scope": self.scope, "ident": ident}


# -- общие лимиты ------------------------------------------------------------


class DefaultAnonThrottle(AnonRateThrottle):
    """Потолок для анонимов — 100 запросов в минуту.

    Это не защита от DDoS (она уровнем выше), а страховка от скрипта,
    который обходит каталог в один поток без пауз.
    """

    scope = "anon"


class DefaultUserThrottle(UserRateThrottle):
    """Потолок для залогиненных — 300 запросов в минуту."""

    scope = "user"


# -- аутентификация ----------------------------------------------------------


class OtpPhoneResendThrottle(PhoneScopedThrottle):
    """Не чаще одного кода в минуту на номер."""

    scope = "otp_phone_resend"


class OtpPhoneHourlyThrottle(PhoneScopedThrottle):
    """Не больше пяти кодов в час на номер: SMS стоят денег."""

    scope = "otp_phone_hourly"


class OtpIpThrottle(IpScopedThrottle):
    """Не больше двадцати запросов кода в час с одного IP."""

    scope = "otp_ip"


class PasswordLoginPhoneThrottle(PhoneScopedThrottle):
    """Десять попыток входа по паролю в час на номер — против перебора."""

    scope = "password_login_phone"


class PasswordLoginIpThrottle(IpScopedThrottle):
    """Тридцать попыток входа по паролю в час с одного IP."""

    scope = "password_login_ip"


# -- данные и деньги ---------------------------------------------------------


class ContactRevealThrottle(UserScopedThrottle):
    """Тридцать раскрытий телефона в час.

    Порог не про удобство, а про выгрузку базы: живой человек за час
    открывает единицы номеров, а скрипт — сотни.
    """

    scope = "contact_reveal"


class MessageSendThrottle(UserScopedThrottle):
    """Тридцать отправок сообщений в минуту на пользователя."""

    scope = "message_send"


class MediaUploadThrottle(UserScopedThrottle):
    """Сто файлов в час на пользователя.

    Считаются именно файлы, а не запросы: загрузка идёт пачками, и лимит
    «20 запросов» ничего не ограничивал бы при двадцати файлах в каждом.
    """

    scope = "media_upload"

    def allow_request(self, request: Request, view: "APIView") -> bool:
        """Пропускает пачку целиком или не пропускает вовсе.

        Проверка идёт до списания: иначе запрос с двадцатью файлами при
        одном свободном слоте прошёл бы полностью — «хватило места первому»
        не значит «хватило места всем».
        """
        if self.rate is None:
            return True

        self.key = self.get_cache_key(request, view)
        if self.key is None:
            return True

        files = request.FILES.getlist("files") if hasattr(request, "FILES") else []
        count = max(len(files), 1)

        self.history = self.cache.get(self.key, [])
        self.now = self.timer()

        while self.history and self.history[-1] <= self.now - self.duration:
            self.history.pop()

        if len(self.history) + count > self.num_requests:
            return self.throttle_failure()

        for _ in range(count):
            self.history.insert(0, self.now)
        self.cache.set(self.key, self.history, self.duration)
        return True


class TopupThrottle(UserScopedThrottle):
    """Десять счетов на пополнение в час: больше — это перебор карт."""

    scope = "wallet_topup"


class KycSubmitThrottle(UserScopedThrottle):
    """Три подачи документов в сутки на пользователя."""

    scope = "kyc_submit"


class ReviewCreateThrottle(UserScopedThrottle):
    """Десять отзывов в сутки: живой человек столько не пишет."""

    scope = "review_create"


class SupportTicketThrottle(UserOrIpThrottle):
    """Пять обращений в час: для залогиненного — на пользователя, иначе на IP."""

    scope = "support_tickets"


def throttle_scopes() -> dict[str, Any]:
    """Все объявленные scope — используется тестом на полноту настроек."""
    return {
        cls.scope
        for cls in globals().values()
        if isinstance(cls, type)
        and issubclass(cls, SimpleRateThrottle)
        and getattr(cls, "scope", None)
    }
