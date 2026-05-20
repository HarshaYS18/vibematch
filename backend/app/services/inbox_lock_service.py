from datetime import datetime, timedelta
from secrets import randbelow

from sqlalchemy.orm import Session

from app.core.security import hash_password, verify_password
from app.models.inbox import InboxLockOtp, InboxLockOtpPurpose, InboxLockSetting
from app.models.user import User

OTP_EXPIRE_MINUTES = 10
OTP_COOLDOWN_SECONDS = 45
DEFAULT_OWNER_RESET_LOCK = "1234"
MAX_ACTIVE_OTPS_PER_USER = 5


def _now() -> datetime:
    return datetime.utcnow()


def _normalize_mobile(mobile_number: str | None) -> str:
    clean = "".join(ch for ch in (mobile_number or "").strip() if ch.isdigit() or ch == "+")
    if len(clean) < 8 or len(clean) > 18:
        raise ValueError("Enter a valid recovery mobile number.")
    return clean


def _generate_otp() -> str:
    return f"{randbelow(1_000_000):06d}"


def get_lock_setting(db: Session, user: User) -> InboxLockSetting | None:
    return db.query(InboxLockSetting).filter(InboxLockSetting.user_id == user.id).first()


def _get_or_create_lock_setting(db: Session, user: User) -> InboxLockSetting:
    setting = get_lock_setting(db, user)
    if setting is not None:
        return setting
    setting = InboxLockSetting(user_id=user.id, is_enabled=False, recovery_requested=False)
    db.add(setting)
    db.flush()
    return setting


def get_status(db: Session, user: User) -> dict:
    setting = get_lock_setting(db, user)
    return {
        "is_enabled": bool(setting and setting.is_enabled),
        "mobile_number": setting.mobile_number if setting else None,
        "recovery_requested": bool(setting and setting.recovery_requested),
    }


def _latest_active_otp(db: Session, user: User, purpose: str) -> InboxLockOtp | None:
    return (
        db.query(InboxLockOtp)
        .filter(
            InboxLockOtp.user_id == user.id,
            InboxLockOtp.purpose == purpose,
            InboxLockOtp.is_used.is_(False),
            InboxLockOtp.expires_at > _now(),
        )
        .order_by(InboxLockOtp.created_at.desc())
        .first()
    )


def _invalidate_old_otps(db: Session, user: User, purpose: str) -> None:
    old_items = (
        db.query(InboxLockOtp)
        .filter(
            InboxLockOtp.user_id == user.id,
            InboxLockOtp.purpose == purpose,
            InboxLockOtp.is_used.is_(False),
        )
        .order_by(InboxLockOtp.created_at.desc())
        .all()
    )
    for index, item in enumerate(old_items):
        if index >= MAX_ACTIVE_OTPS_PER_USER:
            item.is_used = True
            db.add(item)


def _issue_otp(db: Session, user: User, mobile_number: str, purpose: str) -> str:
    latest = _latest_active_otp(db, user, purpose)
    if latest is not None and latest.created_at + timedelta(seconds=OTP_COOLDOWN_SECONDS) > _now():
        raise ValueError("Please wait before requesting another OTP.")

    otp = _generate_otp()
    db.add(
        InboxLockOtp(
            user_id=user.id,
            mobile_number=mobile_number,
            otp_hash=hash_password(otp),
            purpose=purpose,
            is_used=False,
            expires_at=_now() + timedelta(minutes=OTP_EXPIRE_MINUTES),
        )
    )
    _invalidate_old_otps(db, user, purpose)
    db.commit()
    return otp


def _verify_otp(db: Session, user: User, mobile_number: str, otp: str | None, purpose: str) -> None:
    clean_otp = (otp or "").strip()
    if not clean_otp:
        raise ValueError("OTP is required.")
    item = _latest_active_otp(db, user, purpose)
    if item is None:
        raise ValueError("OTP expired. Request a new OTP.")
    if item.mobile_number != mobile_number:
        raise ValueError("OTP does not match this recovery mobile number.")
    if not verify_password(clean_otp, item.otp_hash):
        raise ValueError("Invalid OTP.")
    item.is_used = True
    db.add(item)
    db.flush()


