from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.room_kickout import RoomKickout, RoomKickoutDuration
from app.models.user import User
from app.schemas.rooms.room_kickout import RoomKickoutCreateRequest
from app.services.role_service import get_primary_role
from app.models.role import RoleName


# Protected platform official/staff roles. Business roles like agency_owner,
# bd, coin_seller, merchant, and reseller are not protected here unless they
# also hold one of these official backend roles.
_PROTECTED_ROOM_KICKOUT_ROLES = {
    RoleName.FOUNDER_OWNER,
    RoleName.OWNER,
    RoleName.SUPERADMIN,
    RoleName.ADMIN,
    RoleName.MONITOR,
    RoleName.CS,
}
_PROTECTED_PUBLIC_USER_IDS = {"6922022"}


def _calculate_blocked_until(duration: str) -> tuple[datetime | None, bool]:
    now = datetime.utcnow()

    if duration == RoomKickoutDuration.ONE_HOUR.value:
        return now + timedelta(hours=1), False

    if duration == RoomKickoutDuration.ONE_DAY.value:
        return now + timedelta(days=1), False

    if duration == RoomKickoutDuration.FOREVER.value:
        return None, True

    raise ValueError("Unsupported kickout duration")


def _target_public_id_as_int(value: str | None) -> int | None:
    if value is None:
        return None
    value = value.strip()
    if not value.isdigit():
        return None
    return int(value)


def _load_target_user(db: Session, payload: RoomKickoutCreateRequest) -> User | None:
    if payload.target_user_id is not None:
        user = db.query(User).filter(User.id == payload.target_user_id).first()
        if user is not None:
            return user

    public_id = _target_public_id_as_int(payload.target_public_user_id)
    if public_id is not None:
        return db.query(User).filter(User.public_user_id == public_id).first()

    return None


def _assert_target_can_be_kicked(db: Session, payload: RoomKickoutCreateRequest) -> None:
    public_id = (payload.target_public_user_id or "").strip()
    if public_id in _PROTECTED_PUBLIC_USER_IDS:
        raise HTTPException(status_code=403, detail="Super Owner/Founder Owner cannot be kicked from any chatroom")

    target_user = _load_target_user(db, payload)
    if target_user is None:
        return

    primary_role = get_primary_role(target_user)
    if primary_role in _PROTECTED_ROOM_KICKOUT_ROLES:
        raise HTTPException(status_code=403, detail="Official/staff accounts cannot be kicked from any chatroom")


def create_room_kickout(
    db: Session,
    room_public_id: str,
    payload: RoomKickoutCreateRequest,
    actor_user_id: int | None = None,
    actor_public_user_id: str | None = None,
) -> RoomKickout:
    _assert_target_can_be_kicked(db, payload)
    blocked_until, is_permanent = _calculate_blocked_until(payload.duration.value)

    kickout = RoomKickout(
        room_public_id=room_public_id,
        target_user_id=payload.target_user_id,
        target_public_user_id=payload.target_public_user_id,
        target_display_name=payload.target_display_name,
        created_by_user_id=actor_user_id,
        created_by_public_user_id=actor_public_user_id,
        duration=payload.duration.value,
        blocked_until=blocked_until,
        is_permanent=is_permanent,
        reason=payload.reason,
        is_active=True,
    )

    db.add(kickout)
    db.commit()
    db.refresh(kickout)
    return kickout


def list_active_room_kickouts(
    db: Session,
    room_public_id: str,
) -> list[RoomKickout]:
    now = datetime.utcnow()

    return (
        db.query(RoomKickout)
        .filter(RoomKickout.room_public_id == room_public_id)
        .filter(RoomKickout.is_active.is_(True))
        .filter(
            (RoomKickout.is_permanent.is_(True))
            | (RoomKickout.blocked_until.is_(None))
            | (RoomKickout.blocked_until > now)
        )
        .order_by(RoomKickout.created_at.desc())
        .all()
    )


def remove_room_kickout(
    db: Session,
    room_public_id: str,
    kickout_id: int,
    actor_user_id: int | None = None,
    actor_public_user_id: str | None = None,
) -> RoomKickout | None:
    kickout = (
        db.query(RoomKickout)
        .filter(RoomKickout.id == kickout_id)
        .filter(RoomKickout.room_public_id == room_public_id)
        .filter(RoomKickout.is_active.is_(True))
        .first()
    )

    if kickout is None:
        return None

    kickout.is_active = False
    kickout.updated_at = datetime.utcnow()

    db.add(kickout)
    db.commit()
    db.refresh(kickout)
    return kickout
