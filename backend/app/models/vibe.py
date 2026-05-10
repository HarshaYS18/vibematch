from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class VibePost(Base):
    __tablename__ = "vibe_posts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    author_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    caption: Mapped[str] = mapped_column(Text, nullable=False)
    media_type: Mapped[str] = mapped_column(String(20), default="text", nullable=False, index=True)
    media_url: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    tag: Mapped[str | None] = mapped_column(String(50), nullable=True, index=True)
    uses_mention_all: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    mentions_csv: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    author = relationship("User")
    comments = relationship("VibeComment", back_populates="post", cascade="all, delete-orphan")
    reactions = relationship("VibeReaction", back_populates="post", cascade="all, delete-orphan")


class VibeReaction(Base):
    __tablename__ = "vibe_reactions"
    __table_args__ = (UniqueConstraint("post_id", "user_id", name="uq_vibe_reaction_post_user"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("vibe_posts.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    reaction_type: Mapped[str] = mapped_column(String(20), default="like", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)

    post = relationship("VibePost", back_populates="reactions")


class VibeComment(Base):
    __tablename__ = "vibe_comments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    post_id: Mapped[int] = mapped_column(ForeignKey("vibe_posts.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    post = relationship("VibePost", back_populates="comments")
    user = relationship("User")
