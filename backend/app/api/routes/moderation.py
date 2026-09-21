from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.device_ban import DeviceBan
from app.models.role import RoleName
from app.models.user import User
from app.models.user_ban import BanSource, BanType, UserBan
from app.schemas.ban import (
    BanActionResponse,
    BanUserRequest,
    DeviceBanResponse,
    UnbanDeviceRequest,
    UnbanUserRequest,
    UserBanResponse,
)
from app.services.audit_log_service import create_admin_log
from app.services.ban_service import (
    can_actor_ban_normal_user,
    can_actor_unban_normal_user,
    create_device_ban,
    create_user_ban,
    get_monitor_ban_count_in_3_months,
    get_next_monitor_ban_duration,
    has_active_user_ban,
    is_protected_from_special_ban,
    lift_active_user_bans,
    lift_device_ban,
    should_trigger_device_ban,
)
from app.services.role_service import get_primary_role


router = APIRouter(prefix="/admin/moderation", tags=["Moderation"])


HIGH_LEVEL_BAN_OVERRIDE_ROLES = {
    RoleName.FOUNDER_OWNER,
    RoleName.OWNER,
}


@router.post("/users/ban", response_model=BanActionResponse)
def ban_user(
    payload: BanUserRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_user = db.query(User).filter(User.id == payload.target_user_id).first()

    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found")

    target_role = get_primary_role(target_user)
    actor_role = get_primary_role(current_user)

    if has_active_user_ban(db, target_user.id) and actor_role not in HIGH_LEVEL_BAN_OVERRIDE_ROLES:
        create_admin_log(
            db=db,
            actor_user_id=current_user.id,
            target_user_id=target_user.id,
            action="BAN_BLOCKED_ALREADY_ACTIVE",
            resource_type="user_ban",
            reason=payload.reason,
            metadata_json={
                "actor_role": actor_role.value,
                "target_role": target_role.value,
                "block_reason": "Target user already has an active ban. Only Founder Owner or Owner can apply another ban.",
            },
            device_id=payload.device_id,
        )

        raise HTTPException(
            status_code=409,
            detail="Target user already has an active ban. Only Founder Owner or Owner can apply another ban.",
        )

    if target_role != RoleName.USER:
        create_admin_log(
            db=db,
            actor_user_id=current_user.id,
            target_user_id=target_user.id,
            action="BAN_BLOCKED_PROTECTED_TARGET",
            resource_type="user_ban",
            reason=payload.reason,
            metadata_json={
                "actor_role": actor_role.value,
                "target_role": target_role.value,
                "block_reason": "Only normal users can be banned from this endpoint",
            },
            device_id=payload.device_id,
        )

        raise HTTPException(
            status_code=403,
            detail="Only normal users can be banned from this endpoint",
        )

    can_ban, ban_source = can_actor_ban_normal_user(db, current_user)

    if not can_ban or ban_source is None:
        create_admin_log(
            db=db,
            actor_user_id=current_user.id,
            target_user_id=target_user.id,
            action="BAN_BLOCKED_NO_PERMISSION",
            resource_type="user_ban",
            reason=payload.reason,
            metadata_json={
                "actor_role": actor_role.value,
                "target_role": target_role.value,
            },
            device_id=payload.device_id,
        )

        raise HTTPException(
            status_code=403,
            detail="You do not have permission to ban users",
        )

    expires_at = None
    ban_type = BanType.TEMPORARY

    if ban_source == BanSource.MONITOR_TEAM:
        if should_trigger_device_ban(db, target_user.id):
            if not payload.device_id:
                raise HTTPException(
                    status_code=400,
                    detail="device_id is required for 4th Monitor ban device-ban trigger",
                )

            previous_count = get_monitor_ban_count_in_3_months(db, target_user.id)

            user_ban = create_user_ban(
                db=db,
                user=target_user,
                banned_by_user_id=current_user.id,
                ban_type=BanType.PERMANENT,
                ban_source=BanSource.MONITOR_TEAM,
                reason=payload.reason,
                expires_at=None,
                device_id_snapshot=payload.device_id,
            )

            device_ban = create_device_ban(
                db=db,
                device_id=payload.device_id,
                banned_by_user_id=current_user.id,
                reason="4th Monitor Team ban within rolling 3 months",
                user_id=target_user.id,
                triggered_by_rule="MONITOR_4TH_BAN_3_MONTH_DEVICE_BAN",
                ban_count_snapshot=previous_count + 1,
            )

            create_admin_log(
                db=db,
                actor_user_id=current_user.id,
                target_user_id=target_user.id,
                action="DEVICE_BANNED_BY_MONITOR_LADDER",
                resource_type="device_ban",
                resource_id=str(device_ban.id),
                reason=payload.reason,
                metadata_json={
                    "ban_count_including_current": previous_count + 1,
                    "actor_role": actor_role.value,
                    "target_role": target_role.value,
                    "user_ban_id": user_ban.id,
                },
                device_id=payload.device_id,
            )

            return BanActionResponse(
                message="4th Monitor ban triggered permanent device_id ban",
                user_ban_id=user_ban.id,
                device_ban_id=device_ban.id,
                target_user_id=target_user.id,
                device_id=payload.device_id,
                expires_at=None,
                is_device_banned=True,
            )

        duration = get_next_monitor_ban_duration(db, target_user.id)

        if duration is None:
            raise HTTPException(
                status_code=400,
                detail="Device ban should have triggered but device_id was missing",
            )

        expires_at = datetime.utcnow() + duration

    elif ban_source == BanSource.OWNER:
        ban_type = BanType.PERMANENT
        expires_at = None

    elif ban_source == BanSource.FOUNDER_OWNER:
        ban_type = BanType.PERMANENT
        expires_at = None

    elif ban_source == BanSource.SPECIAL_PERMISSION:
        if is_protected_from_special_ban(target_user):
            create_admin_log(
                db=db,
                actor_user_id=current_user.id,
                target_user_id=target_user.id,
                action="SPECIAL_BAN_BLOCKED_PROTECTED_TARGET",
                resource_type="user_ban",
                reason=payload.reason,
                metadata_json={
                    "actor_role": actor_role.value,
                    "target_role": target_role.value,
                    "block_reason": "Special permission can only affect normal users",
                },
                device_id=payload.device_id,
            )

            raise HTTPException(
                status_code=403,
                detail="Special permission can only affect normal users",
            )

        # Foundation behavior:
        # Special BAN_USER/TEMP_BAN_USER creates a 1-day temporary ban.
        # Later we can split TEMP_BAN_USER and PERMANENT_BAN_USER endpoints more strictly.
        ban_type = BanType.TEMPORARY
        expires_at = datetime.utcnow() + timedelta(days=1)

    user_ban = create_user_ban(
        db=db,
        user=target_user,
        banned_by_user_id=current_user.id,
        ban_type=ban_type,
        ban_source=ban_source,
        reason=payload.reason,
        expires_at=expires_at,
        device_id_snapshot=payload.device_id,
    )

    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        target_user_id=target_user.id,
        action="USER_BANNED",
        resource_type="user_ban",
        resource_id=str(user_ban.id),
        reason=payload.reason,
        metadata_json={
            "ban_type": ban_type.value,
            "ban_source": ban_source.value,
            "actor_role": actor_role.value,
            "target_role": target_role.value,
            "expires_at": expires_at.isoformat() if expires_at else None,
            "active_ban_override_used": actor_role in HIGH_LEVEL_BAN_OVERRIDE_ROLES,
        },
        device_id=payload.device_id,
    )

    return BanActionResponse(
        message="User banned successfully",
        user_ban_id=user_ban.id,
        target_user_id=target_user.id,
        expires_at=expires_at,
        is_device_banned=False,
        device_ban_id=None,
    )


