from pydantic import BaseModel, Field

from app.models.call_session import CallParticipantStatus, CallSessionStatus, CallSessionType


class CallParticipantResponse(BaseModel):
    user_id: int
    public_user_id: int
    display_name: str | None = None
    avatar_url: str | None = None
    status: CallParticipantStatus
    is_muted: bool
    is_camera_enabled: bool


class CallSessionCreateRequest(BaseModel):
    participant_user_ids: list[int] = Field(default_factory=list, max_length=32)
    conversation_id: int | None = None
    room_public_id: str | None = Field(default=None, max_length=32)
    call_type: CallSessionType


class CallParticipantUpdateRequest(BaseModel):
    status: CallParticipantStatus | None = None
    is_muted: bool | None = None
    is_camera_enabled: bool | None = None


class CallSessionEndRequest(BaseModel):
    end_reason: str | None = Field(default="ended", max_length=120)


class CallSessionResponse(BaseModel):
    id: int
    call_public_id: str
    conversation_id: int | None = None
    room_public_id: str | None = None
    call_type: CallSessionType
    status: CallSessionStatus
    started_by_user_id: int
    started_at: str
    answered_at: str | None = None
    ended_at: str | None = None
    duration_seconds: int | None = None
    end_reason: str | None = None
    is_video_enabled: bool
    is_group_call: bool
    participants: list[CallParticipantResponse]
