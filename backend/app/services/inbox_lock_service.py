from datetime import datetime, timedelta
from random import randint

from sqlalchemy.orm import Session

from app.core.security import hash_password, verify_password
from app.models.inbox import InboxLockOtp, InboxLockOtpPurpose, InboxLockSetting
from app.models.user import User

OTP_EXPIRE_MINUTES = 10


def _normalize_mobile(value: str) -> str:
    return value.strip().replace(" ", "")


def _generate_otp() -> str:
    return f"{randint(100000, 999999)}"


def get_lock_setting(db: Session, user: User) -> InboxLockSetting | None:
    return db.query(InboxLockSetting).filter(InboxLockSetting.user_id == user.id).first()


def get_status(db: Session, user: User) -> dict:
    setting = get_lock_setting(db, user)
    return {
        "is_enabled": bool(setting and setting.is_enabled),
        "mobile_number": setting.mobile_number if setting else None,
        "recovery_requested": bool(setting and setting.recovery_requested),
    }


def _create_otp(db: Session, user: User, mobile_number: str, purpose: str) -> str:
    normalized = _normalize_mobile(mobile_number)
    db.query(InboxLockOtp).filter(
        InboxLockOtp.user_id == user.id,
        InboxLockOtp.purpose == purpose,
        InboxLockOtp.is_used.is_(False),
    ).update({"is_used": True})
    otp = _generate_otp()
    db.add(
        InboxLockOtp(
            user_id=user.id,
            mobile_number=normalized,
            otp_hash=hash_password(otp),
            purpose=purpose,
            expires_at=datetime.utcnow() + timedelta(minutes=OTP_EXPIRE_MINUTES),
        )
    )
    db.commit()
    return otp


def start_setup(db: Session, user: User, mobile_number: str) -> str:
    return _create_otp(db, user, mobile_number, InboxLockOtpPurpose.SETUP.value)


def start_recovery(db: Session, user: User, mobile_number: str) -> str:
    setting = get_lock_setting(db, user)
    if setting and setting.mobile_number != _normalize_mobile(mobile_number):
        raise ValueError("Mobile number does not match the registered recovery number.")
    if setting:
        setting.recovery_requested = True
        db.commit()
    return _create_otp(db, user, mobile_number, InboxLockOtpPurpose.RECOVERY.value)


def _verify_otp(db: Session, user: User, mobile_number: str, otp: str, purpose: str) -> bool:
    normalized = _normalize_mobile(mobile_number)
    record = (
        db.query(InboxLockOtp)
        .filter(InboxLockOtp.user_id == user.id)
        .filter(InboxLockOtp.mobile_number == normalized)
        .filter(InboxLockOtp.purpose == purpose)
        .filter(InboxLockOtp.is_used.is_(False))
        .order_by(InboxLockOtp.created_at.desc())
        .first()
    )
    if not record or record.expires_at < datetime.utcnow():
        return False
    if not verify_password(otp, record.otp_hash):
        return False
    record.is_used = True
    db.commit()
    return True


def verify_setup(db: Session, user: User, mobile_number: str, otp: str, lock_code: str) -> InboxLockSetting:
    if not _verify_otp(db, user, mobile_number, otp, InboxLockOtpPurpose.SETUP.value):
        raise ValueError("Invalid or expired OTP.")
    normalized = _normalize_mobile(mobile_number)
    setting = get_lock_setting(db, user)
    if setting is None:
        setting = InboxLockSetting(user_id=user.id)
        db.add(setting)
    setting.mobile_number = normalized
    setting.lock_hash = hash_password(lock_code)
    setting.is_enabled = True
    setting.recovery_requested = False
    db.commit()
    db.refresh(setting)
    return setting


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
    setting.lock_hash = hash_password(new_lock_code)
    setting.recovery_requested = False
    db.commit()
    db.refresh(setting)
    return setting


def recover_lock(db: Session, user: User, mobile_number: str, otp: str, new_lock_code: str) -> InboxLockSetting:
    if not _verify_otp(db, user, mobile_number, otp, InboxLockOtpPurpose.RECOVERY.value):
        raise ValueError("Invalid or expired OTP.")
    setting = get_lock_setting(db, user)
    if setting is None:
        setting = InboxLockSetting(user_id=user.id, mobile_number=_normalize_mobile(mobile_number))
        db.add(setting)
    setting.lock_hash = hash_password(new_lock_code)
    setting.mobile_number = _normalize_mobile(mobile_number)
    setting.is_enabled = True
    setting.recovery_requested = False
    db.commit()
    db.refresh(setting)
    return setting


def request_cs_recovery(db: Session, user: User) -> None:
    setting = get_lock_setting(db, user)
    if setting is None:
        setting = InboxLockSetting(user_id=user.id, recovery_requested=True)
        db.add(setting)
    else:
        setting.recovery_requested = True
    db.commit()


def owner_reset_lock(db: Session, target_user: User, new_lock_code: str | None = None) -> InboxLockSetting:
    setting = get_lock_setting(db, target_user)
    if setting is None:
        setting = InboxLockSetting(user_id=target_user.id)
        db.add(setting)
    setting.lock_hash = hash_password(new_lock_code) if new_lock_code else None
    setting.is_enabled = bool(new_lock_code)
    setting.recovery_requested = False
    db.commit()
    db.refresh(setting)
    return setting
