from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any
from uuid import uuid4

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.presence import UserRoomPresence
from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.room_realtime_state import RoomChatMessage, RoomMemberRequest, RoomRealtimeEvent, RoomSeatApplication, RoomSeatState
from app.models.user import User
from app.services.rooms import room_activity_service, watch_party_service

_ALLOWED_SEAT_LAYOUT_IDS = {"4x2", "5x2", "4x3", "5x3", "host_4x2", "host_5x2", "host_4x3", "host_5x3"}
ROOM_STALE_PRESENCE_TIMEOUT_SECONDS = 10 * 60
TRENDING_ONLINE_WEIGHT = 100
TRENDING_SEATED_WEIGHT = 35
TRENDING_ACTIVE_ROOM_BASE = 25


def normalize_layout(layout_id: str | None) -> str:
    return layout_id if layout_id in _ALLOWED_SEAT_LAYOUT_IDS else "5x2"


def seat_count_for_layout(layout_id: str | None) -> int:
    safe_layout = normalize_layout(layout_id)
    has_host = safe_layout.startswith("host_")
    raw = safe_layout.replace("host_", "", 1)
    try:
        columns, rows = raw.split("x", 1)
        return int(columns) * int(rows) + (2 if has_host else 0)
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
            released_user_id = seat.occupant_user_id
            seat.occupant_user_id = None
            seat.mic_enabled = False
            seat.admin_muted = False
            seat.left_at = datetime.utcnow()
            seat.updated_by_user_id = released_user_id
    db.flush()
    return [existing[index] for index in sorted(existing) if index < max_seats]


def room_sequence(db: Session, room: Room) -> int:
    del db
    return int(room.realtime_event_sequence or 0)


def _next_sequence(db: Session, room: Room) -> int:
    del db
    room.realtime_version = int(room.realtime_version or 0) + 1
    room.realtime_event_sequence = int(room.realtime_event_sequence or 0) + 1
    return room.realtime_event_sequence


def calculate_room_trending_score(active_count: int, seated_count: int) -> int:
    if active_count <= 0:
        return 0
    return TRENDING_ACTIVE_ROOM_BASE + (active_count * TRENDING_ONLINE_WEIGHT) + (seated_count * TRENDING_SEATED_WEIGHT)


def _visible_count_query(db: Session, room: Room) -> int:
    return int(db.query(func.count(RoomParticipant.id)).filter(RoomParticipant.room_id == room.id, RoomParticipant.is_active.is_(True), RoomParticipant.visible_in_online_count.is_(True)).scalar() or 0)


def sync_room_live_counters(db: Session, room: Room) -> tuple[int, int, int]:
    cleanup_orphaned_seat_occupants(db, room)
    public_count = _visible_count_query(db, room)
    seated_count = int(db.query(func.count(RoomSeatState.id)).filter(RoomSeatState.room_id == room.id, RoomSeatState.occupant_user_id.isnot(None)).scalar() or 0)
    trending_score = calculate_room_trending_score(public_count, seated_count)
    room.online_count = public_count
    room.trending_score = trending_score
    room.updated_at = datetime.utcnow()
    db.flush()
    return public_count, seated_count, trending_score


