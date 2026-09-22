"""Idempotent handlers. Value movement is deliberately excluded."""

from pydantic import BaseModel, Field
from sqlalchemy.exc import IntegrityError

from app.database import SessionLocal
from app.models.event_outbox import WorkerProcessedEvent
from app.models.notification import UserNotification
from app.models.user import User
from apps.worker.events import EventEnvelope


class NotificationRequested(BaseModel):
    recipient_user_id: int = Field(gt=0)
    notification_type: str = Field(min_length=1, max_length=60)
    title: str = Field(min_length=1, max_length=160)
    body: str = Field(min_length=1, max_length=4000)
    target_type: str | None = Field(default=None, max_length=60)
    target_id: str | None = Field(default=None, max_length=120)
    target_url: str | None = Field(default=None, max_length=500)


def handle_notification_requested(event: EventEnvelope) -> str:
    """Insert the inbox notification and idempotency marker in one DB commit."""
    payload = NotificationRequested.model_validate(event.payload)
    marker_key = {"event_id": str(event.event_id), "handler": "notification.requested"}
    with SessionLocal() as db:
        try:
            db.add(WorkerProcessedEvent(**marker_key))
            db.flush()
            if db.get(User, payload.recipient_user_id) is None:
                raise ValueError("notification recipient does not exist")
            db.add(UserNotification(
                recipient_user_id=payload.recipient_user_id,
                actor_user_id=event.actor_user_id,
                notification_type=payload.notification_type,
                title=payload.title,
                body=payload.body,
                target_type=payload.target_type,
                target_id=payload.target_id,
                target_url=payload.target_url,
                metadata_json={"event_id": str(event.event_id)},
                is_read=False,
            ))
            db.commit()
            return "processed"
        except IntegrityError:
            db.rollback()
            if db.get(WorkerProcessedEvent, marker_key) is not None:
                return "duplicate"
            raise


HANDLERS = {"notification.requested": handle_notification_requested}
