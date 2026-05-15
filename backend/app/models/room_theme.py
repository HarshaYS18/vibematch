from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class RoomThemeOwnershipType(str, Enum):
    FREE = "free"
    PURCHASED = "purchased"
    CUSTOM = "custom"


class RoomThemeReviewStatus(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class RoomTheme(Base):
    __tablename__ = "room_themes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    theme_id: Mapped[str] = mapped_column(String(120), unique=True, index=True, nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    ownership_type: Mapped[str] = mapped_column(String(40), nullable=False, default=RoomThemeOwnershipType.FREE.value)
    price_coins: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    thumbnail_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    asset_path: Mapped[str | None] = mapped_column(String(500), nullable=True)
    accent: Mapped[str] = mapped_column(String(20), nullable=False, default="#12C7B7")
    overlay_opacity: Mapped[int] = mapped_column(Integer, nullable=False, default=42)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    is_default: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_by_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)


class UserRoomThemeInventory(Base):
    __tablename__ = "user_room_theme_inventory"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    theme_id: Mapped[str] = mapped_column(String(120), index=True, nullable=False)
    source: Mapped[str] = mapped_column(String(40), nullable=False, default="purchase")
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)


class RoomThemeReview(Base):
    __tablename__ = "room_theme_reviews"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    review_public_id: Mapped[str] = mapped_column(String(80), unique=True, index=True, nullable=False)
    submitter_user_id: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    room_id: Mapped[int | None] = mapped_column(Integer, index=True, nullable=True)
    room_public_id: Mapped[str | None] = mapped_column(String(32), index=True, nullable=True)
    image_url: Mapped[str] = mapped_column(String(500), nullable=False)
    thumbnail_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    proposed_theme_id: Mapped[str] = mapped_column(String(120), index=True, nullable=False)
    status: Mapped[str] = mapped_column(String(30), index=True, nullable=False, default=RoomThemeReviewStatus.PENDING.value)
    review_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    reviewed_by_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)
