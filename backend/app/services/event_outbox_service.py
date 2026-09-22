"""Write a versioned domain event in the caller's DB transaction."""

from uuid import uuid4

from sqlalchemy.orm import Session

from app.models.event_outbox import EventOutbox


def enqueue_event(
    db: Session, *, event_type: str, payload: dict,
    actor_user_id: int | None = None, request_id: str | None = None,
    trace_id: str | None = None,
) -> EventOutbox:
    event = EventOutbox(
        event_id=str(uuid4()), event_type=event_type, event_version=1,
        actor_user_id=actor_user_id, request_id=request_id, trace_id=trace_id,
        payload=payload, attempt_count=0,
    )
    db.add(event)
    return event
