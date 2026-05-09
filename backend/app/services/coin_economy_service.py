import json
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.coin_economy import (
    CoinBalance,
    CoinBalanceType,
    CoinTransaction,
    CoinTransactionStatus,
    CoinTransactionType,
)
from app.models.role import RoleName
from app.models.user import User
from app.schemas.coin_economy import CoinBalanceResponse, CoinWalletResponse
from app.services.role_service import get_primary_role

MERCHANT_SEND_ROLES = {RoleName.MERCHANT, RoleName.COIN_SELLER, RoleName.RESELLER}
FOUNDER_SUPPLY_ROLES = {RoleName.FOUNDER_OWNER, RoleName.OWNER}


def get_balance(db: Session, *, user_id: int, balance_type: CoinBalanceType) -> CoinBalance:
    balance = (
        db.query(CoinBalance)
        .filter(CoinBalance.user_id == user_id, CoinBalance.balance_type == balance_type)
        .first()
    )
    if balance:
        return balance

    balance = CoinBalance(user_id=user_id, balance_type=balance_type, amount=0, is_locked=False)
    db.add(balance)
    db.commit()
    db.refresh(balance)
    return balance


def get_wallet(db: Session, *, user: User) -> CoinWalletResponse:
    balances = [get_balance(db, user_id=user.id, balance_type=balance_type) for balance_type in CoinBalanceType]
    return CoinWalletResponse(
        user_id=user.id,
        public_user_id=user.public_user_id,
        display_name=user.display_name,
        balances=[
            CoinBalanceResponse(
                user_id=user.id,
                public_user_id=user.public_user_id,
                display_name=user.display_name,
                balance_type=balance.balance_type,
                amount=balance.amount,
                is_locked=balance.is_locked,
            )
            for balance in balances
        ],
    )


def get_user_by_public_id(db: Session, public_user_id: int) -> User:
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Target user not found")
    return user


def _new_tx_id() -> str:
    return f"coin-{uuid4().hex[:16]}"


def _record_transaction(
    db: Session,
    *,
    transaction_type: CoinTransactionType,
    amount: int,
    actor_user_id: int | None,
    from_user_id: int | None = None,
    to_user_id: int | None = None,
    from_balance_type: CoinBalanceType | None = None,
    to_balance_type: CoinBalanceType | None = None,
    reason: str | None = None,
    metadata: dict | None = None,
) -> CoinTransaction:
    tx = CoinTransaction(
        transaction_public_id=_new_tx_id(),
        transaction_type=transaction_type,
        status=CoinTransactionStatus.COMPLETED,
        from_user_id=from_user_id,
        to_user_id=to_user_id,
        from_balance_type=from_balance_type,
        to_balance_type=to_balance_type,
        amount=amount,
        actor_user_id=actor_user_id,
        reason=reason,
        metadata_json=json.dumps(metadata or {}),
    )
    db.add(tx)
    db.commit()
    db.refresh(tx)
    return tx


def founder_grant_coins(
    db: Session,
    *,
    actor: User,
    target: User,
    amount: int,
    target_balance_type: CoinBalanceType,
    reason: str,
) -> CoinTransaction:
    if get_primary_role(actor) not in FOUNDER_SUPPLY_ROLES:
        raise HTTPException(status_code=403, detail="Founder Owner or Owner access required")

    if target_balance_type == CoinBalanceType.FOUNDER_SUPPLY:
        raise HTTPException(status_code=400, detail="Cannot grant founder supply balance to another account")

    balance = get_balance(db, user_id=target.id, balance_type=target_balance_type)
    balance.amount += amount
    db.add(balance)
    db.commit()

    return _record_transaction(
        db,
        transaction_type=CoinTransactionType.FOUNDER_GRANT,
        amount=amount,
        actor_user_id=actor.id,
        from_user_id=actor.id,
        to_user_id=target.id,
        from_balance_type=CoinBalanceType.FOUNDER_SUPPLY,
        to_balance_type=target_balance_type,
        reason=reason,
        metadata={"target_public_user_id": target.public_user_id},
    )


def merchant_send_to_user(
    db: Session,
    *,
    actor: User,
    target: User,
    amount: int,
    reason: str,
) -> CoinTransaction:
    actor_role = get_primary_role(actor)
    if actor_role not in MERCHANT_SEND_ROLES:
        raise HTTPException(status_code=403, detail="Merchant, Coin Seller, or Reseller role required")

    source_type = CoinBalanceType.MERCHANT_SUPPLY if actor_role == RoleName.MERCHANT else CoinBalanceType.SELLER_SUPPLY
    source = get_balance(db, user_id=actor.id, balance_type=source_type)
    if source.amount < amount:
        raise HTTPException(status_code=400, detail="Insufficient merchant/seller supply coins")

    target_balance = get_balance(db, user_id=target.id, balance_type=CoinBalanceType.CONSUMABLE)
    source.amount -= amount
    target_balance.amount += amount
    db.add(source)
    db.add(target_balance)
    db.commit()

    tx_type = CoinTransactionType.MERCHANT_TRANSFER if actor_role == RoleName.MERCHANT else CoinTransactionType.SELLER_TRANSFER
    return _record_transaction(
        db,
        transaction_type=tx_type,
        amount=amount,
        actor_user_id=actor.id,
        from_user_id=actor.id,
        to_user_id=target.id,
        from_balance_type=source_type,
        to_balance_type=CoinBalanceType.CONSUMABLE,
        reason=reason,
        metadata={"target_public_user_id": target.public_user_id, "actor_role": actor_role.value},
    )


def consume_user_coins(db: Session, *, actor: User, amount: int, reason: str) -> CoinTransaction:
    """Only normal consumable balance can be spent in app consumption.

    Merchant/seller supply balances are intentionally excluded so business supply
    cannot be used for gifts/store/games by the same merchant/seller account.
    """

    consumable = get_balance(db, user_id=actor.id, balance_type=CoinBalanceType.CONSUMABLE)
    if consumable.amount < amount:
        raise HTTPException(status_code=400, detail="Insufficient consumable coins")

    consumable.amount -= amount
    db.add(consumable)
    db.commit()

    return _record_transaction(
        db,
        transaction_type=CoinTransactionType.USER_CONSUMPTION,
        amount=amount,
        actor_user_id=actor.id,
        from_user_id=actor.id,
        to_user_id=None,
        from_balance_type=CoinBalanceType.CONSUMABLE,
        to_balance_type=None,
        reason=reason,
        metadata={"rule": "merchant_seller_supply_not_consumable"},
    )


def list_transactions(db: Session, *, user: User, limit: int = 100) -> list[CoinTransaction]:
    return (
        db.query(CoinTransaction)
        .filter((CoinTransaction.from_user_id == user.id) | (CoinTransaction.to_user_id == user.id) | (CoinTransaction.actor_user_id == user.id))
        .order_by(CoinTransaction.id.desc())
        .limit(limit)
        .all()
    )
