from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.routes import (
    admin,
    auth,
    coin_sales,
    economy,
    economy_admin,
    economy_gift_public,
    experience,
    experience_room_public,
    families,
    game_pool_admin,
    game_props_admin,
    games,
    inbox,
    inbox_backup_google,
    inbox_ws,
    internal_test,
    love_bonds,
    media,
    moderation,
    mvp_core,
    mvp_economy,
    mvp_operations,
    mvp_room_modes,
    mvp_social,
    notifications,
    presence,
    role_badges,
    room_music_media,
    room_realtime,
    social,
    super_owner,
    users,
    vibes,
    vip_admin,
    wallet,
)
from app.api.routes.rooms import cricket, rooms
from app.database import Base, engine
from app.models import (
    AdminLog,
    AuthIdentity,
    CoinPoolLedger,
    CoinSaleOrder,
    CoinSupplyPool,
    CricketMatch,
    CricketTournament,
    DeviceBan,
    GameBet,
    GameDefinition,
    GamePool,
    GamePoolLedger,
    GameRiskAudit,
    GameRound,
    GameRoundPlayer,
    GiftTransaction,
    InboxBackupJob,
    InboxBackupSetting,
    InboxConversation,
    InboxLockOtp,
    InboxLockSetting,
    InboxMessage,
    InboxParticipant,
    InboxReport,
    LoveBond,
    LoveBondInventory,
    LoveBondRequest,
    MvpFeatureState,
    ProfileVisit,
    Room,
    RoomExperienceStatus,
    RubyWithdrawRequest,
    SpecialPermission,
    User,
    UserBan,
    UserBlock,
    UserExperienceStatus,
    UserFollow,
    UserNotification,
    UserRoomPresence,
    UserRole,
    UserVipStatus,
    VibeComment,
    VibePost,
    VibeReaction,
    VibeReport,
    VibeShare,
    WalletLedger,
)

STATIC_DIR = Path("static")
STATIC_DIR.mkdir(parents=True, exist_ok=True)
(STATIC_DIR / "uploads").mkdir(parents=True, exist_ok=True)

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Vibe Match API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


@app.get("/")
def root():
    return {"message": "Vibe Match backend running", "status": "ok"}


@app.get("/health")
def health():
    return {"status": "healthy", "service": "vibe-match-backend"}


app.include_router(auth.router)
app.include_router(users.router)
app.include_router(role_badges.router)
app.include_router(admin.router)
app.include_router(moderation.router)
app.include_router(super_owner.router)
app.include_router(game_pool_admin.router)
app.include_router(game_props_admin.router)
app.include_router(rooms.router)
app.include_router(cricket.router)
app.include_router(families.router)
app.include_router(inbox.router)
app.include_router(inbox_backup_google.router)
app.include_router(love_bonds.router)
app.include_router(inbox_ws.router)
app.include_router(room_realtime.router)
app.include_router(experience.router)
app.include_router(experience_room_public.router)
app.include_router(social.router)
app.include_router(vibes.router)
app.include_router(notifications.router)
app.include_router(presence.router)
app.include_router(media.router)
app.include_router(room_music_media.router)
app.include_router(mvp_core.router)
app.include_router(mvp_social.router)
app.include_router(mvp_economy.router)
app.include_router(mvp_operations.router)
app.include_router(mvp_room_modes.router)
app.include_router(internal_test.router)
app.include_router(economy.router)
app.include_router(economy_gift_public.router)
app.include_router(economy_admin.router)
app.include_router(games.router)
app.include_router(coin_sales.router)
app.include_router(vip_admin.router)
app.include_router(wallet.router)