def cleanup_orphaned_seat_occupants(db: Session, room: Room, now: datetime | None = None) -> list[int]:
    """Release seats whose occupant is not an active participant in this room.

    This protects seat switching from ghost seats after browser refreshes,
    duplicate sessions, or a user leaving without a clean seat release.
    """
    current_time = now or datetime.utcnow()
    active_user_ids = {
        user_id
        for (user_id,) in db.query(RoomParticipant.user_id)
        .filter(RoomParticipant.room_id == room.id, RoomParticipant.is_active.is_(True))
        .all()
    }
    orphaned_seats = (
        db.query(RoomSeatState)
        .filter(RoomSeatState.room_id == room.id, RoomSeatState.occupant_user_id.isnot(None))
        .all()
    )
    released_user_ids: list[int] = []
    for seat in orphaned_seats:
        if seat.occupant_user_id in active_user_ids:
            continue
        released_user_id = int(seat.occupant_user_id)
        seat.occupant_user_id = None
        seat.mic_enabled = False
        seat.admin_muted = False
        seat.left_at = current_time
        seat.updated_by_user_id = released_user_id
        released_user_ids.append(released_user_id)
    if released_user_ids:
        for user_id in sorted(set(released_user_ids)):
            db.add(
                RoomRealtimeEvent(
                    room_id=room.id,
                    room_public_id=room.room_public_id,
                    event_type="seat.orphaned_released",
                    event_id=uuid4().hex,
                    actor_user_id=user_id,
                    target_user_id=user_id,
                    payload={"reason": "seat_occupant_not_active_participant"},
                    sequence=_next_sequence(db, room),
                    room_version=room.realtime_version,
                )
            )
        room.updated_at = current_time
        db.flush()
    return released_user_ids


def cleanup_stale_participants(db: Session, room: Room, now: datetime | None = None) -> list[int]:
    current_time = now or datetime.utcnow()
    cutoff = current_time - timedelta(seconds=ROOM_STALE_PRESENCE_TIMEOUT_SECONDS)
    stale_participants = db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, RoomParticipant.is_active.is_(True), RoomParticipant.last_seen_at.isnot(None), RoomParticipant.last_seen_at < cutoff).all()
    if not stale_participants:
        cleanup_orphaned_seat_occupants(db, room, current_time)
        sync_room_live_counters(db, room)
        return []
    stale_user_ids = [participant.user_id for participant in stale_participants]
    for participant in stale_participants:
        participant.is_active = False
        participant.left_at = current_time
        participant.last_seen_at = current_time
    db.query(UserRoomPresence).filter(
        UserRoomPresence.room_public_id == room.room_public_id,
        UserRoomPresence.user_id.in_(stale_user_ids),
        UserRoomPresence.is_active.is_(True),
    ).update(
        {UserRoomPresence.is_active: False, UserRoomPresence.left_at: current_time},
        synchronize_session=False,
    )
    seats = db.query(RoomSeatState).filter(RoomSeatState.room_id == room.id, RoomSeatState.occupant_user_id.in_(stale_user_ids)).all()
    for seat in seats:
        released_user_id = seat.occupant_user_id
        seat.occupant_user_id = None
        seat.mic_enabled = False
        seat.admin_muted = False
        seat.left_at = current_time
        seat.updated_by_user_id = released_user_id
    for user_id in stale_user_ids:
        sequence = _next_sequence(db, room)
        db.add(RoomRealtimeEvent(room_id=room.id, room_public_id=room.room_public_id, event_type="room.participant_stale_removed", event_id=uuid4().hex, actor_user_id=user_id, target_user_id=user_id, payload={"reason": "presence_timeout", "timeout_seconds": ROOM_STALE_PRESENCE_TIMEOUT_SECONDS}, sequence=sequence, room_version=room.realtime_version))
        db.flush()
        watch_party_service.ensure_controller_after_departure(db, room, user_id)
        room_activity_service.ensure_controller_after_departure(db, room, user_id)
    cleanup_orphaned_seat_occupants(db, room, current_time)
    sync_room_live_counters(db, room)
    room.updated_at = current_time
    db.flush()
    return stale_user_ids


def active_participants(db: Session, room: Room) -> list[RoomParticipant]:
    """Read persisted participant rows without performing maintenance writes."""
    return db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, RoomParticipant.is_active.is_(True)).order_by(RoomParticipant.joined_at.asc()).all()


def room_user_key(room_public_id: str, user_id: int | None) -> str | None:
    if user_id is None:
        return None
    return f"room:{room_public_id}:user:{user_id}"


