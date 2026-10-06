from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, JSON, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class InboxConversationType(str, Enum):
    OFFICIAL = "official"
    CHAT = "chat"
    ROOM_INVITE = "room_invite"
    STRANGER = "stranger"
    FAMILY = "family"


class InboxMessageType(str, Enum):
    TEXT = "text"
    IMAGE = "image"
    VOICE = "voice"
    DOCUMENT = "document"
    LOCATION = "location"
    ROOM_INVITE = "room_invite"
    RELATIONSHIP_REQUEST = "relationship_request"
    SYSTEM = "system"
    STORY_REPLY = "story_reply"
    CALL_LOG = "call_log"


class InboxMessageStatus(str, Enum):
    SENT = "sent"
    DELIVERED = "delivered"
    READ = "read"
    FAILED = "failed"


class InboxReportStatus(str, Enum):
    PENDING_CS_REVIEW = "pending_cs_review"
    REJECTED_BY_CS = "rejected_by_cs"
    ACCEPTED_ESCALATED = "accepted_escalated"
    MONITOR_ACTION_TAKEN = "monitor_action_taken"


class InboxLockOtpPurpose(str, Enum):
    SETUP = "setup"
    RECOVERY = "recovery"


class InboxConversation(Base):
    __tablename__ = "inbox_conversations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    public_id: Mapped[str] = mapped_column(String(80), unique=True, index=True, nullable=False)
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    avatar_text: Mapped[str] = mapped_column(String(8), default="VM")
    conversation_type: Mapped[str] = mapped_column(String(40), index=True, nullable=False)
    is_official: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_locked: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_blocked: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_muted: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_pinned: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_archived: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    room_public_id: Mapped[str | None] = mapped_column(String(80), nullable=True, index=True)
    current_room_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    participants = relationship("InboxParticipant", back_populates="conversation", cascade="all, delete-orphan")
    messages = relationship("InboxMessage", back_populates="conversation", cascade="all, delete-orphan", order_by="InboxMessage.created_at")


class InboxParticipant(Base):
    __tablename__ = "inbox_participants"
    __table_args__ = (
        UniqueConstraint("conversation_id", "user_id", name="uq_inbox_participant_conversation_user"),
        Index("ix_inbox_participant_user_state", "user_id", "is_archived", "is_pinned"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    conversation_id: Mapped[int] = mapped_column(ForeignKey("inbox_conversations.id"), index=True, nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    unread_count: Mapped[int] = mapped_column(Integer, default=0)
    last_read_message_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_deleted_for_user: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_muted: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_pinned: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_archived: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    conversation = relationship("InboxConversation", back_populates="participants")
    user = relationship("User")


class InboxMessage(Base):
    __tablename__ = "inbox_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    public_id: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    source_dedupe_key: Mapped[str | None] = mapped_column(
        String(180),
        unique=True,
        index=True,
        nullable=True,
    )
    conversation_id: Mapped[int] = mapped_column(ForeignKey("inbox_conversations.id"), index=True, nullable=False)
    sender_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), index=True, nullable=True)
    sender_name: Mapped[str] = mapped_column(String(120), nullable=False)
    message_type: Mapped[str] = mapped_column(String(40), default=InboxMessageType.TEXT.value, index=True)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(String(40), default=InboxMessageStatus.SENT.value, index=True)
    reply_to_message_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    reply_to_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    reaction: Mapped[str | None] = mapped_column(String(16), nullable=True)
    is_starred: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_forwarded: Mapped[bool] = mapped_column(Boolean, default=False)
    invite_room_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    attachment_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    conversation = relationship("InboxConversation", back_populates="messages")
    sender = relationship("User")


class InboxReadReceipt(Base):
    __tablename__ = "inbox_read_receipts"
    __table_args__ = (
        UniqueConstraint("message_id", "user_id", name="uq_inbox_read_receipt_message_user"),
        Index("ix_inbox_read_receipt_conversation_user", "conversation_id", "user_id", "message_id"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    message_id: Mapped[int] = mapped_column(ForeignKey("inbox_messages.id", ondelete="CASCADE"), nullable=False, index=True)
    conversation_id: Mapped[int] = mapped_column(ForeignKey("inbox_conversations.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    read_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    message = relationship("InboxMessage")
    conversation = relationship("InboxConversation")
    user = relationship("User")


class InboxReport(Base):
    __tablename__ = "inbox_reports"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    public_id: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    conversation_id: Mapped[int] = mapped_column(ForeignKey("inbox_conversations.id"), index=True, nullable=False)
    reporter_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    reported_user_name: Mapped[str] = mapped_column(String(120), nullable=False)
    reason: Mapped[str] = mapped_column(Text, nullable=False)
    snapshot_json: Mapped[list] = mapped_column(JSON, nullable=False)
    status: Mapped[str] = mapped_column(String(50), default=InboxReportStatus.PENDING_CS_REVIEW.value, index=True)
    cs_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    monitor_action: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    conversation = relationship("InboxConversation")
    reporter = relationship("User")


class InboxLockSetting(Base):
    __tablename__ = "inbox_lock_settings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True, index=True, nullable=False)
    mobile_number: Mapped[str | None] = mapped_column(String(32), nullable=True, index=True)
    lock_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    is_enabled: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    recovery_requested: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    user = relationship("User")


class InboxLockOtp(Base):
    __tablename__ = "inbox_lock_otps"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    mobile_number: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    otp_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    debug_otp_plaintext: Mapped[str | None] = mapped_column(String(12), nullable=True)
    purpose: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    is_used: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    user = relationship("User")
