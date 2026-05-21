from datetime import datetime
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.moderation_case import ModerationCase
from app.models.moderation_evidence import ModerationEvidence
from app.models.moderation_event import ModerationEvent
from app.models.role import RoleName
from app.models.user import User
from app.services.audit_log_service import create_admin_log
from app.services.role_service import get_primary_role


REVIEW_ROLES = {RoleName.MONITOR, RoleName.ADMIN, RoleName.SUPERADMIN, RoleName.OWNER, RoleName.FOUNDER_OWNER}


def create_case_from_event(db: Session, *, actor: User, event: ModerationEvent, recommendation: str) -> ModerationCase:
    case = ModerationCase(
        public_id=f"CASE-{uuid4().hex[:10].upper()}",
        opened_by_user_id=actor.id,
        target_user_id=event.target_user_id,
        room_id=event.room_id,
        status="open",
        category=(event.categories_json or ["moderation"])[0],
        priority="high" if event.severity == "high" else "normal",
        ai_recommendation=recommendation,
    )
    db.add(case)
    db.flush()
    db.add(ModerationEvidence(case_id=case.id, event_id=event.id, evidence_type=event.content_type, text_snapshot=event.snippet, moderation_status=event.decision))
    db.commit()
    db.refresh(case)
    return case


def list_cases(db: Session, *, actor: User, status: str | None = None) -> list[ModerationCase]:
    _require_reviewer(actor)
    query = db.query(ModerationCase)
    if status:
        query = query.filter(ModerationCase.status == status)
    return query.order_by(ModerationCase.updated_at.desc()).limit(100).all()


def add_moderation_note(db: Session, *, actor: User, public_id: str, note: str, status: str | None = None) -> ModerationCase:
    _require_reviewer(actor)
    case = db.query(ModerationCase).filter(ModerationCase.public_id == public_id).first()
    if not case:
        raise HTTPException(status_code=404, detail="Moderation case not found")
    case.moderator_notes = note
    if status:
        case.status = status
        if status in {"resolved", "closed", "rejected"}:
            case.closed_at = datetime.utcnow()
    db.commit()
    db.refresh(case)
    create_admin_log(db=db, actor_user_id=actor.id, target_user_id=case.target_user_id, action="MODERATION_CASE_REVIEWED", resource_type="moderation_case", resource_id=case.public_id, reason=note, metadata_json={"status": case.status})
    return case


def _require_reviewer(actor: User) -> None:
    if get_primary_role(actor) not in REVIEW_ROLES:
        raise HTTPException(status_code=403, detail="Moderation review access required")

