from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy.orm import Session

from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.room_realtime_state import RoomChatMessage, RoomRealtimeEvent, RoomSeatState
from app.models.user import User
from app.services.rooms.room_state_service import ensure_room_seats, normalize_layout, room_sequence, room_snapshot, seat_count_for_layout


def _next_sequence(db: Session, room: Room) -> int:
    return room_sequence(db, room) + 1


def record_room_event(
    db: Session,
    room: Room,
    event_type: str,
    actor_user_id: int | None = None,
    target_user_id: int | None = None,
    payload: dict[str, Any] | None = None,
) -> RoomRealtimeEvent:
    event = RoomRealtimeEvent(
        room_id=room.id,
        room_public_id=room.room_public_id,
        event_type=event_type,
        actor_user_id=actor_user_id,
        target_user_id=target_user_id,
        payload=payload or {},
        sequence=_next_sequence(db, room),
    )
    db.add(event)
    room.updated_at = datetime.utcnow()
    db.flush()
    return event


def _room_participant(db: Session, room: Room, user: User) -> RoomParticipant | None:
    return (
        db.query(RoomParticipant)
        .filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == user.id)
        .first()
    )


def _ensure_room_participant(db: Session, room: Room, user: User) -> RoomParticipant:
    now = datetime.utcnow()
    participant = _room_participant(db, room, user)
    if participant is None:
        participant = RoomParticipant(
            room_id=room.id,
            user_id=user.id,
            is_active=True,
            is_member=False,
            is_room_admin=user.id == room.owner_user_id,
            joined_at=now,
            last_seen_at=now,
        )
        db.add(participant)
    else:
        participant.is_active = True
        participant.last_seen_at = now
        participant.left_at = None
        if user.id == room.owner_user_id:
            participant.is_room_admin = True
    return participant


def _has_pending_room_member_request(db: Session, room: Room, user_id: int) -> bool:
    pending = (
        db.query(RoomRealtimeEvent)
        .filter(
            RoomRealtimeEvent.room_id == room.id,
            RoomRealtimeEvent.event_type == "room.member_request.pending",
            RoomRealtimeEvent.actor_user_id == user_id,
        )
        .order_by(RoomRealtimeEvent.id.desc())
        .first()
    )
    if pending is None:
        return False

    decision = (
        db.query(RoomRealtimeEvent)
        .filter(
            RoomRealtimeEvent.room_id == room.id,
            RoomRealtimeEvent.event_type.in_(["room.member_request.approved", "room.member_request.rejected", "room.member.removed"]),
            RoomRealtimeEvent.target_user_id == user_id,
            RoomRealtimeEvent.id > pending.id,
        )
        .first()
    )
    return decision is None


def join_room(db: Session, room: Room, user: User, payload: dict[str, Any] | None = None) -> dict[str, Any]:
    _ensure_room_participant(db, room, user)
    record_room_event(db, room, "room.joined", actor_user_id=user.id, payload=payload or {})
    db.flush()
    return room_snapshot(db, room)


def heartbeat_room(db: Session, room: Room, user: User) -> dict[str, Any]:
    participant = _room_participant(db, room, user)
    if participant:
        participant.is_active = True
        participant.last_seen_at = datetime.utcnow()
        participant.left_at = None
    db.flush()
    return room_snapshot(db, room, include_chat=False)


def leave_room(db: Session, room: Room, user: User, release_seat: bool = False) -> dict[str, Any]:
    now = datetime.utcnow()
    participant = _room_participant(db, room, user)
    if participant:
        participant.is_active = False
        participant.left_at = now
        participant.last_seen_at = now
    if release_seat:
        for seat in db.query(RoomSeatState).filter(RoomSeatState.room_id == room.id, RoomSeatState.occupant_user_id == user.id).all():
            seat.occupant_user_id = None
            seat.mic_enabled = False
            seat.admin_muted = False
            seat.left_at = now
            seat.updated_by_user_id = user.id
    record_room_event(db, room, "room.left", actor_user_id=user.id, payload={"release_seat": release_seat})
    db.flush()
    return room_snapshot(db, room)