def peer_id_for(room_public_id: str, user: User | None, user_id: int | None = None) -> str | None:
    resolved_user_id = user.id if user else user_id
    if resolved_user_id is None:
        return None
    public_user_id = user.public_user_id if user else resolved_user_id
    return f"{room_public_id}_user_{public_user_id}"


def user_card(user: User | None) -> dict[str, Any] | None:
    if user is None:
        return None
    return {"user_id": user.id, "backend_user_id": user.id, "public_user_id": user.public_user_id, "display_name": user.display_name or user.username or str(user.public_user_id), "username": user.username, "avatar_url": user.avatar_url, "official_handle": user.official_handle, "is_protected": bool(user.is_protected)}


def seat_payload(seat: RoomSeatState, room_public_id: str | None = None) -> dict[str, Any]:
    occupant = seat.occupant
    return {"seat_index": seat.seat_index, "occupant_user_id": seat.occupant_user_id, "occupant_backend_user_id": seat.occupant_user_id, "occupant_public_user_id": occupant.public_user_id if occupant else None, "occupant_room_user_key": room_user_key(room_public_id or "", seat.occupant_user_id) if room_public_id else None, "occupant_peer_id": peer_id_for(room_public_id, occupant, seat.occupant_user_id) if room_public_id else None, "is_locked": seat.is_locked, "mic_enabled": seat.mic_enabled, "admin_muted": seat.admin_muted, "locked_by_user_id": seat.locked_by_user_id, "admin_muted_by_user_id": seat.admin_muted_by_user_id, "updated_by_user_id": seat.updated_by_user_id, "occupant": user_card(occupant)}


def chat_payload(message: RoomChatMessage) -> dict[str, Any]:
    sender = message.sender
    return {"id": message.id, "room_public_id": message.room_public_id, "sender_user_id": message.sender_user_id, "sender_backend_user_id": message.sender_user_id, "sender_public_user_id": sender.public_user_id if sender else None, "sender_room_user_key": room_user_key(message.room_public_id, message.sender_user_id), "sender_peer_id": peer_id_for(message.room_public_id, sender, message.sender_user_id), "message_type": message.message_type, "text": message.text, "media_url": message.media_url, "metadata": message.metadata_json or {}, "created_at": message.created_at.isoformat() if message.created_at else None, "sender": user_card(sender)}


def recent_chat_messages(db: Session, room: Room, limit: int = 80) -> list[dict[str, Any]]:
    rows = db.query(RoomChatMessage).filter(RoomChatMessage.room_id == room.id, RoomChatMessage.is_deleted.is_(False)).order_by(RoomChatMessage.id.desc()).limit(limit).all()
    return [chat_payload(message) for message in reversed(rows)]



def pending_room_member_requests(db: Session, room: Room) -> list[dict[str, Any]]:
    rows = (
        db.query(RoomMemberRequest)
        .filter(
            RoomMemberRequest.room_id == room.id,
            RoomMemberRequest.status == "pending",
        )
        .order_by(RoomMemberRequest.requested_at.asc(), RoomMemberRequest.id.asc())
        .all()
    )
    user_ids = {row.requester_user_id for row in rows}
    users = {
        user.id: user
        for user in (
            db.query(User).filter(User.id.in_(user_ids)).all()
            if user_ids
            else []
        )
    }
    member_ids = {
        user_id
        for (user_id,) in (
            db.query(RoomParticipant.user_id)
            .filter(
                RoomParticipant.room_id == room.id,
                RoomParticipant.user_id.in_(user_ids),
                RoomParticipant.is_member.is_(True),
            )
            .all()
            if user_ids
            else []
        )
    }
    requests: list[dict[str, Any]] = []
    for request in rows:
        if request.requester_user_id in member_ids:
            continue
        user = users.get(request.requester_user_id)
        requests.append(
            {
                "request_id": request.id,
                "user_id": request.requester_user_id,
                "backend_user_id": request.requester_user_id,
                "public_user_id": user.public_user_id if user else request.requester_user_id,
                "display_name": (user.display_name or user.username or str(user.public_user_id)) if user else "Vibe User",
                "username": user.username if user else None,
                "avatar_url": user.avatar_url if user else None,
                "requested_at": request.requested_at.isoformat() if request.requested_at else None,
                "status": "pending",
            }
        )
    return requests


