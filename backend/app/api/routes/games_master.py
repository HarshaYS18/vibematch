from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy_stats import UserGameStats
from app.models.user import User
from app.services import game_platform_runtime_service as game_service

router = APIRouter(prefix="/games", tags=["Games Master And Rankings"])


def _catalog_payload(db: Session) -> list[dict]:
    try:
        return game_service.list_catalog(db)
    except Exception:
        return []


def _stats_payload(row: UserGameStats | None) -> dict:
    if row is None:
        empty = {"bet": 0, "won": 0, "lost": 0, "net": 0, "rounds_played": 0}
        return {"today": empty, "weekly": empty, "monthly": empty, "all_time": empty, "best_multiplier": 0}
    return {
        "today": {"bet": row.daily_bid_amount, "won": row.daily_win_amount, "lost": row.daily_loss_amount, "net": row.daily_net_amount, "rounds_played": row.rounds_played_daily},
        "weekly": {"bet": row.weekly_bid_amount, "won": row.weekly_win_amount, "lost": row.weekly_loss_amount, "net": row.weekly_net_amount, "rounds_played": 0},
        "monthly": {"bet": row.monthly_bid_amount, "won": row.monthly_win_amount, "lost": row.monthly_loss_amount, "net": row.monthly_net_amount, "rounds_played": row.rounds_played_monthly},
        "all_time": {"bet": row.all_time_bid_amount, "won": row.all_time_win_amount, "lost": row.all_time_loss_amount, "net": row.all_time_net_amount, "rounds_played": 0},
        "best_multiplier": row.best_multiplier,
    }


def _score_field(ranking_type: str, period: str):
    safe_type = ranking_type.replace("-", "_").lower()
    safe_period = period.lower()
    period_prefix = "monthly" if safe_period == "monthly" else "weekly" if safe_period == "weekly" else "daily"
    if safe_type in {"winnings", "wins", "win"}:
        return getattr(UserGameStats, f"{period_prefix}_win_amount")
    if safe_type in {"bids", "bid", "spending"}:
        return getattr(UserGameStats, f"{period_prefix}_bid_amount")
    if safe_type in {"losses", "loss"}:
        return getattr(UserGameStats, f"{period_prefix}_loss_amount")
    if safe_type in {"net_profit", "net-profit", "net"}:
        return getattr(UserGameStats, f"{period_prefix}_net_amount")
    if safe_type in {"best_multiplier", "multiplier"}:
        return UserGameStats.best_multiplier
    return getattr(UserGameStats, f"{period_prefix}_win_amount")


def _entry(db: Session, row: UserGameStats, rank: int, score: int) -> dict:
    user = db.query(User).filter(User.id == row.user_id).first()
    return {
        "rank": rank,
        "score": score,
        "game_id": row.game_id,
        "user": {
            "id": row.user_id,
            "public_user_id": user.public_user_id if user else None,
            "display_name": (user.display_name or user.username) if user else None,
            "avatar_url": user.avatar_url if user else None,
        },
    }


@router.get("/master")
def get_games_master(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    catalog = _catalog_payload(db)
    return {
        "categories": [
            {"id": "free_games", "title": "Free to Play Games", "games": [item for item in catalog if str(item.get("entry_type", "coin")).lower() == "free"]},
            {"id": "coin_games", "title": "Coin Games", "games": [item for item in catalog if str(item.get("entry_type", "coin")).lower() != "free"]},
        ],
        "user_limits": {"can_play_coin_games": True, "daily_loss_used": 0, "daily_loss_limit": 0},
        "source": "catalog_plus_user_game_stats",
    }


@router.get("/{game_id}/master")
def get_single_game_master(game_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    catalog = _catalog_payload(db)
    item = next((entry for entry in catalog if str(entry.get("game_key") or entry.get("game_id")) == game_id), None)
    stats = db.query(UserGameStats).filter(UserGameStats.user_id == current_user.id, UserGameStats.game_id == game_id).first()
    return {
        "game_id": game_id,
        "definition": item,
        "rules": item.get("rules", {}) if isinstance(item, dict) else {},
        "rankings_available": ["winnings", "bids", "losses", "net_profit", "best_multiplier"],
        "user_stats": _stats_payload(stats),
    }


@router.get("/{game_id}/me/stats")
def get_my_game_stats(game_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    row = db.query(UserGameStats).filter(UserGameStats.user_id == current_user.id, UserGameStats.game_id == game_id).first()
    payload = _stats_payload(row)
    payload["game_id"] = game_id
    payload["user_id"] = current_user.id
    return payload


@router.get("/{game_id}/rankings/{ranking_type}")
def get_game_ranking(game_id: str, ranking_type: str, period: str = Query(default="daily"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    score_field = _score_field(ranking_type, period)
    rows = db.query(UserGameStats).filter(UserGameStats.game_id == game_id).order_by(score_field.desc()).limit(limit).all()
    return {"game_id": game_id, "ranking_type": ranking_type, "period": period, "entries": [_entry(db, row, index, int(getattr(row, score_field.key) or 0)) for index, row in enumerate(rows, start=1)], "limit": limit}


@router.get("/rankings/{ranking_type}")
def get_all_games_ranking(ranking_type: str, period: str = Query(default="daily"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    score_field = _score_field(ranking_type, period)
    rows = db.query(UserGameStats).order_by(score_field.desc()).limit(limit).all()
    return {"ranking_type": ranking_type, "period": period, "entries": [_entry(db, row, index, int(getattr(row, score_field.key) or 0)) for index, row in enumerate(rows, start=1)], "limit": limit, "scope": "all_games"}
