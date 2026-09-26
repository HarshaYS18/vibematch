from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class EconomyHouseReservation(Base):
    """Durable reserved-liability row for house/game payout exposure."""

    __tablename__ = "economy_house_reservations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    reservation_key: Mapped[str] = mapped_column(String(220), unique=True, nullable=False, index=True)
    release_scope: Mapped[str] = mapped_column(String(220), nullable=False, index=True)
    pool_id: Mapped[int] = mapped_column(
        ForeignKey("game_pools.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="ACTIVE", index=True)
    reference_type: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    reference_id: Mapped[str | None] = mapped_column(String(220), nullable=True, index=True)
    transaction_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    released_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True, index=True)
