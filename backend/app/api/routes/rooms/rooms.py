from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.routes.room_realtime_commands import client_room_snapshot
from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.user import User
from app.realtime.connection_manager import room_realtime_connections
from app.schemas.room_settings import (
    RoomAccessSettingsUpdateRequest,
    RoomAnnouncementUpdateRequest,
    RoomBackgroundUpdateRequest,
    RoomNameUpdateRequest,
    RoomSeatLayoutUpdateRequest,
    RoomSettingsResponse,
)
from app.schemas.room_theme import (
    CustomRoomBackgroundSubmitRequest,
    RoomCoverPhotoUpdateRequest,
    RoomThemeApplyRequest,
    RoomThemePurchaseRequest,
    RoomThemeResponse,
    RoomThemeReviewDecisionRequest,
    RoomThemeReviewResponse,
)
from app.schemas.rooms.room import (
    RoomCreateRequest,
    RoomDetailResponse,
    RoomJoinRequest,
    RoomJoinResponse,
    RoomLeaveResponse,
    RoomMemberActionRequest,
    RoomModeUpdateRequest,
    RoomParticipantUserResponse,
    RoomParticipantsResponse,
    RoomTrendingResponse,
)
from app.schemas.rooms.room_background import RoomBackgroundConfigResponse
from app.schemas.rooms.room_kickout import RoomKickoutCreateRequest, RoomKickoutResponse
from app.services.rooms import room_action_service, room_state_service
from app.services.rooms.room_background_service import list_room_backgrounds
from app.services.rooms.room_contribution_service import room_contribution_rankings
from app.services.rooms.room_kickout_service import (
    create_room_kickout,
    list_active_room_kickouts,
    remove_room_kickout,
)
from app.services.rooms.room_service import (
    apply_room_mode,
    cleanup_stale_room_participants,
    create_room,
    get_my_created_room,
    get_room_by_public_id,
    heartbeat_room,
    join_room,
    leave_room,
    list_following_rooms,
    list_room_participants,
    list_trending_rooms,
    room_to_detail_response,
    set_room_admin,
    set_room_member,
)
from app.services.rooms.room_state_service import normalize_layout
from app.services.rooms.room_theme_service import (
    apply_room_theme,
    decide_custom_background_review,
    list_pending_custom_background_reviews,
    list_store_room_themes,
    purchase_room_theme,
    submit_custom_room_background,
)
from app.services.role_service import get_user_roles


router = APIRouter(prefix="/rooms", tags=["Rooms"])
admin_router = APIRouter(prefix="/admin/rooms", tags=["Admin Rooms"])


def _role_values(user: User) -> set[str]:
    return {
        role.value if hasattr(role, "value") else str(role)
        for role in get_user_roles(user)
    }


def _display_name(user: User) -> str:
    return user.display_name or user.username or str(user.public_user_id)


def _can_manage_room(db: Session, room: Room, user: User) -> bool:
    if room.owner_user_id == user.id or bool(
        _role_values(user) & {"founder_owner", "owner"}
    ):
        return True
    participant = (
        db.query(RoomParticipant)
        .filter(
            RoomParticipant.room_id == room.id,
            RoomParticipant.user_id == user.id,
        )
        .first()
    )
    return bool(participant and participant.is_room_admin)


def _require_manage_room(db: Session, room: Room, user: User) -> None:
    if not _can_manage_room(db, room, user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the channel host/admin or Owner can manage this room",
        )


def _can_update_host_owned_room(room: Room, user: User) -> bool:
    return room.owner_user_id == user.id or bool(
        _role_values(user) & {"founder_owner", "owner"}
    )


