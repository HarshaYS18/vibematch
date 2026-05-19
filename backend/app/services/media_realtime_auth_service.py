from sqlalchemy.orm import Session

from app.models.room import Room
from app.models.user import User
from app.services import role_service

MEDIA_REALTIME_ACTIONS = {
    "join_room",
    "create_transport",
    "connect_transport",
    "produce_audio",
    "consume_audio",
    "pause_producer",
    "resume_producer",
    "close_producer",
    "leave_room",
    "join_seat",
    "leave_seat",
}


def _role_values(user: User) -> list[str]:
    return [role.value for role in role_service.get_user_roles(user)]


def _primary_role_value(user: User) -> str:
    return role_service.get_primary_role(user).value


def _room_lookup(db: Session, room_public_id: str | None) -> Room | None:
    clean = (room_public_id or "").strip()
    if not clean:
        return None
    return db.query(Room).filter(Room.public_id == clean).first()


def _permission_set(action: str) -> list[str]:
    base = ["AUTHENTICATED_MEDIA_SOCKET"]
    if action in {"join_room", "consume_audio"}:
        base.append("ROOM_ACCESS_REQUIRED")
    if action in {"produce_audio", "join_seat"}:
        base.append("MIC_OR_SEAT_PERMISSION_REQUIRED")
    if action in {"pause_producer", "resume_producer", "close_producer"}:
        base.append("PRODUCER_OWNER_REQUIRED")
    return base


def verify_media_realtime_request(
    *,
    db: Session,
    user: User,
    room_public_id: str | None,
    requested_action: str,
    device_id: str | None = None,
) -> dict:
    """Single backend source of truth for mediasoup/signaling authorization.

    The external mediasoup signaling server must call this endpoint after JWT
    verification and before allowing room join, transport creation, produce,
    consume, or seat actions. This service intentionally never trusts user_id,
    roles, or room permissions from the client payload.
    """
    action = (requested_action or "join_room").strip().lower()
    if action not in MEDIA_REALTIME_ACTIONS:
        return _payload(
            allowed=False,
            reason="Unsupported media realtime action.",
            user=user,
            room_public_id=room_public_id,
            requested_action=action,
            permissions=[],
            room=None,
            device_id=device_id,
        )

    if not user.is_active:
        return _payload(
            allowed=False,
            reason="User is inactive.",
            user=user,
            room_public_id=room_public_id,
            requested_action=action,
            permissions=[],
            room=None,
            device_id=device_id,
        )
    if user.is_banned:
        return _payload(
            allowed=False,
            reason="User is banned.",
            user=user,
            room_public_id=room_public_id,
            requested_action=action,
            permissions=[],
            room=None,
            device_id=device_id,
        )

    room = _room_lookup(db, room_public_id)
    if room_public_id and room is None:
        return _payload(
            allowed=False,
            reason="Room not found.",
            user=user,
            room_public_id=room_public_id,
            requested_action=action,
            permissions=[],
            room=None,
            device_id=device_id,
        )

    # This foundation is intentionally conservative. Detailed locked-room,
    # Secret Vibe, kickout, mute, seat, and hidden-presence checks should be
    # delegated to the central room permission service when the mediasoup server
    # is moved into this repo or connected to this endpoint.
    permissions = _permission_set(action)
    return _payload(
        allowed=True,
        reason=None,
        user=user,
        room_public_id=room_public_id,
        requested_action=action,
        permissions=permissions,
        room=room,
        device_id=device_id,
    )


def _payload(
    *,
    allowed: bool,
    reason: str | None,
    user: User,
    room_public_id: str | None,
    requested_action: str,
    permissions: list[str],
    room: Room | None,
    device_id: str | None,
) -> dict:
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
        "permissions": permissions,
        "mediasoup_context": {
            "room_public_id": getattr(room, "public_id", room_public_id),
            "room_name": getattr(room, "name", None),
            "device_id_present": bool((device_id or "").strip()),
            "must_ignore_client_user_id": True,
            "must_ignore_client_roles": True,
            "server_verified_identity": True,
        },
    }
