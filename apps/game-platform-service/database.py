from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import settings


def _database_url() -> str:
    url=settings.GAME_PLATFORM_DATABASE_URL.strip()
    if url: return url
    if settings.is_production: raise RuntimeError("GAME_PLATFORM_DATABASE_URL is required for Game Platform")
    return settings.database_url

database_url=_database_url()
connect_args={}
pool_options={}
if database_url.startswith(("postgresql://","postgresql+")):
    connect_args["connect_timeout"]=settings.DB_CONNECT_TIMEOUT_SECONDS
    connect_args["application_name"]="funkey-game-platform"
    if settings.DB_POOLER_MODE=="direct":
        connect_args["options"]=(f"-c lock_timeout={settings.DB_LOCK_TIMEOUT_MS}ms -c statement_timeout={settings.DB_STATEMENT_TIMEOUT_MS}ms -c idle_in_transaction_session_timeout={settings.DB_IDLE_IN_TRANSACTION_SESSION_TIMEOUT_MS}ms")
    pool_options={"pool_size":settings.GAME_PLATFORM_DB_POOL_SIZE,"max_overflow":settings.GAME_PLATFORM_DB_MAX_OVERFLOW,"pool_timeout":settings.GAME_PLATFORM_DB_POOL_TIMEOUT_SECONDS,"pool_recycle":settings.DB_POOL_RECYCLE_SECONDS,"pool_pre_ping":True,"pool_use_lifo":settings.DB_POOL_USE_LIFO,"pool_reset_on_return":"rollback"}
engine=create_engine(database_url,connect_args=connect_args,**pool_options)
SessionLocal=sessionmaker(autocommit=False,autoflush=False,bind=engine)
def get_game_platform_db():
    db=SessionLocal()
    try: yield db
    finally: db.close()
