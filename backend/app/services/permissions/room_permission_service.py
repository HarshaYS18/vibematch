from __future__ import annotations

from datetime import datetime

from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.models.role import RoleName
from app.models.special_permission import SpecialPermission, SpecialPermissionName
from app.models.user import User
from app.services.role_service import can_act_on, get_primary_role, is_founder_owner, is_owner_or_above


_SPECIAL_PERMISSION_ENUM_SUPPORT: dict[str, bool] = {}


def _db_supports_special_permission(db: Session, permission: SpecialPermissionName) -> bool:
    bind = db.get_bind()
    if bind.dialect.name != "postgresql":
        return True

    cache_key = permission.value
    cached = _SPECIAL_PERMISSION_ENUM_SUPPORT.get(cache_key)
    if cached is not None:
        return cached

    try:
        supported = bool(
            db.execute(
                text(
                    "select exists("
                    "select 1 from pg_type t "
                    "join pg_enum e on e.enumtypid = t.oid "
                    "where t.typname = 'specialpermissionname' "
                    "and e.enumlabel = :permission"
                    ")"
                ),
                {"permission": permission.value},
            ).scalar()
        )
    except SQLAlchemyError:
        db.rollback()
        supported = False

    _SPECIAL_PERMISSION_ENUM_SUPPORT[cache_key] = supported
    return supported


def has_active_special_permission(db: Session, user: User, permission: SpecialPermissionName) -> bool:
    if not _db_supports_special_permission(db, permission):
        return False
    now = datetime.utcnow()
    return db.query(SpecialPermission).filter(
        SpecialPermission.user_id == user.id,
        SpecialPermission.permission == permission,
        SpecialPermission.is_active.is_(True),
        (SpecialPermission.expires_at.is_(None) | (SpecialPermission.expires_at > now)),
    ).first() is not None


def can_use_hidden_presence(db: Session, user: User) -> bool:
    if is_founder_owner(user):
        return True
    return has_active_special_permission(db, user, SpecialPermissionName.STEALTH_MODE)


def can_force_join_room(db: Session, user: User) -> bool:
    if is_founder_owner(user):
        return True
    return has_active_special_permission(db, user, SpecialPermissionName.ROOM_FORCE_JOIN)


def can_override_locked_room(db: Session, user: User) -> bool:
    if is_owner_or_above(user):
        return True
    return has_active_special_permission(db, user, SpecialPermissionName.ROOM_LOCK_OVERRIDE)


def can_override_secret_room(db: Session, user: User) -> bool:
    if is_owner_or_above(user):
        return True
    return has_active_special_permission(db, user, SpecialPermissionName.SECRET_VIBE_OVERRIDE)


def can_manage_room_admins(db: Session, actor: User, room_owner_user_id: int | None) -> bool:
    if is_founder_owner(actor):
        return True
    if actor.id == room_owner_user_id:
        return True
    return has_active_special_permission(db, actor, SpecialPermissionName.ASSIGN_ROOM_ADMIN)


def can_mute_room_user(db: Session, actor: User, target: User) -> bool:
    if is_founder_owner(target):
        return False
    if is_founder_owner(actor):
        return True
    if has_active_special_permission(db, actor, SpecialPermissionName.UNIVERSAL_MUTE) and can_act_on(actor, target):
        return True
    return can_act_on(actor, target)


def can_kick_room_user(db: Session, actor: User, target: User) -> bool:
    if is_founder_owner(target):
        return False
    if is_founder_owner(actor):
        return True
    if has_active_special_permission(db, actor, SpecialPermissionName.UNIVERSAL_KICK) and can_act_on(actor, target):
        return True
    return can_act_on(actor, target)


def can_change_room_privacy(db: Session, actor: User, room_owner_user_id: int | None) -> bool:
    if is_founder_owner(actor):
        return True
    if actor.id == room_owner_user_id:
        return True
    return get_primary_role(actor) in {RoleName.OWNER, RoleName.SUPERADMIN} or can_override_locked_room(db, actor)


def hidden_presence_flags(db: Session, user: User, requested_hidden: bool) -> dict[str, bool]:
    active = requested_hidden and can_use_hidden_presence(db, user)
    return {
        "is_stealth": active,
        "visible_in_online_count": not active,
        "visible_in_user_list": not active,
        "visible_to_public": not active,
    }
