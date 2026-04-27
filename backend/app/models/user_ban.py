from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Enum as SqlEnum, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class BanType(str, Enum):
    TEMPORARY = "temporary"
    PERMANENT = "permanent"


class BanSource(str, Enum):
    MONITOR_TEAM = "monitor_team"
    SPECIAL_PERMISSION = "special_permission"
    OWNER = "owner"
    FOUNDER_OWNER = "founder_owner"


class UserBan(Base):
    __tablename__ = "user_bans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)

    user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    banned_by_user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )

    ban_type: Mapped[BanType] = mapped_column(
        SqlEnum(BanType),
        nullable=False,
        index=True,
    )

    ban_source: Mapped[BanSource] = mapped_column(
        SqlEnum(BanSource),
        nullable=False,
        index=True,
    )

    reason: Mapped[str] = mapped_column(Text, nullable=False)

    starts_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)

    lifted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    lifted_by_user_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    lifted_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    device_id_snapshot: Mapped[str | None] = mapped_column(String(255), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user = relationship(
        "User",
        foreign_keys=[user_id],
    )

    banned_by = relationship(
        "User",
        foreign_keys=[banned_by_user_id],
    )

    lifted_by = relationship(
        "User",
        foreign_keys=[lifted_by_user_id],
    )