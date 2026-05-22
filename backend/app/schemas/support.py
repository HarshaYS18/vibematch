from datetime import datetime
from pydantic import BaseModel, Field


SUPPORT_CATEGORIES = {
    "recharge_issue",
    "ban_appeal",
    "report_user",
    "room_issue",
    "vip_svip_issue",
    "gift_issue",
    "payout_issue",
    "custom_theme_issue",
    "account_issue",
    "inbox_issue",
    "other",
}

SUPPORT_STATUSES = {
    "open",
    "waiting_user",
    "waiting_cs",
    "escalated_to_monitor",
    "resolved",
    "rejected",
    "closed",
}


class AiHelpdeskClassification(BaseModel):
    category: str = "other"
    intent: str = "general_help"
    priority: str = "normal"
    missing_fields: list[str] = Field(default_factory=list)
    suggested_reply: str = "Vibe Match Team · AI Assistant: I can help create a support ticket."
    should_create_ticket: bool = True
    should_escalate: bool = False
    provider: str = "local_rules"
    model: str | None = None


class SupportAttachmentCreate(BaseModel):
    file_url: str = Field(min_length=1, max_length=700)
    content_type: str | None = Field(default=None, max_length=120)


class SupportTicketCreateRequest(BaseModel):
    category: str | None = Field(default=None, max_length=60)
    subject: str = Field(min_length=4, max_length=160)
    message: str = Field(min_length=4, max_length=4000)
    attachments: list[SupportAttachmentCreate] = Field(default_factory=list)


class SupportMessageCreateRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    attachments: list[SupportAttachmentCreate] = Field(default_factory=list)


class SupportAdminActionRequest(BaseModel):
    message: str | None = Field(default=None, max_length=4000)
    status: str | None = Field(default=None, max_length=60)
    reason: str | None = Field(default=None, max_length=1000)
    moderation_notes: str | None = Field(default=None, max_length=2000)


class SupportMessageResponse(BaseModel):
    id: str
    sender_role: str
    body: str
    is_ai_generated: bool = False
    created_at: datetime


class SupportAttachmentResponse(BaseModel):
    file_url: str
    content_type: str | None = None
    moderation_status: str = "pending"
    created_at: datetime


class SupportTicketResponse(BaseModel):
    id: str
    category: str
    subject: str
    status: str
    priority: str
    ai_summary: str | None = None
    ai_summary_generated: bool = False
    missing_fields: list[str] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime
    resolved_at: datetime | None = None
    messages: list[SupportMessageResponse] = Field(default_factory=list)
    attachments: list[SupportAttachmentResponse] = Field(default_factory=list)


class HelpArticleResponse(BaseModel):
    slug: str
    category: str
    title: str
    body: str
    tags: list[str] = Field(default_factory=list)


class HelpAskRequest(BaseModel):
    message: str = Field(min_length=2, max_length=2000)


class HelpAskResponse(BaseModel):
    classification: AiHelpdeskClassification
    matching_articles: list[HelpArticleResponse] = Field(default_factory=list)


class InboxAiSearchRequest(BaseModel):
    query: str = Field(min_length=2, max_length=500)


class InboxAiSearchResult(BaseModel):
    conversation_id: str
    message_id: str | None = None
    title: str
    snippet: str
    time: datetime | None = None
    match_reason: str
    is_locked: bool = False


class InboxAiSearchResponse(BaseModel):
    query: str
    interpreted_filters: dict = Field(default_factory=dict)
    results: list[InboxAiSearchResult] = Field(default_factory=list)


class TextModerationRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    surface: str = Field(default="chat", max_length=60)
    room_id: str | None = Field(default=None, max_length=80)
    target_user_id: int | None = None


class ImageModerationRequest(BaseModel):
    image_url: str = Field(min_length=1, max_length=700)
    surface: str = Field(default="image_upload", max_length=60)
    room_id: str | None = Field(default=None, max_length=80)
    target_user_id: int | None = None


class ModerationResponse(BaseModel):
    event_id: str
    decision: str
    severity: str
    categories: list[str] = Field(default_factory=list)
    user_message: str
    case_id: str | None = None
    provider: str = "local_rules"
