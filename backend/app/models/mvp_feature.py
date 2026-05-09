from sqlalchemy import Boolean, Column, DateTime, Integer, JSON, String, Text, UniqueConstraint
from sqlalchemy.sql import func

from app.database import Base


class MvpFeatureState(Base):
    """Persistent MVP state for app modules that are not production-normalized yet.

    This table lets the Flutter app and admin/control panels start using real
    FastAPI endpoints while we later split each feature into dedicated normalized
    tables. It is intentionally generic but still database-backed, auditable by
    owner_user_id, and scoped by feature/item_type/status.
    """

    __tablename__ = "mvp_feature_states"
    __table_args__ = (
        UniqueConstraint("feature", "public_id", name="uq_mvp_feature_public_id"),
    )

    id = Column(Integer, primary_key=True, index=True)
    public_id = Column(String(80), index=True, nullable=False)
    feature = Column(String(80), index=True, nullable=False)
    item_type = Column(String(80), index=True, nullable=False)
    owner_user_id = Column(Integer, index=True, nullable=True)
    target_user_id = Column(Integer, index=True, nullable=True)
    room_public_id = Column(String(64), index=True, nullable=True)
    title = Column(String(160), nullable=False)
    description = Column(Text, nullable=True)
    status = Column(String(40), index=True, nullable=False, default="active")
    amount = Column(Integer, nullable=False, default=0)
    currency = Column(String(24), nullable=True)
    payload = Column(JSON, nullable=False, default=dict)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
