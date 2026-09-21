from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.core.config import settings


connect_args = {}
if settings.database_url.startswith(("postgresql://", "postgresql+")):
    # A stalled room transaction must not hold an async API worker indefinitely.
    # Migrations use their own engine and are unaffected by these request limits.
    connect_args["options"] = (
        f"-c lock_timeout={settings.DB_LOCK_TIMEOUT_MS}ms "
        f"-c statement_timeout={settings.DB_STATEMENT_TIMEOUT_MS}ms"
    )

engine = create_engine(settings.database_url, connect_args=connect_args)

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
