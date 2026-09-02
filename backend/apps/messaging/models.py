"""Модели диалогов покупателя с продавцом по объявлению."""

from typing import Any

from django.conf import settings
from django.db import models
from django.utils import timezone

from apps.common.models import TimeStampedModel, UUIDModel


class Conversation(UUIDModel, TimeStampedModel):
    listing = models.ForeignKey(
        "catalog.Listing",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="conversations",
    )
    buyer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="buyer_conversations",
    )
    seller = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="seller_conversations",
    )
    listing_slug = models.SlugField(max_length=220)
    listing_title = models.CharField(max_length=255)
    listing_price = models.DecimalField(max_digits=12, decimal_places=2)
    listing_currency = models.CharField(max_length=3)
    listing_cover_url = models.CharField(max_length=500, blank=True)
    last_message_at = models.DateTimeField(default=timezone.now, db_index=True)
    buyer_last_read_at = models.DateTimeField(null=True, blank=True)
    seller_last_read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["listing", "buyer", "seller"],
                name="messaging_unique_listing_participants",
            ),
            models.CheckConstraint(
                condition=~models.Q(buyer=models.F("seller")),
                name="messaging_buyer_is_not_seller",
            ),
        ]
        indexes = [
            models.Index(fields=["buyer", "-last_message_at"], name="msg_buyer_recent_idx"),
            models.Index(fields=["seller", "-last_message_at"], name="msg_seller_recent_idx"),
        ]

    def peer_for(self, user: Any) -> Any:
        if user.pk == self.buyer_id:
            return self.seller
        if user.pk == self.seller_id:
            return self.buyer
        raise ValueError("Пользователь не участвует в диалоге.")

    def read_at_for(self, user: Any) -> Any:
        if user.pk == self.buyer_id:
            return self.buyer_last_read_at
        if user.pk == self.seller_id:
            return self.seller_last_read_at
        raise ValueError("Пользователь не участвует в диалоге.")


class Message(UUIDModel, TimeStampedModel):
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name="messages",
    )
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="sent_messages",
    )
    text = models.CharField(max_length=2000)
    client_message_id = models.UUIDField()

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["sender", "client_message_id"],
                name="messaging_unique_client_message",
            )
        ]
        indexes = [models.Index(fields=["conversation", "-created_at"], name="msg_conv_recent_idx")]
