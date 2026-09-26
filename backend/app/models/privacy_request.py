"""Durable Identity-owned privacy/DSAR workflow state."""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import BigInteger, Column, DateTime, Integer, String

from app.database import Base


class PrivacyRequest(Base):
    __tablename__ = "privacy_requests"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(Integer, nullable=False, index=True)
    public_user_id = Column(BigInteger, nullable=False, index=True)
    request_type = Column(String(20), nullable=False)
    status = Column(String(20), nullable=False, default="PENDING", index=True)
    requested_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    due_at = Column(DateTime(timezone=True), nullable=False)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    cancelled_at = Column(DateTime(timezone=True), nullable=True)
