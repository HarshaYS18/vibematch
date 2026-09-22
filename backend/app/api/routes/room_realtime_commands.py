from __future__ import annotations

import asyncio
import re
from dataclasses import dataclass
from datetime import datetime
from typing import Any
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import SessionLocal, get_db
from app.models.room import Room
from app.models.room_kickout import RoomKickout
from app.models.room_participant import RoomParticipant
from app.models.room_realtime_state import RoomChatMessage, RoomRealtimeEvent
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
from app.services.permissions import room_permission_service as policy_permissions
from app.services.rooms import room_action_service, room_permission_service, room_state_service
from app.services.user_master_state_service import get_user_master_state


router = APIRouter(prefix="/rooms/{room_public_id}/realtime", tags=["Room Realtime Commands"])


def client_room_snapshot(db: Session, room: Room, *, include_chat: bool = True) -> dict[str, Any]:
    snapshot = room_state_service.room_snapshot(db, room, include_chat=include_chat)
    snapshot.pop("internal_participants", None)
    snapshot.pop("internal_online_count", None)
    snapshot.pop("internal_active_participant_count", None)
    return snapshot


def room_or_404(db: Session, room_public_id: str, *, for_update: bool = False) -> Room:
    query = db.query(Room).filter(Room.room_public_id == room_public_id)
    if for_update:
        query = query.with_for_update()
    room = query.first()
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    return room


def _identity_candidates(raw: Any) -> list[int]:
    value = str(raw or "").strip()
    if not value:
        return []
    result: list[int] = []
    if value.isdigit():
        result.append(int(value))
    match = re.search(r"(?:^|_)user_(\d+)$", value)
    if match:
        result.append(int(match.group(1)))
    return list(dict.fromkeys(result))


def resolve_target_user(db: Session, payload: dict[str, Any]) -> User | None:
    for key in ("target_backend_user_id", "target_user_id", "target_public_user_id", "target_peer_id"):
        for candidate in _identity_candidates(payload.get(key)):
            user = db.query(User).filter(User.id == candidate).first()
            if user is not None:
                return user
            user = db.query(User).filter(User.public_user_id == candidate).first()
            if user is not None:
                return user
            user = db.query(User).filter(User.display_custom_id == candidate).first()
            if user is not None:
                return user
    return None


def _int(payload: dict[str, Any], key: str, default: int = -1) -> int:
    try:
        return int(payload.get(key) if payload.get(key) is not None else default)
    except (TypeError, ValueError):
        return default


def _bool(payload: dict[str, Any], key: str, default: bool = False) -> bool:
    value = payload.get(key)
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def _room_user_key(user: User | None) -> str:
    return f"user_{user.public_user_id}" if user is not None else ""


def _display_name(user: User | None, fallback: str = "Vibe User") -> str:
    if user is None:
        return fallback
    return user.display_name or user.username or str(user.public_user_id)


def _event(event_type: str, room: Room, snapshot: dict[str, Any], extra: dict[str, Any] | None = None) -> dict[str, Any]:
    payload: dict[str, Any] = {"room_id": room.room_public_id, "room": snapshot}
    if extra:
        payload.update(extra)
    return {"type": event_type, "payload": payload}


def _system_event(room: Room, event_type: str, message: str, actor: User | None = None, target: User | None = None, seat_index: int | None = None) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "id": f"{event_type}_{room.room_public_id}_{uuid4().hex}",
        "event_type": event_type,
        "type": event_type,
        "room_id": room.room_public_id,
        "actor_user_id": _room_user_key(actor),
        "actor_backend_user_id": actor.id if actor else None,
        "actor_public_user_id": actor.public_user_id if actor else None,
        "actor_name": _display_name(actor, "System"),
        "actor_avatar_url": actor.avatar_url if actor else None,
        "target_user_id": _room_user_key(target),
        "target_backend_user_id": target.id if target else None,
        "target_public_user_id": target.public_user_id if target else None,
        "target_name": _display_name(target, "") if target else "",
        "message": message,
        "created_at": datetime.utcnow().isoformat(),
        "auto_dismiss_seconds": 10,
    }
    if seat_index is not None:
        payload["seat_index"] = seat_index
    return {"type": "room/system_event", "payload": payload}


