from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import (
    admin,
    auth,
    inbox,
    inbox_ws,
    internal_test,
    moderation,
    mvp_core,
    mvp_economy,
    mvp_operations,
    mvp_room_modes,
    mvp_social,
    users,
)
from app.api.routes.rooms import rooms
from app.database import Base, engine
from app.models import (
    AdminLog,
    AuthIdentity,
    DeviceBan,
    InboxBackupJob,
    InboxBackupSetting,
    InboxConversation,
    InboxLockOtp,
    InboxLockSetting,
    InboxMessage,
    InboxParticipant,
    InboxReport,
    MvpFeatureState,
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


@app.get("/")
def root():
    return {"message": "Vibe Match backend running", "status": "ok"}


@app.get("/health")
def health():
    return {"status": "healthy", "service": "vibe-match-backend"}


app.include_router(auth.router)
app.include_router(users.router)
app.include_router(admin.router)
app.include_router(moderation.router)
app.include_router(rooms.router)
app.include_router(inbox.router)
app.include_router(inbox_ws.router)
app.include_router(mvp_core.router)
app.include_router(mvp_social.router)
app.include_router(mvp_economy.router)
app.include_router(mvp_operations.router)
app.include_router(mvp_room_modes.router)
app.include_router(internal_test.router)
