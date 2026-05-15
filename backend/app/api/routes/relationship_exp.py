from fastapi import APIRouter, Depends
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.economy_stats import RelationshipEconomyStats
from app.models.user import User

router = APIRouter(tags=["Relationship EXP"])


def _relationship_payload(row: RelationshipEconomyStats | None, relationship_id: int) -> dict:
    if row is None:
        return {
            "relationship_id": relationship_id,
            "relationship_level": 0,
            "relationship_exp": 0,
            "next_level_exp": 0,
            "progress_percent": 0,
            "score_display": "0",
            "bond_title": None,
            "source": "empty_until_relationship_stats_exist",
        }
    next_level_exp = max((row.relationship_level + 1) * 10000, row.relationship_exp)
    progress = 100 if next_level_exp <= 0 else min(100, int((row.relationship_exp / next_level_exp) * 100))
    return {
        "relationship_id": row.relationship_id,
        "user_a_id": row.user_a_id,
        "user_b_id": row.user_b_id,
        "relationship_level": row.relationship_level,
        "relationship_exp": row.relationship_exp,
        "next_level_exp": next_level_exp,
        "progress_percent": progress,
        "score_display": str(row.relationship_exp),
        "bond_title": None,
        "daily_exp": row.daily_exp,
        "weekly_exp": row.weekly_exp,
        "monthly_exp": row.monthly_exp,
        "updated_at": row.updated_at.isoformat() if row.updated_at else None,
    }


@router.get("/relationships/{relationship_id}/score")
def get_relationship_score(relationship_id: int, db: Session = Depends(get_db)):
    row = db.query(RelationshipEconomyStats).filter(RelationshipEconomyStats.relationship_id == relationship_id).first()
    return _relationship_payload(row, relationship_id)


@router.get("/relationships/{relationship_id}/history")
def get_relationship_history(relationship_id: int, db: Session = Depends(get_db)):
    return {"relationship_id": relationship_id, "history": [], "source": "history_will_use_economy_events_after_event_writer_is_connected"}


@router.get("/users/{public_user_id}/relationship-score")
def get_public_user_relationship_score(public_user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    if user is None:
        return {"public_user_id": public_user_id, "active_relationship": None, "relationship_level": 0, "relationship_exp": 0}
    row = (
        db.query(RelationshipEconomyStats)
        .filter(or_(RelationshipEconomyStats.user_a_id == user.id, RelationshipEconomyStats.user_b_id == user.id))
        .order_by(RelationshipEconomyStats.relationship_exp.desc())
        .first()
    )
    payload = _relationship_payload(row, row.relationship_id if row else 0)
    payload["public_user_id"] = public_user_id
    payload["active_relationship"] = payload.get("relationship_id") if row else None
    return payload
