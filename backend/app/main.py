from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.routes import admin, auth, media, moderation, users, ws
from app.api.routes.rooms import rooms
from app.core.config import settings
from app.database import Base, engine
from app.models import (
    AdminLog,
    AuthIdentity,
    DeviceBan,
    Room,
    SpecialPermission,
    User,
    UserBan,
    UserRole,
)


Base.metadata.create_all(bind=engine)

app = FastAPI(title="Vibe Match API")


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


media_root = Path(settings.MEDIA_ROOT_DIR).resolve()
media_root.mkdir(parents=True, exist_ok=True)
app.mount(
    settings.MEDIA_PUBLIC_PATH,
    StaticFiles(directory=str(media_root)),
    name="media",
)


@app.get("/")
def root():
    return {
        "message": "Vibe Match backend running",
        "status": "ok",
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "service": "vibe-match-backend",
    }


app.include_router(auth.router)
app.include_router(users.router)
app.include_router(admin.router)
app.include_router(moderation.router)
app.include_router(rooms.router)
app.include_router(media.router)
app.include_router(ws.router)