def _default_room_settings_response(room_public_id: str) -> RoomSettingsResponse:
    return RoomSettingsResponse(
        room_public_id=room_public_id.strip(),
        name="Live Room",
        language="English",
        mode="Open",
        is_secret=False,
        is_locked=False,
        is_members_only=False,
        allow_screenshots=True,
        room_images_enabled=True,
        guest_messages_enabled=True,
        apply_only_mode_enabled=False,
        has_lock_password=False,
        cover_photo_url=None,
        background_theme_id="default",
        seat_layout_id="5x2",
        announcement_text=None,
        announcement_updated_at=None,
        announcement_updated_by_user_id=None,
    )


def _room_settings_response(room: Room) -> RoomSettingsResponse:
    return RoomSettingsResponse(
        room_public_id=room.room_public_id,
        name=room.name,
        language=room.language,
        mode=room.mode,
        is_secret=room.is_secret,
        is_locked=room.is_locked,
        is_members_only=room.is_members_only,
        allow_screenshots=room.allow_screenshots,
        room_images_enabled=room.room_images_enabled,
        guest_messages_enabled=room.guest_messages_enabled,
        apply_only_mode_enabled=room.apply_only_mode_enabled,
        has_lock_password=bool(room.lock_password_hash),
        cover_photo_url=room.cover_photo_url,
        background_theme_id=room.background_theme_id or "default",
        seat_layout_id=normalize_layout(room.seat_layout_id),
        announcement_text=room.announcement_text,
        announcement_updated_at=room.announcement_updated_at,
        announcement_updated_by_user_id=room.announcement_updated_by_user_id,
    )


def _latest_user_room(db: Session, user_id: int) -> Room | None:
    return (
        db.query(Room)
        .filter(Room.owner_user_id == user_id)
        .order_by(Room.updated_at.desc(), Room.created_at.desc(), Room.id.desc())
        .first()
    )


def _get_or_create_room_for_settings(
    db: Session,
    room_public_id: str,
    current_user: User | None = None,
) -> Room:
    clean_room_public_id = room_public_id.strip()
    if not clean_room_public_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Room ID is required",
        )
    room = db.query(Room).filter(Room.room_public_id == clean_room_public_id).first()
    if room is not None:
        return room
    if current_user is not None:
        existing_user_room = _latest_user_room(db, current_user.id)
        if existing_user_room is not None:
            return existing_user_room
    room = Room(
        room_public_id=clean_room_public_id,
        owner_user_id=current_user.id if current_user is not None else None,
        name="Live Room",
        subtitle=None,
        avatar_url=None,
        cover_photo_url=None,
        language="English",
        mode="Open",
        room_type="Chat",
        online_count=0,
        trending_score=0,
        is_active=True,
        is_secret=False,
        is_locked=False,
        is_members_only=False,
        allow_screenshots=True,
        room_images_enabled=True,
        guest_messages_enabled=True,
        apply_only_mode_enabled=False,
        background_theme_id="default",
        seat_layout_id="5x2",
    )
    db.add(room)
    db.commit()
    db.refresh(room)
    return room


def _locked_room(db: Session, room: Room) -> Room:
    return db.query(Room).filter(Room.id == room.id).with_for_update().one()


def _get_room_for_update(
    db: Session,
    room_public_id: str,
    current_user: User,
) -> Room:
    room = _get_or_create_room_for_settings(db, room_public_id, current_user)
    room = _locked_room(db, room)
    _require_manage_room(db, room, current_user)
    return room


def _get_room_for_host_update(
    db: Session,
    room_public_id: str,
    current_user: User,
) -> Room:
    room = _get_or_create_room_for_settings(db, room_public_id, current_user)
    room = _locked_room(db, room)
    if not _can_update_host_owned_room(room, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the channel host can update this room field",
        )
    return room


async def _record_and_broadcast(
    db: Session,
    room: Room,
    *,
    event_type: str,
    wire_type: str,
    actor_user_id: int | None = None,
    target_user_id: int | None = None,
    event_payload: dict | None = None,
    extra: dict | None = None,
) -> dict:
    room = _locked_room(db, room)
    room_action_service.record_room_event(
        db,
        room,
        event_type,
        actor_user_id=actor_user_id,
        target_user_id=target_user_id,
        payload=event_payload,
    )
    db.commit()
    db.refresh(room)
    snapshot = client_room_snapshot(db, room)
    db.commit()
    payload = {"room_id": room.room_public_id, "room": snapshot}
    if extra:
        payload.update(extra)
    await room_realtime_connections.broadcast_room(
        room.room_public_id,
        {"type": wire_type, "payload": payload},
    )
    return snapshot


