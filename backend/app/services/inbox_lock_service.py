from sqlalchemy.orm import Session

from app.core.security import hash_password, verify_password
from app.models.inbox import InboxLockSetting
from app.models.user import User

OTP_EXPIRE_MINUTES = 0
DEFAULT_OWNER_RESET_LOCK = "1234"


def get_lock_setting(db: Session, user: User) -> InboxLockSetting | None:
    return db.query(InboxLockSetting).filter(InboxLockSetting.user_id == user.id).first()


def get_status(db: Session, user: User) -> dict:
    setting = get_lock_setting(db, user)
    return {
        "is_enabled": bool(setting and setting.is_enabled),
        "mobile_number": None,
        "recovery_requested": bool(setting and setting.recovery_requested),
    }


def setup_lock(db: Session, user: User, lock_code: str) -> InboxLockSetting:
    clean = (lock_code or "").strip()
    if len(clean) < 4 or len(clean) > 12:
        raise ValueError("Inbox lock must be 4 to 12 characters.")
    setting = get_lock_setting(db, user)
    if setting is None:
        setting = InboxLockSetting(user_id=user.id)
        db.add(setting)
    setting.mobile_number = None
    setting.lock_hash = hash_password(clean)
    setting.is_enabled = True
    setting.recovery_requested = False
    db.commit()
    db.refresh(setting)
    return setting


def start_setup(db: Session, user: User, mobile_number: str | None = None) -> str | None:
    return None


def verify_setup(db: Session, user: User, mobile_number: str | None, otp: str | None, lock_code: str) -> InboxLockSetting:
    return setup_lock(db, user, lock_code)


def verify_lock(db: Session, user: User, lock_code: str) -> bool:
    setting = get_lock_setting(db, user)
    if not setting or not setting.is_enabled or not setting.lock_hash:
        return False
    return verify_password(lock_code, setting.lock_hash)


def change_lock(db: Session, user: User, current_lock_code: str, new_lock_code: str) -> InboxLockSetting:
    setting = get_lock_setting(db, user)
    if not setting or not setting.is_enabled or not setting.lock_hash:
        raise ValueError("Inbox lock is not set up.")
    if not verify_password(current_lock_code, setting.lock_hash):
        raise ValueError("Current lock is incorrect.")
    clean = (new_lock_code or "").strip()
    if len(clean) < 4 or len(clean) > 12:
        raise ValueError("New Inbox lock must be 4 to 12 characters.")
    setting.lock_hash = hash_password(clean)
    setting.recovery_requested = False
    db.commit()
    db.refresh(setting)
    return setting


def start_recovery(db: Session, user: User, mobile_number: str | None = None) -> str | None:
    request_cs_recovery(db, user)
    return None


def recover_lock(db: Session, user: User, mobile_number: str | None, otp: str | None, new_lock_code: str) -> InboxLockSetting:
    raise ValueError("Inbox lock recovery is handled by CS. Please contact Vibe Match Team / CS.")


def request_cs_recovery(db: Session, user: User) -> None:
    setting = get_lock_setting(db, user)
    if setting is None:
        setting = InboxLockSetting(user_id=user.id, recovery_requested=True)
        db.add(setting)
    else:
        setting.recovery_requested = True
    db.commit()


def owner_reset_lock(db: Session, target_user: User, new_lock_code: str | None = DEFAULT_OWNER_RESET_LOCK) -> InboxLockSetting:
    setting = get_lock_setting(db, target_user)
    if setting is None:
        setting = InboxLockSetting(user_id=target_user.id)
        db.add(setting)
    clean = (new_lock_code or DEFAULT_OWNER_RESET_LOCK).strip() or DEFAULT_OWNER_RESET_LOCK
    setting.mobile_number = None
    setting.lock_hash = hash_password(clean)
    setting.is_enabled = True
    setting.recovery_requested = False
    db.commit()
    db.refresh(setting)
    return setting