def pending_seat_applications(db: Session, room: Room) -> list[dict[str, Any]]:
    now = datetime.utcnow()
    rows = (
        db.query(RoomSeatApplication)
        .filter(
            RoomSeatApplication.room_id == room.id,
            RoomSeatApplication.status == "pending",
            RoomSeatApplication.expires_at > now,
        )
        .order_by(RoomSeatApplication.requested_at.asc(), RoomSeatApplication.id.asc())
        .all()
    )
    seat_rows = (
        db.query(RoomSeatState)
        .filter(RoomSeatState.room_id == room.id)
        .all()
    )
    seats = {seat.seat_index: seat for seat in seat_rows}
    user_ids = {row.applicant_user_id for row in rows}
    users = {
        user.id: user
        for user in (
            db.query(User).filter(User.id.in_(user_ids)).all()
            if user_ids
            else []
        )
    }
    requests: list[dict[str, Any]] = []
    for application in rows:
        seat = seats.get(application.seat_index)
        if seat is not None and (seat.is_locked or seat.occupant_user_id is not None):
            continue
        user = users.get(application.applicant_user_id)
        requests.append(
            {
                "id": application.application_id,
                "request_id": application.id,
                "room_id": room.room_public_id,
                "seat_index": application.seat_index,
                "applicant_user_id": application.applicant_user_id,
                "applicant_backend_user_id": application.applicant_user_id,
                "applicant_public_user_id": user.public_user_id if user else application.applicant_user_id,
                "applicant_name": (user.display_name or user.username or str(user.public_user_id)) if user else "Vibe User",
                "applicant_avatar_url": user.avatar_url if user else None,
                "created_at": application.requested_at.isoformat() if application.requested_at else None,
                "expires_at": application.expires_at.isoformat() if application.expires_at else None,
                "status": "pending",
            }
        )
    return requests

def room_participant_type(is_host: bool, is_room_admin: bool, is_room_member: bool) -> str:
    if is_host:
        return "owner"
    if is_room_admin:
        return "admin"
    if is_room_member:
        return "room_member"
    return "visitor"


def participant_payload(room: Room, participant: RoomParticipant, seat: RoomSeatState | None, pending_user_ids: set[int] | None = None) -> dict[str, Any]:
    user = participant.user
    backend_user_id = participant.user_id
    public_user_id = user.public_user_id if user else backend_user_id
    is_host = backend_user_id == room.owner_user_id
    is_room_admin = participant.is_room_admin or is_host
    is_room_member = bool(participant.is_member)
    has_pending_room_member_request = backend_user_id in (pending_user_ids or set())
    participant_type = room_participant_type(is_host, is_room_admin, is_room_member)
    membership_request_status = "room_member" if is_room_member else ("pending" if has_pending_room_member_request else "none")
    return {"backend_user_id": backend_user_id, "user_id": backend_user_id, "public_user_id": public_user_id, "room_user_key": room_user_key(room.room_public_id, backend_user_id), "peer_id": peer_id_for(room.room_public_id, user, backend_user_id), "display_name": (user.display_name or user.username or str(public_user_id)) if user else "Vibe User", "username": user.username if user else None, "avatar_url": user.avatar_url if user else None, "official_handle": user.official_handle if user else None, "is_protected": bool(user.is_protected) if user else False, "is_host": is_host, "is_room_owner": is_host, "is_room_admin": is_room_admin, "is_room_member": is_room_member, "is_stealth": bool(participant.is_stealth), "visible_in_online_count": bool(participant.visible_in_online_count), "visible_in_user_list": bool(participant.visible_in_user_list), "visible_to_public": bool(participant.visible_to_public), "has_pending_room_member_request": has_pending_room_member_request, "membership_request_status": membership_request_status, "participant_type": participant_type, "role_label": "Host" if is_host else ("Admin" if is_room_admin else ("Room Member" if is_room_member else "Visitor")), "seat_index": seat.seat_index if seat else None, "mic_enabled": seat.mic_enabled if seat else False, "admin_muted": seat.admin_muted if seat else False, "is_active": participant.is_active, "is_member": is_room_member, "joined_at": participant.joined_at.isoformat() if participant.joined_at else None, "last_seen_at": participant.last_seen_at.isoformat() if participant.last_seen_at else None}


