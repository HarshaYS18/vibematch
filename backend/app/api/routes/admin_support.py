from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.support import _ticket_response
from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.support import SupportAdminActionRequest, SupportTicketResponse
from app.services import support_ticket_service

router = APIRouter(prefix="/admin/support", tags=["Admin Support"])


@router.get("/tickets", response_model=list[SupportTicketResponse])
def list_support_tickets(status: str | None = None, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return [_ticket_response(ticket) for ticket in support_ticket_service.list_staff_tickets(db, actor=current_user, status=status)]


@router.post("/tickets/{ticket_id}", response_model=SupportTicketResponse)
def update_support_ticket(ticket_id: str, payload: SupportAdminActionRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    ticket = support_ticket_service.staff_update_ticket(db, actor=current_user, public_id=ticket_id, message=payload.message, status=payload.status, reason=payload.reason, moderation_notes=payload.moderation_notes)
    return _ticket_response(ticket)
