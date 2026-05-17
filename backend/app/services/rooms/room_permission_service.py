from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.role import RoleName
from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.user import User
from app.services import role_service

OFFICIAL_PROTECTED_ROLES = {
    RoleName.FOUNDER_OWNER,
    RoleName.OWNER,
    RoleName.SUPERADMIN,
    RoleName.ADMIN,
    RoleName.MONITOR,
    RoleName.CS,
}


def participant_for(db: Session, room: Room, user: User) -> RoomParticipant | None:
    return (
        db.query(RoomParticipant)
        .filter(RoomParticipant.room_id == room.id, RoomParticipant.user_id == user.id)
        .first()
    )


def is_room_owner(room: Room, user: User | None) -> bool:
    return bool(user and room.owner_user_id == user.id)


def is_founder_or_owner(user: User | None) -> bool:
    if user is None:
        return False
    return role_service.get_primary_role(user) in {RoleName.FOUNDER_OWNER, RoleName.OWNER}


def is_room_admin(db: Session, room: Room, user: User | None) -> bool:
    if user is None:
        return False
    if is_room_owner(room, user) or is_founder_or_owner(user):
        return True
    participant = participant_for(db, room, user)
    return bool(participant and participant.is_room_admin)


def is_official_protected(user: User | None) -> bool:
    if user is None:
        return False
    return user.is_protected or role_service.get_primary_role(user) in OFFICIAL_PROTECTED_ROLES


def require_room_view(db: Session, room: Room, user: User | None) -> None:
    if not room.is_active:
        raise HTTPException(status_code=404, detail="Room is not active")
    if is_founder_or_owner(user) or is_room_owner(room, user):
        return
    if room.is_secret:
        participant = participant_for(db, room, user) if user else None
        if not participant or not participant.is_active:
            raise HTTPException(status_code=403, detail="Secret Vibe room requires a valid invite")


def require_join(db: Session, room: Room, user: User | None) -> None:
    if user is None:
        raise HTTPException(status_code=401, detail="Login required")
    require_room_view(db, room, user)
    if is_founder_or_owner(user) or is_room_owner(room, user):
        return
    if room.is_members_only:
        participant = participant_for(db, room, user)
        if not participant or not participant.is_member:
            raise HTTPException(status_code=403, detail="Members-only room requires membership approval")


def require_room_admin(db: Session, room: Room, actor: User | None) -> None:
    if not is_room_admin(db, room, actor):
        raise HTTPException(status_code=403, detail="Room owner/admin permission required")


def require_seat_take(db: Session, room: Room, actor: User | None, target: User | None = None) -> None:
    require_join(db, room, actor)
    if target is not None and actor is not None and target.id != actor.id:
        require_room_admin(db, room, actor)


def require_mic_change(db: Session, room: Room, actor: User | None) -> None:
    require_join(db, room, actor)


def require_admin_mute(db: Session, room: Room, actor: User | None, target: User | None) -> None:
    require_room_admin(db, room, actor)
    if target is None:
        return
    if is_room_owner(room, target):
        raise HTTPException(status_code=403, detail="Room owner cannot be muted")
    if is_official_protected(target) and not is_founder_or_owner(actor):
        raise HTTPException(status_code=403, detail="Official protected user cannot be muted by room admin")
    if actor and target and role_service.get_primary_role(target) in OFFICIAL_PROTECTED_ROLES:
        if not role_service.can_act_on(actor, target) and not is_founder_or_owner(actor):
            raise HTTPException(status_code=403, detail="Cannot mute equal or higher official role")


def require_room_settings(db: Session, room: Room, actor: User | None) -> None:
    require_room_admin(db, room, actor)


def require_chat_send(db: Session, room: Room, actor: User | None) -> None:
    require_join(db, room, actor)