@dataclass(frozen=True)
class RoomCommandEmission:
    target: str
    room_id: str
    message: dict[str, Any]
    user_id: int | None = None


@dataclass(frozen=True)
class RoomCommandOutcome:
    snapshot: dict[str, Any]
    emissions: list[RoomCommandEmission]


def _finish(
    db: Session,
    room: Room,
    emissions: list[RoomCommandEmission],
    event_type: str,
    *,
    extra: dict[str, Any] | None = None,
    include_chat: bool = True,
) -> dict[str, Any]:
    db.commit()
    db.refresh(room)
    snapshot = client_room_snapshot(db, room, include_chat=include_chat)
    db.commit()
    emissions.append(
        RoomCommandEmission(
            target="room",
            room_id=room.room_public_id,
            message=_event(event_type, room, snapshot, extra),
        )
    )
    return snapshot

def _set_room_admin(db: Session, room: Room, actor: User, target: User, enabled: bool) -> None:
    if not policy_permissions.can_manage_room_admins(db, actor, room.owner_user_id):
        raise HTTPException(status_code=403, detail="Only the channel owner or authorized staff can manage room admins")
    if target.id == room.owner_user_id and not enabled:
        raise HTTPException(status_code=400, detail="Channel owner admin status cannot be removed")
    participant = (
        db.query(RoomParticipant)
        .filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == target.id)
        .first()
    )
    if participant is None:
        participant = RoomParticipant(room_id=room.id, user_id=target.id, is_active=False)
        db.add(participant)
    participant.is_room_admin = enabled
    if enabled:
        participant.is_member = True
        participant.admin_added_at = participant.admin_added_at or datetime.utcnow()
    room_action_service.record_room_event(
        db,
        room,
        "room.admin.updated",
        actor_user_id=actor.id,
        target_user_id=target.id,
        payload={"is_room_admin": enabled},
    )


def _remove_kick_for_target(db: Session, room: Room, actor: User, target: User) -> bool:
    room_permission_service.require_room_admin(db, room, actor)
    rows = (
        db.query(RoomKickout)
        .filter(
            RoomKickout.room_public_id == room.room_public_id,
            RoomKickout.is_active.is_(True),
            ((RoomKickout.target_user_id == target.id) | (RoomKickout.target_public_user_id == str(target.public_user_id))),
        )
        .all()
    )
    for item in rows:
        item.is_active = False
        item.updated_at = datetime.utcnow()
    if rows:
        room_action_service.record_room_event(
            db,
            room,
            "room.kickout.removed",
            actor_user_id=actor.id,
            target_user_id=target.id,
        )
    return bool(rows)


def _server_profile_payload(db: Session, room: Room, user: User, snapshot: dict[str, Any]) -> dict[str, Any]:
    state = get_user_master_state(db, user)
    vip = state.get("vip") if isinstance(state.get("vip"), dict) else {}
    exp = state.get("experience") if isinstance(state.get("experience"), dict) else {}
    roles = state.get("roles") if isinstance(state.get("roles"), dict) else {}
    badge = roles.get("primary_role_badge") if isinstance(roles.get("primary_role_badge"), dict) else {}
    participant = next(
        (
            item
            for item in snapshot.get("participants", [])
            if isinstance(item, dict) and int(item.get("backend_user_id") or 0) == user.id
        ),
        None,
    )
    is_host = user.id == room.owner_user_id
    is_admin = bool(participant and participant.get("is_room_admin")) or is_host
    role_label = "Channel Host" if is_host else ("Admin" if is_admin else str(badge.get("badge_label") or "Member"))
    return {
        "room_id": room.room_public_id,
        "room": snapshot,
        "user_id": _room_user_key(user),
        "backend_user_id": user.id,
        "public_user_id": user.public_user_id,
        "display_name": _display_name(user),
        "avatar_url": user.avatar_url,
        "is_host": is_host,
        "is_room_admin": is_admin,
        "role_label": role_label,
        "vip_level": int(vip.get("vip_level") or 0),
        "svip_level": int(vip.get("svip_level") or 0),
        "sending_level": int(exp.get("sent_level") or 0),
        "receiving_level": int(exp.get("received_level") or 0),
    }


