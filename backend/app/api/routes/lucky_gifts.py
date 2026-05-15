from random import choices

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.services import gift_catalog_service

router = APIRouter(prefix="/lucky-gifts", tags=["Lucky Gifts"])

MULTIPLIERS = [0, 1, 2, 5, 10, 20, 50, 100, 500, 1000]
WEIGHTS = [3800, 3400, 1500, 760, 330, 130, 55, 18, 5, 2]


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


def _lucky_gifts() -> list[dict]:
    return [gift for gift in gift_catalog_service.list_gifts().get("gifts", []) if gift.get("gift_type") == "lucky"]


@router.get("/master")
def get_lucky_gift_master():
    return {
        "enabled": True,
        "currency": "coins",
        "multipliers": [{"multiplier": multiplier, "weight": weight, "public_display": multiplier >= 5} for multiplier, weight in zip(MULTIPLIERS, WEIGHTS)],
        "rules": {
            "min_quantity": 1,
            "max_quantity": 999,
            "broadcast_min_reward": 10000,
            "big_win_min_multiplier": 100,
            "ranking_periods": ["daily", "weekly", "monthly", "yearly"],
        },
    }


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
    return {
        "gift_id": payload.gift_id,
        "quantity": payload.quantity,
        "coin_value": coin_value,
        "total_spend_coins": total,
        "possible_multipliers": MULTIPLIERS,
        "max_possible_reward": total * max(MULTIPLIERS),
        "broadcast_if_win_above": 10000,
        "can_send": True,
    }


@router.post("/results/record")
def record_lucky_gift_result(payload: LuckyGiftResultRecordRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return {
        "status": "recorded_placeholder",
        "user_id": current_user.id,
        "gift_id": payload.gift_id,
        "quantity": payload.quantity,
        "spent_coins": payload.spent_coins,
        "multiplier": payload.multiplier,
        "reward_coins": payload.reward_coins,
        "net_win_coins": payload.net_win_coins,
        "note": "Reserved stats endpoint. Project team can connect this to separated lucky coin/winnings tables.",
    }


@router.get("/history")
def get_lucky_gift_history(
    period: str = Query(default="daily"),
    room_public_id: str | None = Query(default=None),
    gift_id: str | None = Query(default=None),
    min_multiplier: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=100),
    db: Session = Depends(get_db),
):
    return {
        "period": period,
        "room_public_id": room_public_id,
        "gift_id": gift_id,
        "min_multiplier": min_multiplier,
        "limit": limit,
        "entries": [],
        "source": "placeholder_until_lucky_gift_transactions_are_connected",
    }


@router.get("/me/stats")
def get_my_lucky_gift_stats(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    empty = {"spent_coins": 0, "reward_coins": 0, "net_coins": 0, "best_multiplier": 0, "rounds": 0}
    return {
        "user_id": current_user.id,
        "today": empty,
        "weekly": empty,
        "monthly": empty,
        "yearly": empty,
        "all_time": empty,
        "source": "placeholder_until_user_lucky_gift_stats_are_connected",
    }


@router.get("/users/{public_user_id}/winnings")
def get_public_lucky_gift_winnings(public_user_id: int, period: str = Query(default="monthly"), db: Session = Depends(get_db)):
    return {
        "public_user_id": public_user_id,
        "period": period,
        "spent_coins": 0,
        "reward_coins": 0,
        "net_win_coins": 0,
        "best_multiplier": 0,
        "biggest_reward": 0,
        "lucky_gifts_sent": 0,
        "rank": None,
        "source": "placeholder_until_user_lucky_gift_stats_are_connected",
    }


@router.get("/rankings/{ranking_type}")
def get_lucky_gift_ranking(ranking_type: str, period: str = Query(default="daily"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    return {
        "ranking_type": ranking_type,
        "period": period,
        "entries": [],
        "limit": limit,
        "source": "placeholder_until_lucky_gift_ranking_snapshots_are_connected",
    }


@router.get("/roll-preview")
def roll_preview_only(total_coin_value: int = Query(default=0, ge=0)):
    multiplier = int(choices(MULTIPLIERS, weights=WEIGHTS, k=1)[0])
    return {
        "multiplier": multiplier,
        "reward_coin_amount": total_coin_value * multiplier,
        "preview_only": True,
    }
