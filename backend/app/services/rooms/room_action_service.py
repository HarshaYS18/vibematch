from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.room import Room, RoomMode
from app.models.room_participant import RoomParticipant
from app.models.room_realtime_state import RoomChatMessage, RoomRealtimeEvent, RoomSeatState
from app.models.user import User
from app.services.event_outbox_service import enqueue_event
from app.services.permissions import room_permission_service
from app.services.rooms.room_kickout_service import create_room_kickout_for_user, deactivate_room_user_for_kickout
from app.services.rooms.room_service import assert_room_entry_allowed, close_other_active_room_sessions, deactivate_user_in_room, mark_user_room_presence_active, user_has_active_room_conflict
from app.services.rooms.room_state_service import ensure_room_seats, normalize_layout, room_sequence, room_snapshot, seat_count_for_layout
from app.services.rooms import watch_party_service

SEAT_APPLICATION_EXPIRY_SECONDS = 20
SEAT_APPLICATION_COOLDOWN_SECONDS = 30


def _next_sequence(db: Session, room: Room) -> int:
    return room_sequence(db, room) + 1


def record_room_event(
    db: Session,
    room: Room,
    event_type: str,
    actor_user_id: int | None = None,
    target_user_id: int | None = None,
    payload: dict[str, Any] | None = None,
    privacy_scope: str = "room",
) -> RoomRealtimeEvent:
    event = RoomRealtimeEvent(
        room_id=room.id,
        room_public_id=room.room_public_id,
        event_type=event_type,
        actor_user_id=actor_user_id,
        target_user_id=target_user_id,
        payload=payload or {},
        privacy_scope=privacy_scope,
        sequence=_next_sequence(db, room),
    )
    db.add(event)
    if event_type in {"room.joined", "room.left", "seat.taken", "seat.left"}:
        # Keep the durable event and outbox insert in the same transaction.
        # Never copy command payloads: they may contain a room password.
        enqueue_event(
            db, event_type=event_type,
            actor_user_id=actor_user_id,
            payload={"room_public_id": room.room_public_id, "actor_user_id": actor_user_id,
                     "target_user_id": target_user_id},
        )
    room.updated_at = datetime.utcnow()
    db.flush()
    return event


def _room_participant(db: Session, room: Room, user: User) -> RoomParticipant | None:
    return db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == user.id).first()


def _requested_hidden(payload: dict[str, Any] | None) -> bool:
    if not payload:
        return False
    return payload.get("stealth") is True or payload.get("is_stealth") is True or payload.get("hidden_presence") is True


def _ensure_room_participant(db: Session, room: Room, user: User, payload: dict[str, Any] | None = None) -> RoomParticipant:
    now = datetime.utcnow()
    participant = _room_participant(db, room, user)
    visibility = room_permission_service.hidden_presence_flags(db, user, _requested_hidden(payload))
    if participant is None:
        participant = RoomParticipant(room_id=room.id, user_id=user.id, is_active=True, is_member=False, is_room_admin=user.id == room.owner_user_id, joined_at=now, last_seen_at=now, **visibility)
        db.add(participant)
    else:
        participant.is_active = True
        participant.last_seen_at = now
        participant.left_at = None
        participant.is_stealth = visibility["is_stealth"]
        participant.visible_in_online_count = visibility["visible_in_online_count"]
        participant.visible_in_user_list = visibility["visible_in_user_list"]
        participant.visible_to_public = visibility["visible_to_public"]
        if user.id == room.owner_user_id:
            participant.is_room_admin = True
    return participant


def _host_or_admin_should_auto_seat(room: Room, participant: RoomParticipant, user: User) -> bool:
    return user.id == room.owner_user_id or participant.is_room_admin


def _seat_occupied_by_user(db: Session, room: Room, user_id: int) -> bool:
    return db.query(RoomSeatState).filter(RoomSeatState.room_id == room.id, RoomSeatState.occupant_user_id == user_id).first() is not None


