from datetime import datetime

from fastapi import HTTPException
from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from app.models.economy import EconomyCurrency, EconomyDirection, GiftTransaction, UserWallet, WalletLedger
from app.models.experience import UserExperienceStatus
from app.models.user import User
from app.models.vip_status import UserVipOverride, UserVipStatus
from app.services import economy_rules_service, economy_service
from app.services import level_progression_service as progression
from app.services.event_outbox_service import enqueue_event
from app.services.get_or_create_service import get_or_create_unique

OFFICIAL_RECHARGE_SOURCE_TYPES = {
    "RECHARGE",
    "OFFICIAL_RECHARGE",
    "SELLER_COIN_SALE",
    "MERCHANT_COIN_SALE",
    "OWNER_RECHARGE",
    "FOUNDER_RECHARGE",
    "ROLE_COIN_SALE",
}


def get_or_create_wallet(db: Session, user_id: int) -> UserWallet:
    """Compatibility wrapper around the canonical economy wallet repository."""
    return economy_service.get_or_create_wallet(db, user_id)


def _current_month_filter(query):
    now = datetime.utcnow()
    return query.filter(
        extract("year", GiftTransaction.created_at) == now.year,
        extract("month", GiftTransaction.created_at) == now.month,
    )


def monthly_gift_coin_totals(db: Session, user_id: int) -> dict[str, int]:
    sent_query = db.query(func.coalesce(func.sum(GiftTransaction.total_coin_value), 0)).filter(
        GiftTransaction.sender_user_id == user_id,
    )
    received_query = db.query(func.coalesce(func.sum(GiftTransaction.total_coin_value), 0)).filter(
        GiftTransaction.receiver_user_id == user_id,
    )
    return {
        "sent": int(_current_month_filter(sent_query).scalar() or 0),
        "received": int(_current_month_filter(received_query).scalar() or 0),
    }


def recharge_exp_totals(db: Session, user_id: int) -> dict[str, int]:
    now = datetime.utcnow()
    base_query = db.query(func.coalesce(func.sum(WalletLedger.amount), 0)).filter(
        WalletLedger.user_id == user_id,
        WalletLedger.currency_type == EconomyCurrency.COIN.value,
        WalletLedger.direction == EconomyDirection.CREDIT.value,
        WalletLedger.source_type.in_(OFFICIAL_RECHARGE_SOURCE_TYPES),
    )
    lifetime = int(base_query.scalar() or 0)
    monthly = int(
        base_query.filter(
            extract("year", WalletLedger.created_at) == now.year,
            extract("month", WalletLedger.created_at) == now.month,
        ).scalar()
        or 0
    )
    return {"lifetime": lifetime, "monthly": monthly}


def _next_month_start() -> datetime:
    now = datetime.utcnow()
    year = now.year + (1 if now.month == 12 else 0)
    month = 1 if now.month == 12 else now.month + 1
    return datetime(year, month, 1)


def _effective_vip_values(
    db: Session,
    *,
    user_id: int,
    derived_vip_level: int,
    derived_svip_level: int,
) -> dict[str, object]:
    override = (
        db.query(UserVipOverride)
        .filter(
            UserVipOverride.user_id == user_id,
            UserVipOverride.is_active.is_(True),
        )
        .first()
    )
    if override is None:
        return {
            "vip_level": derived_vip_level,
            "svip_level": derived_svip_level,
            "vip_is_active": derived_vip_level > 0,
            "svip_is_active": derived_svip_level > 0,
            "svip_expires_at": (
                _next_month_start() if derived_svip_level > 0 else None
            ),
            "updated_by_user_id": None,
            "update_reason": "Recharge ledger VIP/SVIP sync",
            "override": None,
        }

    svip_active = bool(override.svip_is_active and override.svip_level > 0)
    if (
        svip_active
        and override.svip_expires_at is not None
        and override.svip_expires_at <= datetime.utcnow()
    ):
        svip_active = False
    return {
        "vip_level": int(override.vip_level or 0),
        "svip_level": int(override.svip_level or 0),
        "vip_is_active": bool(
            override.vip_is_active and int(override.vip_level or 0) > 0
        ),
        "svip_is_active": svip_active,
        "svip_expires_at": (
            override.svip_expires_at if svip_active else None
        ),
        "updated_by_user_id": override.updated_by_user_id,
        "update_reason": override.update_reason or "Economy VIP manual override",
        "override": override,
    }


