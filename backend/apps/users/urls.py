"""URL-маршруты пользователей и аутентификации."""

from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from apps.users.views import (
    ConsentView,
    DataExportFileView,
    DataExportView,
    IdentityFileView,
    IdentityQueueView,
    IdentityReviewView,
    IdentityVerificationView,
    ListingContactView,
    LogoutView,
    MyReviewView,
    OtpRequestView,
    OtpVerifyView,
    PasswordChangeView,
    PasswordLoginView,
    PasswordResetView,
    ProRegisterView,
    SellerDetailView,
    SellerListingsView,
    SellerMeView,
    SellerReviewsView,
    SellerVerificationView,
    UserMeView,
)

app_name = "users"

urlpatterns = [
    path("auth/otp/request/", OtpRequestView.as_view(), name="otp-request"),
    path("auth/otp/verify/", OtpVerifyView.as_view(), name="otp-verify"),
    path("auth/pro/register/", ProRegisterView.as_view(), name="pro-register"),
    path("auth/password/login/", PasswordLoginView.as_view(), name="password-login"),
    path("auth/password/reset/", PasswordResetView.as_view(), name="password-reset"),
    path("auth/password/change/", PasswordChangeView.as_view(), name="password-change"),
    path("auth/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    path("auth/logout/", LogoutView.as_view(), name="logout"),
    path("users/me/", UserMeView.as_view(), name="me"),
    # Права субъекта ПДн: доступ к своим данным и управление согласиями.
    path("users/me/export/", DataExportView.as_view(), name="data-export"),
    path(
        "users/me/export/<str:token>/",
        DataExportFileView.as_view(),
        name="data-export-file",
    ),
    path("users/me/consents/", ConsentView.as_view(), name="consents"),
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
    # Профиль продавца. `me` объявлен до <int:user_id>, хотя конвертер их
    # и так не спутает.
    path("sellers/me/", SellerMeView.as_view(), name="seller-me"),
    path(
        "sellers/me/verification/",
        SellerVerificationView.as_view(),
        name="seller-verification",
    ),
    path("sellers/<int:user_id>/", SellerDetailView.as_view(), name="seller-detail"),
    path(
        "sellers/<int:user_id>/listings/",
        SellerListingsView.as_view(),
        name="seller-listings",
    ),
    path(
        "sellers/<int:user_id>/reviews/",
        SellerReviewsView.as_view(),
        name="seller-reviews",
    ),
    path("reviews/<int:review_id>/", MyReviewView.as_view(), name="review-detail"),
    path("listings/<slug:slug>/contact/", ListingContactView.as_view(), name="listing-contact"),
]
