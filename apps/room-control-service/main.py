from __future__ import annotations

from fastapi import APIRouter, FastAPI
from fastapi.responses import PlainTextResponse
from sqlalchemy import text

from app.api.routes import room_realtime_commands
from app.api.routes.rooms import rooms
from app.core.config import settings
from app.core.operational import install_query_counter, operational_middleware, render_metrics
from app.core.telemetry import configure_telemetry
from app.database import get_db
from app.services.rooms.room_db_context import configure_room_session_factory
from database import SessionLocal, engine, get_room_control_db
from internal import router as internal_router


settings.validate_room_control_service()
configure_room_session_factory(SessionLocal)

app = FastAPI(
    title="FunKey Room Control Service",
    version="1.0.0",
    docs_url=None,
    redoc_url=None,
)
app.middleware("http")(operational_middleware)
app.dependency_overrides[get_db] = get_room_control_db

api = APIRouter(prefix="/api/v1")
api.include_router(rooms.router)
api.include_router(room_realtime_commands.router)
api.include_router(rooms.admin_router)
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


@app.get("/metrics", include_in_schema=False, response_class=PlainTextResponse)
def metrics() -> PlainTextResponse:
    return PlainTextResponse(
        render_metrics(engine.pool),
        media_type="text/plain; version=0.0.4",
    )


install_query_counter(engine)
configure_telemetry("funkey-room-control", app=app, engine=engine)
