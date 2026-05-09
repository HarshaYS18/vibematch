from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Enum as SqlEnum, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class CoinBalanceType(str, Enum):
    CONSUMABLE = "consumable"
    MERCHANT_SUPPLY = "merchant_supply"
    SELLER_SUPPLY = "seller_supply"
    FOUNDER_SUPPLY = "founder_supply"


class CoinTransactionType(str, Enum):
    FOUNDER_GRANT = "founder_grant"
    MERCHANT_TRANSFER = "merchant_transfer"
    SELLER_TRANSFER = "seller_transfer"
    USER_CONSUMPTION = "user_consumption"
    ADJUSTMENT = "adjustment"


class CoinTransactionStatus(str, Enum):
    COMPLETED = "completed"
    REJECTED = "rejected"
    REVERSED = "reversed"


class CoinBalance(Base):
    __tablename__ = "coin_balances"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    balance_type: Mapped[CoinBalanceType] = mapped_column(SqlEnum(CoinBalanceType), nullable=False, index=True)
    amount: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    is_locked: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class CoinTransaction(Base):
    __tablename__ = "coin_transactions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    transaction_public_id: Mapped[str] = mapped_column(String(80), unique=True, index=True, nullable=False)
    transaction_type: Mapped[CoinTransactionType] = mapped_column(SqlEnum(CoinTransactionType), nullable=False, index=True)
    status: Mapped[CoinTransactionStatus] = mapped_column(SqlEnum(CoinTransactionStatus), nullable=False, default=CoinTransactionStatus.COMPLETED, index=True)
    from_user_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    to_user_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    from_balance_type: Mapped[CoinBalanceType | None] = mapped_column(SqlEnum(CoinBalanceType), nullable=True)
    to_balance_type: Mapped[CoinBalanceType | None] = mapped_column(SqlEnum(CoinBalanceType), nullable=True)
    amount: Mapped[int] = mapped_column(Integer, nullable=False)
    actor_user_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
