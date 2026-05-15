from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class HomeBannerPlacement(str, Enum):
    EVENT = "event"
    POLICY_RULES = "policy_rules"


class HomeBannerTarget(str, Enum):
    EVENT = "event"
    POLICY = "policy"
    PROMO = "promo"
    RECHARGE = "recharge"
    EXTERNAL = "external"


class HomeBanner(Base):
    __tablename__ = "home_banners"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    placement: Mapped[str] = mapped_column(String(40), index=True, nullable=False)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    image_url: Mapped[str] = mapped_column(String(1000), nullable=False)
    target: Mapped[str] = mapped_column(String(40), nullable=False, default=HomeBannerTarget.EVENT.value)
    target_url: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    starts_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_by_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    updated_by_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)
