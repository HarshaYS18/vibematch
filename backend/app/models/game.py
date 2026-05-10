from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class GameDefinition(Base):
    __tablename__ = "game_definitions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    game_key: Mapped[str] = mapped_column(String(80), unique=True, index=True, nullable=False)
    display_name: Mapped[str] = mapped_column(String(120), nullable=False)
    category: Mapped[str] = mapped_column(String(40), index=True, nullable=False)
    is_enabled: Mapped[bool] = mapped_column(Boolean, default=False, index=True, nullable=False)
    is_coin_game: Mapped[bool] = mapped_column(Boolean, default=False, index=True, nullable=False)
    min_app_version: Mapped[str] = mapped_column(String(40), default="1.0.0", nullable=False)
    config_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    cdn_base_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    config_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    asset_manifest_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    ui_config_json: Mapped[str] = mapped_column(Text, nullable=False)
    rules_json: Mapped[str] = mapped_column(Text, nullable=False)
    risk_config_json: Mapped[str] = mapped_column(Text, nullable=False)
    created_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    updated_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class GameBet(Base):
    __tablename__ = "game_bets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    round_id: Mapped[int] = mapped_column(ForeignKey("game_rounds.id"), index=True, nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    target_id: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    accepted_amount: Mapped[int] = mapped_column(BigInteger, nullable=False)
    risk_level: Mapped[str] = mapped_column(String(30), index=True, nullable=False)
    risk_score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    risk_action: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    metadata_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)


class GameRiskAudit(Base):
    __tablename__ = "game_risk_audits"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    game_key: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    round_id: Mapped[int | None] = mapped_column(ForeignKey("game_rounds.id"), index=True, nullable=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), index=True, nullable=True)
    event_type: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    risk_level: Mapped[str] = mapped_column(String(30), index=True, nullable=False)
    risk_score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    action: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    metadata_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
