from __future__ import annotations

from sqlalchemy.orm import Session

from app.models.profile_display import UserStealthState
from app.models.role import RoleName
from app.models.user import User
from app.services import profile_service, role_badge_service, role_service
from app.services.permissions import room_permission_service


def _dump_model(value):
    if value is None:
        return None
    if hasattr(value, "model_dump"):
        return value.model_dump(mode="json")
    if hasattr(value, "dict"):
        return value.dict()
    return value


def get_or_create_stealth_state(db: Session, user_id: int) -> UserStealthState:
    state = db.query(UserStealthState).filter(UserStealthState.user_id == user_id).first()
    if state is not None:
        return state
    state = UserStealthState(user_id=user_id)
    db.add(state)
    db.flush()
    return state


def stealth_enabled_for_user(db: Session, user: User) -> bool:
    if role_service.get_primary_role(user) == RoleName.FOUNDER_OWNER:
        state = db.query(UserStealthState).filter(UserStealthState.user_id == user.id).first()
        return bool(state and state.is_enabled)
    if not room_permission_service.can_use_hidden_presence(db, user):
        return False
    state = db.query(UserStealthState).filter(UserStealthState.user_id == user.id).first()
    return bool(state and state.is_enabled)


def canonical_user_display_payload(
    db: Session,
    user: User,
    *,
    viewer: User | None = None,
    room_role_label: str | None = None,
    is_room_host: bool = False,
    is_room_admin: bool = False,
    is_room_member: bool = False,
    admin_muted: bool = False,
) -> dict:
    roles = role_service.get_user_roles(user)
    primary_role = role_service.get_primary_role(user)
    primary_badge = role_badge_service.get_primary_role_badge(primary_role)
    role_badges = role_badge_service.get_role_badges(roles)
    vip = profile_service.vip_summary(db, user)
    wallet = profile_service.wallet_summary(db, user, include_private_balances=False)
    equipped_items = profile_service.equipped_items_summary(db, user)
    stealth_enabled = stealth_enabled_for_user(db, user)
    viewer_can_see_stealth = viewer is not None and (
        viewer.id == user.id or role_service.get_primary_role(viewer) == RoleName.FOUNDER_OWNER
    )
    role_label = room_role_label
    if not role_label:
        if is_room_host:
            role_label = "Channel Host"
        elif is_room_admin:
            role_label = "Admin"
        elif is_room_member:
            role_label = "Member"
        elif primary_badge is not None:
            role_label = primary_badge.pill_label
        else:
            role_label = "Visitor"

    return {
        "backend_user_id": user.id,
        "public_user_id": user.public_user_id,
        "display_custom_id": user.display_custom_id,
        "username": user.username,
        "display_name": user.display_name or user.username or f"User {user.public_user_id}",
        "avatar_url": user.avatar_url,
        "cover_photo_url": (user.cover_photo_urls or [None])[0],
        "cover_photo_urls": user.cover_photo_urls or [],
        "official_handle": user.official_handle,
        "primary_role": primary_role.value,
        "primary_role_badge": _dump_model(primary_badge),
        "role_badges": [_dump_model(item) for item in role_badges],
        "official_role_badge": _dump_model(primary_badge),
        "verified_official": bool(primary_badge and primary_badge.show_verified_tick),
        "room_role_label": role_label,
        "is_room_host": is_room_host,
        "is_room_admin": is_room_admin,
        "is_room_member": is_room_member,
        "admin_muted": admin_muted,
        "vip": vip,
        "svip_level": int(vip.get("svip_level") or 0),
        "vip_level": int(vip.get("vip_level") or 0),
        "sent_level": int(wallet.get("sent_level") or 0),
        "received_level": int(wallet.get("receive_level") or 0),
        "monthly_sent_coins": int(wallet.get("monthly_gift_coins_sent") or 0),
        "monthly_received_coins": int(wallet.get("monthly_gift_coins_received") or 0),
        "total_sent_coins": int(wallet.get("lifetime_send_exp") or 0),
        "total_received_coins": int(wallet.get("lifetime_receive_exp") or 0),
        "name_gradient": {
            "key": vip.get("name_gradient_key") or "default",
            "colors": vip.get("name_gradient_colors") or [],
        },
        "equipped_items": equipped_items,
        "profile_assets": {
            "avatar_frame": equipped_items.get("avatar_frame"),
            "text_bubble": equipped_items.get("chat_bubble"),
            "chat_bubble": equipped_items.get("chat_bubble"),
            "entrance_effect": equipped_items.get("entrance_effect"),
            "profile_decoration": equipped_items.get("profile_decoration"),
            "name_gradient": {
                "key": vip.get("name_gradient_key") or "default",
                "colors": vip.get("name_gradient_colors") or [],
            },
        },
        "stealth": {
            "visible_to_viewer": not stealth_enabled or viewer_can_see_stealth,
            "is_enabled": stealth_enabled if viewer_can_see_stealth else False,
            "publicly_hidden": stealth_enabled,
        },
    }

