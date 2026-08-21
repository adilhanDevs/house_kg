"""Условные ответы: ETag + 304 Not Modified.

Конфиг приложение дёргает на каждом старте — гонять его целиком незачем.
"""

import hashlib
import json
from typing import Any

from rest_framework import status
from rest_framework.request import Request
from rest_framework.response import Response

CACHE_CONTROL = "public, max-age=900"


def compute_etag(payload: Any) -> str:
    """Сильный ETag — md5 от канонического JSON-представления тела."""
    body = json.dumps(payload, sort_keys=True, ensure_ascii=False, default=str)
    digest = hashlib.md5(body.encode("utf-8"), usedforsecurity=False).hexdigest()
    return f'"{digest}"'


def _matches(header: str, etag: str) -> bool:
    """Разбирает If-None-Match: список тегов, W/-префиксы, звёздочка."""
    candidates = [item.strip() for item in header.split(",") if item.strip()]
    if "*" in candidates:
        return True
    normalized = {item[2:] if item.startswith("W/") else item for item in candidates}
    return etag in normalized


def conditional_response(request: Request, payload: Any) -> Response:
    """Отдаёт 200 с ETag или 304 без тела, если клиент прислал совпадающий тег."""
    etag = compute_etag(payload)
    headers = {"ETag": etag, "Cache-Control": CACHE_CONTROL}

    if_none_match = request.headers.get("If-None-Match", "")
    if if_none_match and _matches(if_none_match, etag):
        return Response(status=status.HTTP_304_NOT_MODIFIED, headers=headers)

    return Response(payload, headers=headers)