def sync_vip_status(
    db: Session,
    user_id: int,
    levels: dict | None = None,
    *,
    actor_user_id: int | None = None,
    request_id: str | None = None,
) -> UserVipStatus:
    safe_levels = levels
    if safe_levels is None:
        safe_levels = user_level_payload(db, user_id)

    derived_vip_level = int((safe_levels.get("vip") or {}).get("level") or 0)
    derived_svip_level = int((safe_levels.get("svip") or {}).get("level") or 0)
    effective = _effective_vip_values(
        db,
        user_id=user_id,
        derived_vip_level=derived_vip_level,
        derived_svip_level=derived_svip_level,
    )

    status = get_or_create_unique(
        db,
        UserVipStatus,
        UserVipStatus.user_id,
        user_id,
    )
    before = (
        int(status.vip_level or 0),
        int(status.svip_level or 0),
        bool(status.vip_is_active),
        bool(status.svip_is_active),
        status.svip_expires_at,
    )

    status.vip_level = int(effective["vip_level"])
    status.svip_level = int(effective["svip_level"])
    status.vip_is_active = bool(effective["vip_is_active"])
    status.svip_is_active = bool(effective["svip_is_active"])
    status.svip_expires_at = effective["svip_expires_at"]
    status.updated_by_user_id = effective["updated_by_user_id"] or actor_user_id
    status.update_reason = str(effective["update_reason"])
    db.flush()

    after = (
        int(status.vip_level or 0),
        int(status.svip_level or 0),
        bool(status.vip_is_active),
        bool(status.svip_is_active),
        status.svip_expires_at,
    )
    if before != after:
        enqueue_event(
            db,
            event_type="economy.vip_projection.updated.v1",
            actor_user_id=actor_user_id,
            request_id=request_id,
            payload={
                "user_id": user_id,
                "vip_level": status.vip_level,
                "svip_level": status.svip_level,
                "vip_is_active": status.vip_is_active,
                "svip_is_active": status.svip_is_active,
                "svip_expires_at": (
                    status.svip_expires_at.isoformat()
                    if status.svip_expires_at is not None
                    else None
                ),
                "source": (
                    "manual_override"
                    if effective["override"] is not None
                    else "derived_recharge"
                ),
            },
        )
    return status


def set_vip_override(
    db: Session,
    *,
    user_id: int,
    actor_user_id: int,
    vip_level: int,
    svip_level: int,
    vip_is_active: bool,
    svip_is_active: bool,
    svip_expires_at: datetime | None,
    reason: str,
    transaction_id: str | None,
    request_id: str | None = None,
) -> UserVipStatus:
    override = (
        db.query(UserVipOverride)
        .filter(UserVipOverride.user_id == user_id)
        .with_for_update()
        .first()
    )
    if override is None:
        override = UserVipOverride(user_id=user_id)
        db.add(override)
        db.flush()

    override.vip_level = int(vip_level)
    override.svip_level = int(svip_level)
    override.vip_is_active = bool(vip_is_active)
    override.svip_is_active = bool(svip_is_active)
    override.svip_expires_at = svip_expires_at
    override.is_active = True
    override.updated_by_user_id = actor_user_id
    override.update_reason = reason
    override.last_transaction_id = transaction_id
    db.flush()

    return sync_vip_status(
        db,
        user_id,
        user_level_payload(db, user_id),
        actor_user_id=actor_user_id,
        request_id=request_id,
    )




def wallet_level_payload(db: Session, wallet: UserWallet) -> dict:
    return user_level_payload(db, wallet.user_id)


def user_level_payload(db: Session, user_id: int) -> dict:
    """Derive public levels without creating wallet or experience rows on reads."""
    recharge = recharge_exp_totals(db, user_id)
    monthly_gifts = monthly_gift_coin_totals(db, user_id)
    user_exp = db.query(UserExperienceStatus).filter(UserExperienceStatus.user_id == user_id).first()
    sent_exp = int(user_exp.send_total_exp or 0) if user_exp else 0
    received_exp = int(user_exp.receive_total_exp or 0) if user_exp else 0
    return {
        "lifetime_recharge_coin_exp": recharge["lifetime"],
        "monthly_recharge_coin_exp": recharge["monthly"],
        "monthly_gift_coins_sent": monthly_gifts["sent"],
        "monthly_gift_coins_received": monthly_gifts["received"],
        "lifetime_send_exp": sent_exp,
        "lifetime_receive_exp": received_exp,
        "vip": economy_rules_service.progress_payload(db, recharge["lifetime"], "vip"),
        "svip": economy_rules_service.progress_payload(db, recharge["monthly"], "svip"),
        "sent": economy_rules_service.progress_payload(db, sent_exp, "send"),
        "received": economy_rules_service.progress_payload(db, received_exp, "receive"),
    }


def credit_official_recharge(
    db: Session,
    *,
    actor: User,
    target_user_id: int | None,
    target_public_user_id: int | None,
    coin_amount: int,
    payment_amount: int,
    payment_currency: str,
    reason: str,
    proof_url: str | None,
) -> dict:
    if target_user_id is None and target_public_user_id is None:
        raise HTTPException(status_code=400, detail="target_user_id or target_public_user_id is required")

    query = db.query(User)
    target = query.filter(User.id == target_user_id).first() if target_user_id is not None else query.filter(User.public_user_id == target_public_user_id).first()
    if target is None:
        raise HTTPException(status_code=404, detail="Target user not found")

    wallet = get_or_create_wallet(db, target.id)
    before = wallet.coin_balance
    wallet.coin_balance += coin_amount
    after = wallet.coin_balance
    db.add(
        WalletLedger(
            user_id=target.id,
            currency_type=EconomyCurrency.COIN.value,
            direction=EconomyDirection.CREDIT.value,
            amount=coin_amount,
            before_balance=before,
            after_balance=after,
            source_type="OFFICIAL_RECHARGE",
            source_id=None,
            created_by_user_id=actor.id,
            reason=reason,
            metadata_json=(
                f'{{"payment_amount":{payment_amount},"payment_currency":"{payment_currency}",'
                f'"proof_url":"{proof_url or ""}"}}'
            ),
        )
    )
    db.commit()
    db.refresh(wallet)
    levels = wallet_level_payload(db, wallet)
    sync_vip_status(db, target.id, levels)
    db.commit()
    return {
        "target": target,
        "wallet": wallet,
        "levels": levels,
        "payment_amount": payment_amount,
        "payment_currency": payment_currency,
    }
