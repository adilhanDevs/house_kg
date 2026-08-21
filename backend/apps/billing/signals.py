"""Кошелёк заводится вместе с пользователем."""

from typing import Any

from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.billing.models import Wallet


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_wallet(sender: type, instance: Any, created: bool, **kwargs: Any) -> None:
    if created:
        Wallet.objects.get_or_create(user=instance)
