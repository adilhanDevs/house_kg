"""Инвалидация кэша при изменении конфигурации и контента."""

from typing import Any

from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from apps.common.models import AppConfig, OnboardingSlide, StaticPage
from apps.common.services import (
    invalidate_config_cache,
    invalidate_onboarding_cache,
    invalidate_page_cache,
)


@receiver([post_save, post_delete], sender=AppConfig)
def on_app_config_changed(sender: type, instance: AppConfig, **kwargs: Any) -> None:
    invalidate_config_cache()


@receiver([post_save, post_delete], sender=OnboardingSlide)
def on_onboarding_slide_changed(sender: type, instance: OnboardingSlide, **kwargs: Any) -> None:
    invalidate_onboarding_cache()


@receiver([post_save, post_delete], sender=StaticPage)
def on_static_page_changed(sender: type, instance: StaticPage, **kwargs: Any) -> None:
    invalidate_page_cache(instance.slug)
