"""Мелкие обёртки над кэшем.

Сброс кэша идёт из сигналов post_save: если Redis моргнул, сохранение объекта
не должно падать. Просроченный кэш — меньшее зло, чем 500 на публикации
объявления, поэтому ошибки инвалидации только логируются.
"""

import logging
from collections.abc import Callable
from typing import Any

logger = logging.getLogger(__name__)


def safe_cache_call(action: Callable[..., Any], *args: Any, warning: str, **kwargs: Any) -> Any:
    """Выполняет операцию с кэшем, проглатывая недоступность бэкенда."""
    try:
        return action(*args, **kwargs)
    except Exception:
        logger.warning(warning, exc_info=True)
        return None
