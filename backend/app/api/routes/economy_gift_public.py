"""Legacy gift-route module retained only for import compatibility.

Canonical public gift endpoints live in ``app.api.routes.economy``.  Keeping an
empty router here lets older imports continue to work without registering a
second copy of the same FastAPI paths.
"""

from fastapi import APIRouter

router = APIRouter()