def _auto_place_host_admin_if_needed(db: Session, room: Room, user: User, participant: RoomParticipant) -> None:
    if participant.is_stealth:
        return
    if not _host_or_admin_should_auto_seat(room, participant, user):
        return
    if _seat_occupied_by_user(db, room, user.id):
        return
    seats = ensure_room_seats(db, room)
    seat_one = next((seat for seat in seats if seat.seat_index == 0), None)
    if seat_one is None or seat_one.is_locked or seat_one.occupant_user_id is not None:
        return
    now = datetime.utcnow()
    seat_one.occupant_user_id = user.id
    seat_one.mic_enabled = False
    seat_one.admin_muted = False
    seat_one.occupied_at = now
    seat_one.left_at = None
    seat_one.updated_by_user_id = user.id


def _has_pending_room_member_request(db: Session, room: Room, user_id: int) -> bool:
    pending = db.query(RoomRealtimeEvent).filter(RoomRealtimeEvent.room_id == room.id, RoomRealtimeEvent.event_type == "room.member_request.pending", RoomRealtimeEvent.actor_user_id == user_id).order_by(RoomRealtimeEvent.id.desc()).first()
    if pending is None:
        return False
    decision = db.query(RoomRealtimeEvent).filter(RoomRealtimeEvent.room_id == room.id, RoomRealtimeEvent.event_type.in_(["room.member_request.approved", "room.member_request.rejected", "room.member.removed"]), RoomRealtimeEvent.target_user_id == user_id, RoomRealtimeEvent.id > pending.id).first()
    return decision is None


def _is_room_manager(db: Session, room: Room, user: User) -> bool:
    if user.id == room.owner_user_id:
        return True
    if room_permission_service.can_force_join_room(db, user):
        return True
    participant = _room_participant(db, room, user)
    return bool(participant and participant.is_room_admin)


def _seat_can_receive_application(db: Session, room: Room, seat_index: int) -> bool:
    if seat_index < 0 or seat_index >= seat_count_for_layout(room.seat_layout_id):
        return False
    seat = next((item for item in ensure_room_seats(db, room) if item.seat_index == seat_index), None)
    return bool(seat is not None and not seat.is_locked and seat.occupant_user_id is None)


def _seat_can_receive_invite(db: Session, room: Room, seat_index: int) -> bool:
    if seat_index < 0 or seat_index >= seat_count_for_layout(room.seat_layout_id):
        return False
    seat = next((item for item in ensure_room_seats(db, room) if item.seat_index == seat_index), None)
    return bool(seat is not None and seat.occupant_user_id is None)


def latest_seat_application_request_id(db: Session, room: Room, user: User) -> int | None:
    latest = (
        db.query(RoomRealtimeEvent.id)
        .filter(
            RoomRealtimeEvent.room_id == room.id,
            RoomRealtimeEvent.event_type == "seat.application.requested",
            RoomRealtimeEvent.actor_user_id == user.id,
        )
        .order_by(RoomRealtimeEvent.id.desc())
        .first()
    )
    return int(latest[0]) if latest else None


def latest_seat_invite_id(db: Session, room: Room, actor: User, target: User, seat_index: int) -> int | None:
    latest = (
        db.query(RoomRealtimeEvent.id)
        .filter(
            RoomRealtimeEvent.room_id == room.id,
            RoomRealtimeEvent.event_type == "seat.invite.sent",
            RoomRealtimeEvent.actor_user_id == actor.id,
            RoomRealtimeEvent.target_user_id == target.id,
        )
        .order_by(RoomRealtimeEvent.id.desc())
        .first()
    )
    if latest is None:
        return None
    return int(latest[0])


def _seat_application_cooldown_remaining(db: Session, room: Room, user: User) -> int:
    latest = (
        db.query(RoomRealtimeEvent)
        .filter(
            RoomRealtimeEvent.room_id == room.id,
            RoomRealtimeEvent.event_type == "seat.application.requested",
            RoomRealtimeEvent.actor_user_id == user.id,
        )
        .order_by(RoomRealtimeEvent.id.desc())
        .first()
    )
    if latest is None:
        return 0
    elapsed = int((datetime.utcnow() - latest.created_at).total_seconds())
    return max(0, SEAT_APPLICATION_COOLDOWN_SECONDS - elapsed)


def _safe_room_join_event_payload(
    payload: dict[str, Any] | None,
    *,
    is_stealth: bool,
) -> dict[str, Any]:
    """Strip entry secrets before durable room event/outbox persistence."""
    safe = {
        key: value
        for key, value in (payload or {}).items()
        if key not in {"lock_password", "password"}
    }
    safe["is_stealth"] = is_stealth
    return safe


