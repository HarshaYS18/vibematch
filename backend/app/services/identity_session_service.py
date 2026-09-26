from __future__ import annotations

from datetime import datetime, timedelta
from uuid import uuid4

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.identity_session import IdentityDevice, IdentitySession


def open_session(db: Session, *, user_id: int, device_id: str | None) -> IdentitySession:
    now = datetime.utcnow()
    normalized_device = (device_id or "").strip() or None
    active = db.query(IdentitySession).filter(
        IdentitySession.user_id == user_id,
        IdentitySession.is_active.is_(True),
        IdentitySession.revoked_at.is_(None),
    ).with_for_update().all()
    for row in active:
        row.is_active = False
        row.revoked_at = now
        row.revoke_reason = "session_replaced"

    if normalized_device:
        device = db.query(IdentityDevice).filter(
            IdentityDevice.user_id == user_id,
            IdentityDevice.device_id == normalized_device,
        ).with_for_update().first()
        if device is None:
            device = IdentityDevice(user_id=user_id, device_id=normalized_device)
            db.add(device)
        device.is_active = True
        device.last_seen_at = now
        device.last_login_at = now

    session = IdentitySession(
        session_id=str(uuid4()),
        user_id=user_id,
        device_id=normalized_device,
        token_version=1,
        issued_at=now,
        expires_at=now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        is_active=True,
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


def is_session_active(db: Session, *, user_id: int, session_id: str, device_id: str | None = None) -> bool:
    row = db.query(IdentitySession).filter(
        IdentitySession.session_id == (session_id or "").strip(),
        IdentitySession.user_id == user_id,
        IdentitySession.is_active.is_(True),
        IdentitySession.revoked_at.is_(None),
        IdentitySession.expires_at > datetime.utcnow(),
    ).first()
    if row is None:
        return False
    expected = (row.device_id or "").strip()
    supplied = (device_id or "").strip()
    return not expected or expected == supplied


def revoke_user_sessions(db: Session, *, user_id: int, reason: str, device_id: str | None = None) -> int:
    query = db.query(IdentitySession).filter(
        IdentitySession.user_id == user_id,
        IdentitySession.is_active.is_(True),
        IdentitySession.revoked_at.is_(None),
    )
    normalized = (device_id or "").strip()
    if normalized:
        query = query.filter(IdentitySession.device_id == normalized)
    rows = query.with_for_update().all()
    now = datetime.utcnow()
    for row in rows:
        row.is_active = False
        row.revoked_at = now
        row.revoke_reason = (reason or "revoked")[:120]
    if rows:
        db.commit()
    return len(rows)
