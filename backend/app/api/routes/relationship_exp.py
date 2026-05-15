from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db

router = APIRouter(tags=["Relationship EXP"])


def _relationship_payload(relationship_id: int) -> dict:
    return {
        "relationship_id": relationship_id,
        "relationship_level": 0,
        "relationship_exp": 0,
        "next_level_exp": 0,
        "progress_percent": 0,
        "score_display": "0",
        "bond_title": None,
        "source": "placeholder_until_relationship_economy_stats_are_connected",
    }


@router.get("/relationships/{relationship_id}/score")
def get_relationship_score(relationship_id: int, db: Session = Depends(get_db)):
    return _relationship_payload(relationship_id)


@router.get("/relationships/{relationship_id}/history")
def get_relationship_history(relationship_id: int, db: Session = Depends(get_db)):
    return {"relationship_id": relationship_id, "history": [], "source": "placeholder_until_economy_event_ledger_is_connected"}


@router.get("/users/{public_user_id}/relationship-score")
def get_public_user_relationship_score(public_user_id: int, db: Session = Depends(get_db)):
    return {
        "public_user_id": public_user_id,
        "active_relationship": None,
        "relationship_level": 0,
        "relationship_exp": 0,
        "source": "placeholder_until_love_bond_score_mapping_is_connected",
    }
