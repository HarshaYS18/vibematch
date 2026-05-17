from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.realtime.connection_manager import room_realtime_connections
from app.schemas.room_realtime import (
    RoomAdminMuteCommand,
    RoomBackgroundThemeCommand,
    RoomChatSendCommand,
    RoomJoinCommand,
    RoomLeaveCommand,
    RoomMicCommand,
    RoomSeatLayoutCommand,
    RoomSeatLeaveCommand,
    RoomSeatLockCommand,
    RoomSeatTakeCommand,
)
from app.services.rooms import room_action_service, room_state_service
from app.services.rooms import room_permission_service

router = APIRouter(prefix="/rooms/{room_public_id}/realtime", tags=["Room Realtime Commands"])


def _room_or_404(db: Session, room_public_id: str):
    room = room_state_service.get_room_by_public_id(db, room_public_id)
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    return room


def _user_or_401(db: Session, user_id: int | None) -> User:
    if not user_id:
        raise HTTPException(status_code=401, detail="user_id is required until auth token wiring is connected")
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    if user.is_banned or not user.is_active:
        raise HTTPException(status_code=403, detail="User is not allowed")
    return user


async def _publish(room_public_id: str, event_type: str, snapshot: dict):
    await room_realtime_connections.broadcast_room(
        room_public_id,
        {"type": event_type, "payload": {"room_id": room_public_id, "room": snapshot}},
    )


@router.get("/snapshot")
def snapshot(room_public_id: str, db: Session = Depends(get_db)):
    room = _room_or_404(db, room_public_id)
    snapshot_data = room_state_service.room_snapshot(db, room)
    db.commit()
    return {"room_id": room_public_id, "room": snapshot_data}


@router.post("/join")
async def join(room_public_id: str, command: RoomJoinCommand, db: Session = Depends(get_db)):
    room = _room_or_404(db, room_public_id)
    user = _user_or_401(db, command.user_id)
    snapshot_data = room_action_service.join_room(db, room, user, command.model_dump())
    db.commit()
    await _publish(room_public_id, "room/joined", snapshot_data)
    return {"room_id": room_public_id, "room": snapshot_data}


@router.post("/leave")
async def leave(room_public_id: str, command: RoomLeaveCommand, db: Session = Depends(get_db)):
    room = _room_or_404(db, room_public_id)
    user = _user_or_401(db, command.user_id)
    snapshot_data = room_action_service.leave_room(db, room, user, release_seat=command.release_seat)
    db.commit()
    await _publish(room_public_id, "room/peer_left", snapshot_data)
    return {"room_id": room_public_id, "room": snapshot_data}


@router.post("/seat/take")
async def take_seat(room_public_id: str, command: RoomSeatTakeCommand, db: Session = Depends(get_db)):
    room = _room_or_404(db, room_public_id)
    user = _user_or_401(db, command.user_id)
    room_permission_service.require_seat_take(db, room, user, user)
    snapshot_data = room_action_service.take_seat(db, room, user, command.seat_index)
    db.commit()
    await _publish(room_public_id, "seat/updated", snapshot_data)
    return {"room_id": room_public_id, "room": snapshot_data}


@router.post("/seat/leave")
async def leave_seat(room_public_id: str, command: RoomSeatLeaveCommand, db: Session = Depends(get_db)):
    room = _room_or_404(db, room_public_id)
    user = _user_or_401(db, command.user_id)
    room_permission_service.require_seat_take(db, room, user, user)
    snapshot_data = room_action_service.leave_seat(db, room, user)
    db.commit()
    await _publish(room_public_id, "seat/updated", snapshot_data)
    return {"room_id": room_public_id, "room": snapshot_data}


@router.post("/seat/lock")
async def lock_seat(room_public_id: str, command: RoomSeatLockCommand, db: Session = Depends(get_db)):
    room = _room_or_404(db, room_public_id)
    actor = _user_or_401(db, command.user_id)
    room_permission_service.require_room_admin(db, room, actor)
    snapshot_data = room_action_service.lock_seat(db, room, command.seat_index, command.locked, actor_user_id=actor.id)
    db.commit()
    await _publish(room_public_id, "seat/updated", snapshot_data)
    return {"room_id": room_public_id, "room": snapshot_data}


@router.post("/mic")
async def set_mic(room_public_id: str, command: RoomMicCommand, db: Session = Depends(get_db)):
    room = _room_or_404(db, room_public_id)
    user = _user_or_401(db, command.user_id)
    room_permission_service.require_mic_change(db, room, user)
    snapshot_data = room_action_service.set_mic_enabled(db, room, user, command.enabled)
    db.commit()
    await _publish(room_public_id, "seat/updated", snapshot_data)
    return {"room_id": room_public_id, "room": snapshot_data}


@router.post("/admin-mute")
async def admin_mute(room_public_id: str, command: RoomAdminMuteCommand, db: Session = Depends(get_db)):
    room = _room_or_404(db, room_public_id)
    actor = _user_or_401(db, command.user_id)
    target = db.query(User).filter(User.id == command.target_user_id).first()
    room_permission_service.require_admin_mute(db, room, actor, target)
    snapshot_data = room_action_service.set_admin_mute(db, room, command.target_user_id, command.muted, actor_user_id=actor.id)
    db.commit()
    await _publish(room_public_id, "admin_mute/updated", snapshot_data)
    return {"room_id": room_public_id, "room": snapshot_data}


@router.post("/settings/seat-layout")
async def seat_layout(room_public_id: str, command: RoomSeatLayoutCommand, db: Session = Depends(get_db)):
    room = _room_or_404(db, room_public_id)
    actor = _user_or_401(db, command.user_id)
    room_permission_service.require_room_settings(db, room, actor)
    snapshot_data = room_action_service.set_seat_layout(db, room, command.seat_layout_id, actor_user_id=actor.id)
    db.commit()
    await _publish(room_public_id, "room_settings/updated", snapshot_data)
    return {"room_id": room_public_id, "room": snapshot_data}


@router.post("/settings/background-theme")
async def background_theme(room_public_id: str, command: RoomBackgroundThemeCommand, db: Session = Depends(get_db)):
    room = _room_or_404(db, room_public_id)
    actor = _user_or_401(db, command.user_id)
    room_permission_service.require_room_settings(db, room, actor)
    snapshot_data = room_action_service.set_background_theme(db, room, command.background_theme_id, actor_user_id=actor.id)
    db.commit()
    await _publish(room_public_id, "room_settings/updated", snapshot_data)
    return {"room_id": room_public_id, "room": snapshot_data}


@router.post("/chat/send")
async def chat_send(room_public_id: str, command: RoomChatSendCommand, db: Session = Depends(get_db)):
    room = _room_or_404(db, room_public_id)
    user = _user_or_401(db, command.user_id)
    room_permission_service.require_chat_send(db, room, user)
    text = command.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Message cannot be empty")
    snapshot_data = room_action_service.create_chat_message(db, room, user, text, message_type=command.message_type)
    db.commit()
    await _publish(room_public_id, "room.chat.message_created", snapshot_data)
    return {"room_id": room_public_id, "room": snapshot_data}
