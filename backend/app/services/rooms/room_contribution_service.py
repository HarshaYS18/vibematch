from __future__ import annotations

from datetime import datetime, timedelta

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.economy import GiftTransaction
from app.models.room import Room
from app.models.user import User
from app.services import experience_service
from app.services import profile_service


def _period_start(period: str) -> datetime:
    now = datetime.utcnow()
    normalized = (period or "daily").strip().lower()
    if normalized in {"today", "day", "daily"}:
        return datetime(now.year, now.month, now.day)
    if normalized in {"week", "weekly"}:
        return now - timedelta(days=7)
    if normalized in {"month", "monthly"}:
        return datetime(now.year, now.month, 1)
    if normalized in {"hour", "hourly"}:
        return now - timedelta(hours=1)
    return datetime(now.year, now.month, now.day)


def _compact_number(value: int) -> str:
    if value >= 1_000_000_000:
        suffix = value / 1_000_000_000
        return f"{suffix:.1f}B" if value % 1_000_000_000 else f"{int(suffix)}B"
    if value >= 1_000_000:
        suffix = value / 1_000_000
        return f"{suffix:.1f}M" if value % 1_000_000 else f"{int(suffix)}M"
    if value >= 1_000:
        suffix = value / 1_000
        return f"{suffix:.1f}K" if value % 1_000 else f"{int(suffix)}K"
    return str(value)


def _user_payload(db: Session, user: User, score: int, rank: int, category: str) -> dict:
    exp = experience_service.get_or_create_user_exp(db, user.id)
    vip = profile_service.vip_summary(db, user)
    if category == "received":
        subtitle = f"Receive Lv {exp.receive_level}"
    else:
        subtitle = f"Sent Lv {exp.send_level}"
    return {
        "rank": rank,
        "score": score,
        "score_text": _compact_number(score),
        "score_label": "coin",
        "subtitle": subtitle,
        "user": {
            "id": user.id,
            "public_user_id": user.public_user_id,
            "display_custom_id": user.display_custom_id,
            "username": user.username,
            "display_name": user.display_name or user.username or str(user.public_user_id),
            "avatar_url": user.avatar_url,
            "vip_level": getattr(vip, "vip_level", 0),
            "svip_level": getattr(vip, "svip_level", 0),
            "sending_level": exp.send_level,
            "receiving_level": exp.receive_level,
            "monthly_sent": 0,
            "monthly_received": 0,
        },
    }


def room_contribution_rankings(db: Session, *, room_public_id: str, category: str = "sent", period: str = "daily", limit: int = 100) -> dict | None:
    room = db.query(Room).filter(Room.room_public_id == room_public_id, Room.is_active.is_(True)).first()
    if room is None:
        return None

    safe_category = (category or "sent").strip().lower()
    if safe_category not in {"sent", "received"}:
        safe_category = "sent"
    start_at = _period_start(period)
    group_column = GiftTransaction.receiver_user_id if safe_category == "received" else GiftTransaction.sender_user_id

    rows = (
        db.query(group_column.label("user_id"), func.coalesce(func.sum(GiftTransaction.total_coin_value), 0).label("score"))
        .filter(GiftTransaction.room_id == room.id, GiftTransaction.created_at >= start_at)
        .group_by(group_column)
        .order_by(func.coalesce(func.sum(GiftTransaction.total_coin_value), 0).desc())
        .limit(max(1, min(limit, 100)))
        .all()
    )

    user_ids = [int(row.user_id) for row in rows if row.user_id is not None]
    users = {user.id: user for user in db.query(User).filter(User.id.in_(user_ids)).all()} if user_ids else {}
    entries = []
    for index, row in enumerate(rows, start=1):
        user = users.get(int(row.user_id))
        if user is None:
            continue
        entries.append(_user_payload(db, user, int(row.score or 0), index, safe_category))

    return {
        "room_public_id": room.room_public_id,
        "room_name": room.name,
        "category": safe_category,
        "period": period,
        "period_start_at": start_at.isoformat(),
        "generated_at": datetime.utcnow().isoformat(),
        "entries": entries,
    }
