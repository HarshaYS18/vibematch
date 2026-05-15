from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import UserWallet
from app.models.economy_stats import LuckyGiftTransaction, UserLuckyGiftStats
from app.models.room import Room
from app.models.user import User
from app.services import gift_catalog_service, lucky_gift_props_service, lucky_gift_stats_service

router = APIRouter(prefix="/lucky-gifts", tags=["Lucky Gifts"])

MULTIPLIERS = [1, 2, 5, 10, 20, 50, 100, 500, 1000]


class LuckyGiftPreviewRequest(BaseModel):
    gift_id: str = Field(..., min_length=1, max_length=80)
    quantity: int = Field(default=1, gt=0, le=999)
    receiver_public_user_id: int | None = None
    room_public_id: str | None = None


class LuckyGiftResultRecordRequest(BaseModel):
    gift_id: str = Field(..., min_length=1, max_length=80)
    quantity: int = Field(default=1, gt=0, le=999)
    receiver_public_user_id: int | None = None
    room_public_id: str | None = None
    spent_coins: int = Field(default=0, ge=0)
    multiplier: int = Field(default=0, ge=0)
    reward_coins: int = Field(default=0, ge=0)
    net_win_coins: int = 0


def _period_start(period: str) -> datetime:
    now = datetime.utcnow()
    safe = period.lower()
    if safe == "yearly":
        return datetime(now.year, 1, 1)
    if safe == "monthly":
        return datetime(now.year, now.month, 1)
    if safe == "weekly":
        return now - timedelta(days=7)
    return datetime(now.year, now.month, now.day)


def _lucky_gifts() -> list[dict]:
    return [gift for gift in gift_catalog_service.list_gifts().get("gifts", []) if gift.get("gift_type") == "lucky"]


def _room_id(db: Session, room_public_id: str | None) -> int | None:
    if not room_public_id:
        return None
    room = db.query(Room).filter(Room.room_public_id == room_public_id).first()
    return room.id if room else None


def _receiver_id(db: Session, public_user_id: int | None) -> int | None:
    if public_user_id is None:
        return None
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    return user.id if user else None


def _get_or_create_stats(db: Session, user_id: int) -> UserLuckyGiftStats:
    return lucky_gift_stats_service.get_or_create_stats(db, user_id)


def _update_stats(row: UserLuckyGiftStats, *, spent: int, reward: int, net: int, multiplier: int) -> None:
    lucky_gift_stats_service.update_stats(row, spent=spent, reward=reward, net=net, multiplier=multiplier)


def _stats_payload(row: UserLuckyGiftStats | None) -> dict:
    return lucky_gift_stats_service.stats_payload(row)


def _wallet_coin_balance(db: Session, user_id: int) -> int:
    wallet = db.query(UserWallet).filter(UserWallet.user_id == user_id).first()
    return int(wallet.coin_balance) if wallet else 0


def _recent_matching_transaction(
    db: Session,
    *,
    sender_user_id: int,
    receiver_user_id: int | None,
    room_id: int | None,
    payload: LuckyGiftResultRecordRequest,
) -> LuckyGiftTransaction | None:
    since = datetime.utcnow() - timedelta(minutes=2)
    query = db.query(LuckyGiftTransaction).filter(
        LuckyGiftTransaction.sender_user_id == sender_user_id,
        LuckyGiftTransaction.gift_id == payload.gift_id,
        LuckyGiftTransaction.quantity == payload.quantity,
        LuckyGiftTransaction.spent_coins == payload.spent_coins,
        LuckyGiftTransaction.multiplier == payload.multiplier,
        LuckyGiftTransaction.reward_coins == payload.reward_coins,
        LuckyGiftTransaction.net_win_coins == payload.net_win_coins,
        LuckyGiftTransaction.created_at >= since,
    )
    query = query.filter(LuckyGiftTransaction.receiver_user_id == receiver_user_id) if receiver_user_id is not None else query.filter(LuckyGiftTransaction.receiver_user_id.is_(None))
    query = query.filter(LuckyGiftTransaction.room_id == room_id) if room_id is not None else query.filter(LuckyGiftTransaction.room_id.is_(None))
    return query.order_by(LuckyGiftTransaction.id.desc()).first()


