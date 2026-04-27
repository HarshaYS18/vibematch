from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class DeviceBan(Base):
    __tablename__ = "device_bans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)

    device_id: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
    )

    user_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    banned_by_user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )

    reason: Mapped[str] = mapped_column(Text, nullable=False)

    triggered_by_rule: Mapped[str | None] = mapped_column(String(120), nullable=True)

    ban_count_snapshot: Mapped[int | None] = mapped_column(Integer, nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    lifted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    lifted_by_user_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    lifted_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

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