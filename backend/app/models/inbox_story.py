from datetime import datetime, timedelta

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class InboxStory(Base):
    """Inbox story item shown in the chat story rail.

    Stories expire by default after 24 hours and are filtered by backend
    privacy rules before being returned to viewers.
    """

    __tablename__ = "inbox_stories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    public_id: Mapped[str] = mapped_column(String(80), unique=True, index=True, nullable=False)
    owner_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    media_url: Mapped[str] = mapped_column(String(700), nullable=False)
    media_type: Mapped[str] = mapped_column(String(32), default="image", nullable=False)
    caption: Mapped[str | None] = mapped_column(Text, nullable=True)
    visibility: Mapped[str] = mapped_column(String(32), default="friends", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)
    view_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.utcnow() + timedelta(hours=24), index=True)

    owner = relationship("User")


class InboxStoryView(Base):
    __tablename__ = "inbox_story_views"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    story_id: Mapped[int] = mapped_column(ForeignKey("inbox_stories.id"), index=True, nullable=False)
    viewer_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    viewed_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    story = relationship("InboxStory")
    viewer = relationship("User")
