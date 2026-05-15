from __future__ import annotations

import json
from random import choices
from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.economy import EconomyCurrency, EconomyDirection, UserWallet, WalletLedger
from app.models.economy_stats import LuckyGiftTransaction, UserLuckyGiftStats
from app.models.user import User
from app.services import house_pool_service, lucky_gift_props_service, lucky_gift_stats_service, whale_risk_service

RUBY_EARNING_BASIS_POINTS = 3000


def _get_or_create_wallet_for_update(db: Session, user_id: int) -> UserWallet:
    wallet = db.query(UserWallet).filter(UserWallet.user_id == user_id).with_for_update().first()
    if wallet is not None:
        return wallet
    wallet = UserWallet(user_id=user_id)
    db.add(wallet)
    db.flush()
    return wallet


def _debit_regular_coin_wallet(
    db: Session,
    *,
    user_id: int,
    amount: int,
    reason: str,
    reference_type: str,
    reference_id: str | None,
) -> UserWallet:
    safe_amount = int(amount or 0)
    if safe_amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
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
            source_type=reference_type,
            source_id=reference_id,
            created_by_user_id=user_id,
            reason=reason,
        )
    )
    db.flush()
    return wallet


def _credit_regular_coin_wallet(
    db: Session,
    *,
    user_id: int,
    amount: int,
    reason: str,
    reference_type: str,
    reference_id: str | None,
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
            source_type=reference_type,
            source_id=reference_id,
            created_by_user_id=user_id,
            reason=reason,
        )
    )
    db.flush()
    return wallet


def _credit_receiver_rubies_for_lucky_gift(
    db: Session,
    *,
    receiver_user_id: int | None,
    spent_coins: int,
    sender_user_id: int,
    source_id: str,
    gift_id: str,
) -> tuple[int, UserWallet | None]:
    if receiver_user_id is None:
        return 0, None
    ruby_amount = max(int(spent_coins or 0), 0) * RUBY_EARNING_BASIS_POINTS // 10_000
    receiver_wallet = _get_or_create_wallet_for_update(db, receiver_user_id)
    receiver_wallet.lifetime_coins_received_as_gifts += max(int(spent_coins or 0), 0)
    if ruby_amount <= 0:
        db.flush()
        return 0, receiver_wallet
    before = int(receiver_wallet.ruby_balance or 0)
    receiver_wallet.ruby_balance = before + ruby_amount
    receiver_wallet.lifetime_rubies_earned += ruby_amount
    db.add(
        WalletLedger(
            user_id=receiver_user_id,
            currency_type=EconomyCurrency.RUBY.value,
            direction=EconomyDirection.CREDIT.value,
            amount=ruby_amount,
            before_balance=before,
            after_balance=receiver_wallet.ruby_balance,
            source_type="LUCKY_GIFT_RECEIVE_RUBY",
            source_id=source_id,
            created_by_user_id=sender_user_id,
            reason=f"Received lucky gift {gift_id}",
        )
    )
    db.flush()
    return ruby_amount, receiver_wallet


def roll_lucky_gift_result(db: Session, *, gift_id: str, gift_name: str, coin_value: int, quantity: int, house_risk_score: int = 0) -> dict[str, Any]:
    try:
        return lucky_gift_props_service.roll_lucky_gift(
            db,
            gift_id=gift_id,
            gift_name=gift_name,
            base_coin_value=coin_value,
            quantity=quantity,
            house_risk_score=house_risk_score,
        )
    except Exception:
        multipliers = [0, 1, 2, 5, 10, 20, 50, 100, 500, 1000]
        weights = [35, 30, 18, 10, 4, 2, 0.7, 0.25, 0.04, 0.01]
        multiplier = int(choices(multipliers, weights=weights, k=1)[0])
        reward = calculate_lucky_gift_reward(spent_coins=int(coin_value or 0) * int(quantity or 1), multiplier=multiplier)
        return {
            "gift_id": gift_id,
            "gift_name": gift_name,
            "multiplier": multiplier,
            "reward_coin_amount": reward,
            "difficulty": "fallback",
            "source": "fallback_safe_roll",
        }


