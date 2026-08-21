"""Троттлинг обращений в поддержку."""

from rest_framework.request import Request
from rest_framework.throttling import SimpleRateThrottle
from rest_framework.views import APIView


class SupportTicketThrottle(SimpleRateThrottle):
    """5 обращений в час: для залогиненного — на пользователя, иначе — на IP."""

    scope = "support_tickets"

    def get_cache_key(self, request: Request, view: APIView) -> str:
        user = request.user
        ident = user.pk if user and user.is_authenticated else self.get_ident(request)
        return self.cache_format % {"scope": self.scope, "ident": ident}
