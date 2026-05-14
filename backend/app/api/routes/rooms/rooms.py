from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.user import User
from app.schemas.rooms.room import RoomCreateRequest, RoomDetailResponse, RoomJoinRequest, RoomJoinResponse, RoomLeaveResponse, RoomMemberActionRequest, RoomModeUpdateRequest, RoomParticipantUserResponse, RoomParticipantsResponse, RoomTrendingResponse
from app.schemas.rooms.room_background import RoomBackgroundConfigResponse
from app.schemas.rooms.room_kickout import RoomKickoutCreateRequest, RoomKickoutResponse
from app.services.rooms.room_background_service import list_room_backgrounds
from app.services.rooms.room_contribution_service import room_contribution_rankings
from app.services.rooms.room_kickout_service import create_room_kickout, list_active_room_kickouts, remove_room_kickout
from app.services.rooms.room_service import (
    apply_room_mode,
    cleanup_stale_room_participants,
    create_room,
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
from app.services.role_service import get_user_roles


router = APIRouter(prefix="/rooms", tags=["Rooms"])


def _role_values(user: User) -> set[str]:
    return {role.value if hasattr(role, "value") else str(role) for role in get_user_roles(user)}


def _can_manage_room(db: Session, room: Room, user: User) -> bool:
    if room.owner_user_id == user.id or bool(_role_values(user) & {"founder_owner", "owner"}):
        return True
    participant = db.query(RoomParticipant).filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == user.id).first()
    return bool(participant and participant.is_room_admin)


@router.post("", response_model=RoomDetailResponse, status_code=status.HTTP_201_CREATED)
def create_live_room(payload: RoomCreateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return create_room(db=db, current_user=current_user, payload=payload)


@router.post("/cleanup-stale")
def cleanup_stale_rooms(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    removed_count = cleanup_stale_room_participants(db)
    return {"removed_count": removed_count, "rule": "Active room participants with no heartbeat for 10 minutes are removed from the room."}


@router.get("/trending", response_model=list[RoomTrendingResponse])
def get_trending_rooms(language: str | None = Query(default=None), category: str | None = Query(default=None), limit: int = Query(default=30, ge=1, le=100), db: Session = Depends(get_db)):
    return list_trending_rooms(db=db, language=language, category=category, limit=limit)


@router.get("/following", response_model=list[RoomTrendingResponse])
def get_following_rooms(language: str | None = Query(default=None), category: str | None = Query(default=None), limit: int = Query(default=30, ge=1, le=100), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return list_following_rooms(db=db, current_user=current_user, language=language, category=category, limit=limit)


@router.get("/backgrounds", response_model=list[RoomBackgroundConfigResponse])
def get_room_backgrounds(mode: str = Query(default="chat_room")):
    return list_room_backgrounds(mode=mode)


@router.get("/{room_public_id}/contributions")
def get_room_contribution_rankings(
    room_public_id: str,
    period: str = Query(default="daily"),
    category: str = Query(default="sent"),
    limit: int = Query(default=100, ge=1, le=100),
    db: Session = Depends(get_db),
):
    payload = room_contribution_rankings(db=db, room_public_id=room_public_id, category=category, period=period, limit=limit)
    if payload is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
    return payload


@router.get("/{room_public_id}", response_model=RoomDetailResponse)
def get_room_detail(room_public_id: str, db: Session = Depends(get_db)):
    room = get_room_by_public_id(db=db, room_public_id=room_public_id)
    if room is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
    return room


@router.patch("/{room_public_id}/mode", response_model=RoomDetailResponse)
def update_room_mode(room_public_id: str, payload: RoomModeUpdateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    room = db.query(Room).filter(Room.room_public_id == room_public_id, Room.is_active.is_(True)).first()
    if room is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
    if not _can_manage_room(db, room, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the channel host/admin or Owner can change room mode")
    apply_room_mode(room, mode=payload.mode, actor_user_id=current_user.id, lock_password=payload.lock_password)
    db.commit()
    db.refresh(room)
    return room_to_detail_response(room)


@router.post("/{room_public_id}/join", response_model=RoomJoinResponse)
def join_live_room(room_public_id: str, payload: RoomJoinRequest | None = None, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    joined = join_room(db=db, room_public_id=room_public_id, current_user=current_user, lock_password=payload.lock_password if payload else None)
    if joined is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found or not accessible")
    return joined


@router.post("/{room_public_id}/heartbeat", response_model=RoomJoinResponse)
def heartbeat_live_room(room_public_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    joined = heartbeat_room(db=db, room_public_id=room_public_id, current_user=current_user)
    if joined is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found or not accessible")
    return joined


@router.post("/{room_public_id}/leave", response_model=RoomLeaveResponse)
def leave_live_room(room_public_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    left = leave_room(db=db, room_public_id=room_public_id, current_user=current_user)
    if left is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
    return left


@router.get("/{room_public_id}/participants", response_model=RoomParticipantsResponse)
def get_live_room_participants(room_public_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    participants = list_room_participants(db=db, room_public_id=room_public_id, current_user=current_user)
    if participants is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found or not accessible")
    return participants


@router.post("/{room_public_id}/members", response_model=RoomParticipantUserResponse)
def add_room_member(room_public_id: str, payload: RoomMemberActionRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return set_room_member(db=db, room_public_id=room_public_id, current_user=current_user, target_public_user_id=payload.public_user_id, is_member=True)


@router.delete("/{room_public_id}/members/{public_user_id}", response_model=RoomParticipantUserResponse)
def remove_room_member(room_public_id: str, public_user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return set_room_member(db=db, room_public_id=room_public_id, current_user=current_user, target_public_user_id=public_user_id, is_member=False)


@router.post("/{room_public_id}/admins", response_model=RoomParticipantUserResponse)
def add_room_admin(room_public_id: str, payload: RoomMemberActionRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return set_room_admin(db=db, room_public_id=room_public_id, current_user=current_user, target_public_user_id=payload.public_user_id, is_admin=True)


@router.delete("/{room_public_id}/admins/{public_user_id}", response_model=RoomParticipantUserResponse)
def remove_room_admin(room_public_id: str, public_user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return set_room_admin(db=db, room_public_id=room_public_id, current_user=current_user, target_public_user_id=public_user_id, is_admin=False)


@router.post("/{room_public_id}/kickouts", response_model=RoomKickoutResponse)
def kickout_room_user(room_public_id: str, payload: RoomKickoutCreateRequest, db: Session = Depends(get_db)):
    return create_room_kickout(db=db, room_public_id=room_public_id, payload=payload)


@router.get("/{room_public_id}/kickouts", response_model=list[RoomKickoutResponse])
def get_room_blocked_users(room_public_id: str, db: Session = Depends(get_db)):
    return list_active_room_kickouts(db=db, room_public_id=room_public_id)


@router.delete("/{room_public_id}/kickouts/{kickout_id}", response_model=RoomKickoutResponse)
def unblock_room_user(room_public_id: str, kickout_id: int, db: Session = Depends(get_db)):
    removed = remove_room_kickout(db=db, room_public_id=room_public_id, kickout_id=kickout_id)
    if removed is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Active room blocked-list entry not found.")
    return removed