def _execute_room_command_in_session(
    db: Session,
    room: Room,
    actor: User,
    event_type: str,
    payload: dict[str, Any],
    emissions: list[RoomCommandEmission],
) -> dict[str, Any]:
    """Apply one authenticated room command and collect post-commit emissions."""
    room = db.query(Room).filter(Room.id == room.id).with_for_update().one()

    if event_type not in {"room/join", "room/leave"}:
        room_action_service.reconcile_authenticated_room_presence(
            db,
            room,
            actor,
        )

    if event_type == "room/join":
        room_action_service.join_room(db, room, actor, payload)
        return _finish(db, room, emissions, "room/joined")

    if event_type == "room/leave":
        room_action_service.leave_room(db, room, actor, release_seat=_bool(payload, "release_seat", True))
        return _finish(db, room, emissions, "room/peer_left")

    if event_type == "seat/take":
        room_permission_service.require_seat_take(db, room, actor, actor)
        room_action_service.take_or_request_seat(
            db,
            room,
            actor,
            _int(payload, "seat_index"),
            mic_enabled=_bool(payload, "mic_enabled", False),
        )
        return _finish(db, room, emissions, "seat/updated")

    if event_type == "seat/leave":
        room_permission_service.require_seat_take(db, room, actor, actor)
        room_action_service.leave_seat(db, room, actor)
        return _finish(db, room, emissions, "seat/updated")

    if event_type == "seat_invite/send":
        room_permission_service.require_room_admin(db, room, actor)
        target = resolve_target_user(db, payload)
        if target is None:
            raise HTTPException(status_code=404, detail="Seat invite target not found")
        seat_index = _int(payload, "seat_index")
        previous = room_action_service.latest_seat_invite_id(db, room, actor, target, seat_index)
        room_action_service.send_seat_invite(db, room, actor, target, seat_index)
        next_id = room_action_service.latest_seat_invite_id(db, room, actor, target, seat_index)
        snapshot = _finish(db, room, emissions, "seat_invite/sent", extra={"target_user_id": target.id, "seat_index": seat_index})
        if next_id != previous:
            invite_id = f"seat_invite_{room.room_public_id}_{actor.id}_{target.id}_{seat_index}_{uuid4().hex}"
            emissions.append(
                RoomCommandEmission(
                    target="user",
                    room_id=room.room_public_id,
                    user_id=target.id,
                    message={
                        "type": "seat_invite/received",
                        "payload": {
                            "id": invite_id,
                            "invite_id": invite_id,
                            "room_id": room.room_public_id,
                            "seat_index": seat_index,
                            "room": snapshot,
                            "inviter_user_id": _room_user_key(actor),
                            "inviter_backend_user_id": actor.id,
                            "inviter_public_user_id": actor.public_user_id,
                            "inviter_name": _display_name(actor),
                            "inviter_avatar_url": actor.avatar_url,
                        },
                    },
                )
            )
        return snapshot

    if event_type in {"seat_invite/accept", "seat_invite/reject"}:
        seat_index = _int(payload, "seat_index")
        if event_type.endswith("accept"):
            room_action_service.accept_seat_invite(db, room, actor, seat_index)
            return _finish(db, room, emissions, "seat/updated")
        room_action_service.reject_seat_invite(db, room, actor, seat_index)
        return _finish(db, room, emissions, "seat_invite/rejected", extra={"seat_index": seat_index})

    if event_type == "seat_application/request":
        room_permission_service.require_join(db, room, actor)
        seat_index = _int(payload, "seat_index")
        room_action_service.take_or_request_seat(db, room, actor, seat_index)
        return _finish(db, room, emissions, "seat_application/requested", extra={"applicant_user_id": actor.id, "seat_index": seat_index})

    if event_type == "seat_application/reject":
        room_permission_service.require_room_admin(db, room, actor)
        target = resolve_target_user(db, payload)
        if target is None:
            raise HTTPException(status_code=404, detail="Seat applicant not found")
        seat_index = _int(payload, "seat_index")
        room_action_service.reject_seat_application(db, room, actor, target, seat_index)
        return _finish(db, room, emissions, "seat_application/rejected", extra={"target_user_id": target.id, "seat_index": seat_index})

    if event_type == "admin/seat_assign":
        room_permission_service.require_room_admin(db, room, actor)
        target = resolve_target_user(db, payload)
        if target is None:
            raise HTTPException(status_code=404, detail="Seat target not found")
        room_action_service.assign_seat(db, room, actor, target, _int(payload, "seat_index"))
        return _finish(db, room, emissions, "seat/updated")

    if event_type in {"admin/seat_leave", "admin/seat_leave_lock"}:
        room_permission_service.require_room_admin(db, room, actor)
        target = resolve_target_user(db, payload)
        if target is None:
            raise HTTPException(status_code=404, detail="Seat target not found")
        seat_index = _int(payload, "seat_index")
        room_action_service.leave_seat(db, room, target, actor_user_id=actor.id)
        if event_type.endswith("leave_lock"):
            room_action_service.lock_seat(db, room, seat_index, True, actor_user_id=actor.id)
        return _finish(db, room, emissions, "seat/updated")

    if event_type in {"admin/seat_lock", "admin/seat_unlock"}:
        room_permission_service.require_room_admin(db, room, actor)
        room_action_service.lock_seat(
            db,
            room,
            _int(payload, "seat_index"),
            event_type.endswith("lock") and not event_type.endswith("unlock"),
            actor_user_id=actor.id,
        )
        return _finish(db, room, emissions, "seat/updated")

    if event_type == "mic/set_enabled":
        room_permission_service.require_mic_change(db, room, actor)
        room_action_service.set_mic_enabled(db, room, actor, _bool(payload, "enabled"))
        return _finish(db, room, emissions, "seat/updated")

    if event_type == "admin_mute/set":
        target = resolve_target_user(db, payload)
        room_permission_service.require_admin_mute(db, room, actor, target)
        if target is None:
            raise HTTPException(status_code=404, detail="Mute target not found")
        muted = _bool(payload, "muted")
        room_action_service.set_admin_mute(db, room, target.id, muted, actor_user_id=actor.id)
        return _finish(db, room, emissions, "admin_mute/updated", extra={"target_user_id": target.id, "user_id": _room_user_key(target), "admin_muted": muted})

    if event_type == "admin/kick":
        target = resolve_target_user(db, payload)
        if target is None:
            raise HTTPException(status_code=404, detail="Kick target not found")
        reason = str(payload.get("reason") or "Removed by room admin")
        duration = str(payload.get("duration") or "1h")
        room_action_service.kick_user(db, room, actor, target, reason=reason, duration=duration)
        snapshot = _finish(db, room, emissions, "room/peer_left", extra={"target_user_id": target.id})
        emissions.append(
            RoomCommandEmission(
                target="user",
                room_id=room.room_public_id,
                user_id=target.id,
                message={"type": "room/kicked", "payload": {"room_id": room.room_public_id, "room": snapshot, "reason": reason, "duration": duration, "target_user_id": _room_user_key(target), "target_backend_user_id": target.id, "target_public_user_id": target.public_user_id}},
            )
        )
        emissions.append(RoomCommandEmission(target="room", room_id=room.room_public_id, message=_system_event(room, "user_removed", f"{_display_name(target)} was removed from the room", actor=actor, target=target)))
        return snapshot

    if event_type == "admin/kick_remove":
        target = resolve_target_user(db, payload)
        if target is None:
            raise HTTPException(status_code=404, detail="Kick target not found")
        removed = _remove_kick_for_target(db, room, actor, target)
        return _finish(db, room, emissions, "kick_block/remove_result", extra={"removed": removed, "target_user_id": _room_user_key(target), "target_backend_user_id": target.id})

    if event_type in {"room_member/request", "room_member/approve", "room_member/reject", "room_member/remove"}:
        if event_type == "room_member/request":
            room_action_service.request_room_membership(db, room, actor)
            return _finish(db, room, emissions, "room_member/request_updated", extra={"request_user_id": actor.id})
        room_permission_service.require_room_admin(db, room, actor)
        target = resolve_target_user(db, payload)
        if target is None:
            raise HTTPException(status_code=404, detail="Room member target not found")
        if event_type.endswith("approve"):
            room_action_service.approve_room_membership(db, room, actor, target)
            decision = "approved"
        elif event_type.endswith("reject"):
            room_action_service.reject_room_membership(db, room, actor, target)
            decision = "rejected"
        else:
            room_action_service.remove_room_member(db, room, actor, target)
            decision = "removed"
        return _finish(db, room, emissions, "room_member/request_updated", extra={"target_user_id": target.id, "decision": decision})

    if event_type == "room_admin/set":
        target = resolve_target_user(db, payload)
        if target is None:
            raise HTTPException(status_code=404, detail="Room admin target not found")
        enabled = _bool(payload, "is_room_admin")
        _set_room_admin(db, room, actor, target, enabled)
        return _finish(db, room, emissions, "room_admin/updated", extra={"target_user_id": _room_user_key(target), "target_backend_user_id": target.id, "target_name": _display_name(target), "is_room_admin": enabled})

    if event_type == "room_settings/seat_layout":
        room_permission_service.require_room_settings(db, room, actor)
        room_action_service.set_seat_layout(db, room, str(payload.get("seat_layout_id") or "5x2"), actor_user_id=actor.id)
        return _finish(db, room, emissions, "room_settings/updated")

    if event_type == "room_settings/background_theme":
        room_permission_service.require_room_settings(db, room, actor)
        room_action_service.set_background_theme(db, room, str(payload.get("background_theme_id") or "default"), actor_user_id=actor.id)
        return _finish(db, room, emissions, "room_settings/updated")

    if event_type == "room_settings/privacy":
        room_action_service.set_room_privacy(db, room, actor, str(payload.get("mode") or payload.get("privacy_mode") or "Open"))
        return _finish(db, room, emissions, "room_settings/updated")

    if event_type == "room_settings/screenshots":
        room_action_service.set_room_screenshots(db, room, actor, _bool(payload, "allow_screenshots", True))
        return _finish(db, room, emissions, "room_settings/updated")

    if event_type in {"room_settings/images", "room_settings/guest_messages", "room_settings/apply_mode"}:
        if event_type.endswith("images"):
            enabled = _bool(payload, "room_images_enabled", _bool(payload, "enabled", True))
            room_action_service.set_room_images_enabled(db, room, actor, enabled)
            label = "image messages"
        elif event_type.endswith("guest_messages"):
            enabled = _bool(payload, "guest_messages_enabled", _bool(payload, "enabled", True))
            room_action_service.set_guest_messages_enabled(db, room, actor, enabled)
            label = "guest messages"
        else:
            enabled = _bool(payload, "apply_only_mode_enabled", _bool(payload, "enabled", False))
            room_action_service.set_apply_only_mode_enabled(db, room, actor, enabled)
            label = "apply-only seat mode"
        snapshot = _finish(db, room, emissions, "room_settings/updated")
        emissions.append(RoomCommandEmission(target="room", room_id=room.room_public_id, message=_system_event(room, "room_system_message", f"{_display_name(actor)} turned {label} {'on' if enabled else 'off'}", actor=actor)))
        return snapshot

    if event_type == "room_settings/announcement":
        room_action_service.set_announcement(db, room, actor, str(payload.get("announcement_text") or ""))
        return _finish(db, room, emissions, "room_settings/updated")

    if event_type in {"room_chat/send", "room/chat"}:
        room_permission_service.require_chat_send(db, room, actor)
        text = str(payload.get("text") or "").strip()
        if not text:
            raise HTTPException(status_code=400, detail="Message cannot be empty")
        room_action_service.create_chat_message(db, room, actor, text, message_type=str(payload.get("message_type") or "text"), metadata=payload)
        return _finish(db, room, emissions, "room.chat.message_created")

    if event_type == "room/chat_clear":
        room_permission_service.require_room_admin(db, room, actor)
        db.query(RoomChatMessage).filter(RoomChatMessage.room_id == room.id, RoomChatMessage.is_deleted.is_(False)).update({RoomChatMessage.is_deleted: True}, synchronize_session=False)
        room_action_service.record_room_event(db, room, "room.chat.cleared", actor_user_id=actor.id)
        snapshot = _finish(db, room, emissions, "room/chat_cleared")
        emissions.append(RoomCommandEmission(target="room", room_id=room.room_public_id, message=_system_event(room, "room_system_message", f"{_display_name(actor)} cleared the room chat", actor=actor)))
        return snapshot

    if event_type == "room/system_message":
        room_permission_service.require_room_admin(db, room, actor)
        message = str(payload.get("message") or "").strip()
        if not message:
            raise HTTPException(status_code=400, detail="System message cannot be empty")
        room_action_service.record_room_event(db, room, "room.system_message", actor_user_id=actor.id, payload={"message": message})
        snapshot = _finish(db, room, emissions, "room.snapshot")
        emissions.append(RoomCommandEmission(target="room", room_id=room.room_public_id, message=_system_event(room, "room_system_message", message, actor=actor)))
        return snapshot

    if event_type == "profile/update":
        room_permission_service.require_join(db, room, actor)
        room_action_service.record_room_event(db, room, "room.profile.refreshed", actor_user_id=actor.id)
        db.commit()
        snapshot = client_room_snapshot(db, room)
        db.commit()
        emissions.append(RoomCommandEmission(target="room", room_id=room.room_public_id, message={"type": "profile/updated", "payload": _server_profile_payload(db, room, actor, snapshot)}))
        return snapshot

    if event_type in {"room_cricket/start", "room_cricket/end"}:
        room_permission_service.require_room_admin(db, room, actor)
        active = event_type.endswith("start")
        state_payload = {
            "active": active,
            "setup": payload.get("setup") if active else None,
            "background_theme_id": str(payload.get("background_theme_id") or ("cricket_floodlight_arena" if active else "default")),
        }
        room_action_service.record_room_event(db, room, "room.cricket.started" if active else "room.cricket.ended", actor_user_id=actor.id, payload=state_payload)
        snapshot = _finish(db, room, emissions, "room.snapshot")
        emissions.append(RoomCommandEmission(target="room", room_id=room.room_public_id, message={"type": "room_cricket/state", "payload": {"room_id": room.room_public_id, "room": snapshot, "actor_user_id": _room_user_key(actor), "actor_name": _display_name(actor), **state_payload}}))
        return snapshot

    raise HTTPException(status_code=400, detail=f"Unsupported room command: {event_type}")



