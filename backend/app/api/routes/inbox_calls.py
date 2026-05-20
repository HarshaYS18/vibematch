from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.inbox_calls import (
    InboxCallDecisionRequest,
    InboxCallMediaContractResponse,
    InboxCallResponse,
    InboxCallStartRequest,
    InboxCallSummaryMessageResponse,
)
from app.services import inbox_call_contract_service, inbox_call_service, inbox_service, push_notification_service
from app.websocket.inbox_ws import inbox_ws_manager

router = APIRouter(prefix="/calls", tags=["Inbox Calls"])


def _response(call, *, current_user: User | None = None, conversation=None) -> InboxCallResponse:
    payload = inbox_call_service.call_to_dict(call)
    if current_user is not None:
        payload["media_contract"] = inbox_call_contract_service.media_join_contract(call, user_id=current_user.id)
        if conversation is not None:
            payload["push_contract"] = inbox_call_contract_service.push_payload_for_call(
                conversation,
                call,
                event="inbox_call_state",
                receiver_user_id=current_user.id,
            )
    return InboxCallResponse(**payload)


async def _broadcast_call(conversation, call, event: str) -> None:
    call_payload = inbox_call_service.call_to_dict(call)
    for participant in conversation.participants:
        await inbox_ws_manager.send_to_user(
            participant.user_id,
            {
                "event": event,
                "conversation_id": conversation.public_id,
                "from_self": participant.user_id == call.started_by_user_id,
                "call": call_payload,
                "push_contract": inbox_call_contract_service.push_payload_for_call(
                    conversation,
                    call,
                    event=event,
                    receiver_user_id=participant.user_id,
                ),
                "media_contract": inbox_call_contract_service.media_join_contract(call, user_id=participant.user_id),
            },
        )


def _send_call_pushes(db: Session, conversation, call, event: str) -> None:
    if event != "inbox_call_started":
        return
    for participant in conversation.participants:
        if participant.user_id == call.started_by_user_id:
            continue
        payload = inbox_call_contract_service.push_payload_for_call(
            conversation,
            call,
            event=event,
            receiver_user_id=participant.user_id,
        )
        push_notification_service.send_to_user(
            db,
            user_id=participant.user_id,
            title=payload.get("title", "Incoming call"),
            body=payload.get("body", "Incoming FunKey call"),
            data=payload,
        )


async def _broadcast_summary(conversation, message) -> None:
    for participant in conversation.participants:
        if participant.user is None:
            continue
        await inbox_ws_manager.send_to_user(
            participant.user_id,
            {
                "event": "inbox_message_created",
                "conversation_id": conversation.public_id,
                "message": inbox_service.message_to_dict(message, participant.user),
            },
        )
    await inbox_ws_manager.broadcast_to_users(
        inbox_service.participant_user_ids(conversation),
        {"event": "inbox_conversation_updated", "conversation_id": conversation.public_id},
    )


@router.post("/conversations/{conversation_id}/start", response_model=InboxCallResponse)
async def start_call(
    conversation_id: str,
    request: InboxCallStartRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    try:
        call = inbox_call_service.start_call(db, conversation, current_user, request.call_type.value)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    await _broadcast_call(conversation, call, "inbox_call_started")
    _send_call_pushes(db, conversation, call, "inbox_call_started")
    return _response(call, current_user=current_user, conversation=conversation)


@router.post("/conversations/{conversation_id}/{call_id}/accept", response_model=InboxCallResponse)
async def accept_call(
    conversation_id: str,
    call_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    call = inbox_call_service.get_call_for_conversation(db, conversation, call_id)
    if not call:
        raise HTTPException(status_code=404, detail="Call not found")
    try:
        call = inbox_call_service.accept_call(db, call, current_user)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    await _broadcast_call(conversation, call, "inbox_call_accepted")
    return _response(call, current_user=current_user, conversation=conversation)


@router.get("/conversations/{conversation_id}/{call_id}/media-contract", response_model=InboxCallMediaContractResponse)
def get_media_contract(
    conversation_id: str,
    call_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    call = inbox_call_service.get_call_for_conversation(db, conversation, call_id)
    if not call:
        raise HTTPException(status_code=404, detail="Call not found")
    return InboxCallMediaContractResponse(
        call_id=call.call_public_id,
        conversation_id=conversation.public_id,
        media_contract=inbox_call_contract_service.media_join_contract(call, user_id=current_user.id),
    )


@router.post("/conversations/{conversation_id}/{call_id}/decline", response_model=InboxCallResponse)
async def decline_call(
    conversation_id: str,
    call_id: str,
    request: InboxCallDecisionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    call = inbox_call_service.get_call_for_conversation(db, conversation, call_id)
    if not call:
        raise HTTPException(status_code=404, detail="Call not found")
    try:
        call, message = inbox_call_service.decline_call(db, call, current_user, reason=request.reason)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    await _broadcast_call(conversation, call, "inbox_call_declined")
    await _broadcast_summary(conversation, message)
    return _response(call, current_user=current_user, conversation=conversation)


@router.post("/conversations/{conversation_id}/{call_id}/end", response_model=InboxCallResponse)
async def end_call(
    conversation_id: str,
    call_id: str,
    request: InboxCallDecisionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    call = inbox_call_service.get_call_for_conversation(db, conversation, call_id)
    if not call:
        raise HTTPException(status_code=404, detail="Call not found")
    try:
        call, message = inbox_call_service.end_call(db, call, current_user, reason=request.reason)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    await _broadcast_call(conversation, call, "inbox_call_ended")
    await _broadcast_summary(conversation, message)
    return _response(call, current_user=current_user, conversation=conversation)


@router.post("/conversations/{conversation_id}/{call_id}/missed", response_model=InboxCallSummaryMessageResponse)
async def mark_missed_call(
    conversation_id: str,
    call_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    call = inbox_call_service.get_call_for_conversation(db, conversation, call_id)
    if not call:
        raise HTTPException(status_code=404, detail="Call not found")
    call, message = inbox_call_service.end_call(db, call, current_user, reason="missed")
    await _broadcast_call(conversation, call, "inbox_call_missed")
    await _broadcast_summary(conversation, message)
    return InboxCallSummaryMessageResponse(
        message_id=message.public_id,
        conversation_id=conversation.public_id,
        text=message.text,
        call_id=call.call_public_id,
        status="missed",
        duration_seconds=call.duration_seconds,
    )
