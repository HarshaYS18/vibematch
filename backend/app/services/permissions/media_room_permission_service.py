from dataclasses import dataclass, field
from datetime import datetime

from sqlalchemy.orm import Session

from app.models.role import RoleName
from app.models.room import Room
from app.models.room_kickout import RoomKickout
from app.models.room_participant import RoomParticipant
from app.models.room_realtime_state import RoomSeatState
from app.models.user import User
from app.services import role_service


STAFF_ROOM_OVERRIDE_ROLES = {
    RoleName.FOUNDER_OWNER,
    RoleName.OWNER,
    RoleName.SUPERADMIN,
}

ROOM_MODERATION_ROLES = {
    RoleName.FOUNDER_OWNER,
    RoleName.OWNER,
    RoleName.SUPERADMIN,
    RoleName.ADMIN,
    RoleName.MONITOR,
}

ROOM_PRODUCE_ACTIONS = {"produce_audio", "join_seat"}
ROOM_CONSUME_ACTIONS = {"consume_audio", "join_room", "create_transport", "connect_transport"}
ROOM_PRODUCER_OWNER_ACTIONS = {"pause_producer", "resume_producer", "close_producer"}


@dataclass(frozen=True)
class MediaRoomPermissionDecision:
    allowed: bool
    reason: str | None = None
    permissions: list[str] = field(default_factory=list)
    context: dict = field(default_factory=dict)


def evaluate_media_room_permission(
    *,
    db: Session,
    user: User,
    room: Room | None,
    action: str,
    device_id: str | None = None,
) -> MediaRoomPermissionDecision:
    """Central room/media permission resolver for realtime audio actions.

    This resolver is intentionally backend-only and is safe for mediasoup
    signaling servers to call through `/media-realtime/verify`. It does not
    trust user/role/room data coming from clients.
    """
    if room is None:
        return MediaRoomPermissionDecision(
            allowed=False,
            reason="Room is required for this media action.",
            permissions=[],
            context={"room_required": True},
        )

    role = role_service.get_primary_role(user)
    is_owner = room.owner_user_id == user.id
    participant = _active_participant(db, room.id, user.id)
    is_room_admin = bool(participant and participant.is_room_admin)
    is_member = bool(participant and participant.is_member)
    is_staff_override = role in STAFF_ROOM_OVERRIDE_ROLES
    is_moderation_staff = role in ROOM_MODERATION_ROLES
    active_kickout = _active_kickout(db, room.room_public_id, user)
    seat_state = _occupied_seat(db, room.id, user.id)

    context = {
        "role": role.value,
        "is_room_owner": is_owner,
        "is_room_admin": is_room_admin,
        "is_room_member": is_member,
        "is_staff_override": is_staff_override,
        "is_moderation_staff": is_moderation_staff,
        "has_active_participant_record": participant is not None,
        "has_active_kickout": active_kickout is not None,
        "has_occupied_seat": seat_state is not None,
        "seat_index": getattr(seat_state, "seat_index", None),
        "admin_muted": bool(getattr(seat_state, "admin_muted", False)),
        "device_id_present": bool((device_id or "").strip()),
    }

    if active_kickout is not None and not is_staff_override:
        return MediaRoomPermissionDecision(
            allowed=False,
            reason="User is kicked out from this room.",
            permissions=[],
            context=context,
        )

    if room.is_secret and not (is_owner or is_room_admin or is_member or is_staff_override):
        return MediaRoomPermissionDecision(
            allowed=False,
            reason="Secret Vibe room requires invite, membership, room admin access, or official override.",
            permissions=[],
            context=context,
        )

    if room.is_locked and not (is_owner or is_room_admin or is_member or is_staff_override):
        return MediaRoomPermissionDecision(
            allowed=False,
            reason="Locked room requires valid access, room admin access, or official override.",
            permissions=[],
            context=context,
        )

    if room.is_members_only and not (is_owner or is_room_admin or is_member or is_staff_override):
        return MediaRoomPermissionDecision(
            allowed=False,
            reason="Members-only room requires membership, room admin access, or official override.",
            permissions=[],
            context=context,
        )

    if action in ROOM_PRODUCE_ACTIONS:
        if room.apply_only_mode_enabled and not (is_owner or is_room_admin or is_staff_override):
            return MediaRoomPermissionDecision(
                allowed=False,
                reason="Apply-only mode requires approval before joining mic.",
                permissions=[],
                context=context,
            )
        if seat_state is not None and seat_state.admin_muted and not (is_owner or is_room_admin or is_moderation_staff):
            return MediaRoomPermissionDecision(
                allowed=False,
                reason="User is admin-muted on mic.",
                permissions=[],
                context=context,
            )

    permissions = ["ROOM_MEDIA_PERMISSION_VERIFIED"]
    if is_staff_override:
        permissions.append("OFFICIAL_ROOM_OVERRIDE")
    if is_owner:
        permissions.append("ROOM_OWNER")
    if is_room_admin:
        permissions.append("ROOM_ADMIN")
    if is_member:
        permissions.append("ROOM_MEMBER")
    if action in ROOM_PRODUCE_ACTIONS:
        permissions.append("CAN_REQUEST_OR_USE_MIC")
    if action in ROOM_CONSUME_ACTIONS:
        permissions.append("CAN_LISTEN")
    if action in ROOM_PRODUCER_OWNER_ACTIONS:
        permissions.append("PRODUCER_OWNER_CHECK_REQUIRED_BY_SIGNALING")

    return MediaRoomPermissionDecision(
        allowed=True,
        reason=None,
        permissions=permissions,
        context=context,
    )


def _active_participant(db: Session, room_id: int, user_id: int) -> RoomParticipant | None:
    return (
        db.query(RoomParticipant)
        .filter(
            RoomParticipant.room_id == room_id,
            RoomParticipant.user_id == user_id,
            RoomParticipant.is_active == True,  # noqa: E712
        )
        .first()
    )


def _active_kickout(db: Session, room_public_id: str, user: User) -> RoomKickout | None:
    now = datetime.utcnow()
    return (
        db.query(RoomKickout)
        .filter(
            RoomKickout.room_public_id == room_public_id,
            RoomKickout.is_active == True,  # noqa: E712
            (RoomKickout.target_user_id == user.id)
            | (RoomKickout.target_public_user_id == str(user.public_user_id)),
            (RoomKickout.is_permanent == True)  # noqa: E712
            | (RoomKickout.blocked_until.is_(None))
            | (RoomKickout.blocked_until > now),
        )
        .first()
    )


def _occupied_seat(db: Session, room_id: int, user_id: int) -> RoomSeatState | None:
    return (
        db.query(RoomSeatState)
        .filter(
            RoomSeatState.room_id == room_id,
            RoomSeatState.occupant_user_id == user_id,
        )
        .first()
    )
