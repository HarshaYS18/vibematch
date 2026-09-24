from fastapi import FastAPI
from fastapi.responses import PlainTextResponse
from sqlalchemy import text

from app.core.config import settings
from app.core.operational import install_query_counter, operational_middleware, render_metrics
from app.core.telemetry import configure_telemetry
from app.database import get_db
from database import engine, get_economy_db
from internal import router as internal_router


settings.validate_economy_service()

app = FastAPI(
    title="FunKey Economy Service",
    version="1.0.0",
    docs_url=None,
    redoc_url=None,
)
app.middleware("http")(operational_middleware)
app.dependency_overrides[get_db] = get_economy_db
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
configure_telemetry("funkey-economy", app=app, engine=engine)
