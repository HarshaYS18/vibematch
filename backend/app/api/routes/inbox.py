from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.inbox import InboxConversation, InboxReport
from app.models.role import RoleName
from app.models.user import User
from app.schemas.inbox import (
    InboxConversationListResponse,
    InboxConversationResponse,
    InboxConversationStateRequest,
    InboxDirectConversationRequest,
    InboxMessageActionRequest,
    InboxMessageResponse,
    InboxMonitorActionRequest,
    InboxReportCreateRequest,
    InboxReportDecisionRequest,
    InboxReportTaskListResponse,
    InboxReportTaskResponse,
    InboxSendMessageRequest,
)
from app.services import inbox_service, role_service
from app.websocket.inbox_ws import inbox_ws_manager

router = APIRouter(prefix="/inbox", tags=["Inbox"])


def _require_cs_or_above(user: User) -> None:
    role = role_service.get_primary_role(user)
    allowed = {
        RoleName.FOUNDER_OWNER,
        RoleName.OWNER,
        RoleName.SUPERADMIN,
        RoleName.ADMIN,
        RoleName.MONITOR,
        RoleName.CS,
    }
    if role not in allowed:
        raise HTTPException(status_code=403, detail="CS report tasks are restricted to staff.")


def _require_monitor_or_above(user: User) -> None:
    role = role_service.get_primary_role(user)
    allowed = {
        RoleName.FOUNDER_OWNER,
        RoleName.OWNER,
        RoleName.SUPERADMIN,
        RoleName.ADMIN,
        RoleName.MONITOR,
    }
    if role not in allowed:
        raise HTTPException(status_code=403, detail="Monitor action is restricted to Monitor team or above.")


def _conversation_payload(conversation: InboxConversation, user: User) -> dict:
    return inbox_service.conversation_to_dict(conversation, user)


async def _broadcast_conversation(conversation: InboxConversation) -> None:
    for participant in conversation.participants:
        await inbox_ws_manager.send_to_user(
            participant.user_id,
            {
                "event": "inbox_conversation_updated",
                "conversation_id": conversation.public_id,
            },
        )


async def _broadcast_message(conversation: InboxConversation, message_payload: dict) -> None:
    await inbox_ws_manager.broadcast_to_users(
        inbox_service.participant_user_ids(conversation),
        {
            "event": "inbox_message_created",
            "conversation_id": conversation.public_id,
            "message": message_payload,
        },
    )


async def _broadcast_report_task(report: InboxReport) -> None:
    await inbox_ws_manager.broadcast_all_staff(
        {
            "event": "inbox_report_task_updated",
            "task": inbox_service.report_to_dict(report),
        }
    )
    await inbox_ws_manager.send_to_user(
        report.reporter_user_id,
        {
            "event": "inbox_report_status_updated",
            "task": inbox_service.report_to_dict(report),
        },
    )


@router.get("/conversations", response_model=InboxConversationListResponse)
def list_my_conversations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversations = inbox_service.list_conversations(db, current_user)
    return InboxConversationListResponse(
        conversations=[
            InboxConversationResponse(**_conversation_payload(item, current_user))
            for item in conversations
        ]
    )


@router.post("/conversations/direct", response_model=InboxConversationResponse)
async def create_direct_conversation(
    request: InboxDirectConversationRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if request.target_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot create a direct chat with yourself.")
    target_user = db.query(User).filter(User.id == request.target_user_id).first()
    if not target_user or not target_user.is_active:
        raise HTTPException(status_code=404, detail="Target user not found")
    conversation = inbox_service.create_direct_conversation(db, current_user, target_user)
    await _broadcast_conversation(conversation)
    return InboxConversationResponse(**_conversation_payload(conversation, current_user))


@router.get("/conversations/{conversation_id}", response_model=InboxConversationResponse)
def get_conversation(
    conversation_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return InboxConversationResponse(**_conversation_payload(conversation, current_user))


@router.post("/conversations/{conversation_id}/messages", response_model=InboxMessageResponse)
async def send_message(
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
    payload = inbox_service.message_to_dict(message, current_user)
    await _broadcast_message(conversation, payload)
    await _broadcast_conversation(conversation)
    return InboxMessageResponse(**payload)


@router.patch("/conversations/{conversation_id}/state", response_model=InboxConversationResponse)
async def update_conversation_state(
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
    await _broadcast_conversation(conversation)
    return InboxConversationResponse(**_conversation_payload(conversation, current_user))


@router.patch("/conversations/{conversation_id}/messages/{message_id}", response_model=InboxMessageResponse)
async def update_message(
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
    payload = inbox_service.message_to_dict(message, current_user)
    await inbox_ws_manager.broadcast_to_users(
        inbox_service.participant_user_ids(conversation),
        {
            "event": "inbox_message_updated",
            "conversation_id": conversation.public_id,
            "message": payload,
        },
    )
    return InboxMessageResponse(**payload)


@router.delete("/conversations/{conversation_id}/messages/{message_id}")
async def delete_message(
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
    await inbox_ws_manager.broadcast_to_users(
        inbox_service.participant_user_ids(conversation),
        {
            "event": "inbox_message_deleted",
            "conversation_id": conversation.public_id,
            "message_id": message_id,
        },
    )
    await _broadcast_conversation(conversation)
    return {"status": "deleted"}


@router.post("/conversations/{conversation_id}/reports", response_model=InboxReportTaskResponse)
async def report_conversation(
    conversation_id: str,
    request: InboxReportCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    report = inbox_service.create_report(db, conversation, current_user, request.reason)
    await _broadcast_report_task(report)
    return InboxReportTaskResponse(**inbox_service.report_to_dict(report))


@router.get("/reports/tasks", response_model=InboxReportTaskListResponse)
def list_report_tasks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_cs_or_above(current_user)
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
async def reject_report_task(
    report_id: str,
    request: InboxReportDecisionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_cs_or_above(current_user)
    report = inbox_service.decide_report(db, _get_report(db, report_id), accepted=False, cs_note=request.cs_note)
    await _broadcast_report_task(report)
    return InboxReportTaskResponse(**inbox_service.report_to_dict(report))


@router.post("/reports/tasks/{report_id}/accept", response_model=InboxReportTaskResponse)
async def accept_report_task(
    report_id: str,
    request: InboxReportDecisionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_cs_or_above(current_user)
    report = inbox_service.decide_report(db, _get_report(db, report_id), accepted=True, cs_note=request.cs_note)
    await _broadcast_report_task(report)
    return InboxReportTaskResponse(**inbox_service.report_to_dict(report))


@router.post("/reports/tasks/{report_id}/monitor-action", response_model=InboxReportTaskResponse)
async def apply_monitor_action(
    report_id: str,
    request: InboxMonitorActionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_monitor_or_above(current_user)
    report = inbox_service.apply_monitor_action(db, _get_report(db, report_id), request.action_label)
    await _broadcast_report_task(report)
    return InboxReportTaskResponse(**inbox_service.report_to_dict(report))
