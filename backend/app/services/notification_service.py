from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.notification import NotificationPreference, UserNotification
from app.models.user import User


def create_notification(
    db: Session,
    *,
    recipient: User,
    actor: User | None,
    notification_type: str,
    title: str,
    body: str,
    target_type: str | None = None,
    target_id: str | None = None,
    target_url: str | None = None,
    metadata: dict | None = None,
    source_event_id: str | None = None,
    dedupe_key: str | None = None,
    collapse_key: str | None = None,
) -> UserNotification:
    notification = UserNotification(
        recipient_user_id=recipient.id,
        actor_user_id=actor.id if actor else None,
        notification_type=notification_type,
        title=title.strip()[:160],
        body=body.strip(),
        target_type=target_type,
        target_id=target_id,
        target_url=target_url,
        metadata_json=metadata or {},
        source_event_id=source_event_id,
        dedupe_key=dedupe_key,
        collapse_key=collapse_key,
        is_read=False,
    )
    db.add(notification)
    db.commit()
    db.refresh(notification)
    return notification


def unread_count(db: Session, user: User) -> int:
    return db.query(func.count(UserNotification.id)).filter(
        UserNotification.recipient_user_id == user.id,
        UserNotification.is_read.is_(False),
    ).scalar() or 0


def list_notifications(db: Session, user: User, *, limit: int = 50, unread_only: bool = False) -> list[UserNotification]:
    query = db.query(UserNotification).filter(UserNotification.recipient_user_id == user.id)
    if unread_only:
        query = query.filter(UserNotification.is_read.is_(False))
    return query.order_by(UserNotification.created_at.desc(), UserNotification.id.desc()).limit(limit).all()


def mark_read(db: Session, user: User, notification_id: int) -> UserNotification | None:
    notification = db.query(UserNotification).filter(
        UserNotification.id == notification_id,
        UserNotification.recipient_user_id == user.id,
    ).first()
    if not notification:
        return None
    if not notification.is_read:
        notification.is_read = True
        notification.read_at = datetime.utcnow()
        db.commit()
        db.refresh(notification)
    return notification


def mark_all_read(db: Session, user: User) -> int:
    now = datetime.utcnow()
    count = (
        db.query(UserNotification)
        .filter(
            UserNotification.recipient_user_id == user.id,
            UserNotification.is_read.is_(False),
        )
        .update(
            {
                UserNotification.is_read: True,
                UserNotification.read_at: now,
            },
            synchronize_session=False,
        )
    )
    db.commit()
    return int(count or 0)


def get_or_create_preference(db: Session, user_id: int) -> NotificationPreference:
    preference = (
        db.query(NotificationPreference)
        .filter(NotificationPreference.user_id == int(user_id))
        .first()
    )
    if preference is None:
        preference = NotificationPreference(
            user_id=int(user_id),
            push_enabled=True,
            timezone="UTC",
            max_push_per_hour=20,
            notification_types_json={},
        )
        db.add(preference)
        db.flush()
    return preference


def update_preference(
    db: Session,
    *,
    user_id: int,
    push_enabled: bool,
    quiet_start_minute: int | None,
    quiet_end_minute: int | None,
    timezone_name: str,
    max_push_per_hour: int,
    notification_types: dict[str, bool],
) -> NotificationPreference:
    if (quiet_start_minute is None) != (quiet_end_minute is None):
        raise ValueError("quiet_start_minute and quiet_end_minute must be set together")
    try:
        ZoneInfo(timezone_name)
    except ZoneInfoNotFoundError as exc:
        raise ValueError("Unknown IANA timezone") from exc
    preference = get_or_create_preference(db, user_id)
    preference.push_enabled = bool(push_enabled)
    preference.quiet_start_minute = quiet_start_minute
    preference.quiet_end_minute = quiet_end_minute
    preference.timezone = timezone_name
    preference.max_push_per_hour = int(max_push_per_hour)
    preference.notification_types_json = {
        str(key)[:60]: bool(value)
        for key, value in notification_types.items()
    }
    db.add(preference)
    db.commit()
    db.refresh(preference)
    return preference


def preference_to_dict(preference: NotificationPreference) -> dict:
    return {
        "push_enabled": bool(preference.push_enabled),
        "quiet_start_minute": preference.quiet_start_minute,
        "quiet_end_minute": preference.quiet_end_minute,
        "timezone": preference.timezone or "UTC",
        "max_push_per_hour": int(preference.max_push_per_hour or 20),
        "notification_types": dict(preference.notification_types_json or {}),
    }


def to_dict(notification: UserNotification) -> dict:
    return {
        "id": notification.id,
        "type": notification.notification_type,
        "title": notification.title,
        "body": notification.body,
        "target_type": notification.target_type,
        "target_id": notification.target_id,
        "target_url": notification.target_url,
        "metadata": notification.metadata_json or {},
        "is_read": notification.is_read,
        "created_at": notification.created_at,
    }
