from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class RoomMode(str, Enum):
    OPEN = "Open"
    LOCKED = "Locked"
    SECRET_VIBE = "Secret Vibe"
    VIBE_SYNC = "Vibe Sync"
    MEMBERS_ONLY = "Members Only"


class RoomType(str, Enum):
    MUSIC = "Music"
    GAMING = "Gaming"
    CHAT = "Chat"
    PK = "PK"
    OTHER = "Other"


class Room(Base):
    __tablename__ = "rooms"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)

    # Human-readable room ID shown in the UI, for example VM120451.
    room_public_id: Mapped[str] = mapped_column(
        String(32),
        unique=True,
        index=True,
        nullable=False,
    )

    owner_user_id: Mapped[int | None] = mapped_column(Integer, index=True, nullable=True)

    name: Mapped[str] = mapped_column(String(120), nullable=False)
    subtitle: Mapped[str | None] = mapped_column(String(240), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    cover_photo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    language: Mapped[str] = mapped_column(String(40), index=True, nullable=False)
    mode: Mapped[str] = mapped_column(
        String(40),
        index=True,
        nullable=False,
        default=RoomMode.OPEN.value,
    )
    room_type: Mapped[str] = mapped_column(
        String(40),
        index=True,
        nullable=False,
        default=RoomType.CHAT.value,
    )

    online_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    trending_score: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    is_secret: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_locked: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_members_only: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    allow_screenshots: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")

    # Functional live room settings. These are backend-owned and broadcast as
    # canonical room snapshots after each child update.
    room_images_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    guest_messages_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    apply_only_mode_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="false")

    # Locked room access. Store only a hash, never the plain lock/password.
    lock_password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    lock_updated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    lock_updated_by_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # Persistent room customization/state.
    background_theme_id: Mapped[str] = mapped_column(String(80), nullable=False, default="default", server_default="default")
    seat_layout_id: Mapped[str] = mapped_column(String(24), nullable=False, default="5x2", server_default="5x2")
    announcement_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    announcement_updated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    announcement_updated_by_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # Chunk 20 Room State Engine v2 counters. room_version advances with
    # authoritative mutation events; event_sequence identifies durable events.
    realtime_version: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    realtime_event_sequence: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")

    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)
