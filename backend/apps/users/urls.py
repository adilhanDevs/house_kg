"""URL-маршруты пользователей и аутентификации."""

from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from apps.users.views import (
    IdentityFileView,
    IdentityQueueView,
    IdentityReviewView,
    IdentityVerificationView,
    LogoutView,
    OtpRequestView,
    OtpVerifyView,
    PasswordLoginView,
    ProRegisterView,
    UserMeView,
)

app_name = "users"

urlpatterns = [
    path("auth/otp/request/", OtpRequestView.as_view(), name="otp-request"),
    path("auth/otp/verify/", OtpVerifyView.as_view(), name="otp-verify"),
    path("auth/pro/register/", ProRegisterView.as_view(), name="pro-register"),
    path("auth/password/login/", PasswordLoginView.as_view(), name="password-login"),
    path("auth/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    path("auth/logout/", LogoutView.as_view(), name="logout"),
    path("users/me/", UserMeView.as_view(), name="me"),
    path(
        "verification/identity/",
        IdentityVerificationView.as_view(),
        name="identity-verification",
    ),
    path(
        "verification/identity/<int:pk>/review/",
        IdentityReviewView.as_view(),
        name="identity-review",
    ),
    path("verification/queue/", IdentityQueueView.as_view(), name="identity-queue"),
    path("verification/files/<str:token>/", IdentityFileView.as_view(), name="kyc-file"),
]
