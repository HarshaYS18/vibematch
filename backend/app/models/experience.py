from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class UserExperienceStatus(Base):
    __tablename__ = "user_experience_statuses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True, index=True, nullable=False)
    send_total_exp: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    send_level: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    receive_total_exp: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    receive_level: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    last_source_type: Mapped[str | None] = mapped_column(String(80), nullable=True)
    last_source_id: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    user = relationship("User")


class RoomExperienceStatus(Base):
    __tablename__ = "room_experience_statuses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    room_id: Mapped[int] = mapped_column(ForeignKey("rooms.id"), unique=True, index=True, nullable=False)
    total_exp: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    level: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    last_source_type: Mapped[str | None] = mapped_column(String(80), nullable=True)
    last_source_id: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    room = relationship("Room")
