from datetime import datetime
from pydantic import BaseModel, Field, model_validator


class NotificationResponse(BaseModel):
    id: int
    type: str
    title: str
    body: str
    target_type: str | None = None
    target_id: str | None = None
    target_url: str | None = None
    metadata: dict = Field(default_factory=dict)
    is_read: bool
    created_at: datetime


class NotificationListResponse(BaseModel):
    unread_count: int
    notifications: list[NotificationResponse] = Field(default_factory=list)


class NotificationUnreadCountResponse(BaseModel):
    unread_count: int


class NotificationMarkReadResponse(BaseModel):
    id: int
    is_read: bool


class NotificationMarkAllReadResponse(BaseModel):
    marked_read_count: int
    unread_count: int


class NotificationPreferenceUpdateRequest(BaseModel):
    push_enabled: bool = True
    quiet_start_minute: int | None = Field(default=None, ge=0, le=1439)
    quiet_end_minute: int | None = Field(default=None, ge=0, le=1439)
    timezone: str = Field(default="UTC", min_length=1, max_length=64)
    max_push_per_hour: int = Field(default=20, ge=1, le=500)
    notification_types: dict[str, bool] = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_quiet_pair(self):
        if (self.quiet_start_minute is None) != (self.quiet_end_minute is None):
            raise ValueError("quiet_start_minute and quiet_end_minute must be set together")
        return self


class NotificationPreferenceResponse(BaseModel):
    push_enabled: bool
    quiet_start_minute: int | None = None
    quiet_end_minute: int | None = None
    timezone: str
    max_push_per_hour: int
    notification_types: dict[str, bool] = Field(default_factory=dict)