def _execute_room_command_transaction(
    room_public_id: str,
    actor_user_id: int,
    event_type: str,
    payload: dict[str, Any],
) -> RoomCommandOutcome:
    emissions: list[RoomCommandEmission] = []
    with SessionLocal() as db:
        try:
            actor = db.query(User).filter(User.id == actor_user_id).first()
            if actor is None or actor.is_banned or not actor.is_active:
                raise HTTPException(status_code=401, detail="Room session is no longer valid")
            room = room_or_404(db, room_public_id)
            snapshot = _execute_room_command_in_session(db, room, actor, event_type, payload, emissions)
            return RoomCommandOutcome(snapshot=snapshot, emissions=emissions)
        except Exception:
            db.rollback()
            raise


async def _emit_room_command(outcome: RoomCommandOutcome) -> None:
    for emission in outcome.emissions:
        if emission.target == "user":
            if emission.user_id is None:
                continue
            await room_realtime_connections.send_room_user(emission.room_id, emission.user_id, emission.message)
        else:
            await room_realtime_connections.broadcast_room(emission.room_id, emission.message)


async def execute_room_command_by_ids(
    room_public_id: str,
    actor_user_id: int,
    event_type: str,
    payload: dict[str, Any],
) -> dict[str, Any]:
    outcome = await asyncio.to_thread(
        _execute_room_command_transaction,
        room_public_id,
        actor_user_id,
        event_type,
        payload,
    )
    await _emit_room_command(outcome)
    return outcome.snapshot


