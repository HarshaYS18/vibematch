from __future__ import annotations

from sqlalchemy.orm import Session

from app.models.economy_stats import UserGameStats


def get_or_create_stats(db: Session, *, user_id: int, game_id: str) -> UserGameStats:
    row = db.query(UserGameStats).filter(UserGameStats.user_id == user_id, UserGameStats.game_id == game_id).first()
    if row:
        return row
    row = UserGameStats(user_id=user_id, game_id=game_id)
    db.add(row)
    db.flush()
    return row


def record_game_bet(db: Session, *, user_id: int, game_id: str, amount: int) -> UserGameStats:
    safe_amount = max(int(amount or 0), 0)
    row = get_or_create_stats(db, user_id=user_id, game_id=game_id)
    for prefix in ["daily", "weekly", "monthly", "all_time"]:
        setattr(row, f"{prefix}_bid_amount", getattr(row, f"{prefix}_bid_amount") + safe_amount)
    db.flush()
    return row


def record_game_settlement(
    db: Session,
    *,
    user_id: int,
    game_id: str,
    spent_coins: int,
    reward_coins: int,
    multiplier: int,
) -> UserGameStats:
    safe_spent = max(int(spent_coins or 0), 0)
    safe_reward = max(int(reward_coins or 0), 0)
    safe_net = safe_reward - safe_spent
    safe_loss = max(safe_spent - safe_reward, 0)
    safe_multiplier = max(int(multiplier or 0), 0)
    row = get_or_create_stats(db, user_id=user_id, game_id=game_id)

    for prefix in ["daily", "weekly", "monthly", "all_time"]:
        setattr(row, f"{prefix}_win_amount", getattr(row, f"{prefix}_win_amount") + safe_reward)
        setattr(row, f"{prefix}_loss_amount", getattr(row, f"{prefix}_loss_amount") + safe_loss)
        setattr(row, f"{prefix}_net_amount", getattr(row, f"{prefix}_net_amount") + safe_net)

    row.rounds_played_daily += 1
    row.rounds_played_monthly += 1
    if safe_reward > 0:
        row.best_multiplier = max(row.best_multiplier, safe_multiplier)
    db.flush()
    return row
