from datetime import datetime

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.role import RoleName
from app.models.special_permission import SpecialPermission, SpecialPermissionName
from app.models.user import User
from app.services.role_service import get_primary_role


def _ensure_founder_owner(actor: User) -> None:
    actor_role = get_primary_role(actor)

    if actor_role != RoleName.FOUNDER_OWNER:
        raise HTTPException(
            status_code=403,
            detail="Only Founder Owner can manage special permissions.",
        )


def _ensure_target_is_normal_user(target_user: User) -> None:
    target_role = get_primary_role(target_user)

    if target_role != RoleName.USER:
        raise HTTPException(
            status_code=403,
            detail="Special permissions can only be granted to normal users.",
        )


def grant_special_permission(
    db: Session,
    target_user: User,
    permission: SpecialPermissionName,
    granted_by: User,
    reason: str,
    expires_at: datetime | None = None,
) -> SpecialPermission:
    _ensure_founder_owner(granted_by)
    _ensure_target_is_normal_user(target_user)

    existing = (
        db.query(SpecialPermission)
        .filter(
            SpecialPermission.user_id == target_user.id,
            SpecialPermission.permission == permission,
            SpecialPermission.is_active == True,  # noqa: E712
        )
        .first()
    )

    if existing:
        if existing.expires_at is not None and existing.expires_at <= datetime.utcnow():
            existing.is_active = False
            db.add(existing)
            db.commit()
        else:
            return existing

    special_permission = SpecialPermission(
        user_id=target_user.id,
        permission=permission,
        granted_by_user_id=granted_by.id,
        reason=reason,
        expires_at=expires_at,
        is_active=True,
    )

    db.add(special_permission)
    db.commit()
    db.refresh(special_permission)

    return special_permission


def revoke_special_permission(
    db: Session,
    special_permission: SpecialPermission,
    revoked_by: User,
    reason: str,
) -> SpecialPermission:
    _ensure_founder_owner(revoked_by)

    special_permission.is_active = False
    special_permission.revoked_at = datetime.utcnow()
    special_permission.revoked_by_user_id = revoked_by.id
    special_permission.revoked_reason = reason

    db.add(special_permission)
    db.commit()
    db.refresh(special_permission)

    return special_permission


def has_active_special_permission(
    db: Session,
    user_id: int,
    permission: SpecialPermissionName,
) -> bool:
    now = datetime.utcnow()

    special_permission = (
        db.query(SpecialPermission)
        .filter(
            SpecialPermission.user_id == user_id,
            SpecialPermission.permission == permission,
            SpecialPermission.is_active == True,  # noqa: E712
        )
        .first()
    )

    if not special_permission:
        return False

    if special_permission.expires_at is not None and special_permission.expires_at <= now:
        special_permission.is_active = False
        db.add(special_permission)
        db.commit()
        return False

    return True