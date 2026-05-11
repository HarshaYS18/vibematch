from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.notification import (
    NotificationListResponse,
    NotificationMarkAllReadResponse,
    NotificationMarkReadResponse,
    NotificationResponse,
    NotificationUnreadCountResponse,
)
from app.services import notification_service

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("", response_model=NotificationListResponse)
def list_my_notifications(
    limit: int = Query(default=50, ge=1, le=100),
    unread_only: bool = Query(default=False),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    notifications = notification_service.list_notifications(db, current_user, limit=limit, unread_only=unread_only)
    return NotificationListResponse(
        unread_count=notification_service.unread_count(db, current_user),
        notifications=[NotificationResponse(**notification_service.to_dict(item)) for item in notifications],
    )


@router.get("/unread-count", response_model=NotificationUnreadCountResponse)
def get_unread_count(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return NotificationUnreadCountResponse(unread_count=notification_service.unread_count(db, current_user))


@router.post("/{notification_id}/read", response_model=NotificationMarkReadResponse)
def mark_notification_read(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    notification = notification_service.mark_read(db, current_user, notification_id)
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    return NotificationMarkReadResponse(id=notification.id, is_read=notification.is_read)


@router.post("/read-all", response_model=NotificationMarkAllReadResponse)
def mark_all_notifications_read(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    count = notification_service.mark_all_read(db, current_user)
    return NotificationMarkAllReadResponse(marked_read_count=count, unread_count=notification_service.unread_count(db, current_user))
