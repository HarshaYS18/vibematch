from __future__ import annotations

import json
from datetime import datetime

from sqlalchemy.orm import Session

from app.models.economy_stats import LuckyGiftTransaction

SAFE_MAX_USER_DAILY_REWARD = 10_000_000
SAFE_MAX_USER_DAILY_WAGER = 50_000_000


def calculate_whale_risk_score(db: Session, user_id: int) -> dict:
    daily_wager_volume = get_user_daily_wager_volume(db, user_id)
    daily_reward_volume = get_user_daily_reward_volume(db, user_id)
    wager_pressure = min(daily_wager_volume / SAFE_MAX_USER_DAILY_WAGER, 1.0)
    reward_pressure = min(daily_reward_volume / SAFE_MAX_USER_DAILY_REWARD, 1.0)
    suspicious_pattern_score = int(max(wager_pressure, reward_pressure) * 100)
    risk_tier = "high" if suspicious_pattern_score >= 80 else "medium" if suspicious_pattern_score >= 40 else "low"
    return {
        "whale_user": daily_wager_volume >= 1_000_000 or daily_reward_volume >= 1_000_000,
        "whale_exposure": max(daily_wager_volume, daily_reward_volume),
        "recent_win_ratio": 0.0,
        "recent_loss_ratio": 0.0,
        "daily_wager_volume": daily_wager_volume,
        "daily_reward_volume": daily_reward_volume,
        "max_user_daily_reward": SAFE_MAX_USER_DAILY_REWARD,
        "suspicious_pattern_score": suspicious_pattern_score,
        "risk_tier": risk_tier,
        "action": "ALLOW",
    }


def get_user_daily_wager_volume(db: Session, user_id: int) -> int:
    start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    rows = db.query(LuckyGiftTransaction.spent_coins).filter(
        LuckyGiftTransaction.sender_user_id == user_id,
        LuckyGiftTransaction.created_at >= start,
    ).all()
    return int(sum(int(row[0] or 0) for row in rows))


def get_user_daily_reward_volume(db: Session, user_id: int) -> int:
    start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    rows = db.query(LuckyGiftTransaction.reward_coins).filter(
        LuckyGiftTransaction.sender_user_id == user_id,
        LuckyGiftTransaction.created_at >= start,
    ).all()
    return int(sum(int(row[0] or 0) for row in rows))


def can_user_receive_reward(db: Session, user_id: int, reward_amount: int) -> bool:
    safe_reward = max(int(reward_amount or 0), 0)
    return get_user_daily_reward_volume(db, user_id) + safe_reward <= SAFE_MAX_USER_DAILY_REWARD


def cap_reward_by_whale_rules(db: Session, user_id: int, reward_amount: int) -> int:
    safe_reward = max(int(reward_amount or 0), 0)
    remaining = max(SAFE_MAX_USER_DAILY_REWARD - get_user_daily_reward_volume(db, user_id), 0)
    return min(safe_reward, remaining)


def flag_suspicious_lucky_gift_activity(db: Session, user_id: int, reason: str, metadata: dict | None = None) -> dict:
    # Full moderation/audit table wiring will be added later.
    return {
        "flagged": True,
        "user_id": user_id,
        "reason": reason,
        "metadata": json.dumps(metadata or {}, separators=(",", ":")),
        "safe_default": True,
    }
