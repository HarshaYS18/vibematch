from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class RoomParticipant(Base):
    __tablename__ = "room_participants"
    __table_args__ = (
        UniqueConstraint("room_id", "user_id", name="uq_room_participant_room_user"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    room_id: Mapped[int] = mapped_column(ForeignKey("rooms.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, index=True)
    is_member: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, index=True)
    is_room_admin: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, index=True)

    # Stealth presence is backend-owned. A stealth participant is internally
    # tracked/audited, but excluded from public online counts, peers, user lists,
    # public room presence, and public join/leave broadcasts.
    is_stealth: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="false", index=True)
    visible_in_online_count: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true", index=True)
    visible_in_user_list: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true", index=True)
    visible_to_public: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true", index=True)

    joined_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=datetime.utcnow, index=True)
    left_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    member_added_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    admin_added_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    room = relationship("Room")
    user = relationship("User")