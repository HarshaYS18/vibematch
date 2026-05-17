from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class GiftCatalogCategory(Base):
    __tablename__ = "gift_catalog_categories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    category_key: Mapped[str] = mapped_column(String(80), unique=True, nullable=False, index=True)
    label: Mapped[str] = mapped_column(String(120), nullable=False)
    is_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=500, nullable=False, index=True)
    source: Mapped[str] = mapped_column(String(80), default="admin_db", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class GiftCatalogItem(Base):
    __tablename__ = "gift_catalog_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    gift_id: Mapped[str] = mapped_column(String(100), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    category_key: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    gift_type: Mapped[str] = mapped_column(String(40), default="normal", nullable=False, index=True)
    coin_value: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    icon_key: Mapped[str | None] = mapped_column(String(120), nullable=True)
    chat_symbol: Mapped[str | None] = mapped_column(String(32), nullable=True)
    asset_path: Mapped[str | None] = mapped_column(Text, nullable=True)
    video_asset_path: Mapped[str | None] = mapped_column(Text, nullable=True)
    cdn_asset_path: Mapped[str | None] = mapped_column(Text, nullable=True)
    cdn_video_path: Mapped[str | None] = mapped_column(Text, nullable=True)
    animation_type: Mapped[str] = mapped_column(String(40), default="image", nullable=False)
    is_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)
    show_gift_slide: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    show_premium_broadcast: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    show_gift_flight: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=500, nullable=False, index=True)
    max_multiplier: Mapped[int | None] = mapped_column(Integer, nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
