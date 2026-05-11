from datetime import date, datetime

from sqlalchemy import BigInteger, Boolean, Date, DateTime, Integer, JSON, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)

    # Permanent public ID. This never changes.
    # Founder Owner public_user_id = 6922022.
    # Normal user IDs use 6418xxxxxx.
    public_user_id: Mapped[int] = mapped_column(
        BigInteger,
        unique=True,
        index=True,
        nullable=False,
    )

    # Optional premium/custom numeric display ID.
    # Normal users can only use numeric custom IDs, never @names.
    # Internal logic must still use id / public_user_id.
    display_custom_id: Mapped[int | None] = mapped_column(
        BigInteger,
        unique=True,
        index=True,
        nullable=True,
    )

    # Official @name only for Founder Owner / Owner / staff / system accounts.
    # Example: @owner, @support, @admin
    # Normal users cannot use @names.
    official_handle: Mapped[str | None] = mapped_column(
        String(50),
        unique=True,
        index=True,
        nullable=True,
    )

    username: Mapped[str | None] = mapped_column(String(50), nullable=True)
    display_name: Mapped[str | None] = mapped_column(String(80), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    bio: Mapped[str | None] = mapped_column(String(240), nullable=True)
    date_of_birth: Mapped[date | None] = mapped_column(Date, nullable=True)
    gender: Mapped[str | None] = mapped_column(String(30), nullable=True)
    profession: Mapped[str | None] = mapped_column(String(80), nullable=True)
    marital_status: Mapped[str | None] = mapped_column(String(30), nullable=True)
    friend_gender_preference: Mapped[str | None] = mapped_column(String(30), nullable=True)
    friend_marital_preference: Mapped[str | None] = mapped_column(String(30), nullable=True)
    interests: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)
    cover_photo_urls: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    is_banned: Mapped[bool] = mapped_column(Boolean, default=False, index=True)

    # Extra protection for Founder Owner / Owner / official accounts.
    # Backend services must block ban/delete/demote actions on protected users.
    is_protected: Mapped[bool] = mapped_column(Boolean, default=False, index=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    # Step 2K login tracking.
    # Stores the most recent device ID used for successful login.
    last_device_id: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        index=True,
    )

    # Stores the most recent successful login timestamp.
    last_login_at: Mapped[datetime | None] = mapped_column(
        DateTime,
        nullable=True,
        index=True,
    )

    auth_identities = relationship(
        "AuthIdentity",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    roles = relationship(
        "UserRole",
        foreign_keys="UserRole.user_id",
        back_populates="user",
        cascade="all, delete-orphan",
    )