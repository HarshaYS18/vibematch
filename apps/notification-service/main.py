from fastapi import APIRouter, FastAPI
from fastapi.responses import PlainTextResponse
from sqlalchemy import text
from app.api.routes import notifications, push
from app.core.config import settings
from app.core.operational import install_query_counter, operational_middleware, render_metrics
from app.core.telemetry import configure_telemetry
from app.database import get_db
from database import engine, get_notification_db
from internal import router as internal_router

settings.validate_notification_service()
app=FastAPI(title="FunKey Notification Service",version="1.0.0",docs_url=None,redoc_url=None)
app.middleware("http")(operational_middleware); app.dependency_overrides[get_db]=get_notification_db
api=APIRouter(prefix="/api/v1"); api.include_router(notifications.router); api.include_router(push.router)
app.include_router(api); app.include_router(internal_router)
@app.get("/live",include_in_schema=False)
def live(): return {"status":"live"}
@app.get("/ready",include_in_schema=False)
def ready():
    with engine.connect() as connection: connection.execute(text("SELECT 1"))
    return {"status":"ready"}
@app.get("/metrics",include_in_schema=False,response_class=PlainTextResponse)
def metrics(): return PlainTextResponse(render_metrics(engine.pool),media_type="text/plain; version=0.0.4")
install_query_counter(engine); configure_telemetry("funkey-notification",app=app,engine=engine)