def _score_field(ranking_type: str, period: str):
    prefix = "yearly" if period == "yearly" else "monthly" if period == "monthly" else "weekly" if period == "weekly" else "daily"
    safe = ranking_type.replace("-", "_").lower()
    if safe in {"winnings", "rewards"}:
        return getattr(UserLuckyGiftStats, f"{prefix}_reward_coins")
    if safe in {"net_wins", "net"}:
        return getattr(UserLuckyGiftStats, f"{prefix}_net_win_coins")
    if safe in {"big_wins", "biggest_reward"}:
        return getattr(UserLuckyGiftStats, f"{prefix}_biggest_reward")
    if safe in {"multipliers", "best_multiplier"}:
        return getattr(UserLuckyGiftStats, f"{prefix}_best_multiplier")
    if safe in {"spending", "spent"}:
        return getattr(UserLuckyGiftStats, f"{prefix}_spent_coins")
    return getattr(UserLuckyGiftStats, f"{prefix}_reward_coins")


@router.get("/master")
def get_lucky_gift_master(db: Session = Depends(get_db)):
    props = lucky_gift_props_service.get_props(db)
    return {"enabled": True, "currency": "coins", "multipliers": [{"multiplier": int(item["multiplier"]), "weight": int(item["weight"]), "difficulty": item.get("difficulty"), "public_display": int(item["multiplier"]) >= 5} for item in props["multipliers"]], "rules": {"min_quantity": 1, "max_quantity": 999, "broadcast_min_reward": props["broadcast_min_reward"], "big_win_min_multiplier": props["big_win_min_multiplier"], "ranking_periods": ["daily", "weekly", "monthly", "yearly"]}}


@router.get("/catalog")
def get_lucky_gift_catalog(current_user: User = Depends(get_current_user)):
    return {"gifts": _lucky_gifts()}


@router.post("/preview")
def preview_lucky_gift(payload: LuckyGiftPreviewRequest, current_user: User = Depends(get_current_user)):
    gift = gift_catalog_service.find_gift(payload.gift_id)
    if gift is None:
        raise HTTPException(status_code=404, detail="Gift not found")
    coin_value = int(gift.get("coin_value") or 0)
    total = coin_value * payload.quantity
    return {"gift_id": payload.gift_id, "quantity": payload.quantity, "coin_value": coin_value, "total_spend_coins": total, "possible_multipliers": MULTIPLIERS, "max_possible_reward": total * max(MULTIPLIERS), "broadcast_if_win_above": 10000, "can_send": True}


