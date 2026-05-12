from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ProfileVisit(Base):
    __tablename__ = "profile_visits"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    profile_owner_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    visitor_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    source: Mapped[str] = mapped_column(String(80), default="public_profile", nullable=False)
    visit_count: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    first_visited_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    last_visited_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    profile_owner = relationship("User", foreign_keys=[profile_owner_user_id])
    visitor = relationship("User", foreign_keys=[visitor_user_id])

    __table_args__ = (
        UniqueConstraint("profile_owner_user_id", "visitor_user_id", name="uq_profile_visit_owner_visitor"),
    )
