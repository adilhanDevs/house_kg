"""API открытия и чтения диалогов."""

from typing import Any

from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.generics import GenericAPIView, ListCreateAPIView, RetrieveAPIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response

from apps.common.throttling import MessageSendThrottle
from apps.messaging.models import Conversation, Message
from apps.messaging.pagination import ConversationCursorPagination, MessageCursorPagination
from apps.messaging.selectors import (
    conversation_for_participant,
    conversations_for,
    messages_for_participant,
    unread_count_for_participant,
)
from apps.messaging.serializers import (
    ConversationCreateSerializer,
    ConversationReadSerializer,
    ConversationSerializer,
    MessageCreateSerializer,
    MessagePollSerializer,
    MessageSerializer,
)
from apps.messaging.services import mark_conversation_read, open_conversation, send_message


class ConversationListCreateView(ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    pagination_class = ConversationCursorPagination
    serializer_class = ConversationSerializer
    queryset = Conversation.objects.none()

    def get_queryset(self):  # noqa: ANN201
        if not self.request.user.is_authenticated:  # pragma: no cover - генерация схемы
            return Conversation.objects.none()
        return conversations_for(self.request.user)

    def post(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        incoming = ConversationCreateSerializer(data=request.data)
        incoming.is_valid(raise_exception=True)
        conversation, created = open_conversation(
            user=request.user,
            listing_slug=incoming.validated_data["listing_slug"],
        )
        conversation = conversation_for_participant(
            user=request.user,
            conversation_id=conversation.id,
        )
        return Response(
            ConversationSerializer(conversation, context={"request": request}).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class ConversationDetailView(RetrieveAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ConversationSerializer
    queryset = Conversation.objects.none()

    def get_object(self) -> Conversation:
        return conversation_for_participant(
            user=self.request.user,
            conversation_id=self.kwargs["conversation_id"],
        )


class MessageListCreateView(ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    pagination_class = MessageCursorPagination
    serializer_class = MessageSerializer
    queryset = Message.objects.none()

    def get_throttles(self):  # noqa: ANN201
        throttles = super().get_throttles()
        if self.request.method == "POST":
            throttles.append(MessageSendThrottle())
        return throttles

    def get_queryset(self):  # noqa: ANN201
        if not self.request.user.is_authenticated:  # pragma: no cover - генерация схемы
            return Message.objects.none()
        query = MessagePollSerializer(data=self.request.query_params)
        query.is_valid(raise_exception=True)
        return messages_for_participant(
            user=self.request.user,
            conversation_id=self.kwargs["conversation_id"],
            after=query.validated_data.get("after"),
        )

    def post(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        incoming = MessageCreateSerializer(data=request.data)
        incoming.is_valid(raise_exception=True)
        conversation = get_object_or_404(Conversation, pk=self.kwargs["conversation_id"])
        message, created = send_message(
            user=request.user,
            conversation=conversation,
            text=incoming.validated_data["text"],
            client_message_id=incoming.validated_data["client_message_id"],
        )
        return Response(
            MessageSerializer(message).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class ConversationReadView(GenericAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ConversationReadSerializer
    queryset = Conversation.objects.none()

    def post(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        incoming = self.get_serializer(data=request.data)
        incoming.is_valid(raise_exception=True)
        conversation = get_object_or_404(Conversation, pk=self.kwargs["conversation_id"])
        updated = mark_conversation_read(
            user=request.user,
            conversation=conversation,
            last_message_id=incoming.validated_data["last_message_id"],
        )
        unread_count = unread_count_for_participant(
            user=request.user,
            conversation_id=conversation.id,
        )
        return Response({"updated": updated, "unread_count": unread_count})
