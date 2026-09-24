from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.models.device_ban import DeviceBan
from app.models.role import RoleName
from app.models.special_permission import SpecialPermissionName
from app.models.user import User
from app.models.user_ban import BanSource, BanType, UserBan
from app.services.role_service import get_primary_role
from app.services.realtime_revocation_service import publish_session_revoked
from app.services import identity_session_service
from app.services.special_permission_service import has_active_special_permission


def is_protected_from_special_ban(target_user: User) -> bool:
    """
    Special ban/unban permission can only affect normal users.
    It cannot affect officials/staff/admin/protected accounts.
    """
    return get_primary_role(target_user) != RoleName.USER


def has_active_user_ban(db: Session, user_id: int) -> bool:
    """
    Prevent duplicate active bans.
    If a user is already banned, another ban should not increase ban count.
    """
    return (
        db.query(UserBan)
        .filter(
            UserBan.user_id == user_id,
            UserBan.is_active == True,  # noqa: E712
        )
        .first()
        is not None
    )


def is_device_banned(db: Session, device_id: str | None) -> bool:
    """
    Used during login.
    If device_id has an active device ban, block login.
    """
    if not device_id:
        return False

    return (
        db.query(DeviceBan)
        .filter(
            DeviceBan.device_id == device_id,
            DeviceBan.is_active == True,  # noqa: E712
        )
        .first()
        is not None
    )


def get_monitor_ban_count_in_3_months(db: Session, user_id: int) -> int:
    since = datetime.utcnow() - timedelta(days=90)

    return (
        db.query(UserBan)
        .filter(
            UserBan.user_id == user_id,
            UserBan.ban_source == BanSource.MONITOR_TEAM,
            UserBan.created_at >= since,
        )
        .count()
    )


def get_next_monitor_ban_duration(db: Session, user_id: int) -> timedelta | None:
    """
    Existing monitor ban count in rolling 3 months determines next ban.

    0 previous = 1st ban = 1 hour
    1 previous = 2nd ban = 1 day
    2 previous = 3rd ban = 1 week
    3+ previous = 4th ban = permanent device_id ban trigger
    """
    previous_count = get_monitor_ban_count_in_3_months(db, user_id)

    if previous_count == 0:
        return timedelta(hours=1)

    if previous_count == 1:
        return timedelta(days=1)

    if previous_count == 2:
        return timedelta(days=7)

    return None


def should_trigger_device_ban(db: Session, user_id: int) -> bool:
    previous_count = get_monitor_ban_count_in_3_months(db, user_id)

    # This means the current ban attempt is the 4th one in 3 months.
    return previous_count >= 3


def create_user_ban(
    db: Session,
    user: User,
    banned_by_user_id: int,
    ban_type: BanType,
    ban_source: BanSource,
    reason: str,
    expires_at: datetime | None,
    device_id_snapshot: str | None = None,
) -> UserBan:
    ban = UserBan(
        user_id=user.id,
        banned_by_user_id=banned_by_user_id,
        ban_type=ban_type,
        ban_source=ban_source,
        reason=reason,
        expires_at=expires_at,
        device_id_snapshot=device_id_snapshot,
        is_active=True,
    )

    user.is_banned = True

    db.add(ban)
    db.add(user)
    db.commit()
    db.refresh(ban)
    identity_session_service.revoke_user_sessions(
        db,
        user_id=user.id,
        reason="user_banned",
    )
    publish_session_revoked(user.id, reason="user_banned")

    return ban


def create_device_ban(
    db: Session,
    device_id: str,
    banned_by_user_id: int,
    reason: str,
    user_id: int | None = None,
    triggered_by_rule: str | None = None,
    ban_count_snapshot: int | None = None,
) -> DeviceBan:
    existing = (
        db.query(DeviceBan)
        .filter(
            DeviceBan.device_id == device_id,
            DeviceBan.is_active == True,  # noqa: E712
        )
        .first()
    )

    if existing:
        return existing

    device_ban = DeviceBan(
        device_id=device_id,
        user_id=user_id,
        banned_by_user_id=banned_by_user_id,
        reason=reason,
        triggered_by_rule=triggered_by_rule,
        ban_count_snapshot=ban_count_snapshot,
        is_active=True,
    )

    db.add(device_ban)
    db.commit()
    db.refresh(device_ban)
    if user_id is not None:
        identity_session_service.revoke_user_sessions(
            db,
            user_id=user_id,
            reason="device_banned",
            device_id=device_id,
        )
        publish_session_revoked(
            user_id,
            reason="device_banned",
            device_id=device_id,
        )

    return device_ban


def can_actor_ban_normal_user(db: Session, actor: User) -> tuple[bool, BanSource | None]:
    actor_role = get_primary_role(actor)

    if actor_role == RoleName.FOUNDER_OWNER:
        return True, BanSource.FOUNDER_OWNER

    if actor_role == RoleName.OWNER:
        return True, BanSource.OWNER

    if actor_role == RoleName.MONITOR:
        return True, BanSource.MONITOR_TEAM

    if has_active_special_permission(db, actor.id, SpecialPermissionName.BAN_USER):
        return True, BanSource.SPECIAL_PERMISSION

    if has_active_special_permission(db, actor.id, SpecialPermissionName.TEMP_BAN_USER):
        return True, BanSource.SPECIAL_PERMISSION

    return False, None


def can_actor_unban_normal_user(db: Session, actor: User) -> bool:
    actor_role = get_primary_role(actor)

    if actor_role in {RoleName.FOUNDER_OWNER, RoleName.OWNER}:
        return True

    if has_active_special_permission(db, actor.id, SpecialPermissionName.UNBAN_USER):
        return True

    return False


def can_actor_lift_official_ban(actor: User) -> bool:
    """
    Official-level bans created by Founder Owner or Owner
    can only be lifted by Founder Owner or Owner.

    This rule overrides normal UNBAN_USER special permission.
    """
    actor_role = get_primary_role(actor)

    return actor_role in {RoleName.FOUNDER_OWNER, RoleName.OWNER}


def lift_active_user_bans(
    db: Session,
    user: User,
    lifted_by_user_id: int,
    reason: str,
    actor: User | None = None,
) -> int:
    active_bans = (
        db.query(UserBan)
        .filter(
            UserBan.user_id == user.id,
            UserBan.is_active == True,  # noqa: E712
        )
        .all()
    )

    if not active_bans:
        return 0

    official_ban_sources = {
        BanSource.FOUNDER_OWNER,
        BanSource.OWNER,
    }

    has_official_ban = any(
        ban.ban_source in official_ban_sources for ban in active_bans
    )

    if has_official_ban:
        if actor is None or not can_actor_lift_official_ban(actor):
            from fastapi import HTTPException

            raise HTTPException(
                status_code=403,
                detail="Only Founder Owner or Owner can unban users banned by official authorities.",
            )

    now = datetime.utcnow()

    for ban in active_bans:
        ban.is_active = False
        ban.lifted_at = now
        ban.lifted_by_user_id = lifted_by_user_id
        ban.lifted_reason = reason
        db.add(ban)

    user.is_banned = False
    db.add(user)
    db.commit()

    return len(active_bans)


def lift_device_ban(
    db: Session,
    device_ban: DeviceBan,
    lifted_by_user_id: int,
    reason: str,
) -> DeviceBan:
    device_ban.is_active = False
    device_ban.lifted_at = datetime.utcnow()
    device_ban.lifted_by_user_id = lifted_by_user_id
    device_ban.lifted_reason = reason

    db.add(device_ban)
    db.commit()
    db.refresh(device_ban)

    return device_ban