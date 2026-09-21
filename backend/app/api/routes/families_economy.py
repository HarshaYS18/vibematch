from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.economy_stats import FamilyEconomyStats, FamilyMemberStats
from app.models.user import User

router = APIRouter(prefix="/families", tags=["Family Economy"])


def _family_row(db: Session, family_id: int) -> FamilyEconomyStats | None:
    return db.query(FamilyEconomyStats).filter(FamilyEconomyStats.family_id == family_id).first()


def _family_payload(row: FamilyEconomyStats | None, family_id: int) -> dict:
    if row is None:
        return {
            "family_id": family_id,
            "family_name": None,
            "family_level": 0,
            "family_exp": 0,
            "next_level_exp": 0,
            "progress_percent": 0,
            "member_count": 0,
            "weekly_rank": None,
            "monthly_rank": None,
            "source": "empty_until_family_stats_exist",
        }
    next_level_exp = max((row.family_level + 1) * 10000, row.family_exp)
    progress = 100 if next_level_exp <= 0 else min(100, int((row.family_exp / next_level_exp) * 100))
    return {
        "family_id": row.family_id,
        "family_name": row.family_name,
        "family_level": row.family_level,
        "family_exp": row.family_exp,
        "next_level_exp": next_level_exp,
        "progress_percent": progress,
        "member_count": row.member_count,
        "daily_exp": row.daily_exp,
        "weekly_exp": row.weekly_exp,
        "monthly_exp": row.monthly_exp,
        "daily_contribution": row.daily_contribution,
        "weekly_contribution": row.weekly_contribution,
        "monthly_contribution": row.monthly_contribution,
        "active_members_daily": row.active_members_daily,
        "updated_at": row.updated_at.isoformat() if row.updated_at else None,
    }


def _member_payload(db: Session, row: FamilyMemberStats, rank: int, score: int) -> dict:
    user = db.query(User).filter(User.id == row.user_id).first()
    return {
        "rank": rank,
        "score": score,
        "score_display": str(score),
        "public_user_id": user.public_user_id if user else None,
        "display_name": (user.display_name or user.username) if user else None,
        "avatar_url": user.avatar_url if user else None,
        "family_role": row.family_role,
        "daily_contribution": row.daily_contribution,
        "weekly_contribution": row.weekly_contribution,
        "monthly_contribution": row.monthly_contribution,
        "total_contribution": row.total_contribution,
        "joined_at": row.joined_at.isoformat() if row.joined_at else None,
    }


@router.get("/{family_id}/master")
def get_family_master(family_id: int, db: Session = Depends(get_db)):
    return _family_payload(_family_row(db, family_id), family_id)



@router.get("/{family_id}/exp")
def get_family_exp(family_id: int, db: Session = Depends(get_db)):
    payload = _family_payload(_family_row(db, family_id), family_id)
    payload["sources"] = {"member_gifts": payload.get("monthly_contribution", 0), "family_events": 0, "active_time": 0}
    return payload


@router.get("/{family_id}/exp/history")
def get_family_exp_history(family_id: int, db: Session = Depends(get_db)):
    return {"family_id": family_id, "history": [], "source": "history_will_use_economy_events_after_event_writer_is_connected"}


@router.get("/{family_id}/rankings/members")
def get_family_member_rankings(family_id: int, period: str = Query(default="weekly"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    score_field = FamilyMemberStats.monthly_contribution if period == "monthly" else FamilyMemberStats.daily_contribution if period == "daily" else FamilyMemberStats.weekly_contribution
    rows = db.query(FamilyMemberStats).filter(FamilyMemberStats.family_id == family_id).order_by(score_field.desc()).limit(limit).all()
    return {"family_id": family_id, "period": period, "ranking_type": "family_members", "entries": [_member_payload(db, row, index, getattr(row, score_field.key)) for index, row in enumerate(rows, start=1)], "limit": limit}


@router.get("/rankings/exp")
def get_family_exp_rankings(period: str = Query(default="weekly"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    score_field = FamilyEconomyStats.monthly_exp if period == "monthly" else FamilyEconomyStats.daily_exp if period == "daily" else FamilyEconomyStats.weekly_exp
    rows = db.query(FamilyEconomyStats).order_by(score_field.desc()).limit(limit).all()
    return {"ranking_type": "family_exp", "period": period, "entries": [{"rank": index, "family_id": row.family_id, "family_name": row.family_name, "family_level": row.family_level, "member_count": row.member_count, "score": getattr(row, score_field.key)} for index, row in enumerate(rows, start=1)], "limit": limit}


@router.get("/rankings/contribution")
def get_family_contribution_rankings(period: str = Query(default="weekly"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    score_field = FamilyEconomyStats.monthly_contribution if period == "monthly" else FamilyEconomyStats.daily_contribution if period == "daily" else FamilyEconomyStats.weekly_contribution
    rows = db.query(FamilyEconomyStats).order_by(score_field.desc()).limit(limit).all()
    return {"ranking_type": "family_contribution", "period": period, "entries": [{"rank": index, "family_id": row.family_id, "family_name": row.family_name, "family_level": row.family_level, "member_count": row.member_count, "score": getattr(row, score_field.key)} for index, row in enumerate(rows, start=1)], "limit": limit}


@router.get("/rankings/events")
def get_family_event_rankings(period: str = Query(default="monthly"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    return {"ranking_type": "family_events", "period": period, "entries": [], "limit": limit, "source": "family_event_stats_not_connected_yet"}
