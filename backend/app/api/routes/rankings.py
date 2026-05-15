from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.economy import GiftTransaction, WalletLedger
from app.models.user import User
from app.services import experience_service, profile_service

router = APIRouter(prefix="/rankings", tags=["Rankings"])


def _period_start(period: str) -> datetime:
    now = datetime.utcnow()
    normalized = (period or "daily").strip().lower()
    if normalized in {"daily", "day", "today"}:
        return datetime(now.year, now.month, now.day)
    if normalized in {"weekly", "week"}:
        return now - timedelta(days=7)
    if normalized in {"monthly", "month"}:
        return datetime(now.year, now.month, 1)
    return datetime(now.year, now.month, now.day)


def _compact(value: int) -> str:
    if value >= 1_000_000_000:
        return f"{value / 1_000_000_000:.1f}B"
    if value >= 1_000_000:
        return f"{value / 1_000_000:.1f}M"
    if value >= 1_000:
        return f"{value / 1_000:.1f}K"
    return str(value)


def _entry(db: Session, user: User, rank: int, score: int) -> dict:
    exp = experience_service.get_or_create_user_exp(db, user.id)
    vip = profile_service.vip_summary(db, user)
    return {
        "rank": rank,
        "score": score,
        "score_display": _compact(score),
        "user": {
            "id": user.id,
            "public_user_id": user.public_user_id,
            "display_name": user.display_name or user.username or str(user.public_user_id),
            "username": user.username,
            "avatar_url": user.avatar_url,
            "vip_level": getattr(vip, "vip_level", 0),
            "svip_level": getattr(vip, "svip_level", 0),
            "send_level": exp.send_level,
            "receive_level": exp.receive_level,
        },
    }


def _gift_ranking(db: Session, *, column, period: str, limit: int) -> dict:
    start_at = _period_start(period)
    rows = (
        db.query(column.label("user_id"), func.coalesce(func.sum(GiftTransaction.total_coin_value), 0).label("score"))
        .filter(GiftTransaction.created_at >= start_at)
        .group_by(column)
        .order_by(func.coalesce(func.sum(GiftTransaction.total_coin_value), 0).desc())
        .limit(max(1, min(limit, 100)))
        .all()
    )
    users = {user.id: user for user in db.query(User).filter(User.id.in_([int(row.user_id) for row in rows if row.user_id])).all()} if rows else {}
    return {
        "period": period,
        "period_start_at": start_at.isoformat(),
        "generated_at": datetime.utcnow().isoformat(),
        "entries": [_entry(db, users[int(row.user_id)], index, int(row.score or 0)) for index, row in enumerate(rows, start=1) if int(row.user_id) in users],
    }


@router.get("/sent")
def sent_rankings(period: str = Query(default="daily"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    payload = _gift_ranking(db, column=GiftTransaction.sender_user_id, period=period, limit=limit)
    payload["ranking_type"] = "sent"
    return payload


@router.get("/received")
def received_rankings(period: str = Query(default="daily"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    payload = _gift_ranking(db, column=GiftTransaction.receiver_user_id, period=period, limit=limit)
    payload["ranking_type"] = "received"
    return payload


@router.get("/recharge")
def recharge_rankings(period: str = Query(default="daily"), limit: int = Query(default=100, ge=1, le=100), db: Session = Depends(get_db)):
    start_at = _period_start(period)
    rows = (
        db.query(WalletLedger.user_id.label("user_id"), func.coalesce(func.sum(WalletLedger.amount), 0).label("score"))
        .filter(WalletLedger.created_at >= start_at, WalletLedger.direction.in_(["credit", "CREDIT"]), WalletLedger.source_type.in_(["RECHARGE", "OFFICIAL_RECHARGE", "SELLER_COIN_SALE"]))
        .group_by(WalletLedger.user_id)
        .order_by(func.coalesce(func.sum(WalletLedger.amount), 0).desc())
        .limit(max(1, min(limit, 100)))
        .all()
    )
    users = {user.id: user for user in db.query(User).filter(User.id.in_([int(row.user_id) for row in rows if row.user_id])).all()} if rows else {}
    return {
        "ranking_type": "recharge",
        "period": period,
        "period_start_at": start_at.isoformat(),
        "generated_at": datetime.utcnow().isoformat(),
        "entries": [_entry(db, users[int(row.user_id)], index, int(row.score or 0)) for index, row in enumerate(rows, start=1) if int(row.user_id) in users],
    }
