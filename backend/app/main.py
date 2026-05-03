from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import admin, audio, auth, moderation, users
from app.api.routes.rooms import rooms
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
from app.websocket import live_room


Base.metadata.create_all(bind=engine)

app = FastAPI(title="Vibe Match API")


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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
app.include_router(audio.router)
app.include_router(rooms.router)
app.include_router(live_room.router)