async def execute_room_command(
    db: Session,
    room: Room,
    actor: User,
    event_type: str,
    payload: dict[str, Any],
) -> dict[str, Any]:
    """Compatibility wrapper; DB work runs in an isolated worker session."""
    del db
    return await execute_room_command_by_ids(str(room.room_public_id), int(actor.id), event_type, payload)


@router.get("/snapshot")
def snapshot(room_public_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = room_or_404(db, room_public_id)
    room_permission_service.require_room_view(db, room, current_user)
    data = client_room_snapshot(db, room)
    db.commit()
    return {"room_id": room_public_id, "room": data}


@router.post("/join")
async def join(room_public_id: str, command: RoomJoinCommand, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = room_or_404(db, room_public_id)
    data = await execute_room_command(db, room, current_user, "room/join", command.model_dump())
    return {"room_id": room_public_id, "room": data}


@router.post("/heartbeat")
def heartbeat(
    room_public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Refresh durable presence and return one canonical room snapshot."""
    room = room_or_404(db, room_public_id, for_update=True)
    try:
        room_permission_service.require_room_view(db, room, current_user)
        data = room_action_service.heartbeat_room(db, room, current_user)
        db.commit()
        return {"room_id": room_public_id, "room": data}
    except Exception:
        db.rollback()
        raise


@router.post("/leave")
async def leave(room_public_id: str, command: RoomLeaveCommand, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = room_or_404(db, room_public_id)
    data = await execute_room_command(db, room, current_user, "room/leave", {"release_seat": command.release_seat})
    return {"room_id": room_public_id, "room": data}


@router.post("/seat/take")
async def take_seat(room_public_id: str, command: RoomSeatTakeCommand, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = room_or_404(db, room_public_id)
    data = await execute_room_command(db, room, current_user, "seat/take", {"seat_index": command.seat_index})
    return {"room_id": room_public_id, "room": data}


@router.post("/seat/leave")
async def leave_seat(room_public_id: str, command: RoomSeatLeaveCommand, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = room_or_404(db, room_public_id)
    data = await execute_room_command(db, room, current_user, "seat/leave", {})
    return {"room_id": room_public_id, "room": data}


@router.post("/seat/lock")
async def lock_seat(room_public_id: str, command: RoomSeatLockCommand, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = room_or_404(db, room_public_id)
    event = "admin/seat_lock" if command.locked else "admin/seat_unlock"
    data = await execute_room_command(db, room, current_user, event, {"seat_index": command.seat_index})
    return {"room_id": room_public_id, "room": data}


@router.post("/mic")
async def set_mic(room_public_id: str, command: RoomMicCommand, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = room_or_404(db, room_public_id)
    data = await execute_room_command(db, room, current_user, "mic/set_enabled", {"enabled": command.enabled})
    return {"room_id": room_public_id, "room": data}


@router.post("/admin-mute")
async def admin_mute(room_public_id: str, command: RoomAdminMuteCommand, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = room_or_404(db, room_public_id)
    data = await execute_room_command(db, room, current_user, "admin_mute/set", {"target_backend_user_id": command.target_user_id, "muted": command.muted})
    return {"room_id": room_public_id, "room": data}


@router.post("/settings/seat-layout")
async def seat_layout(room_public_id: str, command: RoomSeatLayoutCommand, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = room_or_404(db, room_public_id)
    data = await execute_room_command(db, room, current_user, "room_settings/seat_layout", {"seat_layout_id": command.seat_layout_id})
    return {"room_id": room_public_id, "room": data}


@router.post("/settings/background-theme")
async def background_theme(room_public_id: str, command: RoomBackgroundThemeCommand, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = room_or_404(db, room_public_id)
    data = await execute_room_command(db, room, current_user, "room_settings/background_theme", {"background_theme_id": command.background_theme_id})
    return {"room_id": room_public_id, "room": data}


@router.post("/chat/send")
async def chat_send(room_public_id: str, command: RoomChatSendCommand, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = room_or_404(db, room_public_id)
    data = await execute_room_command(db, room, current_user, "room_chat/send", {"text": command.text, "message_type": command.message_type})
    return {"room_id": room_public_id, "room": data}
