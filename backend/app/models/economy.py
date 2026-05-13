from __future__ import annotations

from datetime import datetime
from enum import Enum

from sqlalchemy import BigInteger, Boolean, DateTime, Enum as SqlEnum, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class CoinPoolType(str, Enum):
    FOUNDER_SUPPLY = "founder_supply"
    MERCHANT = "merchant"
    COIN_SELLER = "coin_seller"
    RESELLER = "reseller"
    AGENCY = "agency"


class CoinPoolLedgerDirection(str, Enum):
    CREDIT = "credit"
    DEBIT = "debit"


class CoinPoolLedgerSource(str, Enum):
    FOUNDER_MINT = "founder_mint"
    FOUNDER_ALLOCATION = "founder_allocation"
    MERCHANT_ALLOCATION = "merchant_allocation"
    SELLER_ALLOCATION = "seller_allocation"
    USER_RECHARGE_DELIVERY = "user_recharge_delivery"
    REVERSAL = "reversal"
    ADJUSTMENT = "adjustment"


class CoinSupplyPool(Base):
    __tablename__ = "coin_supply_pools"
    __table_args__ = (
        UniqueConstraint("pool_type", "owner_user_id", name="uq_coin_supply_pool_owner_type"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    pool_type: Mapped[CoinPoolType] = mapped_column(SqlEnum(CoinPoolType, name="coin_pool_type"), nullable=False, index=True)
    owner_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True)
    coin_balance: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    lifetime_coin_in: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    lifetime_coin_out: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)
    is_locked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    lock_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    owner = relationship("User")
    ledger_entries = relationship("CoinPoolLedgerEntry", back_populates="pool", cascade="all, delete-orphan", foreign_keys="CoinPoolLedgerEntry.pool_id")


class CoinPoolLedgerEntry(Base):
    __tablename__ = "coin_pool_ledger_entries"
    __table_args__ = (
        UniqueConstraint("idempotency_key", name="uq_coin_pool_ledger_idempotency_key"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    pool_id: Mapped[int] = mapped_column(ForeignKey("coin_supply_pools.id", ondelete="CASCADE"), nullable=False, index=True)
    actor_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    counterparty_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    related_pool_id: Mapped[int | None] = mapped_column(ForeignKey("coin_supply_pools.id", ondelete="SET NULL"), nullable=True, index=True)
    direction: Mapped[CoinPoolLedgerDirection] = mapped_column(SqlEnum(CoinPoolLedgerDirection, name="coin_pool_ledger_direction"), nullable=False, index=True)
    source: Mapped[CoinPoolLedgerSource] = mapped_column(SqlEnum(CoinPoolLedgerSource, name="coin_pool_ledger_source"), nullable=False, index=True)
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    balance_before: Mapped[int] = mapped_column(BigInteger, nullable=False)
    balance_after: Mapped[int] = mapped_column(BigInteger, nullable=False)
    reference_type: Mapped[str | None] = mapped_column(String(80), nullable=True, index=True)
    reference_id: Mapped[str | None] = mapped_column(String(120), nullable=True, index=True)
    idempotency_key: Mapped[str] = mapped_column(String(180), nullable=False, index=True)
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    pool = relationship("CoinSupplyPool", back_populates="ledger_entries", foreign_keys=[pool_id])
    actor = relationship("User", foreign_keys=[actor_user_id])
    counterparty = relationship("User", foreign_keys=[counterparty_user_id])
    related_pool = relationship("CoinSupplyPool", foreign_keys=[related_pool_id])
