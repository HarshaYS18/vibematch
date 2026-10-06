from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.call_session import CallSession, CallParticipant, CallSessionStatus, CallParticipantStatus
from app.services import ban_service, role_service, room_control_service_client

MEDIA_REALTIME_ACTIONS = {
    "join_room",
    "create_transport",
    "connect_transport",
    "produce_audio",
    "produce_video",
    "consume_audio",
    "pause_producer",
    "resume_producer",
    "close_producer",
    "leave_room",
    "join_seat",
    "leave_seat",
    "start_room_music",
    "stop_room_music",
}

_MEDIA_ACTIONS_REQUIRING_ROOM = {
    "join_room",
    "create_transport",
    "connect_transport",
    "produce_audio",
    "consume_audio",
    "pause_producer",
    "resume_producer",
    "close_producer",
    "join_seat",
    "leave_seat",
    "start_room_music",
    "stop_room_music",
}


def _role_values(user: User) -> list[str]:
    return [role.value for role in role_service.get_user_roles(user)]


def _primary_role_value(user: User) -> str:
    return role_service.get_primary_role(user).value


def _permission_set(action: str) -> list[str]:
    base = ["AUTHENTICATED_MEDIA_SOCKET"]
    if action in {"join_room", "consume_audio"}:
        base.append("ROOM_ACCESS_REQUIRED")
    if action in {"produce_audio", "join_seat"}:
        base.append("MIC_OR_SEAT_PERMISSION_REQUIRED")
    if action in {"pause_producer", "resume_producer", "close_producer"}:
        base.append("PRODUCER_OWNER_REQUIRED")
    if action in {"start_room_music", "stop_room_music"}:
        base.append("ROOM_MUSIC_CONTROL_REQUIRED")
    return base


def verify_media_realtime_request(
    *,
    db: Session,
    user: User,
    room_public_id: str | None,
    requested_action: str,
    device_id: str | None = None,
    has_active_room_connection: bool = False,
) -> dict:
    action = (requested_action or "join_room").strip().lower()
    if action not in MEDIA_REALTIME_ACTIONS:
        return _payload(False, "Unsupported media realtime action.", user, room_public_id, action, [], None, device_id)
    if not user.is_active:
        return _payload(False, "User is inactive.", user, room_public_id, action, [], None, device_id)
    if user.is_banned:
        return _payload(False, "User is banned.", user, room_public_id, action, [], None, device_id)
    if ban_service.is_device_banned(db, device_id):
        return _payload(False, "Device is banned.", user, room_public_id, action, [], None, device_id)

    clean_room_id = str(room_public_id or "").strip()
    if clean_room_id.startswith("call_room_"):
        call = db.query(CallSession).filter(CallSession.room_public_id == clean_room_id).first()
        participant = None if call is None else db.query(CallParticipant).filter(
            CallParticipant.call_session_id == call.id,
            CallParticipant.user_id == user.id,
        ).first()
        allowed = bool(
            call is not None
            and call.status in {CallSessionStatus.RINGING, CallSessionStatus.CONNECTING, CallSessionStatus.ACTIVE}
            and participant is not None
            and participant.status == CallParticipantStatus.JOINED
            and action not in {"start_room_music", "stop_room_music", "join_seat", "leave_seat"}
            and (action != "produce_video" or call.is_video_enabled)
        )
        return _payload(allowed, None if allowed else "Active call participation required.", user, clean_room_id, action, ["CALL_PARTICIPANT_REQUIRED"], None, device_id)

    if action == "produce_video":
        return _payload(False, "Video publishing is only supported in video calls.", user, room_public_id, action, [], None, device_id)
    if action in _MEDIA_ACTIONS_REQUIRING_ROOM and not clean_room_id:
        return _payload(False, "room_public_id is required for this media action.", user, room_public_id, action, [], None, device_id)

    permissions = _permission_set(action)
    permission_context: dict[str, Any] = {}
    room_context: dict[str, Any] | None = None
    if clean_room_id:
        try:
            decision = room_control_service_client.authorize_room_action(
                user_id=user.id,
                room_public_id=clean_room_id,
                action=action,
                device_id=device_id,
                has_active_room_connection=has_active_room_connection,
                evaluate_permissions=action in _MEDIA_ACTIONS_REQUIRING_ROOM,
            )
        except room_control_service_client.RoomControlServiceUnavailable as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        except room_control_service_client.RoomControlServiceError as exc:
            return _payload(False, exc.detail, user, clean_room_id, action, [], None, device_id)
        raw_room = decision.get("room")
        room_context = dict(raw_room) if isinstance(raw_room, dict) else None
        permission_context = dict(decision.get("permission_context") or {})
        if action in _MEDIA_ACTIONS_REQUIRING_ROOM and not decision.get("allowed", False):
            return _payload(
                False,
                str(decision.get("reason") or "Room access denied"),
                user,
                clean_room_id,
                action,
                list(decision.get("permissions") or []),
                room_context,
                device_id,
                permission_context,
            )
        permissions.extend(list(decision.get("permissions") or []))

    return _payload(True, None, user, room_public_id, action, permissions, room_context, device_id, permission_context)


def _payload(
    allowed: bool,
    reason: str | None,
    user: User,
    room_public_id: str | None,
    requested_action: str,
    permissions: list[str],
    room: dict[str, Any] | None,
    device_id: str | None,
    permission_context: dict | None = None,
) -> dict:
    room_context = room or {}
    return {
        "allowed": allowed,
        "reason": reason,
        "user": {
            "user_id": user.id,
            "public_user_id": user.public_user_id,
            "username": user.username,
            "display_name": user.display_name,
            "avatar_url": user.avatar_url,
            "roles": _role_values(user),
            "primary_role": _primary_role_value(user),
            "is_active": user.is_active,
            "is_banned": user.is_banned,
        },
        "room_public_id": room_public_id,
        "requested_action": requested_action,
        "permissions": list(dict.fromkeys(permissions)),
        "mediasoup_context": {
            "room_public_id": room_context.get("room_public_id", room_public_id),
            "room_name": room_context.get("room_name"),
            "room_is_secret": bool(room_context.get("is_secret", False)),
            "room_is_locked": bool(room_context.get("is_locked", False)),
            "room_is_members_only": bool(room_context.get("is_members_only", False)),
            "room_apply_only_mode_enabled": bool(room_context.get("apply_only_mode_enabled", False)),
            "device_id_present": bool((device_id or "").strip()),
            "permission_context": permission_context or {},
            "must_ignore_client_user_id": True,
            "must_ignore_client_roles": True,
            "server_verified_identity": True,
        },
    }
