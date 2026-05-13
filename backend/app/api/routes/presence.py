from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User


router = APIRouter(prefix="/presence", tags=["Presence"])


class PresenceHeartbeatResponse(BaseModel):
    status: str
    user_id: int
    last_seen_at: datetime
    is_online: bool


@router.post("/heartbeat", response_model=PresenceHeartbeatResponse)
def presence_heartbeat(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    current_user.last_seen_at = now
    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return PresenceHeartbeatResponse(
        status="ok",
        user_id=current_user.id,
        last_seen_at=current_user.last_seen_at or now,
        is_online=True,
    )


@router.get("/me", response_model=PresenceHeartbeatResponse)
def get_my_presence(
    current_user: User = Depends(get_current_user),
):
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    return PresenceHeartbeatResponse(
        status="ok",
        user_id=current_user.id,
        last_seen_at=current_user.last_seen_at or now,
        is_online=True,
    )