@router.post("/users/unban", response_model=BanActionResponse)
def unban_user(
    payload: UnbanUserRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_user = db.query(User).filter(User.id == payload.target_user_id).first()

    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found")

    target_role = get_primary_role(target_user)
    actor_role = get_primary_role(current_user)

    if target_role != RoleName.USER:
        create_admin_log(
            db=db,
            actor_user_id=current_user.id,
            target_user_id=target_user.id,
            action="UNBAN_BLOCKED_PROTECTED_TARGET",
            resource_type="user_ban",
            reason=payload.reason,
            metadata_json={
                "actor_role": actor_role.value,
                "target_role": target_role.value,
                "block_reason": "Only normal users can be unbanned from this endpoint",
            },
        )

        raise HTTPException(
            status_code=403,
            detail="Only normal users can be unbanned from this endpoint",
        )

    if not can_actor_unban_normal_user(db, current_user):
        create_admin_log(
            db=db,
            actor_user_id=current_user.id,
            target_user_id=target_user.id,
            action="UNBAN_BLOCKED_NO_PERMISSION",
            resource_type="user_ban",
            reason=payload.reason,
            metadata_json={
                "actor_role": actor_role.value,
                "target_role": target_role.value,
            },
        )

        raise HTTPException(
            status_code=403,
            detail="You do not have permission to unban users",
        )

    lifted_count = lift_active_user_bans(
        db=db,
        user=target_user,
        lifted_by_user_id=current_user.id,
        reason=payload.reason,
    )

    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        target_user_id=target_user.id,
        action="USER_UNBANNED",
        resource_type="user_ban",
        reason=payload.reason,
        metadata_json={
            "lifted_ban_count": lifted_count,
            "actor_role": actor_role.value,
            "target_role": target_role.value,
        },
    )

    return BanActionResponse(
        message="User unbanned successfully",
        target_user_id=target_user.id,
    )


