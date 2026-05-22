from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.support import InboxAiSearchRequest, InboxAiSearchResponse, InboxAiSearchResult
from app.services import inbox_ai_service

router = APIRouter(prefix="/inbox-ai", tags=["Inbox AI"])


@router.post("/search", response_model=InboxAiSearchResponse)
def search_inbox(payload: InboxAiSearchRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    filters, rows = inbox_ai_service.search_inbox(db, user=current_user, query=payload.query)
    return InboxAiSearchResponse(query=payload.query, interpreted_filters={key: str(value) for key, value in filters.items()}, results=[InboxAiSearchResult(**row) for row in rows])
