"""Права доступа приложения пользователей."""

from rest_framework.permissions import BasePermission
from rest_framework.request import Request
from rest_framework.views import APIView

REVIEW_IDENTITY_PERM = "users.can_review_identity"


class IsProUser(BasePermission):
    """Только исполнитель (pro)."""

    message = "Доступно только исполнителям."

    def has_permission(self, request: Request, view: APIView) -> bool:
        user = request.user
        return bool(user and user.is_authenticated and user.is_pro)


class CanReviewIdentity(BasePermission):
    """Сотрудник с явным правом проверять документы.

    Обычного is_staff недостаточно: доступ к сканам паспортов выдаётся
    точечно, отдельным разрешением.
    """

    message = "Нужно право на проверку документов."

    def has_permission(self, request: Request, view: APIView) -> bool:
        user = request.user
        return bool(
            user and user.is_authenticated and user.is_staff and user.has_perm(REVIEW_IDENTITY_PERM)
        )
