from datetime import datetime
from enum import Enum

from sqlalchemy import DateTime, Enum as SqlEnum, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class RoleName(str, Enum):
    FOUNDER_OWNER = "founder_owner"
    OWNER = "owner"
    SUPERADMIN = "superadmin"
    ADMIN = "admin"
    MONITOR = "monitor"
    AGENCY_OWNER = "agency_owner"
    BD = "bd"
    COIN_SELLER = "coin_seller"
    MERCHANT = "merchant"
    RESELLER = "reseller"
    CS = "cs"
    USER = "user"


ROLE_POWER = {
    RoleName.FOUNDER_OWNER: 100,
    RoleName.OWNER: 90,
    RoleName.SUPERADMIN: 80,
    RoleName.ADMIN: 70,
    RoleName.MONITOR: 60,
    RoleName.AGENCY_OWNER: 50,
    RoleName.BD: 45,
    RoleName.COIN_SELLER: 40,
    RoleName.MERCHANT: 40,
    RoleName.RESELLER: 35,
    RoleName.CS: 30,
    RoleName.USER: 10,
}


class UserRole(Base):
    __tablename__ = "user_roles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)

    user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    role: Mapped[RoleName] = mapped_column(
        SqlEnum(RoleName),
        default=RoleName.USER,
        nullable=False,
        index=True,
    )

    assigned_by_user_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    reason: Mapped[str | None] = mapped_column(String(255), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user = relationship(
        "User",
        foreign_keys=[user_id],
        back_populates="roles",
    )