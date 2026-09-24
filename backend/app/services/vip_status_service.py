from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.vip_status import UserVipStatus
from app.services import economy_level_service, economy_service_client, role_service


def _get_user_by_public_id(db: Session, public_user_id: int) -> User:
    user = (
        db.query(User)
        .filter(User.public_user_id == public_user_id)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


def _derived_status_payload(db: Session, user: User) -> dict:
    levels = economy_level_service.user_level_payload(db, user.id)
    vip_level = int((levels.get("vip") or {}).get("level") or 0)
    svip_level = int((levels.get("svip") or {}).get("level") or 0)
    return {
        "user_id": user.id,
        "public_user_id": user.public_user_id,
        "vip_level": vip_level,
        "svip_level": svip_level,
        "vip_is_active": vip_level > 0,
        "svip_is_active": svip_level > 0,
        "svip_expires_at": None,
        "updated_by_user_id": None,
        "update_reason": "Derived Economy VIP/SVIP projection",
    }


def response_payload(user: User, status: UserVipStatus) -> dict:
    svip_active = bool(status.svip_is_active)
    if (
        svip_active
        and status.svip_expires_at is not None
        and status.svip_expires_at <= datetime.utcnow()
    ):
        svip_active = False
    return {
        "user_id": user.id,
        "public_user_id": user.public_user_id,
        "vip_level": int(status.vip_level or 0),
        "svip_level": int(status.svip_level or 0),
        "vip_is_active": bool(status.vip_is_active),
        "svip_is_active": svip_active,
        "svip_expires_at": status.svip_expires_at if svip_active else None,
        "updated_by_user_id": status.updated_by_user_id,
        "update_reason": status.update_reason,
    }


def get_status_by_public_id(db: Session, public_user_id: int) -> dict:
    """Read effective VIP state without creating Economy projection rows."""
    user = _get_user_by_public_id(db, public_user_id)
    status = (
        db.query(UserVipStatus)
        .filter(UserVipStatus.user_id == user.id)
        .first()
    )
    if status is None:
        return _derived_status_payload(db, user)
    return response_payload(user, status)


def update_status_by_public_id(
    db: Session,
    actor: User,
    public_user_id: int,
    payload: dict,
) -> dict:
    if not role_service.is_owner_or_above(actor):
        raise HTTPException(
            status_code=403,
            detail="Only Owner or Super Owner can adjust VIP/SVIP levels.",
        )
    user = _get_user_by_public_id(db, public_user_id)
    svip_active = bool(payload.get("svip_is_active", False))
    svip_days = payload.get("svip_days")
    svip_expires_at = None
    if svip_active and svip_days:
        svip_expires_at = datetime.utcnow() + timedelta(days=int(svip_days))

    try:
        result = economy_service_client.adjust_vip_override(
            request_id=str(payload["request_id"]).strip(),
            actor_user_id=actor.id,
            target_user_id=user.id,
            vip_level=int(payload.get("vip_level", 0)),
            svip_level=int(payload.get("svip_level", 0)),
            vip_is_active=bool(payload.get("vip_is_active", True)),
            svip_is_active=svip_active,
            svip_expires_at=(
                svip_expires_at.isoformat()
                if svip_expires_at is not None
                else None
            ),
            reason=str(payload.get("reason") or "").strip(),
        )
    except economy_service_client.EconomyServiceUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except economy_service_client.EconomyServiceError as exc:
        raise HTTPException(
            status_code=exc.status_code,
            detail=exc.detail,
        ) from exc

    return {
        "user_id": int(result["user_id"]),
        "public_user_id": int(result.get("public_user_id") or user.public_user_id),
        "vip_level": int(result["vip_level"]),
        "svip_level": int(result["svip_level"]),
        "vip_is_active": bool(result["vip_is_active"]),
        "svip_is_active": bool(result["svip_is_active"]),
        "svip_expires_at": result.get("svip_expires_at"),
        "updated_by_user_id": result.get("updated_by_user_id"),
        "update_reason": result.get("update_reason"),
    }
