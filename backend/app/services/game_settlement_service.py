from __future__ import annotations

import json
from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.economy import EconomyCurrency, EconomyDirection, UserWallet, WalletLedger
from app.models.economy_stats import UserGameStats
from app.services import house_pool_service, whale_risk_service


def _get_or_create_wallet_for_update(db: Session, user_id: int) -> UserWallet:
    wallet = db.query(UserWallet).filter(UserWallet.user_id == user_id).with_for_update().first()
    if wallet is not None:
        return wallet
    wallet = UserWallet(user_id=user_id)
    db.add(wallet)
    db.flush()
    return wallet


def debit_user_game_wager(
    db: Session,
    *,
    user_id: int,
    amount: int,
    game_id: str,
    round_id: str | None,
) -> UserWallet:
    safe_amount = int(amount or 0)
    if safe_amount <= 0:
        raise HTTPException(status_code=400, detail="wager_amount must be positive")
    wallet = _get_or_create_wallet_for_update(db, user_id)
    before = int(wallet.coin_balance or 0)
    if before < safe_amount:
        raise HTTPException(status_code=400, detail="Insufficient coins. Please recharge.")
    wallet.coin_balance = before - safe_amount
    wallet.lifetime_coins_spent += safe_amount
    db.add(
        WalletLedger(
            user_id=user_id,
            currency_type=EconomyCurrency.COIN.value,
            direction=EconomyDirection.DEBIT.value,
            amount=safe_amount,
            before_balance=before,
            after_balance=wallet.coin_balance,
            source_type="COIN_GAME_WAGER",
            source_id=round_id,
            created_by_user_id=user_id,
            reason=f"Coin game wager: {game_id}",
        )
    )
    db.flush()
    return wallet


def credit_user_game_winnings(
    db: Session,
    *,
    user_id: int,
    amount: int,
    game_id: str,
    round_id: str | None,
) -> UserWallet:
    safe_amount = int(amount or 0)
    wallet = _get_or_create_wallet_for_update(db, user_id)
    if safe_amount <= 0:
        return wallet
    before = int(wallet.coin_balance or 0)
    wallet.coin_balance = before + safe_amount
    db.add(
        WalletLedger(
            user_id=user_id,
            currency_type=EconomyCurrency.COIN.value,
            direction=EconomyDirection.CREDIT.value,
            amount=safe_amount,
            before_balance=before,
            after_balance=wallet.coin_balance,
            source_type="COIN_GAME_WINNING",
            source_id=round_id,
            created_by_user_id=user_id,
            reason=f"Coin game winnings: {game_id}",
        )
    )
    db.flush()
    return wallet


def get_or_create_user_game_stats(db: Session, *, user_id: int, game_id: str) -> UserGameStats:
    stats = db.query(UserGameStats).filter(UserGameStats.user_id == user_id, UserGameStats.game_id == game_id).first()
    if stats is not None:
        return stats
    stats = UserGameStats(user_id=user_id, game_id=game_id)
    db.add(stats)
    db.flush()
    return stats


def update_user_game_stats(
    db: Session,
    *,
    user_id: int,
    game_id: str,
    wager_amount: int,
    win_amount: int,
    loss_amount: int,
    net_amount: int,
    multiplier: int = 0,
) -> UserGameStats:
    stats = get_or_create_user_game_stats(db, user_id=user_id, game_id=game_id)
    safe_wager = max(int(wager_amount or 0), 0)
    safe_win = max(int(win_amount or 0), 0)
    safe_loss = max(int(loss_amount or 0), 0)
    safe_net = int(net_amount or 0)
    safe_multiplier = max(int(multiplier or 0), 0)

    for prefix in ("daily", "weekly", "monthly", "all_time"):
        setattr(stats, f"{prefix}_bid_amount", getattr(stats, f"{prefix}_bid_amount") + safe_wager)
        setattr(stats, f"{prefix}_win_amount", getattr(stats, f"{prefix}_win_amount") + safe_win)
        setattr(stats, f"{prefix}_loss_amount", getattr(stats, f"{prefix}_loss_amount") + safe_loss)
        setattr(stats, f"{prefix}_net_amount", getattr(stats, f"{prefix}_net_amount") + safe_net)
    stats.rounds_played_daily += 1
    stats.rounds_played_monthly += 1
    stats.best_multiplier = max(stats.best_multiplier, safe_multiplier)
    db.flush()
    return stats


