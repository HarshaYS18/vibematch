from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ModerationEvidence(Base):
    __tablename__ = "moderation_evidence"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    case_id: Mapped[int] = mapped_column(ForeignKey("moderation_cases.id"), index=True, nullable=False)
    event_id: Mapped[int | None] = mapped_column(ForeignKey("moderation_events.id"), index=True, nullable=True)
    evidence_type: Mapped[str] = mapped_column(String(40), index=True, nullable=False)
    content_url: Mapped[str | None] = mapped_column(String(700), nullable=True)
    text_snapshot: Mapped[str | None] = mapped_column(Text, nullable=True)
    moderation_status: Mapped[str] = mapped_column(String(40), default="pending", index=True, nullable=False)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    case = relationship("ModerationCase")
    event = relationship("ModerationEvent")

