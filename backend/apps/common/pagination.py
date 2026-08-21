"""Пагинация по умолчанию для всего API."""

from collections import OrderedDict
from typing import Any

from rest_framework.pagination import CursorPagination
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView


class DefaultCursorPagination(CursorPagination):
    """Курсорная пагинация с ответом ``{results, next, previous, count}``.

    Курсор устойчив к вставкам новых записей (важно для ленты объявлений),
    а ``count`` считается отдельным запросом — он нужен мобильному клиенту
    для отображения общего количества найденных объектов.
    """

    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100
    cursor_query_param = "cursor"
    ordering = "-created_at"

    def paginate_queryset(
        self, queryset: Any, request: Request, view: APIView | None = None
    ) -> list[Any] | None:
        self.total_count = self._get_total_count(queryset)
        return super().paginate_queryset(queryset, request, view)

    def get_paginated_response(self, data: Any) -> Response:
        return Response(
            OrderedDict(
                [
                    ("results", data),
                    ("next", self.get_next_link()),
                    ("previous", self.get_previous_link()),
                    ("count", getattr(self, "total_count", None)),
                ]
            )
        )

    def get_paginated_response_schema(self, schema: dict[str, Any]) -> dict[str, Any]:
        return {
            "type": "object",
            "required": ["results", "next", "previous", "count"],
            "properties": {
                "results": schema,
                "next": {"type": "string", "nullable": True, "format": "uri"},
                "previous": {"type": "string", "nullable": True, "format": "uri"},
                "count": {"type": "integer", "example": 123},
            },
        }

    @staticmethod
    def _get_total_count(queryset: Any) -> int | None:
        try:
            return queryset.count()
        except (AttributeError, TypeError):
            try:
                return len(queryset)
            except TypeError:
                return None