def join_room(db: Session, room: Room, user: User, payload: dict[str, Any] | None = None) -> dict[str, Any]:
    assert_room_entry_allowed(db, room, user, lock_password=str((payload or {}).get("lock_password") or "") or None)
    closed_room_ids = close_other_active_room_sessions(db, user.id, except_room_public_id=room.room_public_id)
    participant = _ensure_room_participant(db, room, user, payload)
    mark_user_room_presence_active(db, room, user)
    _auto_place_host_admin_if_needed(db, room, user, participant)
    record_room_event(
        db,
        room,
        "room.joined",
        actor_user_id=user.id,
        payload=_safe_room_join_event_payload(
            payload,
            is_stealth=participant.is_stealth,
        ),
    )
    db.flush()
    snapshot = room_snapshot(db, room)
    if closed_room_ids:
        snapshot["_closed_room_ids"] = sorted(closed_room_ids)
    return snapshot


def reconcile_authenticated_room_presence(
    db: Session,
    room: Room,
    user: User,
) -> None:
    """Repair stale durable presence for an already-authenticated room socket.

    This never creates a missing participant. Entry restrictions and
    single-active-room rules are rechecked before an existing inactive row is
    reactivated.
    """
    participant = (
        db.query(RoomParticipant)
        .filter(
            RoomParticipant.room_id == room.id,
            RoomParticipant.user_id == user.id,
        )
        .with_for_update()
        .first()
    )
    if participant is None or participant.is_active:
        return

    assert_room_entry_allowed(db, room, user)
    if user_has_active_room_conflict(db, user.id, room.room_public_id):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This account is already active in another chatroom",
        )

    now = datetime.utcnow()
    participant.is_active = True
    participant.last_seen_at = now
    participant.left_at = None
    user.last_seen_at = now
    mark_user_room_presence_active(db, room, user)
    db.flush()


def heartbeat_room(db: Session, room: Room, user: User) -> dict[str, Any]:
    assert_room_entry_allowed(db, room, user)
    if user_has_active_room_conflict(db, user.id, room.room_public_id):
        deactivate_user_in_room(db, room, user.id)
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="This account is already active in another chatroom")
    participant = _room_participant(db, room, user)
    if participant:
        participant.is_active = True
        participant.last_seen_at = datetime.utcnow()
        participant.left_at = None
        mark_user_room_presence_active(db, room, user)
    db.flush()
    return room_snapshot(db, room, include_chat=False)


def leave_room(db: Session, room: Room, user: User, release_seat: bool = False) -> dict[str, Any]:
    deactivate_user_in_room(db, room, user.id, release_seats=release_seat)
    record_room_event(db, room, "room.left", actor_user_id=user.id, payload={"release_seat": release_seat})
    watch_party_service.ensure_controller_after_departure(db, room, user.id)
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
    if actor.id != room.owner_user_id and not room_permission_service.can_manage_room_admins(db, actor, room.owner_user_id):
        return room_snapshot(db, room)
    participant = _ensure_room_participant(db, room, target)
    participant.is_member = True
    participant.member_added_at = datetime.utcnow()
    record_room_event(db, room, "room.member_request.approved", actor_user_id=actor.id, target_user_id=target.id, payload={"status": "room_member"})
    db.flush()
    return room_snapshot(db, room)


def reject_room_membership(db: Session, room: Room, actor: User, target: User) -> dict[str, Any]:
    if actor.id != room.owner_user_id and not room_permission_service.can_manage_room_admins(db, actor, room.owner_user_id):
        return room_snapshot(db, room)
    participant = _ensure_room_participant(db, room, target)
    if not participant.is_member:
        participant.member_added_at = None
    record_room_event(db, room, "room.member_request.rejected", actor_user_id=actor.id, target_user_id=target.id, payload={"status": "rejected"})
    db.flush()
    return room_snapshot(db, room)


def remove_room_member(db: Session, room: Room, actor: User, target: User) -> dict[str, Any]:
    if actor.id != room.owner_user_id and not room_permission_service.can_manage_room_admins(db, actor, room.owner_user_id):
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


