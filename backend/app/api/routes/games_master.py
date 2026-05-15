from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.services import global_jungle_game_service_v2 as game_service

router = APIRouter(prefix="/games", tags=["Games Master And Rankings"])


def _catalog_payload(db: Session) -> list[dict]:
    try:
        return game_service.list_catalog(db)
    except Exception:
        return []


@router.get("/master")
def get_games_master(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    catalog = _catalog_payload(db)
    return {
        "categories": [
            {
                "id": "free_games",
                "title": "Free to Play Games",
                "games": [item for item in catalog if str(item.get("entry_type", "coin")).lower() == "free"],
            },
            {
                "id": "coin_games",
                "title": "Coin Games",
                "games": [item for item in catalog if str(item.get("entry_type", "coin")).lower() != "free"],
            },
        ],
        "user_limits": {
            "can_play_coin_games": True,
            "daily_loss_used": 0,
            "daily_loss_limit": 0,
        },
        "source": "catalog_plus_placeholder_limits",
    }


@router.get("/{game_id}/master")
def get_single_game_master(game_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    catalog = _catalog_payload(db)
    item = next((entry for entry in catalog if str(entry.get("game_key") or entry.get("game_id")) == game_id), None)
    return {
        "game_id": game_id,
        "definition": item,
        "rules": item.get("rules", {}) if isinstance(item, dict) else {},
        "rankings_available": ["winnings", "bids", "losses", "net_profit", "best_multiplier"],
        "user_stats": {
            "today_bet": 0,
            "today_won": 0,
            "today_lost": 0,
            "monthly_bet": 0,
            "monthly_won": 0,
            "monthly_lost": 0,
        },
    }


@router.get("/{game_id}/me/stats")
def get_my_game_stats(game_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return {
        "game_id": game_id,
        "user_id": current_user.id,
        "today": {"bet": 0, "won": 0, "lost": 0, "net": 0, "rounds_played": 0},
        "weekly": {"bet": 0, "won": 0, "lost": 0, "net": 0, "rounds_played": 0},
        "monthly": {"bet": 0, "won": 0, "lost": 0, "net": 0, "rounds_played": 0},
        "all_time": {"bet": 0, "won": 0, "lost": 0, "net": 0, "rounds_played": 0},
        "source": "placeholder_until_user_game_stats_table_is_connected",
    }


@router.get("/{game_id}/rankings/{ranking_type}")
def get_game_ranking(game_id: str, ranking_type: str, period: str = Query(default="daily"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    return {
        "game_id": game_id,
        "ranking_type": ranking_type,
        "period": period,
        "entries": [],
        "limit": limit,
        "source": "placeholder_until_game_ranking_snapshots_are_connected",
    }


@router.get("/rankings/{ranking_type}")
def get_all_games_ranking(ranking_type: str, period: str = Query(default="daily"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    return {
        "ranking_type": ranking_type,
        "period": period,
        "entries": [],
        "limit": limit,
        "scope": "all_games",
        "source": "placeholder_until_game_ranking_snapshots_are_connected",
    }