def request_room_membership(db: Session, room: Room, user: User) -> dict[str, Any]:
    participant = _ensure_room_participant(db, room, user)
    if user.id == room.owner_user_id:
        return room_snapshot(db, room)
    if participant.is_member:
        return room_snapshot(db, room)
    if _has_pending_room_member_request(db, room, user.id):
        return room_snapshot(db, room)
    record_room_event(db, room, "room.member_request.pending", actor_user_id=user.id, target_user_id=room.owner_user_id, payload={"status": "pending"})
    db.flush()
    return room_snapshot(db, room)


def approve_room_membership(db: Session, room: Room, actor: User, target: User) -> dict[str, Any]:
    if actor.id != room.owner_user_id:
        return room_snapshot(db, room)
    participant = _ensure_room_participant(db, room, target)
    participant.is_member = True
    participant.member_added_at = datetime.utcnow()
    record_room_event(db, room, "room.member_request.approved", actor_user_id=actor.id, target_user_id=target.id, payload={"status": "room_member"})
    db.flush()
    return room_snapshot(db, room)


def reject_room_membership(db: Session, room: Room, actor: User, target: User) -> dict[str, Any]:
    if actor.id != room.owner_user_id:
        return room_snapshot(db, room)
    participant = _ensure_room_participant(db, room, target)
    if not participant.is_member:
        participant.member_added_at = None
    record_room_event(db, room, "room.member_request.rejected", actor_user_id=actor.id, target_user_id=target.id, payload={"status": "rejected"})
    db.flush()
    return room_snapshot(db, room)


def remove_room_member(db: Session, room: Room, actor: User, target: User) -> dict[str, Any]:
    if actor.id != room.owner_user_id:
        return room_snapshot(db, room)
    if target.id == room.owner_user_id:
        return room_snapshot(db, room)
    participant = _room_participant(db, room, target)
    if participant:
        participant.is_member = False
        participant.member_added_at = None
    record_room_event(db, room, "room.member.removed", actor_user_id=actor.id, target_user_id=target.id, payload={"status": "removed"})
    db.flush()
    return room_snapshot(db, room)


def take_seat(db: Session, room: Room, user: User, seat_index: int, actor_user_id: int | None = None) -> dict[str, Any]:
    seats = ensure_room_seats(db, room)
    max_seats = seat_count_for_layout(room.seat_layout_id)
    if seat_index < 0 or seat_index >= max_seats:
        return room_snapshot(db, room)
    target = next((seat for seat in seats if seat.seat_index == seat_index), None)
    if target is None or target.is_locked:
        return room_snapshot(db, room)
    now = datetime.utcnow()
    for seat in seats:
        if seat.occupant_user_id == user.id:
            seat.occupant_user_id = None
            seat.mic_enabled = False
            seat.left_at = now
        if seat.seat_index == seat_index:
            seat.occupant_user_id = user.id
            seat.mic_enabled = False
            seat.admin_muted = False
            seat.occupied_at = now
            seat.left_at = None
            seat.updated_by_user_id = actor_user_id or user.id
    record_room_event(db, room, "seat.taken", actor_user_id=actor_user_id or user.id, target_user_id=user.id, payload={"seat_index": seat_index})
    db.flush()
    return room_snapshot(db, room)


def leave_seat(db: Session, room: Room, user: User, actor_user_id: int | None = None) -> dict[str, Any]:
    now = datetime.utcnow()
    for seat in db.query(RoomSeatState).filter(RoomSeatState.room_id == room.id, RoomSeatState.occupant_user_id == user.id).all():
        seat.occupant_user_id = None
        seat.mic_enabled = False
        seat.admin_muted = False
        seat.left_at = now
        seat.updated_by_user_id = actor_user_id or user.id
    record_room_event(db, room, "seat.left", actor_user_id=actor_user_id or user.id, target_user_id=user.id)
    db.flush()
    return room_snapshot(db, room)


