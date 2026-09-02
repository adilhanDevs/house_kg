"""Пагинация диалогов и сообщений."""

from dataclasses import dataclass
from datetime import datetime
from typing import Any
from uuid import UUID

from django.core import signing
from django.db.models import Q
from django.utils.dateparse import parse_datetime
from rest_framework.exceptions import NotFound
from rest_framework.request import Request
from rest_framework.utils.urls import replace_query_param
from rest_framework.views import APIView

from apps.common.pagination import DefaultCursorPagination


class ConversationCursorPagination(DefaultCursorPagination):
    ordering = ("-last_message_at", "-id")


@dataclass(frozen=True)
class _MessageCursor:
    mode: str
    direction: str
    created_at: datetime
    message_id: UUID


class MessageCursorPagination(DefaultCursorPagination):
    """Composite keyset по ``(created_at, id)`` без offset-артефактов.

    History начинается с newest page и движется к older через ``next``.
    Incremental polling с ``after`` начинается с earliest unseen и движется
    к newer. В обоих режимах каждая response page отдаётся хронологически.
    """

    cursor_salt = "messaging.message-keyset.v1"

    def paginate_queryset(
        self,
        queryset: Any,
        request: Request,
        view: APIView | None = None,
    ) -> list[Any] | None:
        self.request = request
        self.page_size = self.get_page_size(request)
        if not self.page_size:
            return None

        self.base_url = request.build_absolute_uri()
        self.total_count = self._get_total_count(queryset)
        expected_mode = "incremental" if "after" in request.query_params else "history"
        cursor = self._decode_message_cursor(request)
        if cursor is not None and cursor.mode != expected_mode:
            raise NotFound(self.invalid_cursor_message)

        mode = cursor.mode if cursor is not None else expected_mode
        direction = (
            cursor.direction
            if cursor is not None
            else ("newer" if mode == "incremental" else "older")
        )
        if cursor is not None:
            queryset = self._apply_boundary(queryset, cursor)

        ordering = ("created_at", "id") if direction == "newer" else ("-created_at", "-id")
        rows = list(queryset.order_by(*ordering)[: self.page_size + 1])
        has_more = len(rows) > self.page_size
        selected = rows[: self.page_size]
        if direction == "older":
            selected.reverse()
        self.page = selected

        has_older = has_more if direction == "older" else cursor is not None
        has_newer = has_more if direction == "newer" else cursor is not None
        self._next_cursor: _MessageCursor | None = None
        self._previous_cursor: _MessageCursor | None = None
        if self.page:
            oldest = self.page[0]
            newest = self.page[-1]
            if mode == "history":
                if has_older:
                    self._next_cursor = self._cursor_at(mode, "older", oldest)
                if has_newer:
                    self._previous_cursor = self._cursor_at(mode, "newer", newest)
            else:
                if has_newer:
                    self._next_cursor = self._cursor_at(mode, "newer", newest)
                if has_older:
                    self._previous_cursor = self._cursor_at(mode, "older", oldest)

        self.has_next = self._next_cursor is not None
        self.has_previous = self._previous_cursor is not None
        if self.has_next or self.has_previous:
            self.display_page_controls = True
        return self.page

    def get_next_link(self) -> str | None:
        return self._encode_message_cursor(self._next_cursor)

    def get_previous_link(self) -> str | None:
        return self._encode_message_cursor(self._previous_cursor)

    @staticmethod
    def _apply_boundary(queryset: Any, cursor: _MessageCursor) -> Any:
        time_filter = (
            Q(created_at__gt=cursor.created_at)
            | Q(created_at=cursor.created_at, id__gt=cursor.message_id)
            if cursor.direction == "newer"
            else Q(created_at__lt=cursor.created_at)
            | Q(created_at=cursor.created_at, id__lt=cursor.message_id)
        )
        return queryset.filter(time_filter)

    @staticmethod
    def _cursor_at(mode: str, direction: str, message: Any) -> _MessageCursor:
        return _MessageCursor(
            mode=mode,
            direction=direction,
            created_at=message.created_at,
            message_id=message.id,
        )

    def _decode_message_cursor(self, request: Request) -> _MessageCursor | None:
        encoded = request.query_params.get(self.cursor_query_param)
        if encoded is None:
            return None
        try:
            payload = signing.loads(encoded, salt=self.cursor_salt)
            mode = payload["mode"]
            direction = payload["direction"]
            created_at = parse_datetime(payload["created_at"])
            message_id = UUID(payload["id"])
            if mode not in {"history", "incremental"}:
                raise ValueError
            if direction not in {"older", "newer"} or created_at is None:
                raise ValueError
        except (signing.BadSignature, KeyError, TypeError, ValueError):
            raise NotFound(self.invalid_cursor_message) from None
        return _MessageCursor(mode, direction, created_at, message_id)

    def _encode_message_cursor(self, cursor: _MessageCursor | None) -> str | None:
        if cursor is None:
            return None
        encoded = signing.dumps(
            {
                "mode": cursor.mode,
                "direction": cursor.direction,
                "created_at": cursor.created_at.isoformat(),
                "id": str(cursor.message_id),
            },
            salt=self.cursor_salt,
            compress=True,
        )
        return replace_query_param(self.base_url, self.cursor_query_param, encoded)
