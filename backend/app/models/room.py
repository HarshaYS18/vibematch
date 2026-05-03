from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Integer, String
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
    # This ID is generated once during room creation and must never change.
    room_public_id: Mapped[str] = mapped_column(
        String(32),
        unique=True,
        index=True,
        nullable=False,
    )

    owner_user_id: Mapped[int | None] = mapped_column(Integer, index=True, nullable=True)

    name: Mapped[str] = mapped_column(String(120), nullable=False)
    subtitle: Mapped[str | None] = mapped_column(String(240), nullable=True)
    cover_image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

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

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )
