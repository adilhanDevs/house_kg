"""Права доступа каталога."""

from rest_framework.permissions import BasePermission
from rest_framework.request import Request
from rest_framework.views import APIView

from apps.catalog.models import Listing


class IsListingOwner(BasePermission):
    """Менять объявление может только его владелец.

    Чужое опубликованное объявление даёт 403, а не 404: то, что оно
    существует и принадлежит кому-то другому, не секрет. Чужие черновики
    скрыты на уровне queryset — там будет 404.
    """

    message = "Изменять объявление может только его владелец."

    def has_object_permission(self, request: Request, view: APIView, obj: Listing) -> bool:
        user = request.user
        return bool(user and user.is_authenticated and obj.owner_id == user.pk)


class IsModerator(BasePermission):
    """Очередь модерации — только для сотрудников.

    Обычный пользователь не должен даже знать, что у объявления есть задача
    модерации и какие автопроверки на нём сработали.
    """

    message = "Раздел доступен только модераторам."

    def has_permission(self, request: Request, view: APIView) -> bool:
        user = request.user
        return bool(user and user.is_authenticated and user.is_staff)