def lock_seat(db: Session, room: Room, seat_index: int, locked: bool, actor_user_id: int | None = None) -> dict[str, Any]:
    seats = ensure_room_seats(db, room)
    now = datetime.utcnow()
    for seat in seats:
        if seat.seat_index == seat_index:
            seat.is_locked = locked
            seat.locked_by_user_id = actor_user_id if locked else None
            seat.locked_at = now if locked else None
            seat.updated_by_user_id = actor_user_id
            if locked:
                seat.occupant_user_id = None
                seat.mic_enabled = False
                seat.admin_muted = False
                seat.left_at = now
            break
    record_room_event(db, room, "seat.locked" if locked else "seat.unlocked", actor_user_id=actor_user_id, payload={"seat_index": seat_index, "locked": locked})
    db.flush()
    return room_snapshot(db, room)


def set_mic_enabled(db: Session, room: Room, user: User, enabled: bool) -> dict[str, Any]:
    for seat in db.query(RoomSeatState).filter(RoomSeatState.room_id == room.id, RoomSeatState.occupant_user_id == user.id).all():
        if not seat.admin_muted:
            seat.mic_enabled = enabled
            seat.updated_by_user_id = user.id
    record_room_event(db, room, "mic.self_unmuted" if enabled else "mic.self_muted", actor_user_id=user.id, payload={"enabled": enabled})
    db.flush()
    return room_snapshot(db, room)


def set_admin_mute(db: Session, room: Room, target_user_id: int, muted: bool, actor_user_id: int | None = None) -> dict[str, Any]:
    now = datetime.utcnow()
    for seat in db.query(RoomSeatState).filter(RoomSeatState.room_id == room.id, RoomSeatState.occupant_user_id == target_user_id).all():
        seat.admin_muted = muted
        seat.admin_muted_by_user_id = actor_user_id if muted else None
        seat.admin_muted_at = now if muted else None
        if muted:
            seat.mic_enabled = False
        seat.updated_by_user_id = actor_user_id
    record_room_event(db, room, "mic.admin_muted" if muted else "mic.admin_unmuted", actor_user_id=actor_user_id, target_user_id=target_user_id, payload={"muted": muted})
    db.flush()
    return room_snapshot(db, room)


def set_seat_layout(db: Session, room: Room, layout_id: str, actor_user_id: int | None = None) -> dict[str, Any]:
    room.seat_layout_id = normalize_layout(layout_id)
    ensure_room_seats(db, room)
    record_room_event(db, room, "room.settings.updated", actor_user_id=actor_user_id, payload={"seat_layout_id": room.seat_layout_id})
    db.flush()
    return room_snapshot(db, room)


def set_background_theme(db: Session, room: Room, theme_id: str, actor_user_id: int | None = None) -> dict[str, Any]:
    room.background_theme_id = theme_id or "default"
    record_room_event(db, room, "room.theme.updated", actor_user_id=actor_user_id, payload={"background_theme_id": room.background_theme_id})
    db.flush()
    return room_snapshot(db, room)


def create_chat_message(db: Session, room: Room, user: User | None, text: str | None, message_type: str = "text", metadata: dict[str, Any] | None = None) -> dict[str, Any]:
    message = RoomChatMessage(
        room_id=room.id,
        room_public_id=room.room_public_id,
        sender_user_id=user.id if user else None,
        message_type=message_type,
        text=text,
        metadata_json=metadata or {},
    )
    db.add(message)
    db.flush()
    record_room_event(db, room, "room.chat.message_created", actor_user_id=user.id if user else None, payload={"message_id": message.id})
    db.flush()
    return room_snapshot(db, room)