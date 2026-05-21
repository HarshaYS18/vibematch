from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class SupportTicket(Base):
    __tablename__ = "support_tickets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    public_id: Mapped[str] = mapped_column(String(80), unique=True, index=True, nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    category: Mapped[str] = mapped_column(String(60), index=True, nullable=False)
    subject: Mapped[str] = mapped_column(String(160), nullable=False)
    status: Mapped[str] = mapped_column(String(60), default="open", index=True, nullable=False)
    priority: Mapped[str] = mapped_column(String(30), default="normal", index=True, nullable=False)
    assigned_role: Mapped[str | None] = mapped_column(String(60), index=True, nullable=True)
    assigned_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), index=True, nullable=True)
    ai_summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    ai_summary_generated: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    missing_fields_json: Mapped[list | None] = mapped_column(JSON, nullable=True)
    resolution_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True, index=True)

    user = relationship("User", foreign_keys=[user_id])
    assigned_user = relationship("User", foreign_keys=[assigned_user_id])
    messages = relationship("SupportMessage", back_populates="ticket", cascade="all, delete-orphan", order_by="SupportMessage.created_at")
    attachments = relationship("SupportAttachment", back_populates="ticket", cascade="all, delete-orphan")