def take_seat(
    db: Session,
    room: Room,
    user: User,
    seat_index: int,
    actor_user_id: int | None = None,
    mic_enabled: bool = False,
) -> dict[str, Any]:
    participant = _room_participant(db, room, user)
    if participant and participant.is_stealth:
        return room_snapshot(db, room)
    seats = ensure_room_seats(db, room)
    max_seats = seat_count_for_layout(room.seat_layout_id)
    if seat_index < 0 or seat_index >= max_seats:
        return room_snapshot(db, room)
    target = next((seat for seat in seats if seat.seat_index == seat_index), None)
    if target is None or target.is_locked:
        return room_snapshot(db, room)
    if target.occupant_user_id is not None and target.occupant_user_id != user.id:
        actor = db.query(User).filter(User.id == actor_user_id).first() if actor_user_id else None
        if actor is None or not _is_room_manager(db, room, actor):
            return room_snapshot(db, room)
    now = datetime.utcnow()
    for seat in seats:
        if seat.occupant_user_id == user.id:
            seat.occupant_user_id = None
            seat.mic_enabled = False
            seat.left_at = now
        if seat.seat_index == seat_index:
            seat.occupant_user_id = user.id
            seat.mic_enabled = mic_enabled
            seat.admin_muted = False
            seat.occupied_at = now
            seat.left_at = None
            seat.updated_by_user_id = actor_user_id or user.id
    record_room_event(db, room, "seat.taken", actor_user_id=actor_user_id or user.id, target_user_id=user.id, payload={"seat_index": seat_index})
    db.flush()
    return room_snapshot(db, room)


def assign_seat(db: Session, room: Room, actor: User, target: User, seat_index: int) -> dict[str, Any]:
    if not _is_room_manager(db, room, actor):
        return room_snapshot(db, room)
    return take_seat(db, room, target, seat_index, actor_user_id=actor.id)


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


def send_seat_invite(db: Session, room: Room, actor: User, target: User, seat_index: int) -> dict[str, Any]:
    if not _is_room_manager(db, room, actor):
        return room_snapshot(db, room)
    if not _seat_can_receive_invite(db, room, seat_index):
        return room_snapshot(db, room)
    invite_id = f"seat_invite_{room.room_public_id}_{actor.id}_{target.id}_{seat_index}_{int(datetime.utcnow().timestamp() * 1000)}"
    record_room_event(db, room, "seat.invite.sent", actor_user_id=actor.id, target_user_id=target.id, payload={"invite_id": invite_id, "seat_index": seat_index}, privacy_scope="target")
    db.flush()
    return room_snapshot(db, room)


def request_seat_application(db: Session, room: Room, user: User, seat_index: int) -> dict[str, Any]:
    if not room.apply_only_mode_enabled:
        return take_seat(db, room, user, seat_index)
    if not _seat_can_receive_application(db, room, seat_index):
        return room_snapshot(db, room)
    if _seat_application_cooldown_remaining(db, room, user) > 0:
        return room_snapshot(db, room)
    now = datetime.utcnow()
    expires_at = now + timedelta(seconds=SEAT_APPLICATION_EXPIRY_SECONDS)
    event_id = f"seat_application_{room.room_public_id}_{user.id}_{seat_index}_{int(now.timestamp() * 1000)}"
    record_room_event(db, room, "seat.application.requested", actor_user_id=user.id, target_user_id=room.owner_user_id, payload={"id": event_id, "seat_index": seat_index, "created_at": now.isoformat(), "expires_at": expires_at.isoformat()})
    db.flush()
    return room_snapshot(db, room)


def reject_seat_application(db: Session, room: Room, actor: User, target: User, seat_index: int) -> dict[str, Any]:
    if not _is_room_manager(db, room, actor):
        return room_snapshot(db, room)
    record_room_event(db, room, "seat.application.rejected", actor_user_id=actor.id, target_user_id=target.id, payload={"seat_index": seat_index})
    db.flush()
    return room_snapshot(db, room)


