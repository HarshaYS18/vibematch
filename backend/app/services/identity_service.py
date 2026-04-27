import random
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


def is_reserved_custom_id(custom_id: int) -> bool:
    custom_id_str = str(custom_id)

    if custom_id == settings.FOUNDER_OWNER_PUBLIC_ID:
        return True

    return custom_id_str.startswith(RESERVED_CUSTOM_ID_PREFIXES)


def generate_public_user_id(db: Session) -> int:
    """
    Permanent public user ID generator.

    Founder Owner gets 6922022 separately.
    Normal users get 10-digit IDs starting with 6418.
    Example: 6418000001 to 6418999999.
    4518 series remains reserved for official/staff display custom IDs.
    """

    while True:
        # 10 digits total:
        # prefix 6418 + 6-digit suffix
        suffix = random.randint(1, 999999)
        public_id = int(f"{NORMAL_USER_PUBLIC_ID_PREFIX}{suffix:06d}")

        if public_id in RESERVED_PUBLIC_IDS:
            continue

        existing = db.query(User).filter(User.public_user_id == public_id).first()

        if not existing:
            return public_id