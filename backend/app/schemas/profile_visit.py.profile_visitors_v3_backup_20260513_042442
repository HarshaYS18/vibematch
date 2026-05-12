from datetime import datetime

from pydantic import BaseModel


class ProfileVisitRecordResponse(BaseModel):
    id: str
    visitor_user_id: int
    visitor_public_user_id: int
    visitor_visible_id: str
    visitor_display_name: str
    visitor_username: str | None = None
    visitor_avatar_url: str | None = None
    visitor_role_label: str
    visited_at: datetime
    visit_count: int


class ProfileVisitListResponse(BaseModel):
    visitors: list[ProfileVisitRecordResponse]
