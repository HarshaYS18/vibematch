from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db

router = APIRouter(prefix="/families", tags=["Family Economy"])


def _empty_family_payload(family_id: int) -> dict:
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
        "source": "placeholder_until_family_tables_are_connected",
    }


@router.get("/{family_id}/master")
def get_family_master(family_id: int, db: Session = Depends(get_db)):
    return _empty_family_payload(family_id)


@router.get("/{family_id}/members")
def get_family_members(
    family_id: int,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=30, ge=1, le=100),
    sort: str = Query(default="role"),
    db: Session = Depends(get_db),
):
    return {
        "family_id": family_id,
        "members": [],
        "pagination": {"page": page, "limit": limit, "has_more": False},
        "sort": sort,
        "source": "placeholder_until_family_membership_tables_are_connected",
    }


@router.get("/{family_id}/exp")
def get_family_exp(family_id: int, db: Session = Depends(get_db)):
    return {
        **_empty_family_payload(family_id),
        "sources": {"member_gifts": 0, "family_events": 0, "active_time": 0},
    }


@router.get("/{family_id}/exp/history")
def get_family_exp_history(family_id: int, db: Session = Depends(get_db)):
    return {"family_id": family_id, "history": [], "source": "placeholder_until_economy_event_ledger_is_connected"}


@router.get("/{family_id}/rankings/members")
def get_family_member_rankings(family_id: int, period: str = Query(default="weekly"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    return {"family_id": family_id, "period": period, "ranking_type": "family_members", "entries": [], "limit": limit}


@router.get("/rankings/exp")
def get_family_exp_rankings(period: str = Query(default="weekly"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    return {"ranking_type": "family_exp", "period": period, "entries": [], "limit": limit}


@router.get("/rankings/contribution")
def get_family_contribution_rankings(period: str = Query(default="weekly"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    return {"ranking_type": "family_contribution", "period": period, "entries": [], "limit": limit}


@router.get("/rankings/events")
def get_family_event_rankings(period: str = Query(default="monthly"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    return {"ranking_type": "family_events", "period": period, "entries": [], "limit": limit}