def room_membership_roster(db: Session, room: Room) -> list[dict[str, Any]]:
    """Return complete durable membership independently from online presence."""
    participants = (
        db.query(RoomParticipant)
        .filter(
            RoomParticipant.room_id == room.id,
            (
                RoomParticipant.is_member.is_(True)
                | RoomParticipant.is_room_admin.is_(True)
                | (RoomParticipant.user_id == room.owner_user_id)
            ),
        )
        .order_by(RoomParticipant.user_id.asc())
        .all()
    )

    roster: list[dict[str, Any]] = []
    seen_user_ids: set[int] = set()
    for participant in participants:
        user = participant.user
        backend_user_id = int(participant.user_id)
        public_user_id = user.public_user_id if user else backend_user_id
        is_host = backend_user_id == room.owner_user_id
        is_room_admin = bool(participant.is_room_admin) or is_host
        is_room_member = bool(participant.is_member) or is_room_admin
        roster.append(
            {
                "backend_user_id": backend_user_id,
                "user_id": backend_user_id,
                "public_user_id": public_user_id,
                "is_host": is_host,
                "is_room_owner": is_host,
                "is_room_admin": is_room_admin,
                "is_room_member": is_room_member,
                "is_member": is_room_member,
            }
        )
        seen_user_ids.add(backend_user_id)

    owner_user_id = room.owner_user_id
    if owner_user_id is not None and owner_user_id not in seen_user_ids:
        owner = db.query(User).filter(User.id == owner_user_id).first()
        roster.append(
            {
                "backend_user_id": owner_user_id,
                "user_id": owner_user_id,
                "public_user_id": owner.public_user_id if owner else owner_user_id,
                "is_host": True,
                "is_room_owner": True,
                "is_room_admin": True,
                "is_room_member": True,
                "is_member": True,
            }
        )

    return roster


