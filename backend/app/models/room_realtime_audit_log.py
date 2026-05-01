from datetime import datetime

from sqlalchemy import DateTime, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class RoomRealtimeAuditLog(Base):
    __tablename__ = "room_realtime_audit_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)

    room_id: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    event_type: Mapped[str] = mapped_column(String(100), nullable=False, index=True)

    actor_user_id: Mapped[str | None] = mapped_column(String(80), nullable=True, index=True)
    actor_name: Mapped[str | None] = mapped_column(String(120), nullable=True)

    target_user_id: Mapped[str | None] = mapped_column(String(80), nullable=True, index=True)
    seat_index: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    from_seat_index: Mapped[int | None] = mapped_column(Integer, nullable=True)
    to_seat_index: Mapped[int | None] = mapped_column(Integer, nullable=True)

    request_id: Mapped[str | None] = mapped_column(String(160), nullable=True, index=True)
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    metadata_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
        index=True,
    )
