from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class RoomPkMatch(Base):
    __tablename__ = "room_pk_matches"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    match_public_id: Mapped[str] = mapped_column(String(80), unique=True, index=True, nullable=False)
    challenger_room_id: Mapped[int] = mapped_column(ForeignKey("rooms.id"), index=True, nullable=False)
    opponent_room_id: Mapped[int] = mapped_column(ForeignKey("rooms.id"), index=True, nullable=False)
    created_by_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    status: Mapped[str] = mapped_column(String(24), index=True, nullable=False, default="challenged")
    duration_seconds: Mapped[int] = mapped_column(Integer, nullable=False, default=180)
    challenger_score: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    opponent_score: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    winner_room_id: Mapped[int | None] = mapped_column(ForeignKey("rooms.id"), nullable=True)
    challenge_expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    started_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    finished_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    finished_reason: Mapped[str | None] = mapped_column(String(80), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)


class RoomPkScoreReceipt(Base):
    __tablename__ = "room_pk_score_receipts"
    __table_args__ = (
        UniqueConstraint("source_event_id", name="uq_room_pk_score_receipt_event"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    match_id: Mapped[int] = mapped_column(ForeignKey("room_pk_matches.id"), index=True, nullable=False)
    room_id: Mapped[int] = mapped_column(ForeignKey("rooms.id"), index=True, nullable=False)
    source_event_id: Mapped[str] = mapped_column(String(160), nullable=False)
    coin_value: Mapped[int] = mapped_column(BigInteger, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
