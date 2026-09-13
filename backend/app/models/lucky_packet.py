from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class LuckyPacket(Base):
    __tablename__ = "lucky_packets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    public_id: Mapped[str] = mapped_column(String(80), unique=True, index=True, nullable=False)
    room_id: Mapped[int] = mapped_column(ForeignKey("rooms.id"), index=True, nullable=False)
    sender_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    coin_amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    winner_count: Mapped[int] = mapped_column(Integer, nullable=False)
    message: Mapped[str] = mapped_column(String(120), default="", nullable=False)
    status: Mapped[str] = mapped_column(String(30), default="ACTIVE", index=True, nullable=False)
    claimed_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    claimed_coin_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    refunded_coin_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    allocation_json: Mapped[str] = mapped_column(Text, nullable=False)
    opens_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, index=True)
    closes_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    closed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    room = relationship("Room")
    sender = relationship("User")


class LuckyPacketClaim(Base):
    __tablename__ = "lucky_packet_claims"
    __table_args__ = (
        UniqueConstraint("packet_id", "user_id", name="uq_lucky_packet_claim_user"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    packet_id: Mapped[int] = mapped_column(ForeignKey("lucky_packets.id"), index=True, nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    reward_coin_amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    packet = relationship("LuckyPacket")
    user = relationship("User")
