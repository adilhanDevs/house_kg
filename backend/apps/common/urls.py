"""URL-маршруты общего приложения."""

from django.urls import path

from apps.common.views import (
    AppConfigView,
    HealthView,
    OnboardingView,
    StaticPageView,
    SupportTicketCreateView,
)

app_name = "common"

urlpatterns = [
    path("health/", HealthView.as_view(), name="health"),
    path("app/config/", AppConfigView.as_view(), name="app-config"),
    path("app/onboarding/", OnboardingView.as_view(), name="app-onboarding"),
    path("app/pages/<slug:slug>/", StaticPageView.as_view(), name="static-page"),
    path("support/tickets/", SupportTicketCreateView.as_view(), name="support-tickets"),
]
