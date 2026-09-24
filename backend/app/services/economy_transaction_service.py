from __future__ import annotations

from datetime import datetime
import hashlib
import json
from typing import Any
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.economy import EconomyCurrency, EconomyDirection, UserWallet, WalletLedger
from app.models.economy_journal import EconomyJournalEntry
from app.models.economy_transaction import EconomyTransaction
from app.services import event_outbox_service

def _hash(payload: dict[str, Any]) -> str:
    return hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":"), default=str).encode()).hexdigest()

def begin(db: Session, *, transaction_id: str, idempotency_key: str, business_reference: str, operation_type: str, actor_user_id: int | None, request_payload: dict[str, Any]):
    for value, field in ((transaction_id,"transaction_id"),(idempotency_key,"idempotency_key"),(business_reference,"business_reference")):
        if not str(value or "").strip():
            raise HTTPException(status_code=400, detail=f"{field} is required")
    request_hash=_hash(request_payload)
    existing=db.query(EconomyTransaction).filter(EconomyTransaction.idempotency_key==idempotency_key).with_for_update().first()
    if existing is not None:
        if existing.request_hash != request_hash or existing.transaction_id != transaction_id:
            raise HTTPException(status_code=409, detail="Idempotency key reused with different request")
        if existing.status=="COMPLETED" and existing.result_json:
            return existing, json.loads(existing.result_json)
        raise HTTPException(status_code=409, detail="Economy transaction is already in progress")

    transaction_reuse=db.query(EconomyTransaction).filter(EconomyTransaction.transaction_id==transaction_id).with_for_update().first()
    if transaction_reuse is not None:
        raise HTTPException(status_code=409, detail="transaction_id is already bound to another idempotency key")
    tx=EconomyTransaction(transaction_id=transaction_id,idempotency_key=idempotency_key,business_reference=business_reference,operation_type=operation_type,request_hash=request_hash,status="PENDING",actor_user_id=actor_user_id)
    db.add(tx); db.flush()
    return tx, None

def record_balanced_transfer(
    db: Session,
    *,
    tx: EconomyTransaction,
    currency: str,
    amount: int,
    debit_account: str,
    credit_account: str,
    source_type: str,
    debit_user_id: int | None = None,
    credit_user_id: int | None = None,
) -> None:
    """Append a balanced debit/credit pair inside the caller's transaction."""

    amount = int(amount or 0)
    if amount <= 0:
        raise HTTPException(status_code=400, detail="journal amount must be positive")
    for direction, account_code, user_id in (
        ("DEBIT", debit_account, debit_user_id),
        ("CREDIT", credit_account, credit_user_id),
    ):
        db.add(
            EconomyJournalEntry(
                economy_transaction_id=tx.id,
                transaction_id=tx.transaction_id,
                business_reference=tx.business_reference,
                currency_type=currency,
                account_code=account_code[:160],
                direction=direction,
                amount=amount,
                user_id=user_id,
                source_type=source_type[:80],
            )
        )


def _assert_journal_balanced(db: Session, tx: EconomyTransaction) -> None:
    rows = (
        db.query(
            EconomyJournalEntry.currency_type,
            EconomyJournalEntry.direction,
            EconomyJournalEntry.amount,
        )
        .filter(EconomyJournalEntry.economy_transaction_id == tx.id)
        .all()
    )
    if not rows:
        return

    totals: dict[str, dict[str, int]] = {}
    for currency, direction, amount in rows:
        bucket = totals.setdefault(str(currency), {"DEBIT": 0, "CREDIT": 0})
        bucket[str(direction)] = bucket.get(str(direction), 0) + int(amount or 0)

    unbalanced = {
        currency: values
        for currency, values in totals.items()
        if values.get("DEBIT", 0) != values.get("CREDIT", 0)
    }
    if unbalanced:
        raise HTTPException(
            status_code=500,
            detail="Economy journal is unbalanced; transaction was not committed",
        )


def wallet_for_update(db: Session, user_id: int) -> UserWallet:
    wallet=db.query(UserWallet).filter(UserWallet.user_id==int(user_id)).with_for_update().first()
    if wallet is None:
        wallet=UserWallet(user_id=int(user_id)); db.add(wallet); db.flush()
    return wallet

