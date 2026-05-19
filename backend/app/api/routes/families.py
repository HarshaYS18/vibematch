from __future__ import annotations

import random
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy_stats import FamilyEconomyStats, FamilyMemberStats
from app.models.user import User

router = APIRouter(prefix="/families", tags=["Families"])


class FamilyCreateRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=80)
    minimum_vip_label: str | None = None


class FamilyAdminsRequest(BaseModel):
    admin_user_ids: list[str] = Field(default_factory=list)


class FamilyInviteRequest(BaseModel):
    user_ids: list[str] = Field(default_factory=list)


def _empty_family(user: User) -> dict:
    return {
        "public_user_id": user.public_user_id,
        "has_family": False,
        "should_show": False,
        "family": None,
        "id": None,
        "family_id": None,
        "name": None,
        "family_name": None,
        "role": None,
        "my_role": None,
        "level": 0,
        "member_count": 0,
        "total_exp": 0,
        "owner_public_user_id": None,
        "is_owner": False,
        "is_admin": False,
        "members": [],
        "rankings": [],
    }


def _parse_family_id(raw: str) -> int:
    try:
        return int(str(raw).strip())
    except (TypeError, ValueError):
        raise HTTPException(status_code=404, detail="Family not found") from None


def _family_by_id(db: Session, family_id: int) -> FamilyEconomyStats:
    family = db.query(FamilyEconomyStats).filter(FamilyEconomyStats.family_id == family_id).first()
    if not family:
        raise HTTPException(status_code=404, detail="Family not found")
    return family


def _member_row(db: Session, user_id: int) -> FamilyMemberStats | None:
    return (
        db.query(FamilyMemberStats)
        .filter(FamilyMemberStats.user_id == user_id)
        .order_by(FamilyMemberStats.joined_at.desc())
        .first()
    )


def _family_members(db: Session, family_id: int) -> list[FamilyMemberStats]:
    return (
        db.query(FamilyMemberStats)
        .filter(FamilyMemberStats.family_id == family_id)
        .order_by(FamilyMemberStats.family_role.desc(), FamilyMemberStats.total_contribution.desc())
        .all()
    )


def _owner_public_user_id(db: Session, family_id: int) -> int | None:
    owner = (
        db.query(FamilyMemberStats, User)
        .join(User, User.id == FamilyMemberStats.user_id)
        .filter(FamilyMemberStats.family_id == family_id, FamilyMemberStats.family_role == "owner")
        .first()
    )
    if not owner:
        return None
    return owner[1].public_user_id


def _display_name(user: User) -> str:
    return user.display_name or user.username or f"User {user.public_user_id}"


def _member_payload(db: Session, member: FamilyMemberStats) -> dict:
    user = db.query(User).filter(User.id == member.user_id).first()
    public_user_id = user.public_user_id if user else member.user_id
    return {
        "id": str(public_user_id),
        "user_id": str(public_user_id),
        "public_user_id": public_user_id,
        "name": _display_name(user) if user else f"User {public_user_id}",
        "avatar_url": user.avatar_url if user else None,
        "role": member.family_role,
        "contribution": member.total_contribution,
        "total_contribution": member.total_contribution,
        "daily_contribution": member.daily_contribution,
        "weekly_contribution": member.weekly_contribution,
        "monthly_contribution": member.monthly_contribution,
        "joined_at": member.joined_at.isoformat() if member.joined_at else None,
    }


def _family_payload(db: Session, family: FamilyEconomyStats, member: FamilyMemberStats | None = None) -> dict:
    role = member.family_role if member else None
    owner_public_user_id = _owner_public_user_id(db, family.family_id)
    return {
        "id": str(family.family_id),
        "family_id": str(family.family_id),
        "name": family.family_name or f"Family {family.family_id}",
        "family_name": family.family_name or f"Family {family.family_id}",
        "role": role,
        "my_role": role,
        "level": family.family_level,
        "family_level": family.family_level,
        "member_count": family.member_count,
        "max_members": 200,
        "total_exp": family.family_exp,
        "family_exp": family.family_exp,
        "quarter_carry_exp": family.monthly_exp,
        "gift_coins_this_quarter": family.monthly_contribution,
        "time_minutes_today": 0,
        "rank_label": "Family",
        "owner_public_user_id": owner_public_user_id,
        "should_show": True,
    }


def _rank_payload(db: Session, family: FamilyEconomyStats, rank: int) -> dict:
    owner_public_user_id = _owner_public_user_id(db, family.family_id)
    payload = _family_payload(db, family)
    payload.update(
        {
            "rank": rank,
            "score": family.weekly_exp or family.family_exp,
            "owner_public_user_id": owner_public_user_id,
            "family": dict(payload),
        }
    )
    return payload


def _rankings(db: Session, limit: int = 50) -> list[dict]:
    rows = (
        db.query(FamilyEconomyStats)
        .order_by(FamilyEconomyStats.weekly_exp.desc(), FamilyEconomyStats.family_exp.desc(), FamilyEconomyStats.member_count.desc())
        .limit(max(1, min(limit, 100)))
        .all()
    )
    return [_rank_payload(db, row, index + 1) for index, row in enumerate(rows)]


def _family_response_for_user(db: Session, user: User) -> dict:
    member = _member_row(db, user.id)
    if not member:
        payload = _empty_family(user)
        payload["rankings"] = _rankings(db, limit=20)
        return payload

    family = _family_by_id(db, member.family_id)
    members = [_member_payload(db, item) for item in _family_members(db, family.family_id)]
    family.member_count = len(members)
    family_payload = _family_payload(db, family, member)
    is_owner = member.family_role == "owner"
    is_admin = member.family_role in {"owner", "admin"}
    return {
        "public_user_id": user.public_user_id,
        "has_family": True,
        "should_show": True,
        "family": family_payload,
        "members": members,
        "rankings": _rankings(db, limit=20),
        "is_owner": is_owner,
        "is_admin": is_admin,
        **family_payload,
    }