@router.post("/results/record")
def record_lucky_gift_result(payload: LuckyGiftResultRecordRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    receiver_id = _receiver_id(db, payload.receiver_public_user_id)
    room_id = _room_id(db, payload.room_public_id)
    duplicate = _recent_matching_transaction(db, sender_user_id=current_user.id, receiver_user_id=receiver_id, room_id=room_id, payload=payload)
    if duplicate is not None:
        stats = db.query(UserLuckyGiftStats).filter(UserLuckyGiftStats.user_id == current_user.id).first()
        return {
            "status": "recorded",
            "transaction_id": duplicate.id,
            "deduplicated": True,
            "spent_coins": duplicate.spent_coins,
            "reward_coins": duplicate.reward_coins,
            "net_win_coins": duplicate.net_win_coins,
            "wallet_coin_balance": _wallet_coin_balance(db, current_user.id),
            "stats": _stats_payload(stats),
        }
    try:
        row, stats = lucky_gift_stats_service.record_lucky_gift_result(
            db,
            sender_user_id=current_user.id,
            receiver_user_id=receiver_id,
            room_id=room_id,
            gift_id=payload.gift_id,
            gift_name=payload.gift_id.replace("_", " ").title(),
            coin_value=payload.spent_coins // max(payload.quantity, 1),
            quantity=payload.quantity,
            spent_coins=payload.spent_coins,
            multiplier=payload.multiplier,
            reward_coins=payload.reward_coins,
            net_win_coins=payload.net_win_coins,
        )
        db.commit()
        db.refresh(row)
    except Exception:
        db.rollback()
        raise
    return {
        "status": "recorded",
        "transaction_id": row.id,
        "deduplicated": False,
        "spent_coins": row.spent_coins,
        "reward_coins": row.reward_coins,
        "net_win_coins": row.net_win_coins,
        "wallet_coin_balance": _wallet_coin_balance(db, current_user.id),
        "stats": _stats_payload(stats),
    }


@router.get("/history")
def get_lucky_gift_history(period: str = Query(default="daily"), room_public_id: str | None = Query(default=None), gift_id: str | None = Query(default=None), min_multiplier: int = Query(default=0, ge=0), limit: int = Query(default=50, ge=1, le=100), db: Session = Depends(get_db)):
    query = db.query(LuckyGiftTransaction).filter(LuckyGiftTransaction.created_at >= _period_start(period), LuckyGiftTransaction.multiplier >= min_multiplier)
    if gift_id:
        query = query.filter(LuckyGiftTransaction.gift_id == gift_id)
    room_id = _room_id(db, room_public_id)
    if room_id is not None:
        query = query.filter(LuckyGiftTransaction.room_id == room_id)
    rows = query.order_by(LuckyGiftTransaction.created_at.desc()).limit(limit).all()
    return {"period": period, "room_public_id": room_public_id, "gift_id": gift_id, "min_multiplier": min_multiplier, "limit": limit, "entries": [{"transaction_id": row.id, "sender_user_id": row.sender_user_id, "receiver_user_id": row.receiver_user_id, "room_id": row.room_id, "gift_id": row.gift_id, "gift_name": row.gift_name, "spent_coins": row.spent_coins, "multiplier": row.multiplier, "reward_coins": row.reward_coins, "net_win_coins": row.net_win_coins, "created_at": row.created_at.isoformat() if row.created_at else None} for row in rows]}


@router.get("/me/stats")
def get_my_lucky_gift_stats(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    row = db.query(UserLuckyGiftStats).filter(UserLuckyGiftStats.user_id == current_user.id).first()
    payload = _stats_payload(row)
    payload["user_id"] = current_user.id
    return payload


@router.get("/users/{public_user_id}/winnings")
def get_public_lucky_gift_winnings(public_user_id: int, period: str = Query(default="monthly"), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    row = db.query(UserLuckyGiftStats).filter(UserLuckyGiftStats.user_id == user.id).first() if user else None
    payload = _stats_payload(row).get("yearly" if period == "yearly" else "weekly" if period == "weekly" else "monthly")
    return {"public_user_id": public_user_id, "period": period, "spent_coins": payload["spent_coins"], "reward_coins": payload["reward_coins"], "net_win_coins": payload["net_coins"], "best_multiplier": payload["best_multiplier"], "biggest_reward": payload["biggest_reward"], "lucky_gifts_sent": payload["rounds"], "rank": None}


@router.get("/rankings/{ranking_type}")
def get_lucky_gift_ranking(ranking_type: str, period: str = Query(default="daily"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    field = _score_field(ranking_type, period)
    rows = db.query(UserLuckyGiftStats).order_by(field.desc()).limit(limit).all()
    entries = []
    for index, row in enumerate(rows, start=1):
        user = db.query(User).filter(User.id == row.user_id).first()
        entries.append({"rank": index, "score": int(getattr(row, field.key) or 0), "user": {"id": row.user_id, "public_user_id": user.public_user_id if user else None, "display_name": (user.display_name or user.username) if user else None, "avatar_url": user.avatar_url if user else None}})
    return {"ranking_type": ranking_type, "period": period, "entries": entries, "limit": limit}


@router.get("/roll-preview")
def roll_preview_only(total_coin_value: int = Query(default=0, ge=0), db: Session = Depends(get_db)):
    result = lucky_gift_props_service.roll_lucky_gift(db, gift_id="preview", gift_name="Preview", base_coin_value=total_coin_value, quantity=1)
    return {"multiplier": result["multiplier"], "difficulty": result["difficulty"], "reward_coin_amount": result["reward_coin_amount"], "preview_only": True}
