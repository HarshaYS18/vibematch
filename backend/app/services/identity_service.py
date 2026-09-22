import secrets

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.user import User


RESERVED_PUBLIC_IDS = {
    settings.FOUNDER_OWNER_PUBLIC_ID,
}

RESERVED_CUSTOM_ID_PREFIXES = (
    "4518",
)

NORMAL_USER_PUBLIC_ID_PREFIX = "6418"
PUBLIC_USER_ID_BASE = 6_418_000_000_000
PUBLIC_USER_ID_MAX_SUFFIX = 999_999_999
PUBLIC_USER_ID_SEQUENCE = "funkey_public_user_id_seq"


def is_reserved_custom_id(custom_id: int) -> bool:
    custom_id_str = str(custom_id)

    if custom_id == settings.FOUNDER_OWNER_PUBLIC_ID:
        return True

    return custom_id_str.startswith(RESERVED_CUSTOM_ID_PREFIXES)


def _fallback_public_user_id(db: Session) -> int:
    """Non-PostgreSQL test/dev allocator with bounded collision retries."""
    for _ in range(100):
        suffix = secrets.randbelow(PUBLIC_USER_ID_MAX_SUFFIX) + 1
        public_id = PUBLIC_USER_ID_BASE + suffix
        exists = db.query(User.id).filter(User.public_user_id == public_id).first()
        if not exists:
            return public_id
    raise RuntimeError("Unable to allocate a unique public user ID after 100 attempts.")


def generate_public_user_id(db: Session) -> int:
    """Allocate a permanent public user ID.

    Existing 7/10-digit IDs remain valid forever. New PostgreSQL-backed users
    receive 13-digit numeric IDs beginning with 6418, backed by a database
    sequence so concurrent signups cannot race each other. The nine-digit suffix
    provides 999,999,999 normal-user IDs without relying on random collision
    retries.
    """
    bind = db.get_bind()
    if bind is not None and bind.dialect.name == "postgresql":
        suffix = int(
            db.execute(
                text(f"SELECT nextval('{PUBLIC_USER_ID_SEQUENCE}')")
            ).scalar_one()
        )
        if suffix < 1 or suffix > PUBLIC_USER_ID_MAX_SUFFIX:
            raise RuntimeError("FunKey public user ID sequence is exhausted.")
        return PUBLIC_USER_ID_BASE + suffix

    return _fallback_public_user_id(db)
