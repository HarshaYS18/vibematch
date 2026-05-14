from sqlalchemy.orm import Session

from app.models.experience import RoomExperienceStatus, UserExperienceStatus
from app.models.room import Room
from app.models.user import User

MAX_EXP_LEVEL = 200


def exp_required_for_level(level: int) -> int:
    safe_level = max(1, min(level, MAX_EXP_LEVEL))
    if safe_level <= 1:
        return 0
    return 1000 * (safe_level - 1) * safe_level // 2


def level_for_exp(total_exp: int) -> int:
    safe_exp = max(int(total_exp or 0), 0)
    level = 1
    while level < MAX_EXP_LEVEL and safe_exp >= exp_required_for_level(level + 1):
        level += 1
    return level


def progress_payload(level: int, total_exp: int) -> dict:
    current_start = exp_required_for_level(level)
    next_exp = exp_required_for_level(min(level + 1, MAX_EXP_LEVEL))
    needed = max(next_exp - current_start, 1)
    into = max(min(total_exp - current_start, needed), 0)
    return {
        "level": level,
        "total_exp": total_exp,
        "current_level_start_exp": current_start,
        "next_level_exp": next_exp,
        "exp_into_level": into,
        "exp_needed_for_next_level": needed,
        "progress": into / needed,
        "is_max_level": level >= MAX_EXP_LEVEL,
    }


def get_or_create_user_exp(db: Session, user_id: int) -> UserExperienceStatus:
    status = db.query(UserExperienceStatus).filter(UserExperienceStatus.user_id == user_id).first()
    if status:
        return status
    status = UserExperienceStatus(user_id=user_id)
    db.add(status)
    db.flush()
    return status


def get_or_create_room_exp(db: Session, room_id: int) -> RoomExperienceStatus:
    status = db.query(RoomExperienceStatus).filter(RoomExperienceStatus.room_id == room_id).first()
    if status:
        return status
    status = RoomExperienceStatus(room_id=room_id)
    db.add(status)
    db.flush()
    return status


def apply_gift_exp(
    db: Session,
    *,
    sender_user_id: int,
    receiver_user_id: int,
    room_id: int | None,
    send_exp: int,
    receive_exp: int,
    room_exp: int,
    source_id: str,
) -> dict:
    sender_status = get_or_create_user_exp(db, sender_user_id)
    receiver_status = get_or_create_user_exp(db, receiver_user_id)

    sender_status.send_total_exp += max(send_exp, 0)
    sender_status.send_level = level_for_exp(sender_status.send_total_exp)
    sender_status.last_source_type = "GIFT_SEND"
    sender_status.last_source_id = source_id

    receiver_status.receive_total_exp += max(receive_exp, 0)
    receiver_status.receive_level = level_for_exp(receiver_status.receive_total_exp)
    receiver_status.last_source_type = "GIFT_RECEIVE"
    receiver_status.last_source_id = source_id

    room_status = None
    if room_id is not None and room_exp > 0:
        room_status = get_or_create_room_exp(db, room_id)
        room_status.total_exp += max(room_exp, 0)
        room_status.level = level_for_exp(room_status.total_exp)
        room_status.last_source_type = "GIFT_RECEIVE"
        room_status.last_source_id = source_id

    return {
        "sender": user_exp_payload(sender_status),
        "receiver": user_exp_payload(receiver_status),
        "room": room_exp_payload(room_status) if room_status else None,
    }


def user_exp_payload(status: UserExperienceStatus) -> dict:
    return {
        "user_id": status.user_id,
        "send": progress_payload(status.send_level, status.send_total_exp),
        "receive": progress_payload(status.receive_level, status.receive_total_exp),
        "last_source_type": status.last_source_type,
        "last_source_id": status.last_source_id,
        "updated_at": status.updated_at.isoformat() if status.updated_at else None,
    }


def room_exp_payload(status: RoomExperienceStatus | None) -> dict | None:
    if status is None:
        return None
    return {
        "room_id": status.room_id,
        "room": progress_payload(status.level, status.total_exp),
        "last_source_type": status.last_source_type,
        "last_source_id": status.last_source_id,
        "updated_at": status.updated_at.isoformat() if status.updated_at else None,
    }


def details_for_user(db: Session, user: User) -> dict:
    status = get_or_create_user_exp(db, user.id)
    return user_exp_payload(status)


def details_for_public_user_id(db: Session, public_user_id: int) -> dict | None:
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    if not user:
        return None
    status = get_or_create_user_exp(db, user.id)
    payload = user_exp_payload(status)
    payload["public_user_id"] = user.public_user_id
    payload["display_name"] = user.display_name or user.username
    return payload


def _room_details_payload(db: Session, room: Room) -> dict:
    status = get_or_create_room_exp(db, room.id)
    payload = room_exp_payload(status) or {}
    payload["room_public_id"] = room.room_public_id
    payload["room_name"] = room.name
    return payload


def details_for_room(db: Session, room_id: int) -> dict | None:
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        return None
    return _room_details_payload(db, room)


def details_for_room_public_id(db: Session, room_public_id: str) -> dict | None:
    room = db.query(Room).filter(Room.room_public_id == room_public_id).first()
    if not room:
        return None
    return _room_details_payload(db, room)
