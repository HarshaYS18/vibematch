from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, JSON, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class RoomSeatState(Base):
    """Persistent source-of-truth for live room seat/mic state.

    This replaces memory-only seat state so minimizing/restoring, leaving/re-entering,
    backend reconnects, and app refreshes can restore the same room state from DB.
    """

    __tablename__ = "room_seat_states"
    __table_args__ = (
        UniqueConstraint("room_id", "seat_index", name="uq_room_seat_state_room_seat"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    room_id: Mapped[int] = mapped_column(ForeignKey("rooms.id"), nullable=False, index=True)
    seat_index: Mapped[int] = mapped_column(Integer, nullable=False, index=True)

    occupant_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    is_locked: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, index=True)
    mic_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    admin_muted: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    locked_by_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    admin_muted_by_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    updated_by_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True)

    occupied_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    left_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    locked_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    admin_muted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    room = relationship("Room")
    occupant = relationship("User", foreign_keys=[occupant_user_id])


class RoomRealtimeEvent(Base):
    """Durable event log for room realtime actions.

    WebSocket delivery can be transient, but the action itself should be saved so
    clients can resync after reconnect and support future replay/debugging.
    """

    __tablename__ = "room_realtime_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    room_id: Mapped[int] = mapped_column(ForeignKey("rooms.id"), nullable=False, index=True)
    room_public_id: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    event_type: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    actor_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    target_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    payload: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    privacy_scope: Mapped[str] = mapped_column(String(40), nullable=False, default="room")
    sequence: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, index=True)

    room = relationship("Room")


class RoomChatMessage(Base):
    """Persistent live-room chat message storage.

    Text/image/ribbon/system/gift chat rows should survive room close/reopen and
    be restored from backend snapshots instead of local-only Flutter lists.
    """

    __tablename__ = "room_chat_messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    room_id: Mapped[int] = mapped_column(ForeignKey("rooms.id"), nullable=False, index=True)
    room_public_id: Mapped[str] = mapped_column(String(32), nullable=False, index=True)
    sender_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    message_type: Mapped[str] = mapped_column(String(40), nullable=False, default="text", index=True)
    text: Mapped[str | None] = mapped_column(Text, nullable=True)
    media_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, index=True)

    room = relationship("Room")
    sender = relationship("User", foreign_keys=[sender_user_id])
