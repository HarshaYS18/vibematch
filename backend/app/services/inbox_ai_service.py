from sqlalchemy.orm import Session

from app.models.user import User
from app.services.message_search_service import search_allowed_messages


def search_inbox(db: Session, *, user: User, query: str) -> tuple[dict, list[dict]]:
    # Only the authenticated user's query is interpreted. Private message
    # history stays in backend search and is never sent to external AI.
    return search_allowed_messages(db, user=user, query=query)
