"""Настройки уведомлений заводятся вместе с пользователем."""

from typing import Any

from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.notifications.models import NotificationSettings


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_notification_settings(sender: type, instance: Any, created: bool, **kwargs: Any) -> None:
    if created:
        NotificationSettings.objects.get_or_create(user=instance)
