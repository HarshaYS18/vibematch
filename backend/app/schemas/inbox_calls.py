from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


class InboxCallType(str, Enum):
    AUDIO = "audio"
    VIDEO = "video"


class InboxCallStatus(str, Enum):
    RINGING = "ringing"
    ACCEPTED = "accepted"
    DECLINED = "declined"
    MISSED = "missed"
    ENDED = "ended"
    FAILED = "failed"
    CANCELLED = "cancelled"


class InboxCallStartRequest(BaseModel):
    call_type: InboxCallType = InboxCallType.AUDIO


class InboxCallDecisionRequest(BaseModel):
    reason: str | None = Field(default=None, max_length=160)


class InboxCallResponse(BaseModel):
    id: str
    conversation_id: str
    call_type: InboxCallType
    status: InboxCallStatus
    started_by_user_id: int
    peer_user_ids: list[int]
    started_at: datetime
    answered_at: datetime | None = None
    ended_at: datetime | None = None
    duration_seconds: int | None = None
    end_reason: str | None = None
    mediasoup_room_id: str | None = None
    media_contract: dict | None = None
    push_contract: dict | None = None


class InboxCallSummaryMessageResponse(BaseModel):
    message_id: str
    conversation_id: str
    text: str
    call_id: str
    status: InboxCallStatus
    duration_seconds: int | None = None


class InboxCallMediaContractResponse(BaseModel):
    call_id: str
    conversation_id: str
    media_contract: dict
