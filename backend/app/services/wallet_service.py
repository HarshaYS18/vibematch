from __future__ import annotations

from dataclasses import dataclass

from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.wallet import (
    GameHousePool,
    GameLedgerEntry,
    Wallet,
    WalletCurrency,
    WalletLedgerDirection,
    WalletLedgerEntry,
    WalletLedgerSource,
)


@dataclass(frozen=True)
class WalletMoveResult:
    wallet: Wallet
    ledger_entry: WalletLedgerEntry


def get_or_create_wallet(
    db: Session,
    user: User,
    *,
    seed_coins: int = 25_000,
    seed_rubies: int = 0,
) -> Wallet:
    wallet = db.query(Wallet).filter(Wallet.user_id == user.id).first()
    if wallet:
        return wallet

    wallet = Wallet(
        user_id=user.id,
        coin_balance=seed_coins,
        ruby_balance=seed_rubies,
        lifetime_coin_in=seed_coins,
        lifetime_coin_out=0,
        lifetime_ruby_in=seed_rubies,
        lifetime_ruby_out=0,
    )
    db.add(wallet)
    db.flush()

    if seed_coins > 0:
        db.add(
            WalletLedgerEntry(
                wallet_id=wallet.id,
                user_id=user.id,
                currency=WalletCurrency.COINS,
                direction=WalletLedgerDirection.CREDIT,
                source=WalletLedgerSource.SYSTEM_GRANT,
                amount=seed_coins,
                balance_before=0,
                balance_after=seed_coins,
                reference_type="wallet_seed",
                reference_id=str(user.id),
                idempotency_key=f"wallet_seed:coins:{user.id}",
                reason="MVP starting test coins",
                metadata_json={"seed": True},
            )
        )

    if seed_rubies > 0:
        db.add(
            WalletLedgerEntry(
                wallet_id=wallet.id,
                user_id=user.id,
                currency=WalletCurrency.RUBIES,
                direction=WalletLedgerDirection.CREDIT,
                source=WalletLedgerSource.SYSTEM_GRANT,
                amount=seed_rubies,
                balance_before=0,
                balance_after=seed_rubies,
                reference_type="wallet_seed",
                reference_id=str(user.id),
                idempotency_key=f"wallet_seed:rubies:{user.id}",
                reason="MVP starting test rubies",
                metadata_json={"seed": True},
            )
        )

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        wallet = db.query(Wallet).filter(Wallet.user_id == user.id).first()
        if wallet:
            return wallet
        raise

    db.refresh(wallet)
    return wallet


def _balance_for_currency(wallet: Wallet, currency: WalletCurrency) -> int:
    return wallet.coin_balance if currency == WalletCurrency.COINS else wallet.ruby_balance


def _set_balance_for_currency(wallet: Wallet, currency: WalletCurrency, value: int) -> None:
    if currency == WalletCurrency.COINS:
        wallet.coin_balance = value
    else:
        wallet.ruby_balance = value


def _add_lifetime(wallet: Wallet, currency: WalletCurrency, direction: WalletLedgerDirection, amount: int) -> None:
    if currency == WalletCurrency.COINS:
        if direction == WalletLedgerDirection.CREDIT:
            wallet.lifetime_coin_in += amount
        else:
            wallet.lifetime_coin_out += amount
    else:
        if direction == WalletLedgerDirection.CREDIT:
            wallet.lifetime_ruby_in += amount
        else:
            wallet.lifetime_ruby_out += amount


