from datetime import datetime
from enum import Enum

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class LoveBondCardType(str, Enum):
    LOVE = "love"
    BESTIE = "bestie"
    SIBLING = "sibling"


class LoveBondRequestStatus(str, Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"
    CANCELLED = "cancelled"


class LoveBondStatus(str, Enum):
    ACTIVE = "active"
    ENDED = "ended"


class LoveBondInventory(Base):
    __tablename__ = "love_bond_inventory"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    card_type: Mapped[str] = mapped_column(String(40), index=True, nullable=False)
    card_name: Mapped[str] = mapped_column(String(80), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    reserved_quantity: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    source: Mapped[str | None] = mapped_column(String(80), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    user = relationship("User")

    __table_args__ = (
        UniqueConstraint("user_id", "card_type", name="uq_love_bond_inventory_user_card"),
    )


class LoveBondRequest(Base):
    __tablename__ = "love_bond_requests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    public_id: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    sender_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    receiver_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    card_type: Mapped[str] = mapped_column(String(40), index=True, nullable=False)
    card_name: Mapped[str] = mapped_column(String(80), nullable=False)
    status: Mapped[str] = mapped_column(String(40), default=LoveBondRequestStatus.PENDING.value, index=True)
    inbox_message_public_id: Mapped[str | None] = mapped_column(String(100), nullable=True, index=True)
    response_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    responded_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    sender = relationship("User", foreign_keys=[sender_user_id])
    receiver = relationship("User", foreign_keys=[receiver_user_id])


class LoveBond(Base):
    __tablename__ = "love_bonds"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    public_id: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    request_id: Mapped[int | None] = mapped_column(ForeignKey("love_bond_requests.id"), nullable=True, index=True)
    user_a_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    user_b_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    card_type: Mapped[str] = mapped_column(String(40), index=True, nullable=False)
    status: Mapped[str] = mapped_column(String(40), default=LoveBondStatus.ACTIVE.value, index=True)
    love_score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    level: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    started_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    request = relationship("LoveBondRequest")
    user_a = relationship("User", foreign_keys=[user_a_id])
    user_b = relationship("User", foreign_keys=[user_b_id])

    __table_args__ = (
        UniqueConstraint("user_a_id", "user_b_id", "card_type", "status", name="uq_love_bond_active_pair_card_status"),
    )
