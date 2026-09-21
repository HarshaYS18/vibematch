from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.router import api_router
from app.core.config import settings
from app.core.schema_guard import assert_database_schema_current
from app.database import engine
from app.services.push_notification_service import assert_firebase_configuration


BACKEND_DIR = Path(__file__).resolve().parents[1]
STATIC_DIR = BACKEND_DIR / "static"
STATIC_DIR.mkdir(parents=True, exist_ok=True)
(STATIC_DIR / "uploads").mkdir(parents=True, exist_ok=True)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    if settings.ENFORCE_SCHEMA_CURRENT or settings.APP_ENV.lower() in {"production", "prod"}:
        assert_database_schema_current(engine)
    assert_firebase_configuration()
    yield


app = FastAPI(
    title="FunKey API",
    version="1.0",
    lifespan=lifespan,
)

cors_origins = settings.cors_allowed_origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=cors_origins != ["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


@app.get("/", tags=["System"])
def root():
    return {
        "message": "FunKey backend running",
        "status": "ok",
        "api_prefix": "/api/v1",
    }


@app.get("/health", tags=["System"])
def health():
    """Unversioned process liveness endpoint for load balancers."""
    return {
        "status": "healthy",
        "service": "funkey-api",
    }


app.include_router(api_router)
