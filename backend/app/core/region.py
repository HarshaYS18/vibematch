"""Regional runtime helpers shared by the compatibility API."""

from __future__ import annotations

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

from app.core.config import settings


class RegionHeaderMiddleware(BaseHTTPMiddleware):
    """Expose the serving region without making it authorization state."""

    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["X-FunKey-Region"] = settings.FUNKEY_REGION
        return response