def debit(db: Session, *, user_id:int, amount:int, currency:str, source_type:str, source_id:str|None, reason:str|None, tx:EconomyTransaction, actor_user_id:int|None) -> UserWallet:
    amount=int(amount or 0)
    if amount<=0: raise HTTPException(status_code=400, detail="amount must be positive")
    wallet=wallet_for_update(db,user_id)
    if currency==EconomyCurrency.COIN.value:
        before=int(wallet.coin_balance or 0)
        if before<amount: raise HTTPException(status_code=400, detail="Insufficient coins. Please recharge.")
        wallet.coin_balance=before-amount; wallet.lifetime_coins_spent+=amount; after=wallet.coin_balance
    elif currency==EconomyCurrency.RUBY.value:
        before=int(wallet.ruby_balance or 0)
        if before<amount: raise HTTPException(status_code=400, detail="Insufficient ruby balance")
        wallet.ruby_balance=before-amount; after=wallet.ruby_balance
    else: raise HTTPException(status_code=400, detail="Unsupported currency")
    db.add(WalletLedger(user_id=user_id,currency_type=currency,direction=EconomyDirection.DEBIT.value,amount=amount,before_balance=before,after_balance=after,source_type=source_type,source_id=source_id,transaction_id=tx.transaction_id,idempotency_key=tx.idempotency_key,business_reference=tx.business_reference,created_by_user_id=actor_user_id,reason=reason))
    record_balanced_transfer(
        db,
        tx=tx,
        currency=currency,
        amount=amount,
        debit_account=f"USER_WALLET:{user_id}:{currency}",
        credit_account=f"SYSTEM_CLEARING:{source_type}:{currency}",
        source_type=source_type,
        debit_user_id=user_id,
    )
    return wallet

def credit(db: Session, *, user_id:int, amount:int, currency:str, source_type:str, source_id:str|None, reason:str|None, tx:EconomyTransaction, actor_user_id:int|None, metadata_json:str|None=None) -> UserWallet:
    amount=int(amount or 0)
    if amount<0: raise HTTPException(status_code=400, detail="amount cannot be negative")
    wallet=wallet_for_update(db,user_id)
    if amount==0: return wallet
    if currency==EconomyCurrency.COIN.value:
        before=int(wallet.coin_balance or 0); wallet.coin_balance=before+amount; after=wallet.coin_balance
    elif currency==EconomyCurrency.RUBY.value:
        before=int(wallet.ruby_balance or 0); wallet.ruby_balance=before+amount; wallet.lifetime_rubies_earned+=amount; after=wallet.ruby_balance
    else: raise HTTPException(status_code=400, detail="Unsupported currency")
    db.add(WalletLedger(user_id=user_id,currency_type=currency,direction=EconomyDirection.CREDIT.value,amount=amount,before_balance=before,after_balance=after,source_type=source_type,source_id=source_id,transaction_id=tx.transaction_id,idempotency_key=tx.idempotency_key,business_reference=tx.business_reference,created_by_user_id=actor_user_id,reason=reason,metadata_json=metadata_json))
    record_balanced_transfer(
        db,
        tx=tx,
        currency=currency,
        amount=amount,
        debit_account=f"SYSTEM_CLEARING:{source_type}:{currency}",
        credit_account=f"USER_WALLET:{user_id}:{currency}",
        source_type=source_type,
        credit_user_id=user_id,
    )
    return wallet

def complete(db: Session, *, tx:EconomyTransaction, result:dict[str,Any], event_type:str, event_payload:dict[str,Any]):
    db.flush()
    _assert_journal_balanced(db, tx)
    tx.status="COMPLETED"; tx.completed_at=datetime.utcnow(); tx.result_json=json.dumps(result,separators=(",",":"),default=str)
    event_outbox_service.enqueue_event(db,event_type=event_type,actor_user_id=tx.actor_user_id,payload={"transaction_id":tx.transaction_id,"idempotency_key":tx.idempotency_key,"business_reference":tx.business_reference,**event_payload})
    db.commit()
    return result
