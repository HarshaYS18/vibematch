from datetime import datetime

from fastapi import HTTPException
from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from app.models.economy import EconomyCurrency, EconomyDirection, GiftTransaction, UserWallet, WalletLedger
from app.models.user import User
from app.models.vip_status import UserVipStatus
from app.services import economy_rules_service, experience_service
from app.services import level_progression_service as progression

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
    wallet = db.query(UserWallet).filter(UserWallet.user_id == user_id).first()
    if wallet:
        return wallet
    wallet = UserWallet(user_id=user_id)
    db.add(wallet)
    db.flush()
    return wallet


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


def sync_vip_status(db: Session, user_id: int, levels: dict | None = None) -> UserVipStatus:
    safe_levels = levels
    if safe_levels is None:
        wallet = get_or_create_wallet(db, user_id)
        safe_levels = wallet_level_payload(db, wallet)

    vip_level = int((safe_levels.get("vip") or {}).get("level") or 0)
    svip_level = int((safe_levels.get("svip") or {}).get("level") or 0)

    status = db.query(UserVipStatus).filter(UserVipStatus.user_id == user_id).first()
    if status is None:
        status = UserVipStatus(user_id=user_id)
        db.add(status)

    status.vip_level = vip_level
    status.svip_level = svip_level
    status.vip_is_active = vip_level > 0
    status.svip_is_active = svip_level > 0
    status.svip_expires_at = _next_month_start() if svip_level > 0 else None
    status.update_reason = "Recharge ledger VIP/SVIP sync"
    db.flush()
    return status


def wallet_level_payload(db: Session, wallet: UserWallet) -> dict:
    recharge = recharge_exp_totals(db, wallet.user_id)
    monthly_gifts = monthly_gift_coin_totals(db, wallet.user_id)
    user_exp = experience_service.get_or_create_user_exp(db, wallet.user_id)
    return {
        "lifetime_recharge_coin_exp": recharge["lifetime"],
        "monthly_recharge_coin_exp": recharge["monthly"],
        "monthly_gift_coins_sent": monthly_gifts["sent"],
        "monthly_gift_coins_received": monthly_gifts["received"],
        "lifetime_send_exp": user_exp.send_total_exp,
        "lifetime_receive_exp": user_exp.receive_total_exp,
        "vip": economy_rules_service.progress_payload(db, recharge["lifetime"], "vip"),
        "svip": economy_rules_service.progress_payload(db, recharge["monthly"], "svip"),
        "sent": economy_rules_service.progress_payload(db, user_exp.send_total_exp, "send"),
        "received": economy_rules_service.progress_payload(db, user_exp.receive_total_exp, "receive"),
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
