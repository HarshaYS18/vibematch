from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class StoreItemCategory(str, Enum):
    AVATAR_FRAME = "avatar_frame"
    CHAT_BUBBLE = "chat_bubble"
    ENTRANCE_EFFECT = "entrance_effect"
    ROOM_BACKGROUND = "room_background"
    PROFILE_THEME = "profile_theme"
    BADGE = "badge"


class StoreItem(Base):
    __tablename__ = "store_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    item_id: Mapped[str] = mapped_column(String(120), unique=True, index=True, nullable=False)
    name: Mapped[str] = mapped_column(String(140), nullable=False)
    category: Mapped[str] = mapped_column(String(60), index=True, nullable=False)
    description: Mapped[str | None] = mapped_column(String(300), nullable=True)
    price_coins: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    asset_path: Mapped[str | None] = mapped_column(String(500), nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    preview_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    linked_theme_id: Mapped[str | None] = mapped_column(String(120), index=True, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    is_featured: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)


class UserStoreInventory(Base):
    __tablename__ = "user_store_inventory"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, index=True, nullable=False)
    item_id: Mapped[str] = mapped_column(String(120), index=True, nullable=False)
    category: Mapped[str] = mapped_column(String(60), index=True, nullable=False)
    source: Mapped[str] = mapped_column(String(60), nullable=False, default="purchase")
    is_equipped: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)
