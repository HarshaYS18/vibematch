from datetime import datetime
from pydantic import BaseModel, Field


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
