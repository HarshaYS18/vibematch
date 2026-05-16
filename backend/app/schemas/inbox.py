from datetime import datetime
from pydantic import BaseModel, Field


class InboxMessageResponse(BaseModel):
    id: str
    sender: str
    text: str
    time: str
    is_mine: bool
    type: str = "text"
    status: str = "read"
    reaction: str | None = None
    reply_to_text: str | None = None
    is_starred: bool = False
    is_forwarded: bool = False
    invite_room_name: str | None = None
    invite_room_id: str | None = None
    love_bond_request_id: str | None = None
    love_bond_card_name: str | None = None
    love_bond_status: str | None = None
    created_at: datetime | None = None


class InboxConversationResponse(BaseModel):
    id: str
    title: str
    subtitle: str
    time: str
    avatar_text: str
    avatar_url: str | None = None
    type: str
    unread_count: int = 0
    is_online: bool = False
    last_seen_text: str = "offline"
    colors: list[str] = Field(default_factory=list)
    messages: list[InboxMessageResponse] = Field(default_factory=list)
    current_room_name: str | None = None
    current_room_id: str | None = None
    is_locked_by_backend: bool = False
    is_blocked: bool = False
    is_muted: bool = False
    is_pinned: bool = False
    is_archived: bool = False


class InboxConversationListResponse(BaseModel):
    conversations: list[InboxConversationResponse]


class InboxDirectConversationRequest(BaseModel):
    target_user_id: int = Field(gt=0)


class InboxRoomInviteRequest(BaseModel):
    room_name: str = Field(min_length=1, max_length=120)
    room_public_id: str | None = Field(default=None, max_length=80)
    room_language: str | None = Field(default=None, max_length=40)
    mode_title: str | None = Field(default=None, max_length=40)


class InboxSendMessageRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    type: str = "text"
    reply_to_text: str | None = None
    invite_room_name: str | None = None
    invite_room_id: str | None = None
    attachment_url: str | None = None


class InboxMessageActionRequest(BaseModel):
    reaction: str | None = None
    is_starred: bool | None = None


class InboxConversationStateRequest(BaseModel):
    is_muted: bool | None = None
    is_pinned: bool | None = None
    is_locked: bool | None = None
    is_blocked: bool | None = None


class InboxReportCreateRequest(BaseModel):
    reason: str = Field(min_length=1, max_length=1000)


class InboxReportTaskResponse(BaseModel):
    id: str
    reported_conversation_id: str
    reported_user_name: str
    reporter_name: str
    reason: str
    snapshot: list[InboxMessageResponse]
    created_at_label: str
    status: str
    cs_note: str | None = None
    monitor_action: str | None = None


class InboxReportTaskListResponse(BaseModel):
    tasks: list[InboxReportTaskResponse]


class InboxReportDecisionRequest(BaseModel):
    cs_note: str | None = None


class InboxMonitorActionRequest(BaseModel):
    action_label: str = Field(min_length=1, max_length=120)


class InboxLockStatusResponse(BaseModel):
    is_enabled: bool
    mobile_number: str | None = None
    recovery_requested: bool = False


class InboxLockStartSetupRequest(BaseModel):
    lock_code: str | None = Field(default=None, min_length=4, max_length=12)
    mobile_number: str | None = None


class InboxLockVerifySetupRequest(BaseModel):
    lock_code: str = Field(min_length=4, max_length=12)
    mobile_number: str | None = None
    otp: str | None = None


class InboxLockVerifyRequest(BaseModel):
    lock_code: str = Field(min_length=4, max_length=12)


class InboxLockChangeRequest(BaseModel):
    current_lock_code: str = Field(min_length=4, max_length=12)
    new_lock_code: str = Field(min_length=4, max_length=12)


class InboxLockRecoveryStartRequest(BaseModel):
    mobile_number: str | None = None


class InboxLockRecoveryVerifyRequest(BaseModel):
    mobile_number: str | None = None
    otp: str | None = None
    new_lock_code: str = Field(min_length=4, max_length=12)


class InboxLockOwnerResetByIdentifierRequest(BaseModel):
    user_identifier: str = Field(min_length=1, max_length=64, description="public_user_id or display_custom_id")


class InboxLockRecoveryRequestResponse(BaseModel):
    status: str
    message: str


class InboxLockDebugOtpResponse(BaseModel):
    status: str
    expires_in_minutes: int = 0
    debug_otp: str | None = None


class InboxBackupStatusResponse(BaseModel):
    is_enabled: bool
    is_authorized: bool
    provider: str
    frequency: str
    google_drive_email: str | None = None
    google_drive_folder_id: str | None = None
    last_backup_at: str | None = None
    last_restore_at: str | None = None
    last_status: str
    last_error: str | None = None
    backup_count: int = 0
    restore_count: int = 0


class InboxBackupSettingsRequest(BaseModel):
    is_enabled: bool | None = None
    frequency: str | None = None


class InboxGoogleDriveAuthStartResponse(BaseModel):
    authorization_url: str


class InboxGoogleDriveConnectRequest(BaseModel):
    google_drive_email: str | None = None
    authorization_code: str | None = "dev_mock_drive_code"


class InboxBackupJobResponse(BaseModel):
    id: str
    job_type: str
    provider: str
    status: str
    backup_file_id: str | None = None
    backup_file_name: str | None = None
    error_message: str | None = None
    created_at: str | None = None
    completed_at: str | None = None

