from __future__ import annotations

from fastapi import APIRouter, FastAPI
from sqlalchemy import text

from app.api.routes import vibes
from app.core.config import settings
from app.database import get_db
from database import engine, get_vibes_db
from internal import router as internal_router


settings.validate_vibes_service()

app = FastAPI(
    title="FunKey Vibes Service",
    version="1.0.0",
    docs_url=None,
    redoc_url=None,
)
app.dependency_overrides[get_db] = get_vibes_db

api = APIRouter(prefix="/api/v1")
api.include_router(vibes.router)
api.include_router(vibes.admin_router)
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
