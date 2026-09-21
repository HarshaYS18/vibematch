from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.vip_status import UserVipStatus
from app.services import role_service
from app.services.get_or_create_service import get_or_create_unique


def _get_user_by_public_id(db: Session, public_user_id: int) -> User:
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


def get_or_create_vip_status(db: Session, user: User) -> UserVipStatus:
    status = get_or_create_unique(db, UserVipStatus, UserVipStatus.user_id, user.id)
    db.commit()
    db.refresh(status)
    return status


def response_payload(user: User, status: UserVipStatus) -> dict:
    return {
        "user_id": user.id,
        "public_user_id": user.public_user_id,
        "vip_level": status.vip_level,
        "svip_level": status.svip_level,
        "vip_is_active": status.vip_is_active,
        "svip_is_active": status.svip_is_active,
        "svip_expires_at": status.svip_expires_at,
        "updated_by_user_id": status.updated_by_user_id,
        "update_reason": status.update_reason,
    }


def get_status_by_public_id(db: Session, public_user_id: int) -> dict:
    user = _get_user_by_public_id(db, public_user_id)
    status = get_or_create_vip_status(db, user)
    return response_payload(user, status)


def update_status_by_public_id(db: Session, actor: User, public_user_id: int, payload: dict) -> dict:
    if not role_service.is_owner_or_above(actor):
        raise HTTPException(status_code=403, detail="Only Owner or Super Owner can adjust VIP/SVIP levels.")
    user = _get_user_by_public_id(db, public_user_id)
    status = get_or_create_vip_status(db, user)
    status.vip_level = int(payload.get("vip_level", 0))
    status.svip_level = int(payload.get("svip_level", 0))
    status.vip_is_active = bool(payload.get("vip_is_active", True))
    status.svip_is_active = bool(payload.get("svip_is_active", False))
    svip_days = payload.get("svip_days")
    if status.svip_is_active and svip_days:
        status.svip_expires_at = datetime.utcnow() + timedelta(days=int(svip_days))
    elif not status.svip_is_active:
        status.svip_expires_at = None
    status.updated_by_user_id = actor.id
    status.update_reason = payload.get("reason")
    db.commit()
    db.refresh(status)
    return response_payload(user, status)
