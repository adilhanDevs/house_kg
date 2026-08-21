"""Проект house_kgz.

Импорт celery-приложения здесь гарантирует, что shared_task-декораторы
подхватят его при старте Django.
"""

from .celery import app as celery_app

__all__ = ("celery_app",)
