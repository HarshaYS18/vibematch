from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.inbox import InboxReport
from app.models.user import User
from app.schemas.inbox import (
    InboxConversationListResponse,
    InboxConversationResponse,
    InboxConversationStateRequest,
    InboxMessageActionRequest,
    InboxMessageResponse,
    InboxMonitorActionRequest,
    InboxReportCreateRequest,
    InboxReportDecisionRequest,
    InboxReportTaskListResponse,
    InboxReportTaskResponse,
    InboxSendMessageRequest,
)
from app.services import inbox_service

router = APIRouter(prefix="/inbox", tags=["Inbox"])


@router.get("/conversations", response_model=InboxConversationListResponse)
def list_my_conversations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversations = inbox_service.list_conversations(db, current_user)
    return InboxConversationListResponse(
        conversations=[
            InboxConversationResponse(**inbox_service.conversation_to_dict(item, current_user))
            for item in conversations
        ]
    )


@router.get("/conversations/{conversation_id}", response_model=InboxConversationResponse)
def get_conversation(
    conversation_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return InboxConversationResponse(**inbox_service.conversation_to_dict(conversation, current_user))


@router.post("/conversations/{conversation_id}/messages", response_model=InboxMessageResponse)
def send_message(
    conversation_id: str,
    request: InboxSendMessageRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    if conversation.is_blocked:
        raise HTTPException(status_code=403, detail="Conversation is blocked")
    if conversation.is_official:
        raise HTTPException(status_code=403, detail="Official team chat is read-only")

    message = inbox_service.send_message(
        db=db,
        conversation=conversation,
        sender=current_user,
        text=request.text,
        message_type=request.type,
        reply_to_text=request.reply_to_text,
        invite_room_name=request.invite_room_name,
        attachment_url=request.attachment_url,
    )
    return InboxMessageResponse(**inbox_service.message_to_dict(message, current_user))


@router.patch("/conversations/{conversation_id}/state", response_model=InboxConversationResponse)
def update_conversation_state(
    conversation_id: str,
    request: InboxConversationStateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    conversation = inbox_service.update_conversation_state(
        db=db,
        conversation=conversation,
        is_muted=request.is_muted,
        is_pinned=request.is_pinned,
        is_locked=request.is_locked,
        is_blocked=request.is_blocked,
    )
    return InboxConversationResponse(**inbox_service.conversation_to_dict(conversation, current_user))


@router.patch("/conversations/{conversation_id}/messages/{message_id}", response_model=InboxMessageResponse)
def update_message(
    conversation_id: str,
    message_id: str,
    request: InboxMessageActionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    message = inbox_service.update_message(
        db=db,
        conversation=conversation,
        message_public_id=message_id,
        reaction=request.reaction,
        is_starred=request.is_starred,
    )
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")
    return InboxMessageResponse(**inbox_service.message_to_dict(message, current_user))


@router.delete("/conversations/{conversation_id}/messages/{message_id}")
def delete_message(
    conversation_id: str,
    message_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    deleted = inbox_service.delete_message(db, conversation, message_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Message not found")
    return {"status": "deleted"}


@router.post("/conversations/{conversation_id}/reports", response_model=InboxReportTaskResponse)
def report_conversation(
    conversation_id: str,
    request: InboxReportCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    report = inbox_service.create_report(db, conversation, current_user, request.reason)
    return InboxReportTaskResponse(**inbox_service.report_to_dict(report))


@router.get("/reports/tasks", response_model=InboxReportTaskListResponse)
def list_report_tasks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    tasks = inbox_service.list_report_tasks(db)
    return InboxReportTaskListResponse(
        tasks=[InboxReportTaskResponse(**inbox_service.report_to_dict(task)) for task in tasks]
    )


def _get_report(db: Session, report_id: str) -> InboxReport:
    report = db.query(InboxReport).filter(InboxReport.public_id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report task not found")
    return report


@router.post("/reports/tasks/{report_id}/reject", response_model=InboxReportTaskResponse)
def reject_report_task(
    report_id: str,
    request: InboxReportDecisionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    report = inbox_service.decide_report(db, _get_report(db, report_id), accepted=False, cs_note=request.cs_note)
    return InboxReportTaskResponse(**inbox_service.report_to_dict(report))


@router.post("/reports/tasks/{report_id}/accept", response_model=InboxReportTaskResponse)
def accept_report_task(
    report_id: str,
    request: InboxReportDecisionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    report = inbox_service.decide_report(db, _get_report(db, report_id), accepted=True, cs_note=request.cs_note)
    return InboxReportTaskResponse(**inbox_service.report_to_dict(report))


@router.post("/reports/tasks/{report_id}/monitor-action", response_model=InboxReportTaskResponse)
def apply_monitor_action(
    report_id: str,
    request: InboxMonitorActionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    report = inbox_service.apply_monitor_action(db, _get_report(db, report_id), request.action_label)
    return InboxReportTaskResponse(**inbox_service.report_to_dict(report))
