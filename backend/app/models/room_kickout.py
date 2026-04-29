from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class RoomKickoutDuration(str, Enum):
    ONE_HOUR = "1h"
    ONE_DAY = "1d"
    FOREVER = "forever"


class RoomKickout(Base):
    __tablename__ = "room_kickouts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)

    # Public room ID, for example VM120451. This keeps the first contract simple
    # before we fully normalize room membership and room IDs.
    room_public_id: Mapped[str] = mapped_column(String(32), index=True, nullable=False)

    target_user_id: Mapped[int | None] = mapped_column(Integer, index=True, nullable=True)
    target_public_user_id: Mapped[str | None] = mapped_column(String(64), index=True, nullable=True)
    target_display_name: Mapped[str | None] = mapped_column(String(120), nullable=True)

    created_by_user_id: Mapped[int | None] = mapped_column(Integer, index=True, nullable=True)
    created_by_public_user_id: Mapped[str | None] = mapped_column(String(64), nullable=True)

    duration: Mapped[str] = mapped_column(String(20), nullable=False)
    blocked_until: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    is_permanent: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )
