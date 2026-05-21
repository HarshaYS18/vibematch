from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class AiHelpdeskLog(Base):
    __tablename__ = "ai_helpdesk_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), index=True, nullable=True)
    ticket_id: Mapped[int | None] = mapped_column(ForeignKey("support_tickets.id"), index=True, nullable=True)
    provider: Mapped[str] = mapped_column(String(40), default="local_rules", index=True, nullable=False)
    model: Mapped[str | None] = mapped_column(String(120), nullable=True)
    intent: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    category: Mapped[str] = mapped_column(String(60), index=True, nullable=False)
    priority: Mapped[str] = mapped_column(String(30), default="normal", index=True, nullable=False)
    prompt_preview: Mapped[str | None] = mapped_column(Text, nullable=True)
    output_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    user = relationship("User")
    ticket = relationship("SupportTicket")