def calculate_lucky_gift_reward(*, spent_coins: int, multiplier: int) -> int:
    return max(int(spent_coins or 0), 0) * max(int(multiplier or 0), 0)


def should_emit_lucky_gift_global_broadcast(*, multiplier: int, reward_coins: int) -> bool:
    return int(multiplier or 0) >= 100 or int(reward_coins or 0) >= 10_000


def record_lucky_gift_transaction(
    db: Session,
    *,
    sender_user_id: int,
    receiver_user_id: int | None,
    room_id: int | None,
    gift_id: str,
    gift_name: str | None,
    coin_value: int,
    quantity: int,
    spent_coins: int,
    multiplier: int,
    reward_coins: int,
    net_win_coins: int,
    metadata: dict[str, Any] | None = None,
) -> tuple[LuckyGiftTransaction, UserLuckyGiftStats]:
    return lucky_gift_stats_service.record_lucky_gift_result(
        db,
        sender_user_id=sender_user_id,
        receiver_user_id=receiver_user_id,
        room_id=room_id,
        gift_id=gift_id,
        gift_name=gift_name,
        coin_value=coin_value,
        quantity=quantity,
        spent_coins=spent_coins,
        multiplier=multiplier,
        reward_coins=reward_coins,
        net_win_coins=net_win_coins,
        metadata_json=json.dumps(metadata or {}, separators=(",", ":")),
        broadcast_sent=1 if should_emit_lucky_gift_global_broadcast(multiplier=multiplier, reward_coins=reward_coins) else 0,
    )


def update_user_lucky_gift_stats(
    db: Session,
    *,
    user_id: int,
    spent_coins: int,
    reward_coins: int,
    net_win_coins: int,
    multiplier: int,
) -> UserLuckyGiftStats:
    stats = lucky_gift_stats_service.get_or_create_stats(db, user_id)
    lucky_gift_stats_service.update_stats(
        stats,
        spent=spent_coins,
        reward=reward_coins,
        net=net_win_coins,
        multiplier=multiplier,
    )
    db.flush()
    return stats


