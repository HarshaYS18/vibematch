from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class UserVipStatus(Base):
    __tablename__ = "user_vip_statuses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True, nullable=False)
    vip_level: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    svip_level: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    vip_is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    svip_is_active: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    svip_expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    updated_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    update_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
