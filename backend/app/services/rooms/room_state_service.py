from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.room_realtime_state import RoomChatMessage, RoomRealtimeEvent, RoomSeatState
from app.models.user import User

_ALLOWED_SEAT_LAYOUT_IDS = {"4x2", "5x2", "4x3", "5x3", "host_4x2", "host_5x2", "host_4x3", "host_5x3"}


def normalize_layout(layout_id: str | None) -> str:
    return layout_id if layout_id in _ALLOWED_SEAT_LAYOUT_IDS else "5x2"


def seat_count_for_layout(layout_id: str | None) -> int:
    safe_layout = normalize_layout(layout_id)
    has_host = safe_layout.startswith("host_")
    raw = safe_layout.replace("host_", "", 1)
    try:
        columns, rows = raw.split("x", 1)
        count = int(columns) * int(rows)
        return count + (2 if has_host else 0)
    except Exception:
        return 10


def get_room_by_public_id(db: Session, room_public_id: str) -> Room | None:
    return db.query(Room).filter(Room.room_public_id == room_public_id).first()


def ensure_room_seats(db: Session, room: Room) -> list[RoomSeatState]:
    max_seats = seat_count_for_layout(room.seat_layout_id)
    existing = {seat.seat_index: seat for seat in db.query(RoomSeatState).filter(RoomSeatState.room_id == room.id).all()}
    for seat_index in range(max_seats):
        if seat_index not in existing:
            seat = RoomSeatState(room_id=room.id, seat_index=seat_index)
            db.add(seat)
            existing[seat_index] = seat
    for seat_index, seat in existing.items():
        if seat_index >= max_seats and seat.occupant_user_id is not None:
            seat.occupant_user_id = None
            seat.mic_enabled = False
            seat.admin_muted = False
            seat.left_at = datetime.utcnow()
    db.flush()
    return [existing[index] for index in sorted(existing) if index < max_seats]


def room_sequence(db: Session, room: Room) -> int:
    value = db.query(func.max(RoomRealtimeEvent.sequence)).filter(RoomRealtimeEvent.room_id == room.id).scalar()
    return int(value or 0)


def active_participants(db: Session, room: Room) -> list[RoomParticipant]:
    return (
        db.query(RoomParticipant)
        .filter(RoomParticipant.room_id == room.id, RoomParticipant.is_active.is_(True))
        .order_by(RoomParticipant.joined_at.asc())
        .all()
    )


def user_card(user: User | None) -> dict[str, Any] | None:
    if user is None:
        return None
    return {
        "user_id": user.id,
        "public_user_id": user.public_user_id,
        "display_name": user.display_name or user.username or str(user.public_user_id),
        "username": user.username,
        "avatar_url": user.avatar_url,
        "official_handle": user.official_handle,
        "is_protected": bool(user.is_protected),
    }


def seat_payload(seat: RoomSeatState) -> dict[str, Any]:
    return {
        "seat_index": seat.seat_index,
        "occupant_user_id": seat.occupant_user_id,
        "is_locked": seat.is_locked,
        "mic_enabled": seat.mic_enabled,
        "admin_muted": seat.admin_muted,
        "locked_by_user_id": seat.locked_by_user_id,
        "admin_muted_by_user_id": seat.admin_muted_by_user_id,
        "updated_by_user_id": seat.updated_by_user_id,
        "occupant": user_card(seat.occupant),
    }


def chat_payload(message: RoomChatMessage) -> dict[str, Any]:
    return {
        "id": message.id,
        "room_public_id": message.room_public_id,
        "sender_user_id": message.sender_user_id,
        "message_type": message.message_type,
        "text": message.text,
        "media_url": message.media_url,
        "metadata": message.metadata_json or {},
        "created_at": message.created_at.isoformat() if message.created_at else None,
        "sender": user_card(message.sender),
    }


def recent_chat_messages(db: Session, room: Room, limit: int = 80) -> list[dict[str, Any]]:
    rows = (
        db.query(RoomChatMessage)
        .filter(RoomChatMessage.room_id == room.id, RoomChatMessage.is_deleted.is_(False))
        .order_by(RoomChatMessage.id.desc())
        .limit(limit)
        .all()
    )
    return [chat_payload(message) for message in reversed(rows)]


def room_snapshot(db: Session, room: Room, include_chat: bool = True) -> dict[str, Any]:
    seats = ensure_room_seats(db, room)
    participants = active_participants(db, room)
    active_count = len(participants)
    if room.online_count != active_count:
        room.online_count = active_count
        db.flush()

    peers = []
    for participant in participants:
        seat = next((item for item in seats if item.occupant_user_id == participant.user_id), None)
        user = participant.user
        peers.append({
            "peer_id": str(participant.user_id),
            "user_id": str(participant.user_id),
            "display_name": (user.display_name or user.username or str(user.public_user_id)) if user else "Vibe User",
            "avatar_url": user.avatar_url if user else None,
            "is_host": participant.user_id == room.owner_user_id,
            "is_room_admin": participant.is_room_admin or participant.user_id == room.owner_user_id,
            "role_label": "Host" if participant.user_id == room.owner_user_id else ("Admin" if participant.is_room_admin else "Member"),
            "seat_index": seat.seat_index if seat else None,
            "mic_enabled": seat.mic_enabled if seat else False,
            "admin_muted": seat.admin_muted if seat else False,
        })

    payload: dict[str, Any] = {
        "room_id": room.room_public_id,
        "room_public_id": room.room_public_id,
        "database_room_id": room.id,
        "owner_user_id": room.owner_user_id,
        "name": room.name,
        "subtitle": room.subtitle,
        "avatar_url": room.avatar_url,
        "cover_photo_url": room.cover_photo_url,
        "language": room.language,
        "mode": room.mode,
        "room_type": room.room_type,
        "online_count": active_count,
        "is_active": room.is_active,
        "is_secret": room.is_secret,
        "is_locked": room.is_locked,
        "is_members_only": room.is_members_only,
        "allow_screenshots": room.allow_screenshots,
        "background_theme_id": room.background_theme_id,
        "seat_layout_id": normalize_layout(room.seat_layout_id),
        "seat_count": seat_count_for_layout(room.seat_layout_id),
        "announcement_text": room.announcement_text,
        "state_version": room_sequence(db, room),
        "updated_at": room.updated_at.isoformat() if room.updated_at else None,
        "seats": [seat_payload(seat) for seat in seats],
        "locked_seat_indexes": [seat.seat_index for seat in seats if seat.is_locked],
        "peers": peers,
        "peer_count": active_count,
    }
    if include_chat:
        payload["recent_messages"] = recent_chat_messages(db, room)
    return payload
