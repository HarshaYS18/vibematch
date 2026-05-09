from datetime import datetime
from enum import Enum

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class EconomyCurrency(str, Enum):
    COIN = "COIN"
    RUBY = "RUBY"


class EconomyDirection(str, Enum):
    CREDIT = "CREDIT"
    DEBIT = "DEBIT"


class CoinSupplyPoolType(str, Enum):
    FOUNDER_MINT_POOL = "FOUNDER_MINT_POOL"
    OWNER_SUPPLY_POOL = "OWNER_SUPPLY_POOL"
    SUB_OWNER_SUPPLY_POOL = "SUB_OWNER_SUPPLY_POOL"
    MERCHANT_SUPPLY_POOL = "MERCHANT_SUPPLY_POOL"
    SELLER_SUPPLY_POOL = "SELLER_SUPPLY_POOL"
    EVENT_POOL = "EVENT_POOL"
    REFUND_POOL = "REFUND_POOL"
    FRIENDS_GAMING_POOL = "FRIENDS_GAMING_POOL"


class GamePoolType(str, Enum):
    FOUNDER_GAMING_POOL = "FOUNDER_GAMING_POOL"
    GAME_HOUSE_POOL = "GAME_HOUSE_POOL"
    GAME_EVENT_POOL = "GAME_EVENT_POOL"
    GAME_JACKPOT_POOL = "GAME_JACKPOT_POOL"
    ROOM_GAME_POOL = "ROOM_GAME_POOL"


class EconomyPoolStatus(str, Enum):
    ACTIVE = "ACTIVE"
    FROZEN = "FROZEN"
    CLOSED = "CLOSED"


class CoinSaleStatus(str, Enum):
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    DELIVERED = "DELIVERED"
    REJECTED = "REJECTED"
    CANCELLED = "CANCELLED"


class RubyWithdrawStatus(str, Enum):
    PENDING = "PENDING"
    UNDER_REVIEW = "UNDER_REVIEW"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    PAID = "PAID"
    CANCELLED = "CANCELLED"


class GameRoundStatus(str, Enum):
    WAITING = "WAITING"
    LOCKED = "LOCKED"
    RUNNING = "RUNNING"
    SETTLING = "SETTLING"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"
    REFUNDED = "REFUNDED"
    UNDER_REVIEW = "UNDER_REVIEW"


class UserWallet(Base):
    __tablename__ = "user_wallets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True, index=True, nullable=False)
    coin_balance: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    ruby_balance: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    locked_ruby_balance: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    pending_withdraw_rubies: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    lifetime_coins_spent: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    lifetime_coins_received_as_gifts: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    lifetime_rubies_earned: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    lifetime_rubies_withdrawn: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User")


class WalletLedger(Base):
    __tablename__ = "wallet_ledger"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    currency_type: Mapped[str] = mapped_column(String(20), index=True, nullable=False)
    direction: Mapped[str] = mapped_column(String(20), index=True, nullable=False)
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    before_balance: Mapped[int] = mapped_column(BigInteger, nullable=False)
    after_balance: Mapped[int] = mapped_column(BigInteger, nullable=False)
    source_type: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    source_id: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    metadata_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)


class CoinSupplyPool(Base):
    __tablename__ = "coin_supply_pools"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    owner_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), index=True, nullable=True)
    pool_type: Mapped[str] = mapped_column(String(50), index=True, nullable=False)
    balance: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    reserved_balance: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default=EconomyPoolStatus.ACTIVE.value, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    owner = relationship("User")


class CoinPoolLedger(Base):
    __tablename__ = "coin_pool_ledger"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    pool_id: Mapped[int] = mapped_column(ForeignKey("coin_supply_pools.id"), index=True, nullable=False)
    direction: Mapped[str] = mapped_column(String(20), index=True, nullable=False)
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    before_balance: Mapped[int] = mapped_column(BigInteger, nullable=False)
    after_balance: Mapped[int] = mapped_column(BigInteger, nullable=False)
    source_type: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    source_pool_id: Mapped[int | None] = mapped_column(ForeignKey("coin_supply_pools.id"), nullable=True)
    target_pool_id: Mapped[int | None] = mapped_column(ForeignKey("coin_supply_pools.id"), nullable=True)
    target_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    metadata_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)


