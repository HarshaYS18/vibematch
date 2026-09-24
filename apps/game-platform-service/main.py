from fastapi import APIRouter, FastAPI
from fastapi.responses import PlainTextResponse
from sqlalchemy import text
from app.api.routes import games, games_master
from app.core.config import settings
from app.core.operational import install_query_counter, operational_middleware, render_metrics
from app.core.telemetry import configure_telemetry
from app.database import get_db
from database import engine, get_game_platform_db

settings.validate_game_platform_service()
app=FastAPI(title="FunKey Game Platform Service",version="1.0.0",docs_url=None,redoc_url=None)
app.middleware("http")(operational_middleware)
app.dependency_overrides[get_db]=get_game_platform_db
api=APIRouter(prefix="/api/v1")
api.include_router(games.router)
api.include_router(games_master.router)
api.include_router(games.admin_router)
app.include_router(api)
@app.get("/live",include_in_schema=False)
def live(): return {"status":"live"}
@app.get("/ready",include_in_schema=False)
def ready():
    with engine.connect() as connection: connection.execute(text("SELECT 1"))
    return {"status":"ready"}
@app.get("/metrics",include_in_schema=False,response_class=PlainTextResponse)
def metrics(): return PlainTextResponse(render_metrics(engine.pool),media_type="text/plain; version=0.0.4")
install_query_counter(engine)
configure_telemetry("funkey-game-platform",app=app,engine=engine)