def settle_lucky_gift_to_regular_wallet(
    db: Session,
    *,
    sender: User,
    receiver_user_id: int | None,
    room_id: int | None,
    gift_id: str,
    gift_name: str | None,
    coin_value: int,
    quantity: int,
    metadata: dict[str, Any] | None = None,
) -> dict[str, Any]:
    safe_coin_value = int(coin_value or 0)
    safe_quantity = max(int(quantity or 1), 1)
    if safe_coin_value <= 0:
        raise HTTPException(status_code=400, detail="coin_value must be positive")
    spent_coins = safe_coin_value * safe_quantity

    risk = whale_risk_service.calculate_whale_risk_score(db, sender.id)
    if risk.get("action") == "BLOCK":
        raise HTTPException(status_code=429, detail={"message": "Lucky gift blocked by whale detection", "risk": risk})

    try:
        debit_wallet = _debit_regular_coin_wallet(
            db,
            user_id=sender.id,
            amount=spent_coins,
            reason="Lucky gift wager/spend",
            reference_type="LUCKY_GIFT_WAGER",
            reference_id=f"pending:{gift_id}",
        )
        house_pool_service.reserve_house_liability(
            db,
            pool_type="GAME_HOUSE_POOL",
            amount=spent_coins * 1000,
            reference_type="LUCKY_GIFT",
            reference_id=f"pending:{sender.id}:{gift_id}",
        )
        lucky_result = roll_lucky_gift_result(
            db,
            gift_id=gift_id,
            gift_name=gift_name or gift_id.replace("_", " ").title(),
            coin_value=safe_coin_value,
            quantity=safe_quantity,
            house_risk_score=int(risk.get("suspicious_pattern_score") or risk.get("score") or 0),
        )
        multiplier = int(lucky_result.get("multiplier") or 0)
        raw_reward = int(lucky_result.get("reward_coin_amount") or calculate_lucky_gift_reward(spent_coins=spent_coins, multiplier=multiplier))
        house_capped_reward = house_pool_service.cap_reward_by_house_rules(db, "GAME_HOUSE_POOL", raw_reward)
        reward_coins = whale_risk_service.cap_reward_by_whale_rules(db, sender.id, house_capped_reward)
        if reward_coins != raw_reward:
            lucky_result["raw_reward_coin_amount"] = raw_reward
            lucky_result["reward_coin_amount"] = reward_coins
            lucky_result["capped_by_risk_rules"] = True
        net_win_coins = reward_coins - spent_coins

        ruby_source_id = f"pending:{gift_id}:{sender.id}:{receiver_user_id or 'none'}"
        receiver_ruby_amount, receiver_wallet = _credit_receiver_rubies_for_lucky_gift(
            db,
            receiver_user_id=receiver_user_id,
            spent_coins=spent_coins,
            sender_user_id=sender.id,
            source_id=ruby_source_id,
            gift_id=gift_id,
        )

        credit_wallet = _credit_regular_coin_wallet(
            db,
            user_id=sender.id,
            amount=reward_coins,
            reason="Lucky gift multiplier reward",
            reference_type="LUCKY_GIFT_REWARD",
            reference_id=f"pending:{gift_id}",
        )
        tx, stats = record_lucky_gift_transaction(
            db,
            sender_user_id=sender.id,
            receiver_user_id=receiver_user_id,
            room_id=room_id,
            gift_id=gift_id,
            gift_name=gift_name or gift_id.replace("_", " ").title(),
            coin_value=safe_coin_value,
            quantity=safe_quantity,
            spent_coins=spent_coins,
            multiplier=multiplier,
            reward_coins=reward_coins,
            net_win_coins=net_win_coins,
            metadata={
                "source": "regular_wallet_lucky_gift_settlement",
                "risk": risk,
                "lucky_result": lucky_result,
                "receiver_ruby_amount": receiver_ruby_amount,
                **(metadata or {}),
            },
        )
        house_profit_or_loss = spent_coins - reward_coins
        house_pool_service.record_house_profit_or_loss(
            db,
            pool_type="GAME_HOUSE_POOL",
            amount=house_profit_or_loss,
            reference_type="LUCKY_GIFT",
            reference_id=str(tx.id),
        )
        house_pool_service.release_house_liability(db, f"LUCKY_GIFT:{tx.id}")
        db.flush()
        return {
            "lucky_gift_transaction_id": tx.id,
            "sender_user_id": sender.id,
            "receiver_user_id": receiver_user_id,
            "room_id": room_id,
            "gift_id": gift_id,
            "gift_name": gift_name or gift_id.replace("_", " ").title(),
            "coin_value": safe_coin_value,
            "quantity": safe_quantity,
            "spent_coin_amount": spent_coins,
            "reward_coin_amount": reward_coins,
            "spent_coins": spent_coins,
            "reward_coins": reward_coins,
            "net_win_coins": net_win_coins,
            "receiver_ruby_amount": receiver_ruby_amount,
            "receiver_ruby_balance": receiver_wallet.ruby_balance if receiver_wallet is not None else 0,
            "receiver_lifetime_gift_coin_value": receiver_wallet.lifetime_coins_received_as_gifts if receiver_wallet is not None else 0,
            "receiver_lifetime_rubies_earned": receiver_wallet.lifetime_rubies_earned if receiver_wallet is not None else 0,
            "ruby_rule": "Receiver rubies = lucky gift spent coin value × 30%.",
            "lucky_multiplier": multiplier,
            "lucky_reward_coin_amount": reward_coins,
            "lucky_result": lucky_result,
            "sender_coin_balance": credit_wallet.coin_balance,
            "wallet_coin_balance": credit_wallet.coin_balance,
            "winner_coin_balance": credit_wallet.coin_balance,
            "house_profit_or_loss": house_profit_or_loss,
            "risk": risk,
            "stats": lucky_gift_stats_service.stats_payload(stats),
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
    from app.services import game_settlement_service

    return game_settlement_service.settle_coin_game_to_regular_wallet(
        db,
        user_id=user_id,
        game_id=game_id,
        round_id=round_id,
        wager_amount=wager_amount,
        win_amount=win_amount,
        multiplier=multiplier,
        metadata=metadata,
    )
