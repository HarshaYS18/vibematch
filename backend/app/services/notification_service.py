from datetime import datetime
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.notification import UserNotification
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
    return query.order_by(UserNotification.created_at.desc()).limit(limit).all()


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
    notifications = db.query(UserNotification).filter(
        UserNotification.recipient_user_id == user.id,
        UserNotification.is_read.is_(False),
    ).all()
    now = datetime.utcnow()
    for notification in notifications:
        notification.is_read = True
        notification.read_at = now
    db.commit()
    return len(notifications)


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
