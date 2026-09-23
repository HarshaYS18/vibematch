from __future__ import annotations

from fastapi import APIRouter, FastAPI
from sqlalchemy import text

from app.api.routes import (
    calls,
    inbox,
    inbox_ai,
    inbox_backup_google,
    inbox_calls,
    inbox_message_tools,
    inbox_preferences,
    inbox_stories,
)
from app.core.config import settings
from app.database import get_db
from database import engine, get_inbox_db
from internal import router as internal_router
from realtime import router as realtime_router


settings.validate_inbox_service()

app = FastAPI(
    title="FunKey Inbox Service",
    version="1.0.0",
    docs_url=None,
    redoc_url=None,
)
app.dependency_overrides[get_db] = get_inbox_db

api = APIRouter(prefix="/api/v1")
api.include_router(inbox.router)
api.include_router(inbox_preferences.router, prefix="/inbox", tags=["Inbox"])
api.include_router(inbox_stories.router, prefix="/inbox", tags=["Inbox"])
api.include_router(inbox_message_tools.router, prefix="/inbox", tags=["Inbox"])
api.include_router(inbox_calls.router, prefix="/inbox", tags=["Inbox Calls"])
for router in (inbox_backup_google.router, inbox_ai.router, calls.router):
    api.include_router(router)
api.include_router(realtime_router)
app.include_router(api)
app.include_router(internal_router)


@app.get("/live", include_in_schema=False)
def live() -> dict[str, str]:
    return {"status": "live"}


@app.get("/ready", include_in_schema=False)
def ready() -> dict[str, str]:
    with engine.connect() as connection:
        connection.execute(text("SELECT 1"))
    return {"status": "ready"}
