from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, JSON, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class InboxUserPreference(Base):
    __tablename__ = "inbox_user_preferences"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True, index=True, nullable=False)
    strangers_can_message: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    strangers_can_mention_in_vibes: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    read_receipts_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    online_visibility: Mapped[str] = mapped_column(String(32), default="everyone", nullable=False)
    last_seen_visibility: Mapped[str] = mapped_column(String(32), default="everyone", nullable=False)
    typing_activity_visibility: Mapped[str] = mapped_column(String(32), default="everyone", nullable=False)
    story_visibility: Mapped[str] = mapped_column(String(32), default="friends", nullable=False)
    device_unlock_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    default_chat_theme: Mapped[str] = mapped_column(String(64), default="pearl", nullable=False)
    default_wallpaper_key: Mapped[str] = mapped_column(String(80), default="premium_pearl", nullable=False)
    default_wallpaper_url: Mapped[str | None] = mapped_column(String(700), nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    user = relationship("User")


class InboxConversationUserSetting(Base):
    __tablename__ = "inbox_conversation_user_settings"
    __table_args__ = (UniqueConstraint("conversation_id", "user_id", name="uq_inbox_conversation_user_settings"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    conversation_id: Mapped[int] = mapped_column(ForeignKey("inbox_conversations.id"), index=True, nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    chat_theme: Mapped[str | None] = mapped_column(String(64), nullable=True)
    wallpaper_key: Mapped[str | None] = mapped_column(String(80), nullable=True)
    wallpaper_url: Mapped[str | None] = mapped_column(String(700), nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    conversation = relationship("InboxConversation")
    user = relationship("User")


class InboxMessageUserState(Base):
    __tablename__ = "inbox_message_user_states"
    __table_args__ = (UniqueConstraint("message_id", "user_id", name="uq_inbox_message_user_state"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    message_id: Mapped[int] = mapped_column(ForeignKey("inbox_messages.id"), index=True, nullable=False)
    conversation_id: Mapped[int] = mapped_column(ForeignKey("inbox_conversations.id"), index=True, nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    is_deleted_for_user: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    message = relationship("InboxMessage")
    conversation = relationship("InboxConversation")
    user = relationship("User")
