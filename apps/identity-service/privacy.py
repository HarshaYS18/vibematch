"""Identity-owned data export/deletion request orchestration."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.privacy_request import PrivacyRequest
from app.models.user import User
from app.services.event_outbox_service import enqueue_event

router = APIRouter(prefix="/privacy", tags=["Privacy"])


class PrivacyRequestCreate(BaseModel):
    request_type: Literal["export", "delete"]


def _payload(row: PrivacyRequest) -> dict[str, object]:
    return {
        "id": row.id,
        "request_type": row.request_type,
        "status": row.status,
        "requested_at": row.requested_at,
        "due_at": row.due_at,
        "completed_at": row.completed_at,
        "cancelled_at": row.cancelled_at,
    }


@router.post("/requests", status_code=202)
def create_privacy_request(
    payload: PrivacyRequestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    active = (
        db.query(PrivacyRequest)
        .filter(
            PrivacyRequest.user_id == current_user.id,
            PrivacyRequest.request_type == payload.request_type,
            PrivacyRequest.status.in_(["PENDING", "IN_PROGRESS"]),
        )
        .first()
    )
    if active is not None:
        return _payload(active)

    now = datetime.now(timezone.utc)
    row = PrivacyRequest(
        user_id=current_user.id,
        public_user_id=current_user.public_user_id,
        request_type=payload.request_type,
        status="PENDING",
        requested_at=now,
        due_at=now + timedelta(days=30),
    )
    db.add(row)
    db.flush()
    enqueue_event(
        db,
        event_type=f"privacy.{payload.request_type}.requested",
        actor_user_id=current_user.id,
        payload={"privacy_request_id": row.id},
    )
    db.commit()
    db.refresh(row)
    return _payload(row)


@router.get("/requests")
def list_privacy_requests(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = (
        db.query(PrivacyRequest)
        .filter(PrivacyRequest.user_id == current_user.id)
        .order_by(PrivacyRequest.requested_at.desc())
        .limit(50)
        .all()
    )
    return {"requests": [_payload(row) for row in rows]}


@router.delete("/requests/{request_id}")
def cancel_privacy_request(
    request_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    row = (
        db.query(PrivacyRequest)
        .filter(
            PrivacyRequest.id == request_id,
            PrivacyRequest.user_id == current_user.id,
        )
        .first()
    )
    if row is None:
        raise HTTPException(status_code=404, detail="Privacy request not found")
    if row.status != "PENDING":
        raise HTTPException(status_code=409, detail="Only pending privacy requests can be cancelled")
    row.status = "CANCELLED"
    row.cancelled_at = datetime.now(timezone.utc)
    enqueue_event(
        db,
        event_type="privacy.request.cancelled",
        actor_user_id=current_user.id,
        payload={"privacy_request_id": row.id},
    )
    db.commit()
    return _payload(row)