def room_snapshot(db: Session, room: Room, include_chat: bool = True) -> dict[str, Any]:
    max_seats = seat_count_for_layout(room.seat_layout_id)
    seats = (
        db.query(RoomSeatState)
        .filter(
            RoomSeatState.room_id == room.id,
            RoomSeatState.seat_index < max_seats,
        )
        .order_by(RoomSeatState.seat_index.asc())
        .all()
    )
    participants = active_participants(db, room)
    member_requests = pending_room_member_requests(db, room)
    membership_roster = room_membership_roster(db, room)
    seat_applications = pending_seat_applications(db, room)
    pending_user_ids = {int(request["backend_user_id"]) for request in member_requests if request.get("backend_user_id") is not None}
    public_online_count = len([participant for participant in participants if participant.visible_in_online_count])
    internal_online_count = len(participants)
    seated_count = len([seat for seat in seats if seat.occupant_user_id is not None])
    trending_score = calculate_room_trending_score(public_online_count, seated_count)

    public_participants = []
    internal_participants = []
    peers = []
    seen_backend_user_ids: set[int] = set()
    for participant in participants:
        if participant.user_id in seen_backend_user_ids:
            continue
        seen_backend_user_ids.add(participant.user_id)
        seat = next((item for item in seats if item.occupant_user_id == participant.user_id), None)
        participant_data = participant_payload(room, participant, seat, pending_user_ids=pending_user_ids)
        internal_participants.append(participant_data)
        if not participant.visible_in_user_list:
            continue
        public_participants.append(participant_data)
        peers.append({"peer_id": participant_data["peer_id"], "user_id": str(participant_data["backend_user_id"]), "backend_user_id": participant_data["backend_user_id"], "public_user_id": participant_data["public_user_id"], "room_user_key": participant_data["room_user_key"], "display_name": participant_data["display_name"], "avatar_url": participant_data["avatar_url"], "is_host": participant_data["is_host"], "is_room_owner": participant_data["is_room_owner"], "is_room_admin": participant_data["is_room_admin"], "is_room_member": participant_data["is_room_member"], "has_pending_room_member_request": participant_data["has_pending_room_member_request"], "membership_request_status": participant_data["membership_request_status"], "participant_type": participant_data["participant_type"], "role_label": participant_data["role_label"], "seat_index": participant_data["seat_index"], "mic_enabled": participant_data["mic_enabled"], "admin_muted": participant_data["admin_muted"]})

    seat_payload_by_index = {
        seat.seat_index: seat_payload(seat, room.room_public_id)
        for seat in seats
    }
    seat_payloads = [
        seat_payload_by_index.get(
            seat_index,
            {
                "seat_index": seat_index,
                "occupant_user_id": None,
                "occupant_backend_user_id": None,
                "occupant_public_user_id": None,
                "occupant_room_user_key": None,
                "occupant_peer_id": None,
                "is_locked": False,
                "mic_enabled": False,
                "admin_muted": False,
                "locked_by_user_id": None,
                "admin_muted_by_user_id": None,
                "updated_by_user_id": None,
                "occupant": None,
            },
        )
        for seat_index in range(max_seats)
    ]
    payload: dict[str, Any] = {"room_id": room.room_public_id, "room_public_id": room.room_public_id, "database_room_id": room.id, "owner_user_id": room.owner_user_id, "name": room.name, "subtitle": room.subtitle, "avatar_url": room.avatar_url, "cover_photo_url": room.cover_photo_url, "language": room.language, "mode": room.mode, "room_type": room.room_type, "online_count": public_online_count, "public_online_count": public_online_count, "internal_online_count": internal_online_count, "active_presence_score": trending_score, "trending_score": trending_score, "active_participant_count": public_online_count, "internal_active_participant_count": internal_online_count, "active_seated_count": seated_count, "is_active": room.is_active, "is_secret": room.is_secret, "is_locked": room.is_locked, "is_members_only": room.is_members_only, "allow_screenshots": room.allow_screenshots, "room_images_enabled": room.room_images_enabled, "guest_messages_enabled": room.guest_messages_enabled, "apply_only_mode_enabled": room.apply_only_mode_enabled, "background_theme_id": room.background_theme_id, "seat_layout_id": normalize_layout(room.seat_layout_id), "seat_count": max_seats, "announcement_text": room.announcement_text, "state_version": int(room.realtime_version or 0), "event_sequence": int(room.realtime_event_sequence or 0), "server_time": watch_party_service.server_now_ms(), "activity": room_activity_service.room_activity_snapshot(db, room), "watch_party": watch_party_service.watch_party_snapshot(db, room), "updated_at": room.updated_at.isoformat() if room.updated_at else None, "seats": seat_payloads, "locked_seat_indexes": [seat.seat_index for seat in seats if seat.is_locked], "participants": public_participants, "internal_participants": internal_participants, "pending_room_member_requests": member_requests, "pending_room_member_request_count": len(member_requests), "membership_roster": membership_roster, "pending_seat_applications": seat_applications, "pending_seat_application_count": len(seat_applications), "peers": peers, "peer_count": len(public_participants)}
    if include_chat:
        payload["recent_messages"] = recent_chat_messages(db, room)
    return payload