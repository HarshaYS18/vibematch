from datetime import datetime
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.ai_helpdesk_log import AiHelpdeskLog
from app.models.role import RoleName
from app.models.support_attachment import SupportAttachment
from app.models.support_message import SupportMessage
from app.models.support_ticket import SupportTicket
from app.models.user import User
from app.schemas.support import SUPPORT_CATEGORIES, SUPPORT_STATUSES, SupportAttachmentCreate
from app.services import ai_helpdesk_service
from app.services.audit_log_service import create_admin_log
from app.services.role_service import get_primary_role


STAFF_ROLES = {RoleName.CS, RoleName.MONITOR, RoleName.ADMIN, RoleName.SUPERADMIN, RoleName.OWNER, RoleName.FOUNDER_OWNER}
MONITOR_REVIEW_ROLES = {RoleName.MONITOR, RoleName.ADMIN, RoleName.SUPERADMIN, RoleName.OWNER, RoleName.FOUNDER_OWNER}


def create_ticket(db: Session, *, user: User, category: str | None, subject: str, message: str, attachments: list[SupportAttachmentCreate]) -> SupportTicket:
    classification = ai_helpdesk_service.classify_support_message(message, explicit_category=_normalize_category(category))
    public_id = f"SUP-{uuid4().hex[:10].upper()}"
    ticket = SupportTicket(
        public_id=public_id,
        user_id=user.id,
        category=classification.category,
        subject=subject.strip(),
        status="escalated_to_monitor" if classification.should_escalate else "waiting_cs",
        priority=classification.priority,
        assigned_role="monitor" if classification.should_escalate else "cs",
        ai_summary=_summary_for(subject, message, classification.category),
        ai_summary_generated=True,
        missing_fields_json=classification.missing_fields,
        metadata_json={"intent": classification.intent, "ai_provider": classification.provider},
    )
    db.add(ticket)
    db.flush()
    db.add(SupportMessage(public_id=f"SM-{uuid4().hex[:12]}", ticket_id=ticket.id, sender_user_id=user.id, sender_role="user", body=message.strip()))
    db.add(SupportMessage(public_id=f"SM-{uuid4().hex[:12]}", ticket_id=ticket.id, sender_user_id=None, sender_role="ai_assistant", body=classification.suggested_reply, is_ai_generated=True))
    _add_attachments(db, ticket=ticket, message_id=None, user=user, attachments=attachments)
    db.add(AiHelpdeskLog(user_id=user.id, ticket_id=ticket.id, provider=classification.provider, model=classification.model, intent=classification.intent, category=classification.category, priority=classification.priority, prompt_preview=message[:500], output_json=ai_helpdesk_service.classification_metadata(classification)))
    db.commit()
    db.refresh(ticket)
    return ticket


def list_user_tickets(db: Session, *, user: User) -> list[SupportTicket]:
    return db.query(SupportTicket).filter(SupportTicket.user_id == user.id).order_by(SupportTicket.updated_at.desc()).limit(50).all()


def get_user_ticket(db: Session, *, user: User, public_id: str) -> SupportTicket:
    ticket = db.query(SupportTicket).filter(SupportTicket.public_id == public_id, SupportTicket.user_id == user.id).first()
    if not ticket:
        raise HTTPException(status_code=404, detail="Support ticket not found")
    return ticket


def add_user_message(db: Session, *, user: User, public_id: str, message: str, attachments: list[SupportAttachmentCreate]) -> SupportTicket:
    ticket = get_user_ticket(db, user=user, public_id=public_id)
    if ticket.status in {"resolved", "rejected", "closed"}:
        raise HTTPException(status_code=400, detail="This ticket is closed")
    msg = SupportMessage(public_id=f"SM-{uuid4().hex[:12]}", ticket_id=ticket.id, sender_user_id=user.id, sender_role="user", body=message.strip())
    db.add(msg)
    db.flush()
    _add_attachments(db, ticket=ticket, message_id=msg.id, user=user, attachments=attachments)
    ticket.status = "waiting_cs" if ticket.status != "escalated_to_monitor" else ticket.status
    ticket.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(ticket)
    return ticket


def list_staff_tickets(db: Session, *, actor: User, status: str | None = None) -> list[SupportTicket]:
    _require_staff(actor)
    query = db.query(SupportTicket)
    if status:
        query = query.filter(SupportTicket.status == status)
    return query.order_by(SupportTicket.updated_at.desc()).limit(100).all()


def staff_update_ticket(db: Session, *, actor: User, public_id: str, message: str | None = None, status: str | None = None, reason: str | None = None, moderation_notes: str | None = None) -> SupportTicket:
    _require_staff(actor)
    ticket = db.query(SupportTicket).filter(SupportTicket.public_id == public_id).first()
    if not ticket:
        raise HTTPException(status_code=404, detail="Support ticket not found")
    next_status = status.strip() if status else None
    if next_status and next_status not in SUPPORT_STATUSES:
        raise HTTPException(status_code=400, detail="Unsupported ticket status")
    if next_status == "escalated_to_monitor":
        ticket.assigned_role = "monitor"
    if next_status in {"resolved", "rejected", "closed"}:
        ticket.resolved_at = datetime.utcnow()
        ticket.resolution_reason = reason
    if next_status:
        if next_status == "escalated_to_monitor":
            _require_monitor_or_admin(actor, allow_cs_escalation=True)
        elif ticket.status == "escalated_to_monitor":
            _require_monitor_or_admin(actor)
        ticket.status = next_status
    if message and message.strip():
        db.add(SupportMessage(public_id=f"SM-{uuid4().hex[:12]}", ticket_id=ticket.id, sender_user_id=actor.id, sender_role=get_primary_role(actor).value, body=message.strip()))
    metadata = dict(ticket.metadata_json or {})
    if moderation_notes and moderation_notes.strip():
        metadata["moderation_notes"] = moderation_notes.strip()
    ticket.metadata_json = metadata
    ticket.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(ticket)
    create_admin_log(db=db, actor_user_id=actor.id, target_user_id=ticket.user_id, action="SUPPORT_TICKET_UPDATED", resource_type="support_ticket", resource_id=ticket.public_id, reason=reason or message or "support update", metadata_json={"status": ticket.status, "assigned_role": ticket.assigned_role})
    return ticket


def _normalize_category(category: str | None) -> str | None:
    if not category:
        return None
    normalized = category.strip().lower().replace(" ", "_").replace("/", "_")
    return normalized if normalized in SUPPORT_CATEGORIES else None


def _summary_for(subject: str, message: str, category: str) -> str:
    body = message.strip().replace("\n", " ")
    return f"{category}: {subject.strip()} - {body[:220]}"


def _add_attachments(db: Session, *, ticket: SupportTicket, message_id: int | None, user: User, attachments: list[SupportAttachmentCreate]) -> None:
    for attachment in attachments:
        db.add(SupportAttachment(ticket_id=ticket.id, message_id=message_id, uploaded_by_user_id=user.id, file_url=attachment.file_url, content_type=attachment.content_type, moderation_status="pending"))


def _require_staff(actor: User) -> None:
    if get_primary_role(actor) not in STAFF_ROLES:
        raise HTTPException(status_code=403, detail="Support review access required")


def _require_monitor_or_admin(actor: User, *, allow_cs_escalation: bool = False) -> None:
    role = get_primary_role(actor)
    if allow_cs_escalation and role in STAFF_ROLES:
        return
    if role not in MONITOR_REVIEW_ROLES:
        raise HTTPException(status_code=403, detail="Monitor review access required")
