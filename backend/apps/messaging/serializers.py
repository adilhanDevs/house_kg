"""Сериализаторы диалогов."""

from typing import Any

from rest_framework import serializers

from apps.messaging.models import Conversation, Message


class ConversationCreateSerializer(serializers.Serializer):
    listing_slug = serializers.SlugField(max_length=220)


class ConversationSerializer(serializers.ModelSerializer):
    peer = serializers.SerializerMethodField()
    latest_message = serializers.SerializerMethodField()
    unread_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = Conversation
        fields = [
            "id",
            "listing_slug",
            "listing_title",
            "listing_price",
            "listing_currency",
            "listing_cover_url",
            "peer",
            "latest_message",
            "unread_count",
            "last_message_at",
        ]
        read_only_fields = fields

    def get_peer(self, obj: Conversation) -> dict[str, Any]:
        peer = obj.peer_for(self.context["request"].user)
        avatar_url = None
        if peer.avatar:
            avatar_url = self.context["request"].build_absolute_uri(peer.avatar.url)
        return {"id": peer.id, "name": peer.name, "avatar_url": avatar_url}

    def get_latest_message(self, obj: Conversation) -> dict[str, Any] | None:
        message_id = getattr(obj, "latest_message_id", None)
        if message_id is None:
            return None
        return {
            "id": serializers.UUIDField().to_representation(message_id),
            "sender_id": obj.latest_message_sender_id,
            "text": obj.latest_message_text,
            "created_at": serializers.DateTimeField().to_representation(
                obj.latest_message_created_at
            ),
        }


class MessageCreateSerializer(serializers.Serializer):
    text = serializers.CharField(max_length=2000, allow_blank=False, trim_whitespace=True)
    client_message_id = serializers.UUIDField()


class MessagePollSerializer(serializers.Serializer):
    after = serializers.UUIDField(required=False)


class MessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = Message
        fields = ["id", "sender_id", "text", "client_message_id", "created_at"]
        read_only_fields = fields


class ConversationReadSerializer(serializers.Serializer):
    last_message_id = serializers.UUIDField()
