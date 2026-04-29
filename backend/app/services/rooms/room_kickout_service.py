from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.models.room_kickout import RoomKickout, RoomKickoutDuration
from app.schemas.rooms.room_kickout import RoomKickoutCreateRequest


def _calculate_blocked_until(duration: str) -> tuple[datetime | None, bool]:
    now = datetime.utcnow()

    if duration == RoomKickoutDuration.ONE_HOUR.value:
        return now + timedelta(hours=1), False

    if duration == RoomKickoutDuration.ONE_DAY.value:
        return now + timedelta(days=1), False

    if duration == RoomKickoutDuration.FOREVER.value:
        return None, True

    raise ValueError("Unsupported kickout duration")


def create_room_kickout(
    db: Session,
    room_public_id: str,
    payload: RoomKickoutCreateRequest,
    actor_user_id: int | None = None,
    actor_public_user_id: str | None = None,
) -> RoomKickout:
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
