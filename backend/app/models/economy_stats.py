from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class FamilyEconomyStats(Base):
    __tablename__ = "family_economy_stats"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    family_id: Mapped[int] = mapped_column(Integer, unique=True, index=True, nullable=False)
    family_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    family_level: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    family_exp: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    daily_exp: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    weekly_exp: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    monthly_exp: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    daily_contribution: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    weekly_contribution: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    monthly_contribution: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    member_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    active_members_daily: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class FamilyMemberStats(Base):
    __tablename__ = "family_member_stats"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    family_id: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    family_role: Mapped[str] = mapped_column(String(40), default="member", nullable=False)
    daily_contribution: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    weekly_contribution: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    monthly_contribution: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    daily_exp: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    weekly_exp: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    monthly_exp: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    total_contribution: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    joined_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class RelationshipEconomyStats(Base):
    __tablename__ = "relationship_economy_stats"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    relationship_id: Mapped[int] = mapped_column(Integer, unique=True, index=True, nullable=False)
    user_a_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), index=True, nullable=True)
    user_b_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), index=True, nullable=True)
    relationship_exp: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    relationship_level: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    daily_exp: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    weekly_exp: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    monthly_exp: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class UserGameStats(Base):
    __tablename__ = "user_game_stats"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    game_id: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    daily_bid_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    daily_win_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    daily_loss_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    daily_net_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    weekly_bid_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    weekly_win_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    weekly_loss_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    weekly_net_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    monthly_bid_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    monthly_win_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    monthly_loss_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    monthly_net_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    all_time_bid_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    all_time_win_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    all_time_loss_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    all_time_net_amount: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    rounds_played_daily: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    rounds_played_monthly: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    best_multiplier: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class LuckyGiftTransaction(Base):
    __tablename__ = "lucky_gift_transactions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    sender_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    receiver_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), index=True, nullable=True)
    room_id: Mapped[int | None] = mapped_column(ForeignKey("rooms.id"), index=True, nullable=True)
    gift_id: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    gift_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    coin_value: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    spent_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    multiplier: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    reward_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    net_win_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    is_big_win: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    broadcast_sent: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    metadata_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)


class UserLuckyGiftStats(Base):
    __tablename__ = "user_lucky_gift_stats"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True, index=True, nullable=False)
    daily_spent_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    daily_reward_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    daily_net_win_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    daily_best_multiplier: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    daily_biggest_reward: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    daily_rounds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    weekly_spent_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    weekly_reward_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    weekly_net_win_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    weekly_best_multiplier: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    weekly_biggest_reward: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    weekly_rounds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    monthly_spent_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    monthly_reward_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    monthly_net_win_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    monthly_best_multiplier: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    monthly_biggest_reward: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    monthly_rounds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    yearly_spent_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    yearly_reward_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    yearly_net_win_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    yearly_best_multiplier: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    yearly_biggest_reward: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    yearly_rounds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    all_time_spent_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    all_time_reward_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    all_time_net_win_coins: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    all_time_best_multiplier: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    all_time_biggest_reward: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    all_time_rounds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class RankingSnapshot(Base):
    __tablename__ = "ranking_snapshots"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    ranking_type: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    period: Mapped[str] = mapped_column(String(30), index=True, nullable=False)
    scope_id: Mapped[str | None] = mapped_column(String(120), index=True, nullable=True)
    rank: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), index=True, nullable=True)
    family_id: Mapped[int | None] = mapped_column(Integer, index=True, nullable=True)
    game_id: Mapped[str | None] = mapped_column(String(80), index=True, nullable=True)
    score: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    snapshot_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
