"""Short-lived PostgreSQL leases for reliable outbox publishing.

The database transaction ends before any broker I/O. A worker crash may result
in a later re-publish after the lease expires, which is intentional
at-least-once behavior. JetStream message IDs and idempotent consumers absorb
that duplicate safely.
"""

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from sqlalchemy import or_

from app.database import SessionLocal
from app.models.event_outbox import EventOutbox


@dataclass(frozen=True)
class ClaimedOutboxEvent:
    event_id: str
    event_type: str
    event_version: int
    occurred_at: datetime
    request_id: str | None
    trace_id: str | None
    traceparent: str | None
    actor_user_id: int | None
    payload: dict
    attempt_count: int


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def claim_outbox_batch(
    worker_id: str,
    *,
    limit: int = 25,
    lease_seconds: int = 120,
    now: datetime | None = None,
) -> list[ClaimedOutboxEvent]:
    if not worker_id.strip():
        raise ValueError("worker_id is required")
    if limit < 1:
        raise ValueError("limit must be positive")
    now = now or _utcnow()
    stale_before = now - timedelta(seconds=max(1, lease_seconds))
    with SessionLocal.begin() as db:
        rows = (
            db.query(EventOutbox)
            .filter(
                EventOutbox.published_at.is_(None),
                or_(EventOutbox.next_attempt_at.is_(None), EventOutbox.next_attempt_at <= now),
                or_(EventOutbox.claimed_at.is_(None), EventOutbox.claimed_at <= stale_before),
            )
            .order_by(EventOutbox.occurred_at, EventOutbox.event_id)
            .with_for_update(skip_locked=True)
            .limit(limit)
            .all()
        )
        claimed: list[ClaimedOutboxEvent] = []
        for row in rows:
            row.claimed_at = now
            row.claimed_by = worker_id
            row.attempt_count += 1
            row.last_error = None
            claimed.append(
                ClaimedOutboxEvent(
                    event_id=row.event_id,
                    event_type=row.event_type,
                    event_version=row.event_version,
                    occurred_at=row.occurred_at,
                    request_id=row.request_id,
                    trace_id=row.trace_id,
                    traceparent=row.traceparent,
                    actor_user_id=row.actor_user_id,
                    payload=dict(row.payload or {}),
                    attempt_count=row.attempt_count,
                )
            )
        return claimed


def mark_outbox_published(
    event_id: str,
    worker_id: str,
    *,
    now: datetime | None = None,
) -> bool:
    now = now or _utcnow()
    with SessionLocal.begin() as db:
        row = (
            db.query(EventOutbox)
            .filter(
                EventOutbox.event_id == event_id,
                EventOutbox.published_at.is_(None),
                EventOutbox.claimed_by == worker_id,
            )
            .with_for_update()
            .first()
        )
        if row is None:
            return False
        row.published_at = now
        row.claimed_at = None
        row.claimed_by = None
        row.next_attempt_at = None
        row.last_error = None
        return True


def release_outbox_claim(
    event_id: str,
    worker_id: str,
    *,
    error: str,
    delay_seconds: float,
    now: datetime | None = None,
) -> bool:
    now = now or _utcnow()
    with SessionLocal.begin() as db:
        row = (
            db.query(EventOutbox)
            .filter(
                EventOutbox.event_id == event_id,
                EventOutbox.published_at.is_(None),
                EventOutbox.claimed_by == worker_id,
            )
            .with_for_update()
            .first()
        )
        if row is None:
            return False
        row.claimed_at = None
        row.claimed_by = None
        row.next_attempt_at = now + timedelta(seconds=max(0.0, delay_seconds))
        row.last_error = error[:500]
        return True
