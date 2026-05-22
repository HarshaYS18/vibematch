from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class SupportAttachment(Base):
    __tablename__ = "support_attachments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    ticket_id: Mapped[int] = mapped_column(ForeignKey("support_tickets.id"), index=True, nullable=False)
    message_id: Mapped[int | None] = mapped_column(ForeignKey("support_messages.id"), index=True, nullable=True)
    uploaded_by_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    file_url: Mapped[str] = mapped_column(String(700), nullable=False)
    content_type: Mapped[str | None] = mapped_column(String(120), nullable=True)
    moderation_status: Mapped[str] = mapped_column(String(40), default="pending", index=True, nullable=False)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    ticket = relationship("SupportTicket", back_populates="attachments")
    message = relationship("SupportMessage")
    uploaded_by = relationship("User")