def game_stats_payload(stats: UserGameStats) -> dict[str, Any]:
    return {
        "user_id": stats.user_id,
        "game_id": stats.game_id,
        "daily": {
            "total_wager_amount": stats.daily_bid_amount,
            "total_win_amount": stats.daily_win_amount,
            "total_loss_amount": stats.daily_loss_amount,
            "net_amount": stats.daily_net_amount,
            "rounds_played": stats.rounds_played_daily,
        },
        "weekly": {
            "total_wager_amount": stats.weekly_bid_amount,
            "total_win_amount": stats.weekly_win_amount,
            "total_loss_amount": stats.weekly_loss_amount,
            "net_amount": stats.weekly_net_amount,
        },
        "monthly": {
            "total_wager_amount": stats.monthly_bid_amount,
            "total_win_amount": stats.monthly_win_amount,
            "total_loss_amount": stats.monthly_loss_amount,
            "net_amount": stats.monthly_net_amount,
            "rounds_played": stats.rounds_played_monthly,
        },
        "all_time": {
            "total_wager_amount": stats.all_time_bid_amount,
            "total_win_amount": stats.all_time_win_amount,
            "total_loss_amount": stats.all_time_loss_amount,
            "net_amount": stats.all_time_net_amount,
        },
        "best_multiplier": stats.best_multiplier,
    }


def create_coin_game_wager(
    db: Session,
    *,
    user_id: int,
    game_id: str,
    round_id: str | None,
    wager_amount: int,
    metadata: dict[str, Any] | None = None,
) -> dict[str, Any]:
    try:
        wallet = debit_user_game_wager(db, user_id=user_id, amount=wager_amount, game_id=game_id, round_id=round_id)
        reserve = house_pool_service.reserve_house_liability(
            db,
            pool_type="GAME_HOUSE_POOL",
            amount=int(wager_amount or 0),
            reference_type="COIN_GAME_WAGER",
            reference_id=round_id or game_id,
        )
        db.commit()
        db.refresh(wallet)
        return {
            "game_id": game_id,
            "round_id": round_id,
            "wager_amount": int(wager_amount or 0),
            "wallet_coin_balance": wallet.coin_balance,
            "reference_id": round_id or f"game:{game_id}:user:{user_id}",
            "house_reservation": reserve,
            "metadata": metadata or {},
            "rule": "Coin-game wager debited from regular UserWallet.coin_balance.",
        }
    except Exception:
        db.rollback()
        raise


def settle_coin_game_to_regular_wallet(
    db: Session,
    *,
    user_id: int,
    game_id: str,
    round_id: str | None,
    wager_amount: int,
    win_amount: int,
    multiplier: int = 0,
    metadata: dict[str, Any] | None = None,
) -> dict[str, Any]:
    safe_wager = max(int(wager_amount or 0), 0)
    safe_win = max(int(win_amount or 0), 0)
    safe_multiplier = max(int(multiplier or 0), 0)
    try:
        if safe_wager > 0:
            debit_user_game_wager(db, user_id=user_id, amount=safe_wager, game_id=game_id, round_id=round_id)
        capped_win = house_pool_service.cap_reward_by_house_rules(db, "GAME_HOUSE_POOL", safe_win)
        capped_win = whale_risk_service.cap_reward_by_whale_rules(db, user_id, capped_win)
        wallet = credit_user_game_winnings(db, user_id=user_id, amount=capped_win, game_id=game_id, round_id=round_id)
        loss_amount = safe_wager if capped_win <= 0 else max(safe_wager - capped_win, 0)
        net_amount = capped_win - safe_wager
        stats = update_user_game_stats(
            db,
            user_id=user_id,
            game_id=game_id,
            wager_amount=safe_wager,
            win_amount=capped_win,
            loss_amount=loss_amount,
            net_amount=net_amount,
            multiplier=safe_multiplier,
        )
        house_profit_or_loss = safe_wager - capped_win
        house_result = house_pool_service.record_house_profit_or_loss(
            db,
            pool_type="GAME_HOUSE_POOL",
            amount=house_profit_or_loss,
            reference_type="COIN_GAME_SETTLEMENT",
            reference_id=round_id or game_id,
        )
        house_pool_service.release_house_liability(db, round_id)
        risk = whale_risk_service.calculate_whale_risk_score(db, user_id)
        db.flush()
        return {
            "game_id": game_id,
            "round_id": round_id,
            "wager_amount": safe_wager,
            "win_amount": capped_win,
            "raw_win_amount": safe_win,
            "loss_amount": loss_amount,
            "net_amount": net_amount,
            "multiplier": safe_multiplier,
            "wallet_coin_balance": wallet.coin_balance,
            "house_profit_or_loss": house_profit_or_loss,
            "house_result": house_result,
            "risk_score": int(risk.get("suspicious_pattern_score") or 0),
            "risk": risk,
            "stats": game_stats_payload(stats),
            "metadata": json.dumps(metadata or {}, separators=(",", ":")),
            "rule": "Coin-game settlement uses regular UserWallet.coin_balance for wager and winnings.",
        }
    except Exception:
        db.rollback()
        raise
