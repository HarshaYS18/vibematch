from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Enum as SqlEnum, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class CallSessionType(str, Enum):
    DIRECT_AUDIO = "direct_audio"
    DIRECT_VIDEO = "direct_video"
    GROUP_AUDIO = "group_audio"
    GROUP_VIDEO = "group_video"


class CallSessionStatus(str, Enum):
    RINGING = "ringing"
    CONNECTING = "connecting"
    ACTIVE = "active"
    DECLINED = "declined"
    MISSED = "missed"
    ENDED = "ended"
    FAILED = "failed"
    CANCELLED = "cancelled"


class CallParticipantStatus(str, Enum):
    INVITED = "invited"
    RINGING = "ringing"
    JOINED = "joined"
    DECLINED = "declined"
    MISSED = "missed"
    LEFT = "left"
    FAILED = "failed"


class CallSession(Base):
    __tablename__ = "call_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    call_public_id: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)
    conversation_id: Mapped[int | None] = mapped_column(ForeignKey("inbox_conversations.id"), nullable=True, index=True)
    room_public_id: Mapped[str | None] = mapped_column(String(32), nullable=True, index=True)
    call_type: Mapped[CallSessionType] = mapped_column(SqlEnum(CallSessionType), nullable=False, index=True)
    status: Mapped[CallSessionStatus] = mapped_column(SqlEnum(CallSessionStatus), nullable=False, default=CallSessionStatus.RINGING, index=True)
    started_by_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    started_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, index=True)
    answered_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    duration_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    end_reason: Mapped[str | None] = mapped_column(String(120), nullable=True)
    is_video_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_group_call: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    conversation = relationship("InboxConversation")
    started_by = relationship("User", foreign_keys=[started_by_user_id])
    participants = relationship(
        "CallParticipant",
        back_populates="call_session",
        cascade="all, delete-orphan",
        order_by="CallParticipant.id",
    )


class CallParticipant(Base):
    __tablename__ = "call_participants"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    call_session_id: Mapped[int] = mapped_column(ForeignKey("call_sessions.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    status: Mapped[CallParticipantStatus] = mapped_column(SqlEnum(CallParticipantStatus), nullable=False, default=CallParticipantStatus.INVITED, index=True)
    invited_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    joined_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    left_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    is_muted: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_camera_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    call_session = relationship("CallSession", back_populates="participants")
    user = relationship("User", foreign_keys=[user_id])
