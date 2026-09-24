from __future__ import annotations

import hmac
from datetime import datetime

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.config import settings
from app.database import get_db
from app.models.inbox import InboxMessage
from app.models.user import User
from app.services import inbox_backup_service, inbox_service


router = APIRouter(prefix="/internal/inbox", tags=["Inbox Internal"])


def require_internal_token(
    x_funkey_internal_token: str | None = Header(default=None),
) -> None:
    expected = settings.INBOX_INTERNAL_TOKEN.strip()
    provided = (x_funkey_internal_token or "").strip()
    if not expected or not hmac.compare_digest(provided, expected):
        raise HTTPException(status_code=403, detail="Internal Inbox access denied")


class TeamMessageRequest(BaseModel):
    target_user_id: int = Field(gt=0)
    text: str = Field(min_length=1, max_length=4000)


class DirectMessageRequest(BaseModel):
    sender_user_id: int = Field(gt=0)
    target_user_id: int = Field(gt=0)
    text: str = Field(min_length=1, max_length=4000)
    message_type: str = Field(default="text", max_length=40)
    attachment_url: str | None = Field(default=None, max_length=700)
    metadata: dict = Field(default_factory=dict)


class MessagePatchRequest(BaseModel):
    text: str | None = Field(default=None, min_length=1, max_length=4000)
    metadata_patch: dict = Field(default_factory=dict)


class MediaExpiredRequest(BaseModel):
    attachment_url: str = Field(min_length=1, max_length=700)
    media_id: str = Field(min_length=1, max_length=120)
    expired_at: datetime
    local_first_allowed: bool = True


class FamilySyncRequest(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    member_user_ids: list[int] = Field(default_factory=list, max_length=5000)


class FamilySendRequest(FamilySyncRequest):
    sender_user_id: int = Field(gt=0)
    text: str = Field(min_length=1, max_length=2000)


def _user_or_404(db: Session, user_id: int) -> User:
    user = db.query(User).filter(User.id == int(user_id)).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.post("/team-message", dependencies=[Depends(require_internal_token)])
def send_team_message(
    payload: TeamMessageRequest,
    db: Session = Depends(get_db),
):
    user = _user_or_404(db, payload.target_user_id)
    message = inbox_service.send_team_system_message(db, user, payload.text)
    return {
        "conversation_id": message.conversation.public_id,
        "message_id": message.public_id,
    }


@router.post("/direct-message", dependencies=[Depends(require_internal_token)])
def send_direct_message(
    payload: DirectMessageRequest,
    db: Session = Depends(get_db),
):
    sender = _user_or_404(db, payload.sender_user_id)
    target = _user_or_404(db, payload.target_user_id)
    conversation = inbox_service.create_direct_conversation(db, sender, target)
    message = inbox_service.send_message(
        db,
        conversation,
        sender,
        payload.text,
        message_type=payload.message_type,
        attachment_url=payload.attachment_url,
        metadata=dict(payload.metadata or {}),
    )
    return {
        "conversation_id": conversation.public_id,
        "message_id": message.public_id,
        "message": inbox_service.message_to_dict(message, sender),
    }


@router.patch(
    "/messages/{message_id}",
    dependencies=[Depends(require_internal_token)],
)
def patch_message(
    message_id: str,
    payload: MessagePatchRequest,
    db: Session = Depends(get_db),
):
    message = (
        db.query(InboxMessage)
        .filter(InboxMessage.public_id == message_id)
        .first()
    )
    if message is None:
        raise HTTPException(status_code=404, detail="Inbox message not found")
    if payload.text is not None:
        message.text = payload.text.strip()
    if payload.metadata_patch:
        metadata = dict(message.metadata_json or {})
        metadata.update(payload.metadata_patch)
        message.metadata_json = metadata
    message.updated_at = datetime.utcnow()
    db.add(message)
    db.commit()
    return {"status": "updated", "message_id": message.public_id}


@router.post(
    "/media-expired",
    dependencies=[Depends(require_internal_token)],
)
def mark_media_expired(
    payload: MediaExpiredRequest,
    db: Session = Depends(get_db),
):
    messages = (
        db.query(InboxMessage)
        .filter(InboxMessage.attachment_url == payload.attachment_url)
        .all()
    )
    for message in messages:
        metadata = dict(message.metadata_json or {})
        metadata.update(
            {
                "media_expired": True,
                "expired_media_url": payload.attachment_url,
                "expired_media_id": payload.media_id,
                "media_expired_at": payload.expired_at.isoformat(),
                "local_first_allowed": bool(payload.local_first_allowed),
            }
        )
        message.metadata_json = metadata
        db.add(message)
    db.commit()
    return {"updated": len(messages)}


@router.post(
    "/family/{family_id}/sync",
    dependencies=[Depends(require_internal_token)],
)
def sync_family(
    family_id: int,
    payload: FamilySyncRequest,
    db: Session = Depends(get_db),
):
    conversation = inbox_service.ensure_family_conversation(
        db,
        family_id=family_id,
        title=payload.title,
        member_user_ids=payload.member_user_ids,
    )
    return {"conversation_id": conversation.public_id}


@router.get(
    "/family/{family_id}/messages",
    dependencies=[Depends(require_internal_token)],
)
def get_family_messages(
    family_id: int,
    user_id: int = Query(gt=0),
    limit: int = Query(default=80, ge=1, le=100),
    before: str | None = Query(default=None),
    db: Session = Depends(get_db),
):
    user = _user_or_404(db, user_id)
    conversation_id = f"family_chat_{int(family_id)}"
    conversation = inbox_service.get_conversation_for_user(
        db,
        user,
        conversation_id,
    )
    if conversation is None:
        raise HTTPException(status_code=404, detail="Family chat not found")
    messages, next_cursor, has_more = inbox_service.list_messages_page(
        db,
        conversation,
        user,
        limit=limit,
        before=before,
    )
    statuses = inbox_service.message_statuses_for_user(db, messages, user)
    return {
        "family_id": int(family_id),
        "conversation_id": conversation.public_id,
        "messages": [
            inbox_service.message_to_dict(
                message,
                user,
                status_override=statuses.get(message.id),
            )
            for message in messages
        ],
        "next_cursor": next_cursor,
        "has_more": has_more,
    }


@router.post(
    "/family/{family_id}/messages",
    dependencies=[Depends(require_internal_token)],
)
def send_family_message(
    family_id: int,
    payload: FamilySendRequest,
    db: Session = Depends(get_db),
):
    sender = _user_or_404(db, payload.sender_user_id)
    conversation = inbox_service.ensure_family_conversation(
        db,
        family_id=family_id,
        title=payload.title,
        member_user_ids=payload.member_user_ids,
    )
    participant_ids = set(inbox_service.participant_user_ids(conversation))
    if sender.id not in participant_ids:
        raise HTTPException(status_code=403, detail="Family membership required")
    message = inbox_service.send_message(
        db,
        conversation,
        sender,
        payload.text,
        metadata={"family_id": int(family_id)},
    )
    return {
        "family_id": int(family_id),
        "conversation_id": conversation.public_id,
        "message": inbox_service.message_to_dict(message, sender),
    }


@router.post(
    "/backup/jobs/{job_id}/execute",
    dependencies=[Depends(require_internal_token)],
)
def execute_backup_job(
    job_id: str,
    db: Session = Depends(get_db),
):
    try:
        job, duplicate = inbox_backup_service.execute_backup_or_restore_job(
            db,
            job_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return {
        **inbox_backup_service.job_payload(job),
        "duplicate": duplicate,
    }
