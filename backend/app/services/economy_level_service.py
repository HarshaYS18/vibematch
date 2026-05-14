from datetime import datetime

from fastapi import HTTPException
from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from app.models.economy import EconomyCurrency, EconomyDirection, UserWallet, WalletLedger
from app.models.user import User
from app.services import experience_service
from app.services import level_progression_service as progression

OFFICIAL_RECHARGE_SOURCE_TYPES = {
    "OFFICIAL_RECHARGE",
    "SELLER_COIN_SALE",
    "MERCHANT_COIN_SALE",
    "OWNER_RECHARGE",
    "FOUNDER_RECHARGE",
}


def get_or_create_wallet(db: Session, user_id: int) -> UserWallet:
    wallet = db.query(UserWallet).filter(UserWallet.user_id == user_id).first()
    if wallet:
        return wallet
    wallet = UserWallet(user_id=user_id)
    db.add(wallet)
    db.flush()
    return wallet


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


def wallet_level_payload(db: Session, wallet: UserWallet) -> dict:
    recharge = recharge_exp_totals(db, wallet.user_id)
    user_exp = experience_service.get_or_create_user_exp(db, wallet.user_id)
    return {
        "lifetime_recharge_coin_exp": recharge["lifetime"],
        "monthly_recharge_coin_exp": recharge["monthly"],
        "vip": progression.vip_payload(recharge["lifetime"]),
        "svip": progression.svip_payload(recharge["monthly"]),
        "sent": progression.send_payload(user_exp.send_total_exp),
        "received": progression.receive_payload(user_exp.receive_total_exp),
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
    return {
        "target": target,
        "wallet": wallet,
        "levels": wallet_level_payload(db, wallet),
        "payment_amount": payment_amount,
        "payment_currency": payment_currency,
    }
