from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.economy import GiftTransaction, WalletLedger
from app.models.experience import UserExperienceStatus
from app.models.user import User
from app.models.vip_status import UserVipStatus


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


def _ranking_projection(
    db: Session,
    user_ids: list[int],
) -> tuple[
    dict[int, User],
    dict[int, UserExperienceStatus],
    dict[int, UserVipStatus],
]:
    """Load all display metadata for one ranking page in three bounded reads."""
    resolved_ids = list(dict.fromkeys(int(user_id) for user_id in user_ids if user_id))
    if not resolved_ids:
        return {}, {}, {}

    users = {
        user.id: user
        for user in db.query(User).filter(User.id.in_(resolved_ids)).all()
    }
    experiences = {
        row.user_id: row
        for row in db.query(UserExperienceStatus)
        .filter(UserExperienceStatus.user_id.in_(resolved_ids))
        .all()
    }
    vip_statuses = {
        row.user_id: row
        for row in db.query(UserVipStatus)
        .filter(UserVipStatus.user_id.in_(resolved_ids))
        .all()
    }
    return users, experiences, vip_statuses


def _entry(
    user: User,
    *,
    rank: int,
    score: int,
    experience: UserExperienceStatus | None,
    vip: UserVipStatus | None,
) -> dict:
    return {
        "rank": rank,
        "score": score,
        "score_display": _compact(score),
        "user": {
            "id": user.id,
            "public_user_id": user.public_user_id,
            "display_name": (
                user.display_name or user.username or str(user.public_user_id)
            ),
            "username": user.username,
            "avatar_url": user.avatar_url,
            "vip_level": int(vip.vip_level or 0) if vip else 0,
            "svip_level": int(vip.svip_level or 0) if vip else 0,
            "send_level": int(experience.send_level or 1) if experience else 1,
            "receive_level": (
                int(experience.receive_level or 1) if experience else 1
            ),
        },
    }


def _render_ranking(
    db: Session,
    *,
    rows,
    period: str,
    start_at: datetime,
    ranking_type: str,
) -> dict:
    user_ids = [int(row.user_id) for row in rows if row.user_id]
    users, experiences, vip_statuses = _ranking_projection(db, user_ids)
    entries = []
    for index, row in enumerate(rows, start=1):
        user_id = int(row.user_id)
        user = users.get(user_id)
        if user is None:
            continue
        entries.append(
            _entry(
                user,
                rank=index,
                score=int(row.score or 0),
                experience=experiences.get(user_id),
                vip=vip_statuses.get(user_id),
            )
        )
    return {
        "ranking_type": ranking_type,
        "period": period,
        "period_start_at": start_at.isoformat(),
        "generated_at": datetime.utcnow().isoformat(),
        "entries": entries,
    }


def _gift_ranking(
    db: Session,
    *,
    column,
    period: str,
    limit: int,
    ranking_type: str,
) -> dict:
    start_at = _period_start(period)
    score = func.coalesce(func.sum(GiftTransaction.total_coin_value), 0)
    rows = (
        db.query(column.label("user_id"), score.label("score"))
        .filter(GiftTransaction.created_at >= start_at)
        .group_by(column)
        .order_by(score.desc(), column.asc())
        .limit(max(1, min(limit, 100)))
        .all()
    )
    return _render_ranking(
        db,
        rows=rows,
        period=period,
        start_at=start_at,
        ranking_type=ranking_type,
    )


@router.get("/sent")
def sent_rankings(
    period: str = Query(default="daily"),
    limit: int = Query(default=100, ge=1, le=100),
    db: Session = Depends(get_db),
):
    return _gift_ranking(
        db,
        column=GiftTransaction.sender_user_id,
        period=period,
        limit=limit,
        ranking_type="sent",
    )


@router.get("/received")
def received_rankings(
    period: str = Query(default="daily"),
    limit: int = Query(default=100, ge=1, le=100),
    db: Session = Depends(get_db),
):
    return _gift_ranking(
        db,
        column=GiftTransaction.receiver_user_id,
        period=period,
        limit=limit,
        ranking_type="received",
    )


@router.get("/recharge")
def recharge_rankings(
    period: str = Query(default="daily"),
    limit: int = Query(default=100, ge=1, le=100),
    db: Session = Depends(get_db),
):
    start_at = _period_start(period)
    score = func.coalesce(func.sum(WalletLedger.amount), 0)
    rows = (
        db.query(WalletLedger.user_id.label("user_id"), score.label("score"))
        .filter(
            WalletLedger.created_at >= start_at,
            WalletLedger.direction.in_(["credit", "CREDIT"]),
            WalletLedger.source_type.in_(
                [
                    "RECHARGE",
                    "OFFICIAL_RECHARGE",
                    "SELLER_COIN_SALE",
                    "MERCHANT_COIN_SALE",
                    "OWNER_RECHARGE",
                    "FOUNDER_RECHARGE",
                    "ROLE_COIN_SALE",
                ]
            ),
        )
        .group_by(WalletLedger.user_id)
        .order_by(score.desc(), WalletLedger.user_id.asc())
        .limit(max(1, min(limit, 100)))
        .all()
    )
    return _render_ranking(
        db,
        rows=rows,
        period=period,
        start_at=start_at,
        ranking_type="recharge",
    )