def setup_lock(db: Session, user: User, lock_code: str, mobile_number: str | None = None) -> InboxLockSetting:
    clean = (lock_code or "").strip()
    if len(clean) < 4 or len(clean) > 12:
        raise ValueError("Inbox lock must be 4 to 12 characters.")
    setting = _get_or_create_lock_setting(db, user)
    if mobile_number is not None:
        setting.mobile_number = _normalize_mobile(mobile_number)
    elif not setting.mobile_number:
        raise ValueError("Recovery mobile number is required for Inbox lock setup.")
    setting.lock_hash = hash_password(clean)
    setting.is_enabled = True
    setting.recovery_requested = False
    db.add(setting)
    db.commit()
    db.refresh(setting)
    return setting


def start_setup(db: Session, user: User, mobile_number: str | None = None) -> str | None:
    mobile = _normalize_mobile(mobile_number)
    setting = _get_or_create_lock_setting(db, user)
    setting.mobile_number = mobile
    db.add(setting)
    db.commit()
    return _issue_otp(db, user, mobile, InboxLockOtpPurpose.SETUP.value)


def verify_setup(db: Session, user: User, mobile_number: str | None, otp: str | None, lock_code: str) -> InboxLockSetting:
    mobile = _normalize_mobile(mobile_number)
    _verify_otp(db, user, mobile, otp, InboxLockOtpPurpose.SETUP.value)
    return setup_lock(db, user, lock_code, mobile_number=mobile)


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
    db.add(setting)
    db.commit()
    db.refresh(setting)
    return setting


def start_recovery(db: Session, user: User, mobile_number: str | None = None) -> str | None:
    setting = get_lock_setting(db, user)
    if not setting or not setting.is_enabled or not setting.mobile_number:
        request_cs_recovery(db, user)
        raise ValueError("No verified recovery mobile is available. Contact Vibe Match Team / CS for manual recovery.")

    mobile = _normalize_mobile(mobile_number or setting.mobile_number)
    if mobile != setting.mobile_number:
        request_cs_recovery(db, user)
        raise ValueError("Recovery mobile does not match. Contact Vibe Match Team / CS for manual verification.")

    setting.recovery_requested = True
    db.add(setting)
    db.commit()
    return _issue_otp(db, user, mobile, InboxLockOtpPurpose.RECOVERY.value)


def recover_lock(db: Session, user: User, mobile_number: str | None, otp: str | None, new_lock_code: str) -> InboxLockSetting:
    setting = get_lock_setting(db, user)
    if not setting or not setting.mobile_number:
        raise ValueError("No recovery mobile is linked. Contact Vibe Match Team / CS.")
    mobile = _normalize_mobile(mobile_number or setting.mobile_number)
    if mobile != setting.mobile_number:
        raise ValueError("Recovery mobile does not match.")
    _verify_otp(db, user, mobile, otp, InboxLockOtpPurpose.RECOVERY.value)
    return setup_lock(db, user, new_lock_code, mobile_number=mobile)


def request_cs_recovery(db: Session, user: User) -> None:
    setting = _get_or_create_lock_setting(db, user)
    setting.recovery_requested = True
    db.add(setting)
    db.commit()


def owner_reset_lock(db: Session, target_user: User, new_lock_code: str | None = DEFAULT_OWNER_RESET_LOCK) -> InboxLockSetting:
    setting = _get_or_create_lock_setting(db, target_user)
    clean = (new_lock_code or DEFAULT_OWNER_RESET_LOCK).strip() or DEFAULT_OWNER_RESET_LOCK
    if len(clean) < 4 or len(clean) > 12:
        raise ValueError("Owner reset lock must be 4 to 12 characters.")
    setting.lock_hash = hash_password(clean)
    setting.is_enabled = True
    setting.recovery_requested = False
    db.add(setting)
    db.commit()
    db.refresh(setting)
    return setting