def kick_user(db: Session, room: Room, actor: User, target: User, reason: str = "Removed by room admin", duration: str = "1h") -> dict[str, Any]:
    if target.id == actor.id:
        return room_snapshot(db, room)
    actor_can_manage_room = _is_room_manager(db, room, actor)
    role_can_kick = room_permission_service.can_kick_room_user(db, actor, target)
    if not actor_can_manage_room and not role_can_kick:
        return room_snapshot(db, room)
    if actor_can_manage_room and not role_can_kick:
        target_is_normal = not bool(target.is_protected)
        if not target_is_normal:
            return room_snapshot(db, room)
    create_room_kickout_for_user(
        db,
        room_public_id=room.room_public_id,
        target=target,
        actor=actor,
        duration=duration,
        reason=reason,
        actor_can_manage_room=actor_can_manage_room,
    )
    deactivate_room_user_for_kickout(
        db,
        room_public_id=room.room_public_id,
        target=target,
        actor_user_id=actor.id,
    )
    record_room_event(db, room, "room.user.kicked", actor_user_id=actor.id, target_user_id=target.id, payload={"reason": reason, "duration": duration})
    watch_party_service.ensure_controller_after_departure(db, room, target.id)
    db.flush()
    return room_snapshot(db, room)


def take_or_request_seat(
    db: Session,
    room: Room,
    user: User,
    seat_index: int,
    mic_enabled: bool = False,
) -> dict[str, Any]:
    if room.apply_only_mode_enabled and not _is_room_manager(db, room, user):
        return request_seat_application(db, room, user, seat_index)
    return take_seat(db, room, user, seat_index, mic_enabled=mic_enabled)


def _has_pending_seat_invite(db: Session, room: Room, user: User, seat_index: int) -> bool:
    invite = (
        db.query(RoomRealtimeEvent)
        .filter(
            RoomRealtimeEvent.room_id == room.id,
            RoomRealtimeEvent.event_type == "seat.invite.sent",
            RoomRealtimeEvent.target_user_id == user.id,
        )
        .order_by(RoomRealtimeEvent.id.desc())
        .first()
    )
    if invite is None:
        return False
    payload = invite.payload or {}
    try:
        invited_seat_index = int(payload.get("seat_index"))
    except Exception:
        return False
    if invited_seat_index != seat_index:
        return False
    decision = (
        db.query(RoomRealtimeEvent)
        .filter(
            RoomRealtimeEvent.room_id == room.id,
            RoomRealtimeEvent.event_type.in_(["seat.invite.accepted", "seat.invite.rejected", "seat.taken"]),
            RoomRealtimeEvent.target_user_id == user.id,
            RoomRealtimeEvent.id > invite.id,
        )
        .first()
    )
    return decision is None


def accept_seat_invite(db: Session, room: Room, user: User, seat_index: int) -> dict[str, Any]:
    if not _has_pending_seat_invite(db, room, user, seat_index):
        return room_snapshot(db, room)
    if not _seat_can_receive_invite(db, room, seat_index):
        return room_snapshot(db, room)
    for seat in ensure_room_seats(db, room):
        if seat.seat_index == seat_index and seat.is_locked:
            seat.is_locked = False
            seat.locked_by_user_id = None
            seat.locked_at = None
            seat.updated_by_user_id = user.id
            break
    record_room_event(db, room, "seat.invite.accepted", actor_user_id=user.id, target_user_id=user.id, payload={"seat_index": seat_index}, privacy_scope="target")
    return take_seat(db, room, user, seat_index)


def reject_seat_invite(db: Session, room: Room, user: User, seat_index: int) -> dict[str, Any]:
    record_room_event(db, room, "seat.invite.rejected", actor_user_id=user.id, target_user_id=user.id, payload={"seat_index": seat_index}, privacy_scope="target")
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
    actor = db.query(User).filter(User.id == actor_user_id).first() if actor_user_id else None
    target = db.query(User).filter(User.id == target_user_id).first()
    if actor is not None and target is not None and not room_permission_service.can_mute_room_user(db, actor, target):
        return room_snapshot(db, room)
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


def set_room_privacy(db: Session, room: Room, actor: User, mode: str, lock_password_hash: str | None = None) -> dict[str, Any]:
    if not room_permission_service.can_change_room_privacy(db, actor, room.owner_user_id):
        return room_snapshot(db, room)
    clean_mode = mode if mode in {item.value for item in RoomMode} else RoomMode.OPEN.value
    room.mode = clean_mode
    room.is_secret = clean_mode == RoomMode.SECRET_VIBE.value
    room.is_locked = clean_mode == RoomMode.LOCKED.value
    room.is_members_only = clean_mode == RoomMode.MEMBERS_ONLY.value
    watch_party_service.end_ott_if_room_not_private(db, room, actor)
    if lock_password_hash is not None:
        room.lock_password_hash = lock_password_hash
        room.lock_updated_at = datetime.utcnow()
        room.lock_updated_by_user_id = actor.id
    record_room_event(db, room, "room.privacy.updated", actor_user_id=actor.id, payload={"mode": clean_mode})
    db.flush()
    return room_snapshot(db, room)


