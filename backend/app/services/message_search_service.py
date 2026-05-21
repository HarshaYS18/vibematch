from datetime import datetime, timedelta

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.models.inbox import InboxConversation, InboxMessage, InboxParticipant
from app.models.inbox_preferences import InboxMessageUserState
from app.models.user import User


def parse_search_filters(query: str) -> dict:
    lowered = query.lower()
    filters: dict = {"terms": [term for term in lowered.replace("?", " ").split() if len(term) > 2]}
    if "yesterday" in lowered:
        today = datetime.utcnow().date()
        filters["after"] = datetime.combine(today - timedelta(days=1), datetime.min.time())
        filters["before"] = datetime.combine(today, datetime.min.time())
    if "unread" in lowered:
        filters["unread"] = True
    if "invite" in lowered or "room" in lowered:
        filters["message_type"] = "room_invite"
    if "support" in lowered or "recharge" in lowered:
        filters["official"] = True
    if "friend" in lowered or "friends" in lowered:
        filters["exclude_stranger"] = True
    return filters


def search_allowed_messages(db: Session, *, user: User, query: str, limit: int = 20) -> tuple[dict, list[dict]]:
    filters = parse_search_filters(query)
    participant_rows = db.query(InboxParticipant).filter(InboxParticipant.user_id == user.id, InboxParticipant.is_deleted_for_user.is_(False)).all()
    allowed_conversation_ids = [row.conversation_id for row in participant_rows]
    if not allowed_conversation_ids:
        return filters, []
    unread_conversation_ids = {row.conversation_id for row in participant_rows if row.unread_count > 0}
    deleted_message_ids = {
        row.message_id
        for row in db.query(InboxMessageUserState)
        .filter(InboxMessageUserState.user_id == user.id, InboxMessageUserState.is_deleted_for_user.is_(True))
        .all()
    }
    query_builder = db.query(InboxMessage, InboxConversation).join(InboxConversation, InboxConversation.id == InboxMessage.conversation_id).filter(InboxMessage.conversation_id.in_(allowed_conversation_ids))
    if deleted_message_ids:
        query_builder = query_builder.filter(~InboxMessage.id.in_(deleted_message_ids))
    if filters.get("after"):
        query_builder = query_builder.filter(InboxMessage.created_at >= filters["after"])
    if filters.get("before"):
        query_builder = query_builder.filter(InboxMessage.created_at < filters["before"])
    if filters.get("message_type"):
        query_builder = query_builder.filter(InboxMessage.message_type == filters["message_type"])
    if filters.get("official"):
        query_builder = query_builder.filter(InboxConversation.is_official.is_(True))
    if filters.get("exclude_stranger"):
        query_builder = query_builder.filter(InboxConversation.conversation_type != "stranger")
    terms = [term for term in filters.get("terms", []) if term not in {"find", "show", "from", "where", "sent", "chat", "chats", "message", "messages"}]
    if terms:
        text_filters = [InboxMessage.text.ilike(f"%{term}%") for term in terms[:5]]
        text_filters.append(InboxConversation.title.ilike(f"%{terms[0]}%"))
        query_builder = query_builder.filter(or_(*text_filters))
    rows = query_builder.order_by(InboxMessage.created_at.desc()).limit(limit * 2).all()
    results: list[dict] = []
    for message, conversation in rows:
        if filters.get("unread") and conversation.id not in unread_conversation_ids:
            continue
        locked = conversation.is_locked
        if locked:
            results.append({"conversation_id": conversation.public_id, "message_id": None, "title": "Locked chat", "snippet": "Unlock Inbox to search this private chat.", "time": message.created_at, "match_reason": "Locked result hidden", "is_locked": True})
            continue
        metadata = conversation.metadata_json or {}
        is_secret = metadata.get("secret_vibe") is True or metadata.get("is_secret_vibe") is True
        snippet = _safe_snippet(message.text)
        if is_secret:
            snippet = "Secret Vibe content is hidden from AI helper previews."
        results.append({"conversation_id": conversation.public_id, "message_id": message.public_id, "title": conversation.title if not is_secret else "Private chat", "snippet": snippet, "time": message.created_at, "match_reason": _reason_for(filters), "is_locked": False})
        if len(results) >= limit:
            break
    return filters, results


def _safe_snippet(text: str) -> str:
    clean = " ".join(text.strip().split())
    return clean[:160] + ("..." if len(clean) > 160 else "")


def _reason_for(filters: dict) -> str:
    if filters.get("message_type") == "room_invite":
        return "Matched room invite"
    if filters.get("official"):
        return "Matched support or official chat"
    if filters.get("unread"):
        return "Matched unread chat"
    return "Matched chat text"
