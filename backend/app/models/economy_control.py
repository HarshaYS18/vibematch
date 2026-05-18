from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Integer, JSON, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class EconomyRuleSet(Base):
    __tablename__ = "economy_rule_sets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    track_key: Mapped[str] = mapped_column(String(40), index=True, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    title: Mapped[str] = mapped_column(String(140), nullable=False)
    max_level: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    curve_type: Mapped[str] = mapped_column(String(40), default="explicit_threshold_table", nullable=False)
    curve_exponent: Mapped[str | None] = mapped_column(String(40), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True, nullable=False)
    is_published: Mapped[bool] = mapped_column(Boolean, default=True, index=True, nullable=False)
    rule_payload_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    updated_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    __table_args__ = (UniqueConstraint("track_key", "version", name="uq_economy_rule_set_track_version"),)


class EconomyRuleLevel(Base):
    __tablename__ = "economy_rule_levels"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    rule_set_id: Mapped[int] = mapped_column(ForeignKey("economy_rule_sets.id", ondelete="CASCADE"), index=True, nullable=False)
    level: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    required_exp: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    required_coin_value: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    reward_payload_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (UniqueConstraint("rule_set_id", "level", name="uq_economy_rule_level_set_level"),)