def set_room_screenshots(db: Session, room: Room, actor: User, allow_screenshots: bool) -> dict[str, Any]:
    if not room_permission_service.can_change_room_privacy(db, actor, room.owner_user_id):
        return room_snapshot(db, room)
    room.allow_screenshots = allow_screenshots
    record_room_event(db, room, "room.screenshots.updated", actor_user_id=actor.id, payload={"allow_screenshots": allow_screenshots})
    db.flush()
    return room_snapshot(db, room)


def set_room_images_enabled(db: Session, room: Room, actor: User, enabled: bool) -> dict[str, Any]:
    if not room_permission_service.can_change_room_privacy(db, actor, room.owner_user_id):
        return room_snapshot(db, room)
    room.room_images_enabled = enabled
    record_room_event(db, room, "room.images.updated", actor_user_id=actor.id, payload={"room_images_enabled": enabled})
    db.flush()
    return room_snapshot(db, room)


def set_guest_messages_enabled(db: Session, room: Room, actor: User, enabled: bool) -> dict[str, Any]:
    if not room_permission_service.can_change_room_privacy(db, actor, room.owner_user_id):
        return room_snapshot(db, room)
    room.guest_messages_enabled = enabled
    record_room_event(db, room, "room.guest_messages.updated", actor_user_id=actor.id, payload={"guest_messages_enabled": enabled})
    db.flush()
    return room_snapshot(db, room)


def set_apply_only_mode_enabled(db: Session, room: Room, actor: User, enabled: bool) -> dict[str, Any]:
    if not room_permission_service.can_change_room_privacy(db, actor, room.owner_user_id):
        return room_snapshot(db, room)
    room.apply_only_mode_enabled = enabled
    record_room_event(db, room, "room.apply_only.updated", actor_user_id=actor.id, payload={"apply_only_mode_enabled": enabled})
    db.flush()
    return room_snapshot(db, room)


def set_announcement(db: Session, room: Room, actor: User, announcement_text: str) -> dict[str, Any]:
    if not room_permission_service.can_change_room_privacy(db, actor, room.owner_user_id):
        return room_snapshot(db, room)
    room.announcement_text = announcement_text.strip()
    room.announcement_updated_at = datetime.utcnow()
    room.announcement_updated_by_user_id = actor.id
    record_room_event(db, room, "room.announcement.updated", actor_user_id=actor.id, payload={"announcement_text": room.announcement_text})
    db.flush()
    return room_snapshot(db, room)


def create_chat_message(db: Session, room: Room, user: User | None, text: str | None, message_type: str = "text", metadata: dict[str, Any] | None = None) -> dict[str, Any]:
    participant = _room_participant(db, room, user) if user is not None else None
    can_bypass_guest_block = bool(user is not None and (_is_room_manager(db, room, user) or (participant is not None and participant.is_member)))
    if user is not None and not room.guest_messages_enabled and not can_bypass_guest_block:
        record_room_event(db, room, "room.chat.blocked", actor_user_id=user.id, payload={"reason": "guest_messages_disabled"})
        db.flush()
        return room_snapshot(db, room)
    if user is not None and message_type == "image" and not room.room_images_enabled and not _is_room_manager(db, room, user):
        record_room_event(db, room, "room.chat.blocked", actor_user_id=user.id, payload={"reason": "room_images_disabled"})
        db.flush()
        return room_snapshot(db, room)
    message = RoomChatMessage(room_id=room.id, room_public_id=room.room_public_id, sender_user_id=user.id if user else None, message_type=message_type, text=text, metadata_json=metadata or {})
    db.add(message)
    db.flush()
    record_room_event(db, room, "room.chat.message_created", actor_user_id=user.id if user else None, payload={"message_id": message.id})
    db.flush()
    return room_snapshot(db, room)
