from typing import Any

from django.contrib import admin
from django.http import HttpRequest

from apps.messaging.models import Conversation, Message


class ReadOnlyAdminMixin:
    def has_add_permission(self, request: HttpRequest) -> bool:
        return False

    def has_change_permission(self, request: HttpRequest, obj: Any = None) -> bool:
        return False

    def has_delete_permission(self, request: HttpRequest, obj: Any = None) -> bool:
        return False


@admin.register(Conversation)
class ConversationAdmin(ReadOnlyAdminMixin, admin.ModelAdmin):
    list_display = ["id", "listing_slug", "buyer", "seller", "last_message_at"]
    search_fields = ["listing_slug", "buyer__phone", "seller__phone"]
    list_select_related = ["buyer", "seller"]
    date_hierarchy = "last_message_at"


@admin.register(Message)
class MessageAdmin(ReadOnlyAdminMixin, admin.ModelAdmin):
    list_display = ["id", "conversation", "sender", "client_message_id", "created_at"]
    search_fields = ["conversation__id", "sender__phone", "client_message_id"]
    list_select_related = ["conversation", "sender"]
    date_hierarchy = "created_at"
