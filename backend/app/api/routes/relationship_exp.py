from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.economy_stats import RelationshipEconomyStats
from app.models.user import User
from app.api.routes.users import get_current_user

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


def _public_user_payload(user: User | None) -> dict | None:
    if user is None:
        return None
    return {
        "public_user_id": user.public_user_id,
        "display_name": user.display_name or user.username or f"User {user.public_user_id}",
        "username": user.username,
        "avatar_url": user.avatar_url,
    }


def _summary_payload(public_user_id: int, row: RelationshipEconomyStats | None, *, best_pair: User | None = None) -> dict:
    total_exp = int(row.relationship_exp if row else 0)
    level = int(row.relationship_level if row else 0)
    next_level_exp = max((level + 1) * 10000, total_exp)
    progress = 1.0 if next_level_exp <= 0 else min(1.0, total_exp / next_level_exp)
    return {
        "public_user_id": public_user_id,
        "total_exp": total_exp,
        "exp": total_exp,
        "level": level,
        "next_level_exp": next_level_exp,
        "progress": progress,
        "progress_ratio": progress,
        "relationship_level": level,
        "relationship_exp": total_exp,
        "best_pair": _public_user_payload(best_pair),
        "relationship_id": row.relationship_id if row else None,
        "source": "relationship_economy_stats",
    }


def _find_user_by_public_id(db: Session, public_user_id: int) -> User:
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user


def _best_relationship_for_user(db: Session, user: User) -> tuple[RelationshipEconomyStats | None, User | None]:
    row = (
        db.query(RelationshipEconomyStats)
        .filter(or_(RelationshipEconomyStats.user_a_id == user.id, RelationshipEconomyStats.user_b_id == user.id))
        .order_by(RelationshipEconomyStats.relationship_exp.desc(), RelationshipEconomyStats.updated_at.desc())
        .first()
    )
    if row is None:
        return None, None
    other_id = row.user_b_id if row.user_a_id == user.id else row.user_a_id
    other = db.query(User).filter(User.id == other_id).first() if other_id else None
    return row, other


@router.get("/relationships/{relationship_id}/score")
def get_relationship_score(relationship_id: int, db: Session = Depends(get_db)):
    row = db.query(RelationshipEconomyStats).filter(RelationshipEconomyStats.relationship_id == relationship_id).first()
    return _relationship_payload(row, relationship_id)


@router.get("/relationships/{relationship_id}/history")
def get_relationship_history(relationship_id: int, db: Session = Depends(get_db)):
    return {"relationship_id": relationship_id, "history": [], "source": "history_will_use_economy_events_after_event_writer_is_connected"}


@router.get("/relationships/me/summary")
def get_my_relationship_summary(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    row, best_pair = _best_relationship_for_user(db, current_user)
    return _summary_payload(current_user.public_user_id, row, best_pair=best_pair)


@router.get("/relationships/users/{public_user_id}/summary")
def get_public_user_relationship_summary(public_user_id: int, db: Session = Depends(get_db)):
    user = _find_user_by_public_id(db, public_user_id)
    row, best_pair = _best_relationship_for_user(db, user)
    return _summary_payload(user.public_user_id, row, best_pair=best_pair)


@router.get("/relationships/pairs/{other_public_user_id}/summary")
def get_relationship_pair_summary(
    other_public_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    other_user = _find_user_by_public_id(db, other_public_user_id)
    row = (
        db.query(RelationshipEconomyStats)
        .filter(
            or_(
                (RelationshipEconomyStats.user_a_id == current_user.id) & (RelationshipEconomyStats.user_b_id == other_user.id),
                (RelationshipEconomyStats.user_a_id == other_user.id) & (RelationshipEconomyStats.user_b_id == current_user.id),
            )
        )
        .first()
    )
    total_exp = int(row.relationship_exp if row else 0)
    level = int(row.relationship_level if row else 0)
    next_level_exp = max((level + 1) * 10000, total_exp)
    progress = 1.0 if next_level_exp <= 0 else min(1.0, total_exp / next_level_exp)
    return {
        "pair": {
            "id": str(row.relationship_id if row else f"{current_user.public_user_id}_{other_user.public_user_id}"),
            "pair_id": str(row.relationship_id if row else f"{current_user.public_user_id}_{other_user.public_user_id}"),
            "total_exp": total_exp,
            "exp": total_exp,
            "level": level,
            "next_level_exp": next_level_exp,
            "progress": progress,
            "progress_ratio": progress,
            "current_user": _public_user_payload(current_user),
            "other_user": _public_user_payload(other_user),
        }
    }


@router.get("/relationships/master")
def get_relationship_exp_master():
    return {
        "enabled": True,
        "max_level": 100,
        "rules": {
            "source": "relationship_economy_stats",
            "read_only_foundation": True,
        },
    }


@router.get("/relationships/rankings")
def get_relationship_rankings(period: str = Query("weekly"), limit: int = Query(100, ge=1, le=100), db: Session = Depends(get_db)):
    period_column = {
        "daily": RelationshipEconomyStats.daily_exp,
        "weekly": RelationshipEconomyStats.weekly_exp,
        "monthly": RelationshipEconomyStats.monthly_exp,
    }.get(period, RelationshipEconomyStats.weekly_exp)
    rows = db.query(RelationshipEconomyStats).order_by(period_column.desc(), RelationshipEconomyStats.relationship_exp.desc()).limit(limit).all()
    entries = []
    for index, row in enumerate(rows, start=1):
        user_a = db.query(User).filter(User.id == row.user_a_id).first() if row.user_a_id else None
        user_b = db.query(User).filter(User.id == row.user_b_id).first() if row.user_b_id else None
        entries.append(
            {
                "rank": index,
                "score": int(getattr(row, f"{period}_exp", row.weekly_exp) or row.relationship_exp or 0),
                "pair": {
                    "id": str(row.relationship_id),
                    "pair_id": str(row.relationship_id),
                    "total_exp": row.relationship_exp,
                    "level": row.relationship_level,
                    "user_a": _public_user_payload(user_a),
                    "user_b": _public_user_payload(user_b),
                },
            }
        )
    return {"period": period, "entries": entries}


@router.get("/relationships/me/history")
def get_my_relationship_history(limit: int = Query(50, ge=1, le=100), other_public_user_id: int | None = None):
    return {"entries": [], "history": [], "limit": limit, "other_public_user_id": other_public_user_id}


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