def _generate_family_id(db: Session) -> int:
    for _ in range(25):
        family_id = random.randint(100000, 999999)
        exists = db.query(FamilyEconomyStats.id).filter(FamilyEconomyStats.family_id == family_id).first()
        if not exists:
            return family_id
    raise HTTPException(status_code=500, detail="Unable to allocate family id")


def _user_by_any_id(db: Session, raw_id: str) -> User | None:
    clean = str(raw_id).strip()
    if not clean:
        return None
    numeric_id: int | None = None
    if clean.isdigit():
        numeric_id = int(clean)
    query = db.query(User)
    if numeric_id is not None:
        return query.filter(or_(User.id == numeric_id, User.public_user_id == numeric_id)).first()
    return query.filter(or_(User.username == clean, User.display_name == clean)).first()


def _require_family_admin(db: Session, family_id: int, user: User, owner_only: bool = False) -> FamilyMemberStats:
    member = (
        db.query(FamilyMemberStats)
        .filter(FamilyMemberStats.family_id == family_id, FamilyMemberStats.user_id == user.id)
        .first()
    )
    allowed_roles = {"owner"} if owner_only else {"owner", "admin"}
    if not member or member.family_role not in allowed_roles:
        raise HTTPException(status_code=403, detail="Family admin permission required")
    return member


def _recount_members(db: Session, family_id: int) -> None:
    family = _family_by_id(db, family_id)
    family.member_count = db.query(FamilyMemberStats).filter(FamilyMemberStats.family_id == family_id).count()
    family.updated_at = datetime.utcnow()


@router.get("/me")
def get_my_family(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return _family_response_for_user(db, current_user)


@router.get("/rankings")
def get_family_rankings(period: str = "weekly", limit: int = 50, db: Session = Depends(get_db)):
    entries = _rankings(db, limit=limit)
    return {"period": period, "entries": entries, "rankings": entries}


@router.get("/public/{public_user_id}")
def get_public_family(public_user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return _family_response_for_user(db, user)


@router.get("/{family_id}/members")
def get_family_members(family_id: str, db: Session = Depends(get_db)):
    parsed_id = _parse_family_id(family_id)
    _family_by_id(db, parsed_id)
    return {"members": [_member_payload(db, member) for member in _family_members(db, parsed_id)]}


@router.post("")
def create_family(payload: FamilyCreateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if _member_row(db, current_user.id):
        raise HTTPException(status_code=409, detail="You are already in a family")

    family_id = _generate_family_id(db)
    family = FamilyEconomyStats(
        family_id=family_id,
        family_name=payload.name.strip(),
        family_level=0,
        family_exp=0,
        member_count=1,
    )
    db.add(family)
    db.flush()
    db.add(FamilyMemberStats(family_id=family_id, user_id=current_user.id, family_role="owner"))
    db.commit()
    return _family_response_for_user(db, current_user)


@router.post("/{family_id}/join-requests")
def request_join_family(family_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    parsed_id = _parse_family_id(family_id)
    _family_by_id(db, parsed_id)
    if _member_row(db, current_user.id):
        raise HTTPException(status_code=409, detail="You are already in a family")

    db.add(FamilyMemberStats(family_id=parsed_id, user_id=current_user.id, family_role="member"))
    _recount_members(db, parsed_id)
    db.commit()
    return {"status": "joined", **_family_response_for_user(db, current_user)}


@router.post("/{family_id}/leave")
def leave_family(family_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    parsed_id = _parse_family_id(family_id)
    member = (
        db.query(FamilyMemberStats)
        .filter(FamilyMemberStats.family_id == parsed_id, FamilyMemberStats.user_id == current_user.id)
        .first()
    )
    if not member:
        raise HTTPException(status_code=404, detail="Family membership not found")
    if member.family_role == "owner":
        raise HTTPException(status_code=400, detail="Owner must disband the family or transfer ownership")
    db.delete(member)
    _recount_members(db, parsed_id)
    db.commit()
    return _empty_family(current_user)


@router.post("/{family_id}/disband")
def disband_family(family_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    parsed_id = _parse_family_id(family_id)
    _require_family_admin(db, parsed_id, current_user, owner_only=True)
    for member in _family_members(db, parsed_id):
        db.delete(member)
    family = _family_by_id(db, parsed_id)
    db.delete(family)
    db.commit()
    return _empty_family(current_user)


@router.post("/{family_id}/admins")
def set_family_admins(family_id: str, payload: FamilyAdminsRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    parsed_id = _parse_family_id(family_id)
    _require_family_admin(db, parsed_id, current_user, owner_only=True)
    admin_user_ids = {user.id for raw in payload.admin_user_ids if (user := _user_by_any_id(db, raw))}
    for member in _family_members(db, parsed_id):
        if member.user_id == current_user.id:
            member.family_role = "owner"
        elif member.user_id in admin_user_ids:
            member.family_role = "admin"
        else:
            member.family_role = "member"
    db.commit()
    return {"members": [_member_payload(db, member) for member in _family_members(db, parsed_id)]}


@router.post("/{family_id}/invites")
def send_family_invites(family_id: str, payload: FamilyInviteRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    parsed_id = _parse_family_id(family_id)
    _require_family_admin(db, parsed_id, current_user)
    valid_targets = [_user_by_any_id(db, raw) for raw in payload.user_ids]
    return {"status": "sent", "sent_count": len([user for user in valid_targets if user is not None])}
