"""Троттлинг аутентификации.

Классы переехали в `apps/common/throttling.py`: лимиты — сквозная тема, и
держать их в двух местах значит рано или поздно разойтись в настройках.
Модуль оставлен как точка совместимости для уже написанных импортов.
"""

from apps.common.throttling import (
    ContactRevealThrottle,
    IpScopedThrottle,
    KycSubmitThrottle,
    OtpIpThrottle,
    OtpPhoneHourlyThrottle,
    OtpPhoneResendThrottle,
    PasswordLoginIpThrottle,
    PasswordLoginPhoneThrottle,
    PhoneScopedThrottle,
    ReviewCreateThrottle,
)

__all__ = [
    "ContactRevealThrottle",
    "IpScopedThrottle",
    "KycSubmitThrottle",
    "OtpIpThrottle",
    "OtpPhoneHourlyThrottle",
    "OtpPhoneResendThrottle",
    "PasswordLoginIpThrottle",
    "PasswordLoginPhoneThrottle",
    "PhoneScopedThrottle",
    "ReviewCreateThrottle",
]
