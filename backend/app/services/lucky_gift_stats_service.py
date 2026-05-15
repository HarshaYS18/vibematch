from __future__ import annotations

from sqlalchemy.orm import Session

from app.models.economy_stats import LuckyGiftTransaction, UserLuckyGiftStats


def get_or_create_stats(db: Session, user_id: int) -> UserLuckyGiftStats:
    row = db.query(UserLuckyGiftStats).filter(UserLuckyGiftStats.user_id == user_id).first()
    if row:
        return row
    row = UserLuckyGiftStats(user_id=user_id)
    db.add(row)
    db.flush()
    return row


def update_stats(row: UserLuckyGiftStats, *, spent: int, reward: int, net: int, multiplier: int) -> None:
    safe_spent = max(int(spent or 0), 0)
    safe_reward = max(int(reward or 0), 0)
    safe_net = int(net or 0)
    safe_multiplier = max(int(multiplier or 0), 0)

    for prefix in ["daily", "weekly", "monthly", "yearly", "all_time"]:
        setattr(row, f"{prefix}_spent_coins", getattr(row, f"{prefix}_spent_coins") + safe_spent)
        setattr(row, f"{prefix}_reward_coins", getattr(row, f"{prefix}_reward_coins") + safe_reward)
        setattr(row, f"{prefix}_net_win_coins", getattr(row, f"{prefix}_net_win_coins") + safe_net)
        setattr(row, f"{prefix}_best_multiplier", max(getattr(row, f"{prefix}_best_multiplier"), safe_multiplier))
        setattr(row, f"{prefix}_biggest_reward", max(getattr(row, f"{prefix}_biggest_reward"), safe_reward))
        setattr(row, f"{prefix}_rounds", getattr(row, f"{prefix}_rounds") + 1)


def stats_payload(row: UserLuckyGiftStats | None) -> dict:
    def part(prefix: str) -> dict:
        if row is None:
            return {"spent_coins": 0, "reward_coins": 0, "net_coins": 0, "best_multiplier": 0, "biggest_reward": 0, "rounds": 0}
        return {
            "spent_coins": getattr(row, f"{prefix}_spent_coins"),
            "reward_coins": getattr(row, f"{prefix}_reward_coins"),
            "net_coins": getattr(row, f"{prefix}_net_win_coins"),
            "best_multiplier": getattr(row, f"{prefix}_best_multiplier"),
            "biggest_reward": getattr(row, f"{prefix}_biggest_reward"),
            "rounds": getattr(row, f"{prefix}_rounds"),
        }

    return {"today": part("daily"), "weekly": part("weekly"), "monthly": part("monthly"), "yearly": part("yearly"), "all_time": part("all_time")}


def record_lucky_gift_result(
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
    net_win_coins: int | None = None,
    metadata_json: str | None = None,
    broadcast_sent: int = 0,
) -> tuple[LuckyGiftTransaction, UserLuckyGiftStats]:
    safe_spent = max(int(spent_coins or 0), 0)
    safe_reward = max(int(reward_coins or 0), 0)
    safe_net = int(safe_reward - safe_spent if net_win_coins is None else net_win_coins)
    safe_multiplier = max(int(multiplier or 0), 0)
    safe_quantity = max(int(quantity or 1), 1)

    row = LuckyGiftTransaction(
        sender_user_id=sender_user_id,
        receiver_user_id=receiver_user_id,
        room_id=room_id,
        gift_id=gift_id,
        gift_name=gift_name,
        coin_value=max(int(coin_value or 0), 0),
        quantity=safe_quantity,
        spent_coins=safe_spent,
        multiplier=safe_multiplier,
        reward_coins=safe_reward,
        net_win_coins=safe_net,
        is_big_win=1 if safe_multiplier >= 100 or safe_reward >= 10000 else 0,
        broadcast_sent=broadcast_sent,
        metadata_json=metadata_json,
    )
    db.add(row)

    stats = get_or_create_stats(db, sender_user_id)
    update_stats(stats, spent=safe_spent, reward=safe_reward, net=safe_net, multiplier=safe_multiplier)
    db.flush()
    return row, stats
