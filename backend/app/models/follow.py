from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class UserFollow(Base):
    __tablename__ = "user_follows"
    __table_args__ = (
        UniqueConstraint("follower_user_id", "followed_user_id", name="uq_user_follow_pair"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    follower_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    followed_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)

    follower = relationship("User", foreign_keys=[follower_user_id])
    followed = relationship("User", foreign_keys=[followed_user_id])
