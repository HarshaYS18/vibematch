from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class ModerationCase(Base):
    __tablename__ = "moderation_cases"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    public_id: Mapped[str] = mapped_column(String(80), unique=True, index=True, nullable=False)
    opened_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), index=True, nullable=True)
    target_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), index=True, nullable=True)
    room_id: Mapped[str | None] = mapped_column(String(80), index=True, nullable=True)
    status: Mapped[str] = mapped_column(String(40), default="open", index=True, nullable=False)
    category: Mapped[str] = mapped_column(String(60), index=True, nullable=False)
    priority: Mapped[str] = mapped_column(String(30), default="normal", index=True, nullable=False)
    ai_recommendation: Mapped[str | None] = mapped_column(Text, nullable=True)
    moderator_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)
    closed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True, index=True)

