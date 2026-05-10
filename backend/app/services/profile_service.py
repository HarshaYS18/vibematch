from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.economy import UserWallet
from app.models.user import User
from app.services import role_badge_service, role_service, vip_status_service

SVIP_NAME_GRADIENTS: dict[int, dict[str, object]] = {
    1: {"key": "svip_1_aqua_violet", "colors": ["#20E3B2", "#7C4DFF", "#E040FB"]},
    2: {"key": "svip_2_sunset_gold", "colors": ["#FF8A00", "#FFD166", "#FF4D6D"]},
    3: {"key": "svip_3_rose_ice", "colors": ["#FF4DCA", "#8EC5FC", "#E0C3FC"]},
    4: {"key": "svip_4_emerald_neon", "colors": ["#00F5A0", "#00D9F5", "#00A3FF"]},
    5: {"key": "svip_5_royal_fire", "colors": ["#F7971E", "#FFD200", "#F953C6"]},
    6: {"key": "svip_6_cosmic_luxe", "colors": ["#8A2BE2", "#00C6FF", "#FFD700"]},
    7: {"key": "svip_7_opal_dream", "colors": ["#A1FFCE", "#FAFFD1", "#FBC2EB"]},
    8: {"key": "svip_8_crimson_star", "colors": ["#FF0844", "#FFB199", "#F9D423"]},
    9: {"key": "svip_9_mythic_aurora", "colors": ["#00DBDE", "#FC00FF", "#FFD700"]},
    10: {"key": "svip_10_founder_glow", "colors": ["#FFD700", "#FFFFFF", "#7F00FF", "#00F5FF"]},
}


def _gradient_for_svip(svip_level: int, is_active: bool) -> dict[str, object]:
    if not is_active or svip_level <= 0:
        return {"key": "default", "colors": []}
    return SVIP_NAME_GRADIENTS.get(min(svip_level, 10), SVIP_NAME_GRADIENTS[10])


def vip_summary(db: Session, user: User) -> dict:
    status = vip_status_service.get_or_create_vip_status(db, user)
    gradient = _gradient_for_svip(status.svip_level, status.svip_is_active)
    return {
        "vip_level": status.vip_level,
        "svip_level": status.svip_level,
        "vip_is_active": status.vip_is_active,
        "svip_is_active": status.svip_is_active,
        "svip_expires_at": status.svip_expires_at,
        "name_gradient_key": str(gradient["key"]),
        "name_gradient_colors": list(gradient["colors"]),
    }


def wallet_summary(db: Session, user: User) -> dict:
    wallet = db.query(UserWallet).filter(UserWallet.user_id == user.id).first()
    if not wallet:
        return {"coin_balance": 0, "ruby_balance": 0, "lifetime_coins_spent": 0, "lifetime_rubies_earned": 0}
    return {
        "coin_balance": wallet.coin_balance,
        "ruby_balance": wallet.ruby_balance,
        "lifetime_coins_spent": wallet.lifetime_coins_spent,
        "lifetime_rubies_earned": wallet.lifetime_rubies_earned,
    }


def public_profile_payload(db: Session, public_user_id: int) -> dict:
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user_roles = role_service.get_user_roles(user)
    primary_role = role_service.get_primary_role(user)
    is_online = False
    if user.last_seen_at:
        is_online = user.last_seen_at >= datetime.utcnow() - timedelta(minutes=2)
    return {
        "public_user_id": user.public_user_id,
        "display_custom_id": user.display_custom_id,
        "username": user.username,
        "display_name": user.display_name,
        "avatar_url": user.avatar_url,
        "primary_role": primary_role.value,
        "primary_role_badge": role_badge_service.get_primary_role_badge(primary_role),
        "role_badges": role_badge_service.get_role_badges(user_roles),
        "vip": vip_summary(db, user),
        "is_online": is_online,
        "last_seen_at": user.last_seen_at,
        "created_at": user.created_at,
    }
