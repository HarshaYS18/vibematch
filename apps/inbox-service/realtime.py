from __future__ import annotations

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.services import inbox_realtime_command_service


router = APIRouter(prefix="/realtime", tags=["Inbox Realtime Commands"])


class InboxRealtimeCommandRequest(BaseModel):
    type: str = Field(min_length=1, max_length=80)
    conversation_id: str = Field(min_length=1, max_length=128)
    activity: str | None = Field(default=None, max_length=32)
    command_id: str | None = Field(default=None, max_length=128)
    payload: dict = Field(default_factory=dict)


class InboxRealtimeCommandResponse(BaseModel):
    accepted: bool = True
    command_id: str | None = None
    scope: str = "inbox"
    conversation_id: str


@router.post("/command", response_model=InboxRealtimeCommandResponse)
async def execute_inbox_realtime_command(
    payload: InboxRealtimeCommandRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    result = await inbox_realtime_command_service.execute_inbox_realtime_command(
        db,
        current_user,
        command_type=payload.type,
        conversation_id=payload.conversation_id,
        activity=payload.activity,
    )
    return InboxRealtimeCommandResponse(
        command_id=payload.command_id,
        conversation_id=result.conversation_id,
    )
