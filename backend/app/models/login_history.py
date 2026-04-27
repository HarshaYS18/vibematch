from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, Enum as SqlEnum, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class LoginHistoryStatus(str, Enum):
    SUCCESS = "success"
    FAILED = "failed"


class LoginHistoryFailureReason(str, Enum):
    DEVICE_BANNED = "device_banned"
    USER_BANNED = "user_banned"
    USER_INACTIVE = "user_inactive"
    UNKNOWN = "unknown"


class LoginHistory(Base):
    __tablename__ = "login_history"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)

    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id"),
        nullable=True,
        index=True,
    )

    email: Mapped[str] = mapped_column(String(255), nullable=False, index=True)

    provider: Mapped[str] = mapped_column(String(50), nullable=False, index=True)

    provider_user_id: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
    )

    device_id: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        index=True,
    )

    ip_address: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
        index=True,
    )

    status: Mapped[LoginHistoryStatus] = mapped_column(
        SqlEnum(LoginHistoryStatus),
        nullable=False,
        index=True,
    )

    failure_reason: Mapped[LoginHistoryFailureReason | None] = mapped_column(
        SqlEnum(LoginHistoryFailureReason),
        nullable=True,
        index=True,
    )

    failure_detail: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
    )

    is_success: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        index=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        index=True,
    )

    user = relationship("User")