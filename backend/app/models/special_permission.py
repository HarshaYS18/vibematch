from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Enum as SqlEnum, ForeignKey, Integer, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class SpecialPermissionName(str, Enum):
    BAN_USER = "BAN_USER"
    UNBAN_USER = "UNBAN_USER"
    TEMP_BAN_USER = "TEMP_BAN_USER"
    PERMANENT_BAN_USER = "PERMANENT_BAN_USER"


class SpecialPermission(Base):
    __tablename__ = "special_permissions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)

    user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    permission: Mapped[SpecialPermissionName] = mapped_column(
        SqlEnum(SpecialPermissionName),
        nullable=False,
        index=True,
    )

    granted_by_user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )

    reason: Mapped[str] = mapped_column(Text, nullable=False)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)

    expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    revoked_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    revoked_by_user_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    revoked_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    user = relationship(
        "User",
        foreign_keys=[user_id],
    )

    granted_by = relationship(
        "User",
        foreign_keys=[granted_by_user_id],
    )

    revoked_by = relationship(
        "User",
        foreign_keys=[revoked_by_user_id],
    )