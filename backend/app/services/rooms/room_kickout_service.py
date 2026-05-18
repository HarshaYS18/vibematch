from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.role import ROLE_POWER, RoleName
from app.models.presence import UserRoomPresence
from app.models.room import Room
from app.models.room_kickout import RoomKickout, RoomKickoutDuration
from app.models.room_participant import RoomParticipant
from app.models.room_realtime_state import RoomSeatState
from app.models.user import User
from app.schemas.rooms.room_kickout import RoomKickoutCreateRequest
from app.services.permissions import room_permission_service
from app.services.role_service import get_primary_role


_OFFICIAL_STAFF_ROLES = {
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


def active_kickout_for_user(
    db: Session,
    *,
    room_public_id: str,
    user: User,
) -> RoomKickout | None:
    now = datetime.utcnow()
    public_user_id = str(user.public_user_id)
    return (
        db.query(RoomKickout)
        .filter(RoomKickout.room_public_id == room_public_id)
        .filter(RoomKickout.is_active.is_(True))
        .filter(
            (RoomKickout.target_user_id == user.id)
            | (RoomKickout.target_public_user_id == public_user_id)
        )
        .filter(
            (RoomKickout.is_permanent.is_(True))
            | (RoomKickout.blocked_until.is_(None))
            | (RoomKickout.blocked_until > now)
        )
        .order_by(RoomKickout.created_at.desc(), RoomKickout.id.desc())
        .first()
    )


def is_user_kicked_out(db: Session, *, room_public_id: str, user: User) -> bool:
    return active_kickout_for_user(db, room_public_id=room_public_id, user=user) is not None


def _role_power(role: RoleName) -> int:
    return ROLE_POWER.get(role, 0)


def _is_top_official(role: RoleName) -> bool:
    return role in {RoleName.FOUNDER_OWNER, RoleName.OWNER}


def _assert_target_can_be_kicked(
    db: Session,
    room_public_id: str,
    payload: RoomKickoutCreateRequest,
    actor: User | None,
    *,
    actor_can_manage_room: bool = False,
) -> None:
    if actor is None:
        raise HTTPException(status_code=401, detail="Login required to kick a room user")

    public_id = (payload.target_public_user_id or "").strip()
    if public_id in _PROTECTED_PUBLIC_USER_IDS:
        raise HTTPException(status_code=403, detail="Founder Owner cannot be kicked from any chatroom")

    target_user = _load_target_user(db, payload)
    if target_user is None:
        raise HTTPException(status_code=404, detail="Kickout target user could not be resolved")

    if target_user.id == actor.id:
        raise HTTPException(status_code=400, detail="You cannot kick yourself from the room")

    room = db.query(Room).filter(Room.room_public_id == room_public_id).first()
    is_channel_host = bool(room and room.owner_user_id == target_user.id)

    target_role = get_primary_role(target_user)
    actor_role = get_primary_role(actor) if actor is not None else RoleName.USER

    if target_role == RoleName.FOUNDER_OWNER:
        raise HTTPException(status_code=403, detail="Founder Owner cannot be kicked from any chatroom")

    if target_role == RoleName.OWNER:
        raise HTTPException(status_code=403, detail="Owner accounts cannot be kicked from any chatroom")

    if actor_can_manage_room and target_role == RoleName.USER and not bool(target_user.is_protected):
        return

    # Founder Owner and Owner can kick channel hosts, room admins, normal users,
    # and lower official/staff accounts. They still cannot kick Founder/Owner.
    if _is_top_official(actor_role):
        if _role_power(actor_role) <= _role_power(target_role):
            raise HTTPException(status_code=403, detail="Cannot kick equal or higher official role")
        return

    # Room-level admins cannot kick the channel host.
    if is_channel_host:
        raise HTTPException(status_code=403, detail="Only Founder Owner or Owner can kick a channel host")

    # Lower users/room admins cannot kick protected official staff.
    if target_role in _OFFICIAL_STAFF_ROLES:
        raise HTTPException(status_code=403, detail="Official/staff accounts cannot be kicked by room admins or lower roles")

    if not actor_can_manage_room and not room_permission_service.can_kick_room_user(db, actor, target_user):
        raise HTTPException(status_code=403, detail="You do not have permission to kick this user")


def deactivate_room_user_for_kickout(
    db: Session,
    *,
    room_public_id: str,
    target: User,
    actor_user_id: int | None = None,
) -> None:
    now = datetime.utcnow()
    room = db.query(Room).filter(Room.room_public_id == room_public_id).first()
    if room is not None:
        participant = (
            db.query(RoomParticipant)
            .filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == target.id)
            .first()
        )
        if participant is not None:
            participant.is_active = False
            participant.left_at = now
            participant.last_seen_at = now

        for seat in (
            db.query(RoomSeatState)
            .filter(RoomSeatState.room_id == room.id, RoomSeatState.occupant_user_id == target.id)
            .all()
        ):
            seat.occupant_user_id = None
            seat.mic_enabled = False
            seat.admin_muted = False
            seat.left_at = now
            seat.updated_by_user_id = actor_user_id

    for presence in (
        db.query(UserRoomPresence)
        .filter(
            UserRoomPresence.room_public_id == room_public_id,
            UserRoomPresence.user_id == target.id,
            UserRoomPresence.is_active.is_(True),
        )
        .all()
    ):
        presence.is_active = False
        presence.left_at = now
        presence.last_heartbeat_at = now


def create_room_kickout(
    db: Session,
    room_public_id: str,
    payload: RoomKickoutCreateRequest,
    actor_user_id: int | None = None,
    actor_public_user_id: str | None = None,
    actor_can_manage_room: bool = False,
) -> RoomKickout:
    actor = db.query(User).filter(User.id == actor_user_id).first() if actor_user_id is not None else None
    _assert_target_can_be_kicked(db, room_public_id, payload, actor, actor_can_manage_room=actor_can_manage_room)
    target = _load_target_user(db, payload)
    if target is None:
        raise HTTPException(status_code=404, detail="Kickout target user could not be resolved")
    blocked_until, is_permanent = _calculate_blocked_until(payload.duration.value)

    kickout = RoomKickout(
        room_public_id=room_public_id,
        target_user_id=target.id,
        target_public_user_id=str(target.public_user_id),
        target_display_name=payload.target_display_name or target.display_name or target.username,
        created_by_user_id=actor_user_id,
        created_by_public_user_id=actor_public_user_id,
        duration=payload.duration.value,
        blocked_until=blocked_until,
        is_permanent=is_permanent,
        reason=payload.reason,
        is_active=True,
    )

    db.add(kickout)
    deactivate_room_user_for_kickout(
        db,
        room_public_id=room_public_id,
        target=target,
        actor_user_id=actor_user_id,
    )
    db.commit()
    db.refresh(kickout)
    return kickout


def create_room_kickout_for_user(
    db: Session,
    *,
    room_public_id: str,
    target: User,
    actor: User,
    duration: str,
    reason: str | None,
    actor_can_manage_room: bool,
) -> RoomKickout:
    payload = RoomKickoutCreateRequest(
        target_user_id=target.id,
        target_public_user_id=str(target.public_user_id),
        target_display_name=target.display_name or target.username,
        duration=duration,
        reason=reason,
    )
    return create_room_kickout(
        db=db,
        room_public_id=room_public_id,
        payload=payload,
        actor_user_id=actor.id,
        actor_public_user_id=str(actor.public_user_id),
        actor_can_manage_room=actor_can_manage_room,
    )


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
