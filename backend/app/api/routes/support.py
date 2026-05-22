from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.help_article import HelpArticle
from app.models.support_attachment import SupportAttachment
from app.models.support_message import SupportMessage
from app.models.support_ticket import SupportTicket
from app.models.user import User
from app.schemas.support import (
    HelpArticleResponse,
    HelpAskRequest,
    HelpAskResponse,
    SupportAttachmentResponse,
    SupportMessageCreateRequest,
    SupportMessageResponse,
    SupportTicketCreateRequest,
    SupportTicketResponse,
)
from app.services import ai_helpdesk_service, help_knowledge_service, support_ticket_service

router = APIRouter(prefix="/support", tags=["Support"])


@router.get("/tickets", response_model=list[SupportTicketResponse])
def list_my_tickets(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return [_ticket_response(ticket) for ticket in support_ticket_service.list_user_tickets(db, user=current_user)]


@router.post("/tickets", response_model=SupportTicketResponse)
def create_ticket(payload: SupportTicketCreateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    ticket = support_ticket_service.create_ticket(db, user=current_user, category=payload.category, subject=payload.subject, message=payload.message, attachments=payload.attachments)
    return _ticket_response(ticket)


@router.get("/tickets/{ticket_id}", response_model=SupportTicketResponse)
def get_ticket(ticket_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return _ticket_response(support_ticket_service.get_user_ticket(db, user=current_user, public_id=ticket_id))


@router.post("/tickets/{ticket_id}/messages", response_model=SupportTicketResponse)
def add_message(ticket_id: str, payload: SupportMessageCreateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return _ticket_response(support_ticket_service.add_user_message(db, user=current_user, public_id=ticket_id, message=payload.message, attachments=payload.attachments))


@router.post("/ask", response_model=HelpAskResponse)
def ask_helpdesk(payload: HelpAskRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    classification = ai_helpdesk_service.classify_support_message(payload.message)
    articles = help_knowledge_service.search_articles(db, payload.message, category=classification.category)
    return HelpAskResponse(classification=classification, matching_articles=[_article_response(item) for item in articles])


@router.get("/articles", response_model=list[HelpArticleResponse])
def list_articles(q: str = "", category: str | None = None, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return [_article_response(item) for item in help_knowledge_service.search_articles(db, q, category=category, limit=20)]


def _ticket_response(ticket: SupportTicket) -> SupportTicketResponse:
    return SupportTicketResponse(
        id=ticket.public_id,
        category=ticket.category,
        subject=ticket.subject,
        status=ticket.status,
        priority=ticket.priority,
        ai_summary=ticket.ai_summary,
        ai_summary_generated=ticket.ai_summary_generated,
        missing_fields=list(ticket.missing_fields_json or []),
        created_at=ticket.created_at,
        updated_at=ticket.updated_at,
        resolved_at=ticket.resolved_at,
        messages=[_message_response(item) for item in ticket.messages],
        attachments=[_attachment_response(item) for item in ticket.attachments],
    )


def _message_response(message: SupportMessage) -> SupportMessageResponse:
    return SupportMessageResponse(id=message.public_id, sender_role=message.sender_role, body=message.body, is_ai_generated=message.is_ai_generated, created_at=message.created_at)


def _attachment_response(attachment: SupportAttachment) -> SupportAttachmentResponse:
    return SupportAttachmentResponse(file_url=attachment.file_url, content_type=attachment.content_type, moderation_status=attachment.moderation_status, created_at=attachment.created_at)


def _article_response(article: HelpArticle) -> HelpArticleResponse:
    return HelpArticleResponse(slug=article.slug, category=article.category, title=article.title, body=article.body, tags=list(article.tags_json or []))
