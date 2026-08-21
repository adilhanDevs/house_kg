"""Общие классы прав доступа."""

from typing import Any

from django.db.models import Model
from rest_framework.permissions import SAFE_METHODS, BasePermission
from rest_framework.request import Request
from rest_framework.views import APIView


class IsOwnerOrReadOnly(BasePermission):
    """Читать может кто угодно, изменять — только владелец объекта.

    Владелец ищется по первому существующему полю из ``owner_fields``.
    Если ни одного такого поля нет, доступ на запись запрещён.
    """

    message = "Изменять этот объект может только его владелец."
    owner_fields: tuple[str, ...] = ("owner", "user", "author", "created_by")

    def has_object_permission(self, request: Request, view: APIView, obj: Model) -> bool:
        if request.method in SAFE_METHODS:
            return True

        user = request.user
        if not user or not user.is_authenticated:
            return False

        owner = self._get_owner(obj)
        if owner is None:
            return False
        return owner == user

    def _get_owner(self, obj: Model) -> Any | None:
        for field in self.owner_fields:
            if hasattr(obj, field):
                return getattr(obj, field)
        return None