class GamePool(Base):
    __tablename__ = "game_pools"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    game_key: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    pool_type: Mapped[str] = mapped_column(String(50), index=True, nullable=False)
    balance: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    reserved_balance: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default=EconomyPoolStatus.ACTIVE.value, index=True)
    daily_payout_cap: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    daily_loss_limit: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    max_single_payout: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    rtp_target_basis_points: Mapped[int] = mapped_column(Integer, default=8000, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class GamePoolLedger(Base):
    __tablename__ = "game_pool_ledger"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    pool_id: Mapped[int] = mapped_column(ForeignKey("game_pools.id"), index=True, nullable=False)
    direction: Mapped[str] = mapped_column(String(20), index=True, nullable=False)
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    before_balance: Mapped[int] = mapped_column(BigInteger, nullable=False)
    after_balance: Mapped[int] = mapped_column(BigInteger, nullable=False)
    source_type: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    source_id: Mapped[str | None] = mapped_column(String(120), nullable=True)
    game_key: Mapped[str | None] = mapped_column(String(80), nullable=True)
    round_id: Mapped[int | None] = mapped_column(ForeignKey("game_rounds.id"), nullable=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    metadata_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)


class CoinSaleOrder(Base):
    __tablename__ = "coin_sale_orders"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    seller_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    buyer_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    source_pool_id: Mapped[int] = mapped_column(ForeignKey("coin_supply_pools.id"), index=True, nullable=False)
    coin_amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    payment_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    payment_currency: Mapped[str] = mapped_column(String(20), default="INR", nullable=False)
    payment_status: Mapped[str] = mapped_column(String(30), default="PENDING", index=True)
    delivery_status: Mapped[str] = mapped_column(String(30), default=CoinSaleStatus.PENDING.value, index=True)
    proof_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    approved_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class GiftTransaction(Base):
    __tablename__ = "gift_transactions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    sender_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    receiver_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    room_id: Mapped[int | None] = mapped_column(ForeignKey("rooms.id"), index=True, nullable=True)
    gift_id: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    coin_value: Mapped[int] = mapped_column(BigInteger, nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    total_coin_value: Mapped[int] = mapped_column(BigInteger, nullable=False)
    receiver_ruby_amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    platform_share_coin_value: Mapped[int] = mapped_column(BigInteger, nullable=False)
    agency_share_coin_value: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    room_exp_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    send_exp_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    receive_exp_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    relationship_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    love_score_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)


class RubyWithdrawRequest(Base):
    __tablename__ = "ruby_withdraw_requests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    ruby_amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    payout_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    payout_method: Mapped[str | None] = mapped_column(String(80), nullable=True)
    payout_account_snapshot: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(30), default=RubyWithdrawStatus.PENDING.value, index=True)
    fraud_review_status: Mapped[str] = mapped_column(String(30), default="PENDING", index=True)
    reviewed_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    rejected_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    paid_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class GameRound(Base):
    __tablename__ = "game_rounds"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    game_key: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    room_id: Mapped[int | None] = mapped_column(ForeignKey("rooms.id"), index=True, nullable=True)
    status: Mapped[str] = mapped_column(String(30), default=GameRoundStatus.WAITING.value, index=True)
    entry_fee: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    currency_type: Mapped[str] = mapped_column(String(20), default=EconomyCurrency.COIN.value, nullable=False)
    max_players: Mapped[int] = mapped_column(Integer, default=4, nullable=False)
    started_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    round_pool_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    platform_fee_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    reward_pool_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    result_seed_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    server_seed_encrypted: Mapped[str | None] = mapped_column(String(500), nullable=True)
    client_seed_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    metadata_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class GameRoundPlayer(Base):
    __tablename__ = "game_round_players"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    round_id: Mapped[int] = mapped_column(ForeignKey("game_rounds.id"), index=True, nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    seat_no: Mapped[int | None] = mapped_column(Integer, nullable=True)
    entry_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    entry_status: Mapped[str] = mapped_column(String(30), default="JOINED", index=True)
    result_rank: Mapped[int | None] = mapped_column(Integer, nullable=True)
    reward_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    joined_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    left_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    metadata_json: Mapped[str | None] = mapped_column(Text, nullable=True)
