"""URL-маршруты диалогов."""

from django.urls import path

from apps.messaging.views import (
    ConversationDetailView,
    ConversationListCreateView,
    ConversationReadView,
    MessageListCreateView,
)

app_name = "messaging"

urlpatterns = [
    path("conversations/", ConversationListCreateView.as_view(), name="conversation-list"),
    path(
        "conversations/<uuid:conversation_id>/",
        ConversationDetailView.as_view(),
        name="conversation-detail",
    ),
    path(
        "conversations/<uuid:conversation_id>/messages/",
        MessageListCreateView.as_view(),
        name="message-list",
    ),
    path(
        "conversations/<uuid:conversation_id>/read/",
        ConversationReadView.as_view(),
        name="conversation-read",
    ),
]
