from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any, Callable

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.economy import GiftTransaction, UserWallet
from app.models.experience import RoomExperienceStatus, UserExperienceStatus
from app.models.room import Room
from app.models.room_participant import RoomParticipant
from app.models.room_realtime_state import RoomSeatState
from app.models.user import User
from app.models.vip_status import UserVipStatus
from app.services import profile_service
from app.services.role_badge_service import get_primary_role_badge, get_role_badges
from app.services.role_service import get_primary_role, get_user_roles


def _iso(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


def _safe(section_name: str, default: Any, builder: Callable[[], Any]) -> Any:
    try:
        return builder()
    except Exception as exc:
        return {"status": "unavailable", "section": section_name, "error": str(exc), "data": default}


def _identity(user: User) -> dict[str, Any]:
    return {
        "backend_user_id": user.id,
        "user_id": user.id,
        "public_user_id": user.public_user_id,
        "display_custom_id": user.display_custom_id,
        "visible_user_id": user.display_custom_id or user.public_user_id,
        "username": user.username,
        "display_name": user.display_name or user.username or f"User {user.public_user_id}",
        "avatar_url": user.avatar_url,
        "bio": user.bio,
        "official_handle": user.official_handle,
        "is_active": user.is_active,
        "is_banned": user.is_banned,
        "is_protected": user.is_protected,
        "created_at": _iso(user.created_at),
        "updated_at": _iso(user.updated_at),
        "last_seen_at": _iso(user.last_seen_at),
    }


def _user_role_badge() -> dict[str, Any]:
    return {
        "role": "user",
        "display_title": "Member",
        "badge_label": "Member",
        "pill_label": "Member",
        "group": "user",
        "priority": 0,
        "icon": "person",
        "background_color": "#F3EEF7",
        "text_color": "#5B176A",
        "border_color": "#E6D8EA",
        "show_verified_tick": False,
    }


def _roles_default() -> dict[str, Any]:
    badge = _user_role_badge()
    return {
        "roles": ["user"],
        "primary_role": "user",
        "primary_role_badge": badge,
        "role_badges": [badge],
    }


def _roles(user: User) -> dict[str, Any]:
    user_roles = get_user_roles(user)
    primary_role = get_primary_role(user)
    primary_badge = get_primary_role_badge(primary_role)
    role_badges = get_role_badges(user_roles)
    if primary_badge is None:
        return _roles_default()
    return {
        "roles": [role.value for role in user_roles] or ["user"],
        "primary_role": primary_role.value,
        "primary_role_badge": primary_badge.model_dump(),
        "role_badges": [badge.model_dump() for badge in role_badges] or [primary_badge.model_dump()],
    }


def _vip_default() -> dict[str, Any]:
    return {
        "vip_level": 0,
        "vip_is_active": False,
        "vip_status": "none",
        "svip_level": 0,
        "svip_is_active": False,
        "svip_expires_at": None,
        "updated_at": None,
    }


def _vip(db: Session, user: User) -> dict[str, Any]:
    summary = profile_service.vip_summary(db, user)
    status = db.query(UserVipStatus).filter(UserVipStatus.user_id == user.id).first()
    vip_level = int(summary.get("vip_level") or 0)
    svip_level = int(summary.get("svip_level") or 0)
    vip_active = bool(summary.get("vip_is_active"))
    svip_active = bool(summary.get("svip_is_active"))
    vip_status = "active" if vip_active and vip_level > 0 else ("frozen" if vip_level > 0 else "none")
    return {
        "vip_level": vip_level,
        "vip_is_active": vip_active,
        "vip_status": vip_status,
        "svip_level": svip_level,
        "svip_is_active": svip_active,
        "svip_expires_at": _iso(summary.get("svip_expires_at")),
        "updated_at": _iso(status.updated_at) if status else None,
    }


def _wallet_default() -> dict[str, Any]:
    return {
        "coin_balance": 0,
        "ruby_balance": 0,
        "locked_ruby_balance": 0,
        "pending_withdraw_rubies": 0,
        "lifetime_coins_spent": 0,
        "lifetime_coins_received_as_gifts": 0,
        "lifetime_rubies_earned": 0,
        "lifetime_rubies_withdrawn": 0,
        "updated_at": None,
    }


def _wallet(db: Session, user: User) -> dict[str, Any]:
    wallet = db.query(UserWallet).filter(UserWallet.user_id == user.id).first()
    if wallet is None:
        return _wallet_default()
    return {
        "coin_balance": wallet.coin_balance,
        "ruby_balance": wallet.ruby_balance,
        "locked_ruby_balance": wallet.locked_ruby_balance,
        "pending_withdraw_rubies": wallet.pending_withdraw_rubies,
        "lifetime_coins_spent": wallet.lifetime_coins_spent,
        "lifetime_coins_received_as_gifts": wallet.lifetime_coins_received_as_gifts,
        "lifetime_rubies_earned": wallet.lifetime_rubies_earned,
        "lifetime_rubies_withdrawn": wallet.lifetime_rubies_withdrawn,
        "updated_at": _iso(wallet.updated_at),
    }


def _experience_default() -> dict[str, Any]:
    return {
        "sent_level": 1,
        "received_level": 1,
        "sent_exp_lifetime": 0,
        "received_exp_lifetime": 0,
        "updated_at": None,
    }


def _experience(db: Session, user: User) -> dict[str, Any]:
    status = db.query(UserExperienceStatus).filter(UserExperienceStatus.user_id == user.id).first()
    if status is None:
        return _experience_default()
    return {
        "sent_level": status.send_level,
        "received_level": status.receive_level,
        "sent_exp_lifetime": status.send_total_exp,
        "received_exp_lifetime": status.receive_total_exp,
        "last_source_type": status.last_source_type,
        "last_source_id": status.last_source_id,
        "updated_at": _iso(status.updated_at),
    }


def _sent_sum(db: Session, user_id: int, since: datetime | None = None) -> int:
    query = db.query(func.coalesce(func.sum(GiftTransaction.total_coin_value), 0)).filter(GiftTransaction.sender_user_id == user_id)
    if since is not None:
        query = query.filter(GiftTransaction.created_at >= since)
    return int(query.scalar() or 0)


def _received_sum(db: Session, user_id: int, since: datetime | None = None) -> int:
    query = db.query(func.coalesce(func.sum(GiftTransaction.total_coin_value), 0)).filter(GiftTransaction.receiver_user_id == user_id)
    if since is not None:
        query = query.filter(GiftTransaction.created_at >= since)
    return int(query.scalar() or 0)


def _contribution_default() -> dict[str, Any]:
    zero = {"daily": 0, "weekly": 0, "monthly": 0, "yearly": 0, "lifetime": 0}
    return {"sent": dict(zero), "received": dict(zero)}


def _contribution(db: Session, user: User) -> dict[str, Any]:
    now = datetime.utcnow()
    windows = {
        "daily": now - timedelta(days=1),
        "weekly": now - timedelta(days=7),
        "monthly": now - timedelta(days=30),
        "yearly": now - timedelta(days=365),
        "lifetime": None,
    }
    sent = {name: _sent_sum(db, user.id, since) for name, since in windows.items()}
    received = {name: _received_sum(db, user.id, since) for name, since in windows.items()}
    return {"sent": sent, "received": received}


def _room_presence(db: Session, user: User) -> dict[str, Any] | None:
    participant = (
        db.query(RoomParticipant)
        .filter(RoomParticipant.user_id == user.id, RoomParticipant.is_active.is_(True))
        .order_by(RoomParticipant.last_seen_at.desc())
        .first()
    )
    if participant is None:
        return None
    room = participant.room
    seat = db.query(RoomSeatState).filter(RoomSeatState.room_id == participant.room_id, RoomSeatState.occupant_user_id == user.id).first()
    is_host = room.owner_user_id == user.id if room else False
    room_exp = db.query(RoomExperienceStatus).filter(RoomExperienceStatus.room_id == participant.room_id).first()
    return {
        "room_id": room.room_public_id if room else None,
        "database_room_id": participant.room_id,
        "room_user_key": f"room:{room.room_public_id}:user:{user.id}" if room else None,
        "peer_id": f"{room.room_public_id}_user_{user.public_user_id}" if room else None,
        "room_name": room.name if room else None,
        "is_host": is_host,
        "is_room_admin": participant.is_room_admin or is_host,
        "seat_index": seat.seat_index if seat else None,
        "mic_enabled": seat.mic_enabled if seat else False,
        "admin_muted": seat.admin_muted if seat else False,
        "joined_at": _iso(participant.joined_at),
        "last_seen_at": _iso(participant.last_seen_at),
        "room_level": room_exp.level if room_exp else 1,
        "room_exp": room_exp.total_exp if room_exp else 0,
    }


def _owned_room(db: Session, user: User) -> dict[str, Any] | None:
    room = db.query(Room).filter(Room.owner_user_id == user.id).order_by(Room.created_at.asc()).first()
    if room is None:
        return None
    room_exp = db.query(RoomExperienceStatus).filter(RoomExperienceStatus.room_id == room.id).first()
    return {
        "room_id": room.room_public_id,
        "database_room_id": room.id,
        "name": room.name,
        "room_level": room_exp.level if room_exp else 1,
        "room_exp": room_exp.total_exp if room_exp else 0,
        "online_count": room.online_count,
        "updated_at": _iso(room.updated_at),
    }


def _profile_summary_default() -> dict[str, Any]:
    return {
        "vip": _vip_default(),
        "wallet": _wallet_default(),
        "equipped_items": {},
    }


def _profile_summary(db: Session, user: User) -> dict[str, Any]:
    return {
        "vip": profile_service.vip_summary(db, user),
        "wallet": profile_service.wallet_summary(db, user),
        "equipped_items": profile_service.equipped_items_summary(db, user),
    }


def get_user_master_state(db: Session, user: User) -> dict[str, Any]:
    """Production read model for the full user state.

    The users table remains identity-only. Wallet, VIP, room presence, EXP,
    contribution and profile equipment data keep their own child table owners.
    If a child section has no row yet, the endpoint still returns a complete
    master-state object with safe defaults instead of falling back to older APIs.
    """
    generated_at = datetime.utcnow()
    return {
        "version": int(generated_at.timestamp()),
        "generated_at": generated_at.isoformat(),
        "identity": _identity(user),
        "roles": _safe("roles", _roles_default(), lambda: _roles(user)),
        "vip": _safe("vip", _vip_default(), lambda: _vip(db, user)),
        "wallet": _safe("wallet", _wallet_default(), lambda: _wallet(db, user)),
        "experience": _safe("experience", _experience_default(), lambda: _experience(db, user)),
        "contribution": _safe("contribution", _contribution_default(), lambda: _contribution(db, user)),
        "room_presence": _safe("room_presence", None, lambda: _room_presence(db, user)),
        "owned_room": _safe("owned_room", None, lambda: _owned_room(db, user)),
        "profile_summary": _safe("profile_summary", _profile_summary_default(), lambda: _profile_summary(db, user)),
    }
