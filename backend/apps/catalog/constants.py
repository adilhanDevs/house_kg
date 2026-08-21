"""Лимиты каталога.

Совпадают с `AppState.draftMediaLimit` во Flutter: форма объявления не даст
приложить больше, а бэкенд обязан проверить это ещё раз.
"""

MAX_PHOTOS_PER_LISTING = 20
MAX_VIDEOS_PER_LISTING = 20

# Длина случайного хвоста в слаге объявления.
SLUG_SUFFIX_LENGTH = 8
SLUG_MAX_LENGTH = 140
