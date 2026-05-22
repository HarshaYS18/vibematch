from datetime import datetime

from sqlalchemy.orm import Session

from app.models.user import User
from app.models.user_app_setting import UserAppSetting


DEFAULT_USER_SETTINGS = {
    "notifications_enabled": True,
    "room_invites_enabled": True,
    "stranger_messages_enabled": True,
    "mentions_enabled": True,
    "gift_alerts_enabled": True,
    "event_alerts_enabled": True,
    "family_alerts_enabled": True,
    "admin_system_alerts_enabled": True,
    "floating_notifications_enabled": True,
    "notification_sound_enabled": True,
    "vibration_enabled": True,
    "do_not_disturb_enabled": False,
    "hide_online_status": False,
    "hide_current_room": False,
    "private_profile": False,
    "show_last_seen": True,
    "show_gift_stats": True,
    "read_receipts_enabled": True,
    "allow_stranger_messages": True,
    "anonymous_chatroom_appearance": False,
    "inbox_lock_enabled": False,
    "biometric_unlock_enabled": False,
    "auto_lock_inbox": True,
    "login_alerts_enabled": True,
    "hide_sensitive_notifications": True,
    "auto_join_mic_muted": True,
    "show_entrance_effects": True,
    "image_messages_enabled": True,
    "high_quality_animations": True,
    "data_saver_mode": False,
    "ringtone_name": "Vibe Classic Ring",
    "ringtone_path": None,
    "notification_tone_name": "Soft Vibe Ping",
    "notification_tone_path": None,
    "language": "English",
    "appearance": "System",
    "chat_wallpaper": "Pearl",
    "device_trust_enabled": True,
}


ALLOWED_KEYS = set(DEFAULT_USER_SETTINGS.keys())


def get_settings(db: Session, *, user: User) -> UserAppSetting:
    row = db.query(UserAppSetting).filter(UserAppSetting.user_id == user.id).first()
    if row:
        merged = _merged_settings(row.settings_json)
        if merged != row.settings_json:
            row.settings_json = merged
            row.updated_at = datetime.utcnow()
            db.commit()
            db.refresh(row)
        return row
    row = UserAppSetting(user_id=user.id, settings_json=dict(DEFAULT_USER_SETTINGS))
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def update_settings(db: Session, *, user: User, settings: dict) -> UserAppSetting:
    row = get_settings(db, user=user)
    current = _merged_settings(row.settings_json)
    updates = {key: value for key, value in settings.items() if key in ALLOWED_KEYS}
    row.settings_json = _merged_settings({**current, **updates})
    row.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(row)
    return row


def reset_settings(db: Session, *, user: User) -> UserAppSetting:
    row = get_settings(db, user=user)
    row.settings_json = dict(DEFAULT_USER_SETTINGS)
    row.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(row)
    return row


def _merged_settings(value: dict | None) -> dict:
    merged = dict(DEFAULT_USER_SETTINGS)
    if isinstance(value, dict):
        for key, item in value.items():
            if key in ALLOWED_KEYS:
                merged[key] = item
    return merged