async def _broadcast_closed_room_sessions(
    db: Session,
    room_ids: list[str],
    user: User,
) -> None:
    for room_id in room_ids:
        room = (
            db.query(Room)
            .filter(Room.room_public_id == room_id, Room.is_active.is_(True))
            .first()
        )
        if room is None:
            continue
        snapshot = client_room_snapshot(db, room)
        db.commit()
        await room_realtime_connections.broadcast_room(
            room_id,
            {
                "type": "room/peer_left",
                "payload": {
                    "room_id": room_id,
                    "room": snapshot,
                    "target_user_id": user.id,
                    "target_public_user_id": user.public_user_id,
                    "reason": "joined_another_room",
                },
            },
        )


@router.post("", response_model=RoomDetailResponse, status_code=status.HTTP_201_CREATED)
def create_live_room(
    payload: RoomCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_room(db=db, current_user=current_user, payload=payload)


@router.get("/my-created-room", response_model=RoomDetailResponse | None)
def get_my_live_room(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_my_created_room(db=db, current_user=current_user)


@router.post("/cleanup-stale")
def cleanup_stale_rooms(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    removed_count = cleanup_stale_room_participants(db)
    return {
        "removed_count": removed_count,
        "rule": "Inactive room participants are removed by heartbeat timeout.",
    }


@router.get("/trending", response_model=list[RoomTrendingResponse])
def get_trending_rooms(
    language: str | None = Query(default=None),
    category: str | None = Query(default=None),
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(get_db),
):
    return list_trending_rooms(
        db=db,
        language=language,
        category=category,
        limit=limit,
    )


@router.get("/following", response_model=list[RoomTrendingResponse])
def get_following_rooms(
    language: str | None = Query(default=None),
    category: str | None = Query(default=None),
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_following_rooms(
        db=db,
        current_user=current_user,
        language=language,
        category=category,
        limit=limit,
    )


@router.get("/backgrounds", response_model=list[RoomBackgroundConfigResponse])
def get_room_backgrounds(mode: str = Query(default="chat_room")):
    return list_room_backgrounds(mode=mode)


@router.get("/themes", response_model=list[RoomThemeResponse])
def get_room_theme_store(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_store_room_themes(db, current_user)


@router.post("/themes/purchase", response_model=RoomThemeResponse)
def purchase_room_background_theme(
    payload: RoomThemePurchaseRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return purchase_room_theme(db, current_user, payload.theme_id)


@router.post(
    "/custom-backgrounds",
    response_model=RoomThemeReviewResponse,
    status_code=status.HTTP_201_CREATED,
)
def submit_custom_background(
    payload: CustomRoomBackgroundSubmitRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room: Room | None = None
    if payload.room_public_id:
        room = _get_room_for_update(db, payload.room_public_id, current_user)
    return submit_custom_room_background(
        db,
        current_user,
        image_url=payload.image_url,
        thumbnail_url=payload.thumbnail_url,
        room=room,
    )


@admin_router.get(
    "/custom-background-reviews",
    response_model=list[RoomThemeReviewResponse],
)
def get_pending_custom_background_reviews(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_pending_custom_background_reviews(db, current_user)


@admin_router.post(
    "/custom-background-reviews/{review_public_id}",
    response_model=RoomThemeReviewResponse,
)
def decide_custom_background(
    review_public_id: str,
    payload: RoomThemeReviewDecisionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return decide_custom_background_review(
        db,
        current_user,
        review_public_id,
        payload.status,
        payload.review_note,
    )


@router.get("/{room_public_id}/settings", response_model=RoomSettingsResponse)
def get_room_settings(
    room_public_id: str,
    db: Session = Depends(get_db),
) -> RoomSettingsResponse:
    room = (
        db.query(Room)
        .filter(Room.room_public_id == room_public_id.strip())
        .first()
    )
    if room is None:
        return _default_room_settings_response(room_public_id)
    return _room_settings_response(room)


@router.patch("/{room_public_id}/settings", response_model=RoomSettingsResponse)
async def update_room_settings(
    room_public_id: str,
    payload: RoomAccessSettingsUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> RoomSettingsResponse:
    room = _get_room_for_update(db, room_public_id, current_user)
    if payload.language is not None:
        room.language = payload.language.strip()
    if payload.allow_screenshots is not None:
        room.allow_screenshots = payload.allow_screenshots
    if payload.mode is not None:
        apply_room_mode(
            room,
            mode=payload.mode,
            actor_user_id=current_user.id,
            lock_password=payload.lock_password,
        )
    room.is_active = True
    await _record_and_broadcast(
        db,
        room,
        event_type="room.settings.updated",
        wire_type="room_settings/updated",
        actor_user_id=current_user.id,
    )
    return _room_settings_response(room)


@router.patch("/{room_public_id}/name", response_model=RoomSettingsResponse)
async def update_room_name(
    room_public_id: str,
    payload: RoomNameUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> RoomSettingsResponse:
    room = _get_room_for_host_update(db, room_public_id, current_user)
    room.name = payload.name.strip()
    room.is_active = True
    room.updated_at = datetime.utcnow()
    await _record_and_broadcast(
        db,
        room,
        event_type="room.name.updated",
        wire_type="room_settings/updated",
        actor_user_id=current_user.id,
        event_payload={"name": room.name},
        extra={
            "name": room.name,
            "actor_user_id": str(current_user.id),
            "actor_name": _display_name(current_user),
        },
    )
    return _room_settings_response(room)


@router.patch("/{room_public_id}/background", response_model=RoomSettingsResponse)
async def update_room_background(
    room_public_id: str,
    payload: RoomBackgroundUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = _get_room_for_update(db, room_public_id, current_user)
    room.background_theme_id = payload.background_theme_id.strip()
    room.is_active = True
    room.updated_at = datetime.utcnow()
    await _record_and_broadcast(
        db,
        room,
        event_type="room.theme.updated",
        wire_type="room_settings/updated",
        actor_user_id=current_user.id,
        event_payload={"background_theme_id": room.background_theme_id},
        extra={"background_theme_id": room.background_theme_id},
    )
    return _room_settings_response(room)


@router.patch("/{room_public_id}/seat-layout", response_model=RoomSettingsResponse)
async def update_room_seat_layout(
    room_public_id: str,
    payload: RoomSeatLayoutUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = _get_room_for_update(db, room_public_id, current_user)
    room.seat_layout_id = normalize_layout(payload.seat_layout_id)
    room.is_active = True
    room.updated_at = datetime.utcnow()
    room_state_service.ensure_room_seats(db, room)
    await _record_and_broadcast(
        db,
        room,
        event_type="room.settings.updated",
        wire_type="room_settings/updated",
        actor_user_id=current_user.id,
        event_payload={"seat_layout_id": room.seat_layout_id},
        extra={"seat_layout_id": room.seat_layout_id},
    )
    return _room_settings_response(room)


@router.patch("/{room_public_id}/announcement", response_model=RoomSettingsResponse)
async def update_room_announcement(
    room_public_id: str,
    payload: RoomAnnouncementUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = _get_room_for_host_update(db, room_public_id, current_user)
    room.announcement_text = payload.announcement_text.strip()
    room.announcement_updated_at = datetime.utcnow()
    room.announcement_updated_by_user_id = current_user.id
    room.is_active = True
    await _record_and_broadcast(
        db,
        room,
        event_type="room.announcement.updated",
        wire_type="room_settings/updated",
        actor_user_id=current_user.id,
        event_payload={"announcement_text": room.announcement_text},
        extra={
            "announcement_text": room.announcement_text,
            "actor_user_id": str(current_user.id),
            "actor_name": _display_name(current_user),
        },
    )
    return _room_settings_response(room)


@router.patch("/{room_public_id}/cover-photo", response_model=RoomSettingsResponse)
async def update_room_cover_photo(
    room_public_id: str,
    payload: RoomCoverPhotoUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = _get_room_for_update(db, room_public_id, current_user)
    room.cover_photo_url = payload.cover_photo_url.strip()
    room.is_active = True
    await _record_and_broadcast(
        db,
        room,
        event_type="room.cover_photo.updated",
        wire_type="room_settings/updated",
        actor_user_id=current_user.id,
        event_payload={"cover_photo_url": room.cover_photo_url},
        extra={"cover_photo_url": room.cover_photo_url},
    )
    return _room_settings_response(room)


@router.post("/{room_public_id}/background-theme", response_model=RoomSettingsResponse)
async def apply_room_background_theme(
    room_public_id: str,
    payload: RoomThemeApplyRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = _get_room_for_update(db, room_public_id, current_user)
    room = apply_room_theme(db, room, current_user, payload.theme_id)
    room = _get_room_for_update(db, room_public_id, current_user)
    await _record_and_broadcast(
        db,
        room,
        event_type="room.theme.updated",
        wire_type="room_settings/updated",
        actor_user_id=current_user.id,
        event_payload={"background_theme_id": room.background_theme_id},
        extra={"background_theme_id": room.background_theme_id},
    )
    return _room_settings_response(room)


@router.get("/{room_public_id}/contributions")
def get_room_contribution_rankings(
    room_public_id: str,
    period: str = Query(default="daily"),
    category: str = Query(default="sent"),
    limit: int = Query(default=100, ge=1, le=100),
    db: Session = Depends(get_db),
):
    payload = room_contribution_rankings(
        db=db,
        room_public_id=room_public_id,
        category=category,
        period=period,
        limit=limit,
    )
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found",
        )
    return payload


@router.get("/{room_public_id}", response_model=RoomDetailResponse)
def get_room_detail(room_public_id: str, db: Session = Depends(get_db)):
    room = get_room_by_public_id(db=db, room_public_id=room_public_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found",
        )
    return room


@router.patch("/{room_public_id}/mode", response_model=RoomDetailResponse)
async def update_room_mode(
    room_public_id: str,
    payload: RoomModeUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = (
        db.query(Room)
        .filter(Room.room_public_id == room_public_id, Room.is_active.is_(True))
        .with_for_update()
        .first()
    )
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found",
        )
    _require_manage_room(db, room, current_user)
    apply_room_mode(
        room,
        mode=payload.mode,
        actor_user_id=current_user.id,
        lock_password=payload.lock_password,
    )
    await _record_and_broadcast(
        db,
        room,
        event_type="room.privacy.updated",
        wire_type="room_settings/updated",
        actor_user_id=current_user.id,
        event_payload={"mode": room.mode},
        extra={"mode": room.mode},
    )
    return room_to_detail_response(room)


@router.post("/{room_public_id}/join", response_model=RoomJoinResponse)
async def join_live_room(
    room_public_id: str,
    payload: RoomJoinRequest | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room_before = (
        db.query(Room)
        .filter(Room.room_public_id == room_public_id)
        .first()
    )
    previous = None
    if room_before is not None:
        previous = (
            db.query(RoomParticipant)
            .filter(
                RoomParticipant.room_id == room_before.id,
                RoomParticipant.user_id == current_user.id,
            )
            .first()
        )
    was_active = bool(previous and previous.is_active)
    joined = join_room(
        db=db,
        room_public_id=room_public_id,
        current_user=current_user,
        lock_password=payload.lock_password if payload else None,
    )
    if joined is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found or not accessible",
        )
    await _broadcast_closed_room_sessions(db, joined.closed_room_ids, current_user)
    if not was_active:
        room = db.query(Room).filter(Room.room_public_id == room_public_id).first()
        if room is not None:
            await _record_and_broadcast(
                db,
                room,
                event_type="room.joined",
                wire_type="room/joined",
                actor_user_id=current_user.id,
            )
    return joined


@router.post("/{room_public_id}/heartbeat", response_model=RoomJoinResponse)
def heartbeat_live_room(
    room_public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    joined = heartbeat_room(
        db=db,
        room_public_id=room_public_id,
        current_user=current_user,
    )
    if joined is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found or not accessible",
        )
    return joined


@router.post("/{room_public_id}/leave", response_model=RoomLeaveResponse)
async def leave_live_room(
    room_public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = db.query(Room).filter(Room.room_public_id == room_public_id).first()
    participant = None
    if room is not None:
        participant = (
            db.query(RoomParticipant)
            .filter(
                RoomParticipant.room_id == room.id,
                RoomParticipant.user_id == current_user.id,
            )
            .first()
        )
    was_active = bool(participant and participant.is_active)
    left = leave_room(
        db=db,
        room_public_id=room_public_id,
        current_user=current_user,
    )
    if left is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found",
        )
    if was_active and room is not None:
        await _record_and_broadcast(
            db,
            room,
            event_type="room.left",
            wire_type="room/peer_left",
            actor_user_id=current_user.id,
            extra={"target_user_id": current_user.id},
        )
    return left


@router.get("/{room_public_id}/participants", response_model=RoomParticipantsResponse)
def get_live_room_participants(
    room_public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    participants = list_room_participants(
        db=db,
        room_public_id=room_public_id,
        current_user=current_user,
    )
    if participants is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found or not accessible",
        )
    return participants


async def _broadcast_roster_change(
    db: Session,
    room_public_id: str,
    current_user: User,
    target_public_user_id: int,
    *,
    event_type: str,
    wire_type: str,
    value: bool,
) -> None:
    room = db.query(Room).filter(Room.room_public_id == room_public_id).first()
    target = (
        db.query(User)
        .filter(User.public_user_id == target_public_user_id)
        .first()
    )
    if room is None or target is None:
        return
    key = "is_room_admin" if "admin" in event_type else "is_member"
    await _record_and_broadcast(
        db,
        room,
        event_type=event_type,
        wire_type=wire_type,
        actor_user_id=current_user.id,
        target_user_id=target.id,
        event_payload={key: value},
        extra={
            "target_user_id": f"user_{target.public_user_id}",
            "target_backend_user_id": target.id,
            "target_public_user_id": target.public_user_id,
            "target_name": _display_name(target),
            key: value,
        },
    )


@router.post("/{room_public_id}/members", response_model=RoomParticipantUserResponse)
async def add_room_member(
    room_public_id: str,
    payload: RoomMemberActionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = set_room_member(
        db=db,
        room_public_id=room_public_id,
        current_user=current_user,
        target_public_user_id=payload.public_user_id,
        is_member=True,
    )
    await _broadcast_roster_change(
        db,
        room_public_id,
        current_user,
        payload.public_user_id,
        event_type="room.member.updated",
        wire_type="room_member/request_updated",
        value=True,
    )
    return result


@router.delete(
    "/{room_public_id}/members/{public_user_id}",
    response_model=RoomParticipantUserResponse,
)
async def remove_room_member(
    room_public_id: str,
    public_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = set_room_member(
        db=db,
        room_public_id=room_public_id,
        current_user=current_user,
        target_public_user_id=public_user_id,
        is_member=False,
    )
    await _broadcast_roster_change(
        db,
        room_public_id,
        current_user,
        public_user_id,
        event_type="room.member.updated",
        wire_type="room_member/request_updated",
        value=False,
    )
    return result


@router.post("/{room_public_id}/admins", response_model=RoomParticipantUserResponse)
async def add_room_admin(
    room_public_id: str,
    payload: RoomMemberActionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = set_room_admin(
        db=db,
        room_public_id=room_public_id,
        current_user=current_user,
        target_public_user_id=payload.public_user_id,
        is_admin=True,
    )
    await _broadcast_roster_change(
        db,
        room_public_id,
        current_user,
        payload.public_user_id,
        event_type="room.admin.updated",
        wire_type="room_admin/updated",
        value=True,
    )
    return result


@router.delete(
    "/{room_public_id}/admins/{public_user_id}",
    response_model=RoomParticipantUserResponse,
)
async def remove_room_admin(
    room_public_id: str,
    public_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = set_room_admin(
        db=db,
        room_public_id=room_public_id,
        current_user=current_user,
        target_public_user_id=public_user_id,
        is_admin=False,
    )
    await _broadcast_roster_change(
        db,
        room_public_id,
        current_user,
        public_user_id,
        event_type="room.admin.updated",
        wire_type="room_admin/updated",
        value=False,
    )
    return result


@router.post("/{room_public_id}/kickouts", response_model=RoomKickoutResponse)
async def kickout_room_user(
    room_public_id: str,
    payload: RoomKickoutCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = (
        db.query(Room)
        .filter(Room.room_public_id == room_public_id, Room.is_active.is_(True))
        .first()
    )
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found",
        )
    actor_can_manage_room = _can_manage_room(db, room, current_user)
    created = create_room_kickout(
        db=db,
        room_public_id=room_public_id,
        payload=payload,
        actor_user_id=current_user.id,
        actor_public_user_id=str(current_user.public_user_id),
        actor_can_manage_room=actor_can_manage_room,
    )
    room = db.query(Room).filter(Room.id == room.id).first()
    snapshot = await _record_and_broadcast(
        db,
        room,
        event_type="room.user.kicked",
        wire_type="room/peer_left",
        actor_user_id=current_user.id,
        target_user_id=created.target_user_id,
        event_payload={"reason": created.reason, "duration": created.duration},
        extra={"target_user_id": created.target_user_id},
    )
    if created.target_user_id is not None:
        await room_realtime_connections.send_room_user(
            room_public_id,
            created.target_user_id,
            {
                "type": "room/kicked",
                "payload": {
                    "room_id": room_public_id,
                    "room": snapshot,
                    "reason": created.reason,
                    "duration": created.duration,
                    "target_user_id": created.target_user_id,
                    "target_public_user_id": created.target_public_user_id,
                },
            },
        )
    return created


@router.get(
    "/{room_public_id}/kickouts",
    response_model=list[RoomKickoutResponse],
)
def get_room_blocked_users(
    room_public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = db.query(Room).filter(Room.room_public_id == room_public_id).first()
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    _require_manage_room(db, room, current_user)
    return list_active_room_kickouts(db=db, room_public_id=room_public_id)


@router.delete(
    "/{room_public_id}/kickouts/{kickout_id}",
    response_model=RoomKickoutResponse,
)
async def unblock_room_user(
    room_public_id: str,
    kickout_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = db.query(Room).filter(Room.room_public_id == room_public_id).first()
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    _require_manage_room(db, room, current_user)
    removed = remove_room_kickout(
        db=db,
        room_public_id=room_public_id,
        kickout_id=kickout_id,
        actor_user_id=current_user.id,
        actor_public_user_id=str(current_user.public_user_id),
    )
    if removed is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Active room blocked-list entry not found.",
        )
    room = db.query(Room).filter(Room.id == room.id).first()
    await _record_and_broadcast(
        db,
        room,
        event_type="room.kickout.removed",
        wire_type="kick_block/remove_result",
        actor_user_id=current_user.id,
        target_user_id=removed.target_user_id,
        extra={
            "removed": True,
            "target_user_id": removed.target_user_id,
            "target_public_user_id": removed.target_public_user_id,
        },
    )
    return removed
