from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class RoomKickoutDurationSchema(str, Enum):
    ONE_HOUR = "1h"
    ONE_DAY = "1d"
    FOREVER = "forever"


class RoomKickoutCreateRequest(BaseModel):
    target_user_id: int | None = None
    target_public_user_id: str | None = None
    target_display_name: str | None = None
    duration: RoomKickoutDurationSchema
    reason: str | None = Field(default=None, max_length=500)


class RoomKickoutResponse(BaseModel):
    id: int
    room_public_id: str
    target_user_id: int | None = None
    target_public_user_id: str | None = None
    target_display_name: str | None = None
    created_by_user_id: int | None = None
    created_by_public_user_id: str | None = None
    duration: str
    blocked_until: datetime | None = None
    is_permanent: bool
    reason: str | None = None
    is_active: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
