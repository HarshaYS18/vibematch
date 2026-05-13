from __future__ import annotations

from datetime import datetime
from enum import Enum

from sqlalchemy import BigInteger, Boolean, DateTime, Enum as SqlEnum, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class WalletCurrency(str, Enum):
    COINS = "coins"
    RUBIES = "rubies"


class WalletLedgerDirection(str, Enum):
    CREDIT = "credit"
    DEBIT = "debit"


class WalletLedgerSource(str, Enum):
    SYSTEM_GRANT = "system_grant"
    RECHARGE = "recharge"
    GIFT_SENT = "gift_sent"
    GIFT_RECEIVED = "gift_received"
    GAME_BET = "game_bet"
    GAME_WIN = "game_win"
    GAME_REFUND = "game_refund"
    STORE_PURCHASE = "store_purchase"
    RUBY_CONVERT = "ruby_convert"
    PAYOUT = "payout"
    ADJUSTMENT = "adjustment"


class Wallet(Base):
    __tablename__ = "wallets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    coin_balance: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    ruby_balance: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    lifetime_coin_in: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    lifetime_coin_out: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    lifetime_ruby_in: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    lifetime_ruby_out: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    lifetime_recharge_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False, index=True)
    monthly_recharge_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False, index=True)
    monthly_recharge_period: Mapped[str | None] = mapped_column(String(7), nullable=True, index=True)
    vip_level: Mapped[int] = mapped_column(Integer, default=0, nullable=False, index=True)
    svip_level: Mapped[int] = mapped_column(Integer, default=0, nullable=False, index=True)
    svip_expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True, index=True)
    is_frozen: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    freeze_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    user = relationship("User", back_populates="wallet")
    ledger_entries = relationship("WalletLedgerEntry", back_populates="wallet", cascade="all, delete-orphan")


class WalletLedgerEntry(Base):
    __tablename__ = "wallet_ledger_entries"
    __table_args__ = (UniqueConstraint("idempotency_key", name="uq_wallet_ledger_idempotency_key"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    wallet_id: Mapped[int] = mapped_column(ForeignKey("wallets.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    currency: Mapped[WalletCurrency] = mapped_column(SqlEnum(WalletCurrency, name="wallet_currency"), nullable=False, index=True)
    direction: Mapped[WalletLedgerDirection] = mapped_column(SqlEnum(WalletLedgerDirection, name="wallet_ledger_direction"), nullable=False, index=True)
    source: Mapped[WalletLedgerSource] = mapped_column(SqlEnum(WalletLedgerSource, name="wallet_ledger_source"), nullable=False, index=True)
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    balance_before: Mapped[int] = mapped_column(BigInteger, nullable=False)
    balance_after: Mapped[int] = mapped_column(BigInteger, nullable=False)
    reference_type: Mapped[str | None] = mapped_column(String(80), nullable=True, index=True)
    reference_id: Mapped[str | None] = mapped_column(String(120), nullable=True, index=True)
    idempotency_key: Mapped[str] = mapped_column(String(160), nullable=False, index=True)
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    wallet = relationship("Wallet", back_populates="ledger_entries")
    user = relationship("User")


class GameHousePool(Base):
    __tablename__ = "game_house_pools"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    game_id: Mapped[str] = mapped_column(String(80), unique=True, nullable=False, index=True)
    coin_reserve: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    lifetime_coin_in: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    lifetime_coin_out: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class GameLedgerEntry(Base):
    __tablename__ = "game_ledger_entries"
    __table_args__ = (UniqueConstraint("idempotency_key", name="uq_game_ledger_idempotency_key"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    game_id: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    session_id: Mapped[str] = mapped_column(String(120), nullable=False, index=True)
    spin_id: Mapped[str | None] = mapped_column(String(120), nullable=True, index=True)
    bet_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    win_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    net_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    risk_tier: Mapped[str | None] = mapped_column(String(40), nullable=True, index=True)
    house_reserve_before: Mapped[int] = mapped_column(BigInteger, nullable=False)
    house_reserve_after: Mapped[int] = mapped_column(BigInteger, nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(160), nullable=False, index=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    user = relationship("User")
