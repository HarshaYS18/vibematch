from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class UserViolationScore(Base):
    __tablename__ = "user_violation_scores"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True, index=True, nullable=False)
    score: Mapped[int] = mapped_column(Integer, default=0, index=True, nullable=False)
    severity: Mapped[str] = mapped_column(String(30), default="none", index=True, nullable=False)
    last_event_id: Mapped[int | None] = mapped_column(ForeignKey("moderation_events.id"), index=True, nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    user = relationship("User")
    last_event = relationship("ModerationEvent")