@router.post("/devices/unban", response_model=BanActionResponse)
def unban_device(
    payload: UnbanDeviceRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    actor_role = get_primary_role(current_user)

    if actor_role != RoleName.FOUNDER_OWNER:
        create_admin_log(
            db=db,
            actor_user_id=current_user.id,
            action="DEVICE_UNBAN_BLOCKED",
            resource_type="device_ban",
            reason=payload.reason,
            metadata_json={
                "actor_role": actor_role.value,
                "device_id": payload.device_id,
                "block_reason": "Only Founder Owner can unban device_id",
            },
            device_id=payload.device_id,
        )

        raise HTTPException(
            status_code=403,
            detail="Only Founder Owner can unban device_id",
        )

    device_ban = (
        db.query(DeviceBan)
        .filter(
            DeviceBan.device_id == payload.device_id,
            DeviceBan.is_active == True,  # noqa: E712
        )
        .first()
    )

    if not device_ban:
        raise HTTPException(
            status_code=404,
            detail="Active device ban not found",
        )

    lifted = lift_device_ban(
        db=db,
        device_ban=device_ban,
        lifted_by_user_id=current_user.id,
        reason=payload.reason,
    )

    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        target_user_id=lifted.user_id,
        action="DEVICE_UNBANNED",
        resource_type="device_ban",
        resource_id=str(lifted.id),
        reason=payload.reason,
        metadata_json={
            "device_id": lifted.device_id,
            "actor_role": actor_role.value,
        },
        device_id=lifted.device_id,
    )

    return BanActionResponse(
        message="Device ID unbanned successfully",
        device_ban_id=lifted.id,
        target_user_id=lifted.user_id,
        device_id=lifted.device_id,
    )


@router.get("/users/bans", response_model=list[UserBanResponse])
def list_user_bans(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    actor_role = get_primary_role(current_user)

    if actor_role not in {
        RoleName.FOUNDER_OWNER,
        RoleName.OWNER,
        RoleName.SUPERADMIN,
        RoleName.ADMIN,
        RoleName.MONITOR,
    }:
        raise HTTPException(status_code=403, detail="Moderation access required")

    return db.query(UserBan).order_by(UserBan.id.desc()).limit(100).all()


@router.get("/devices/bans", response_model=list[DeviceBanResponse])
def list_device_bans(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    actor_role = get_primary_role(current_user)

    if actor_role != RoleName.FOUNDER_OWNER:
        raise HTTPException(
            status_code=403,
            detail="Only Founder Owner can view device bans",
        )

    return db.query(DeviceBan).order_by(DeviceBan.id.desc()).limit(100).all()