def move_wallet_balance(
    db: Session,
    *,
    user: User,
    currency: WalletCurrency,
    direction: WalletLedgerDirection,
    source: WalletLedgerSource,
    amount: int,
    idempotency_key: str,
    reference_type: str | None = None,
    reference_id: str | None = None,
    reason: str | None = None,
    metadata_json: dict | None = None,
) -> WalletMoveResult:
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Wallet amount must be greater than zero")

    existing_entry = (
        db.query(WalletLedgerEntry)
        .filter(WalletLedgerEntry.idempotency_key == idempotency_key)
        .first()
    )
    if existing_entry:
        wallet = db.query(Wallet).filter(Wallet.id == existing_entry.wallet_id).first()
        if not wallet:
            raise HTTPException(status_code=500, detail="Wallet ledger is inconsistent")
        return WalletMoveResult(wallet=wallet, ledger_entry=existing_entry)

    wallet = get_or_create_wallet(db, user)
    wallet = (
        db.query(Wallet)
        .filter(Wallet.id == wallet.id)
        .with_for_update()
        .first()
    )
    if not wallet:
        raise HTTPException(status_code=500, detail="Wallet not found")
    if wallet.is_frozen:
        raise HTTPException(status_code=403, detail=wallet.freeze_reason or "Wallet is frozen")

    balance_before = _balance_for_currency(wallet, currency)
    if direction == WalletLedgerDirection.DEBIT:
        if balance_before < amount:
            raise HTTPException(status_code=400, detail="Insufficient wallet balance")
        balance_after = balance_before - amount
    else:
        balance_after = balance_before + amount

    _set_balance_for_currency(wallet, currency, balance_after)
    _add_lifetime(wallet, currency, direction, amount)

    ledger_entry = WalletLedgerEntry(
        wallet_id=wallet.id,
        user_id=user.id,
        currency=currency,
        direction=direction,
        source=source,
        amount=amount,
        balance_before=balance_before,
        balance_after=balance_after,
        reference_type=reference_type,
        reference_id=reference_id,
        idempotency_key=idempotency_key,
        reason=reason,
        metadata_json=metadata_json,
    )

    db.add(wallet)
    db.add(ledger_entry)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        existing_entry = (
            db.query(WalletLedgerEntry)
            .filter(WalletLedgerEntry.idempotency_key == idempotency_key)
            .first()
        )
        if existing_entry:
            wallet = db.query(Wallet).filter(Wallet.id == existing_entry.wallet_id).first()
            if wallet:
                return WalletMoveResult(wallet=wallet, ledger_entry=existing_entry)
        raise

    return WalletMoveResult(wallet=wallet, ledger_entry=ledger_entry)


def get_or_create_game_house_pool(
    db: Session,
    *,
    game_id: str,
    seed_reserve: int = 5_000_000,
) -> GameHousePool:
    pool = db.query(GameHousePool).filter(GameHousePool.game_id == game_id).first()
    if pool:
        return pool

    pool = GameHousePool(
        game_id=game_id,
        coin_reserve=seed_reserve,
        lifetime_coin_in=seed_reserve,
        lifetime_coin_out=0,
        is_active=True,
    )
    db.add(pool)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        pool = db.query(GameHousePool).filter(GameHousePool.game_id == game_id).first()
        if pool:
            return pool
        raise
    db.refresh(pool)
    return pool


def record_game_ledger(
    db: Session,
    *,
    game_id: str,
    user: User,
    session_id: str,
    spin_id: str | None,
    bet_amount: int,
    win_amount: int,
    risk_tier: str | None,
    house_reserve_before: int,
    house_reserve_after: int,
    idempotency_key: str,
    metadata_json: dict | None = None,
) -> GameLedgerEntry:
    existing = db.query(GameLedgerEntry).filter(GameLedgerEntry.idempotency_key == idempotency_key).first()
    if existing:
        return existing

    entry = GameLedgerEntry(
        game_id=game_id,
        user_id=user.id,
        session_id=session_id,
        spin_id=spin_id,
        bet_amount=bet_amount,
        win_amount=win_amount,
        net_amount=win_amount - bet_amount,
        risk_tier=risk_tier,
        house_reserve_before=house_reserve_before,
        house_reserve_after=house_reserve_after,
        idempotency_key=idempotency_key,
        metadata_json=metadata_json,
    )
    db.add(entry)
    db.flush()
    return entry
