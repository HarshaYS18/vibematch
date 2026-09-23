from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.core.config import settings


connect_args = {}
if settings.database_url.startswith(("postgresql://", "postgresql+")):
    connect_args["connect_timeout"] = settings.DB_CONNECT_TIMEOUT_SECONDS
    connect_args["application_name"] = settings.DB_APPLICATION_NAME

    # PgBouncer transaction pooling must not depend on arbitrary session state.
    # In that mode these timeout defaults are applied at the PostgreSQL
    # role/database layer. Direct connections can safely use startup options.
    if settings.DB_POOLER_MODE == "direct":
        connect_args["options"] = (
            f"-c lock_timeout={settings.DB_LOCK_TIMEOUT_MS}ms "
            f"-c statement_timeout={settings.DB_STATEMENT_TIMEOUT_MS}ms "
            f"-c idle_in_transaction_session_timeout="
            f"{settings.DB_IDLE_IN_TRANSACTION_SESSION_TIMEOUT_MS}ms"
        )

pool_options = {}
if settings.database_url.startswith(("postgresql://", "postgresql+")):
    pool_options = {
        "pool_size": settings.DB_POOL_SIZE,
        "max_overflow": settings.DB_MAX_OVERFLOW,
        "pool_timeout": settings.DB_POOL_TIMEOUT_SECONDS,
        "pool_recycle": settings.DB_POOL_RECYCLE_SECONDS,
        "pool_pre_ping": True,
        "pool_use_lifo": settings.DB_POOL_USE_LIFO,
        "pool_reset_on_return": "rollback",
    }

engine = create_engine(settings.database_url, connect_args=connect_args, **pool_options)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
