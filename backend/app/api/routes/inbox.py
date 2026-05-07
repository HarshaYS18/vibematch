from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.inbox import InboxConversation, InboxReport
from app.models.role import RoleName
from app.models.user import User
from app.schemas.inbox import (
    InboxBackupJobResponse,
    InboxBackupSettingsRequest,
    InboxBackupStatusResponse,
    InboxConversationListResponse,
    InboxConversationResponse,
    InboxConversationStateRequest,
    InboxDirectConversationRequest,
    InboxGoogleDriveAuthStartResponse,
    InboxGoogleDriveConnectRequest,
    InboxLockChangeRequest,
    InboxLockDebugOtpResponse,
    InboxLockRecoveryRequestResponse,
    InboxLockRecoveryStartRequest,
    InboxLockRecoveryVerifyRequest,
    InboxLockStartSetupRequest,
    InboxLockStatusResponse,
    InboxLockVerifyRequest,
    InboxLockVerifySetupRequest,
    InboxMessageActionRequest,
    InboxMessageResponse,
    InboxMonitorActionRequest,
    InboxReportCreateRequest,
    InboxReportDecisionRequest,
    InboxReportTaskListResponse,
    InboxReportTaskResponse,
    InboxSendMessageRequest,
)
from app.services import inbox_backup_service, inbox_lock_service, inbox_service, role_service
from app.websocket.inbox_ws import inbox_ws_manager

router = APIRouter(prefix="/inbox", tags=["Inbox"])


def _require_cs_or_above(user: User) -> None:
    role = role_service.get_primary_role(user)
    allowed = {RoleName.FOUNDER_OWNER, RoleName.OWNER, RoleName.SUPERADMIN, RoleName.ADMIN, RoleName.MONITOR, RoleName.CS}
    if role not in allowed:
        raise HTTPException(status_code=403, detail="CS report tasks are restricted to staff.")


def _require_monitor_or_above(user: User) -> None:
    role = role_service.get_primary_role(user)
    allowed = {RoleName.FOUNDER_OWNER, RoleName.OWNER, RoleName.SUPERADMIN, RoleName.ADMIN, RoleName.MONITOR}
    if role not in allowed:
        raise HTTPException(status_code=403, detail="Monitor action is restricted to Monitor team or above.")


def _require_owner_or_founder(user: User) -> None:
    role = role_service.get_primary_role(user)
    if role not in {RoleName.FOUNDER_OWNER, RoleName.OWNER}:
        raise HTTPException(status_code=403, detail="Only Owner or Super Owner can reset inbox lock in special cases.")


def _conversation_payload(conversation: InboxConversation, user: User) -> dict:
    return inbox_service.conversation_to_dict(conversation, user)


async def _broadcast_conversation(conversation: InboxConversation) -> None:
    for participant in conversation.participants:
        await inbox_ws_manager.send_to_user(participant.user_id, {"event": "inbox_conversation_updated", "conversation_id": conversation.public_id})


async def _broadcast_message(conversation: InboxConversation, message_payload: dict) -> None:
    await inbox_ws_manager.broadcast_to_users(inbox_service.participant_user_ids(conversation), {"event": "inbox_message_created", "conversation_id": conversation.public_id, "message": message_payload})


async def _broadcast_report_task(report: InboxReport) -> None:
    payload = inbox_service.report_to_dict(report)
    await inbox_ws_manager.broadcast_all_staff({"event": "inbox_report_task_updated", "task": payload})
    await inbox_ws_manager.send_to_user(report.reporter_user_id, {"event": "inbox_report_status_updated", "task": payload})


@router.get("/backup/status", response_model=InboxBackupStatusResponse)
def get_backup_status(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return InboxBackupStatusResponse(**inbox_backup_service.get_status(db, current_user))


@router.patch("/backup/settings", response_model=InboxBackupStatusResponse)
def update_backup_settings(request: InboxBackupSettingsRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    try:
        setting = inbox_backup_service.update_settings(db, current_user, is_enabled=request.is_enabled, frequency=request.frequency)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return InboxBackupStatusResponse(**inbox_backup_service.status_payload(setting))


@router.get("/backup/google/authorize", response_model=InboxGoogleDriveAuthStartResponse)
def start_google_drive_authorization(current_user: User = Depends(get_current_user)):
    try:
        url = inbox_backup_service.google_drive_authorize_url(current_user)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return InboxGoogleDriveAuthStartResponse(authorization_url=url)


@router.post("/backup/google/connect", response_model=InboxBackupStatusResponse)
def connect_google_drive(request: InboxGoogleDriveConnectRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if not request.authorization_code:
        raise HTTPException(status_code=400, detail="Authorization code is required to connect Google Drive.")
    try:
        setting = inbox_backup_service.connect_google_drive(db, current_user, authorization_code=request.authorization_code, google_email=request.google_drive_email)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return InboxBackupStatusResponse(**inbox_backup_service.status_payload(setting))


@router.post("/backup/run", response_model=InboxBackupJobResponse)
def run_backup_now(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    try:
        job = inbox_backup_service.run_backup_now(db, current_user)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return InboxBackupJobResponse(**inbox_backup_service.job_payload(job))


@router.post("/backup/restore", response_model=InboxBackupJobResponse)
def restore_latest_backup(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    try:
        job = inbox_backup_service.run_restore_latest(db, current_user)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return InboxBackupJobResponse(**inbox_backup_service.job_payload(job))


@router.get("/lock/status", response_model=InboxLockStatusResponse)
def get_lock_status(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return InboxLockStatusResponse(**inbox_lock_service.get_status(db, current_user))


@router.post("/lock/setup/start", response_model=InboxLockDebugOtpResponse)
def start_lock_setup(request: InboxLockStartSetupRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    otp = inbox_lock_service.start_setup(db, current_user, request.mobile_number)
    return InboxLockDebugOtpResponse(status="otp_sent", expires_in_minutes=inbox_lock_service.OTP_EXPIRE_MINUTES, debug_otp=otp)


@router.post("/lock/setup/verify", response_model=InboxLockStatusResponse)
def verify_lock_setup(request: InboxLockVerifySetupRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    try:
        inbox_lock_service.verify_setup(db, current_user, request.mobile_number, request.otp, request.lock_code)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return InboxLockStatusResponse(**inbox_lock_service.get_status(db, current_user))


@router.post("/lock/verify")
def verify_lock(request: InboxLockVerifyRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if not inbox_lock_service.verify_lock(db, current_user, request.lock_code):
        raise HTTPException(status_code=403, detail="Invalid lock code")
    return {"status": "verified"}


@router.post("/lock/change", response_model=InboxLockStatusResponse)
def change_lock(request: InboxLockChangeRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    try:
        inbox_lock_service.change_lock(db, current_user, request.current_lock_code, request.new_lock_code)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return InboxLockStatusResponse(**inbox_lock_service.get_status(db, current_user))


@router.post("/lock/recovery/start", response_model=InboxLockDebugOtpResponse)
def start_lock_recovery(request: InboxLockRecoveryStartRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    try:
        otp = inbox_lock_service.start_recovery(db, current_user, request.mobile_number)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return InboxLockDebugOtpResponse(status="recovery_otp_sent", expires_in_minutes=inbox_lock_service.OTP_EXPIRE_MINUTES, debug_otp=otp)


@router.post("/lock/recovery/verify", response_model=InboxLockStatusResponse)
def verify_lock_recovery(request: InboxLockRecoveryVerifyRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    try:
        inbox_lock_service.recover_lock(db, current_user, request.mobile_number, request.otp, request.new_lock_code)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return InboxLockStatusResponse(**inbox_lock_service.get_status(db, current_user))


@router.post("/lock/recovery/request-cs", response_model=InboxLockRecoveryRequestResponse)
def request_cs_recovery(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    inbox_lock_service.request_cs_recovery(db, current_user)
    return InboxLockRecoveryRequestResponse(status="submitted", message="Recovery request submitted. CS will review your identity confirmation request.")


@router.post("/lock/owner-reset/{target_user_id}", response_model=InboxLockStatusResponse)
def owner_reset_lock(target_user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_owner_or_founder(current_user)
    target_user = db.query(User).filter(User.id == target_user_id).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found")
    inbox_lock_service.owner_reset_lock(db, target_user)
    return InboxLockStatusResponse(**inbox_lock_service.get_status(db, target_user))


@router.get("/conversations", response_model=InboxConversationListResponse)
def list_my_conversations(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    conversations = inbox_service.list_conversations(db, current_user)
    return InboxConversationListResponse(conversations=[InboxConversationResponse(**_conversation_payload(item, current_user)) for item in conversations])


@router.post("/conversations/direct", response_model=InboxConversationResponse)
async def create_direct_conversation(request: InboxDirectConversationRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if request.target_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot create a direct chat with yourself.")
    target_user = db.query(User).filter(User.id == request.target_user_id).first()
    if not target_user or not target_user.is_active:
        raise HTTPException(status_code=404, detail="Target user not found")
    conversation = inbox_service.create_direct_conversation(db, current_user, target_user)
    await _broadcast_conversation(conversation)
    return InboxConversationResponse(**_conversation_payload(conversation, current_user))


@router.get("/conversations/{conversation_id}", response_model=InboxConversationResponse)
def get_conversation(conversation_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return InboxConversationResponse(**_conversation_payload(conversation, current_user))


@router.post("/conversations/{conversation_id}/messages", response_model=InboxMessageResponse)
async def send_message(conversation_id: str, request: InboxSendMessageRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    if conversation.is_blocked:
        raise HTTPException(status_code=403, detail="Conversation is blocked")
    if conversation.is_official:
        raise HTTPException(status_code=403, detail="Official team chat is read-only")
    message = inbox_service.send_message(db=db, conversation=conversation, sender=current_user, text=request.text, message_type=request.type, reply_to_text=request.reply_to_text, invite_room_name=request.invite_room_name, attachment_url=request.attachment_url)
    payload = inbox_service.message_to_dict(message, current_user)
    await _broadcast_message(conversation, payload)
    await _broadcast_conversation(conversation)
    return InboxMessageResponse(**payload)


@router.patch("/conversations/{conversation_id}/state", response_model=InboxConversationResponse)
async def update_conversation_state(conversation_id: str, request: InboxConversationStateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    conversation = inbox_service.update_conversation_state(db=db, conversation=conversation, is_muted=request.is_muted, is_pinned=request.is_pinned, is_locked=request.is_locked, is_blocked=request.is_blocked)
    await _broadcast_conversation(conversation)
    return InboxConversationResponse(**_conversation_payload(conversation, current_user))


@router.patch("/conversations/{conversation_id}/messages/{message_id}", response_model=InboxMessageResponse)
async def update_message(conversation_id: str, message_id: str, request: InboxMessageActionRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    message = inbox_service.update_message(db=db, conversation=conversation, message_public_id=message_id, reaction=request.reaction, is_starred=request.is_starred)
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")
    payload = inbox_service.message_to_dict(message, current_user)
    await inbox_ws_manager.broadcast_to_users(inbox_service.participant_user_ids(conversation), {"event": "inbox_message_updated", "conversation_id": conversation.public_id, "message": payload})
    return InboxMessageResponse(**payload)


@router.delete("/conversations/{conversation_id}/messages/{message_id}")
async def delete_message(conversation_id: str, message_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    deleted = inbox_service.delete_message(db, conversation, message_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Message not found")
    await inbox_ws_manager.broadcast_to_users(inbox_service.participant_user_ids(conversation), {"event": "inbox_message_deleted", "conversation_id": conversation.public_id, "message_id": message_id})
    await _broadcast_conversation(conversation)
    return {"status": "deleted"}


@router.post("/conversations/{conversation_id}/reports", response_model=InboxReportTaskResponse)
async def report_conversation(conversation_id: str, request: InboxReportCreateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    report = inbox_service.create_report(db, conversation, current_user, request.reason)
    await _broadcast_report_task(report)
    return InboxReportTaskResponse(**inbox_service.report_to_dict(report))


@router.get("/reports/tasks", response_model=InboxReportTaskListResponse)
def list_report_tasks(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_cs_or_above(current_user)
    tasks = inbox_service.list_report_tasks(db)
    return InboxReportTaskListResponse(tasks=[InboxReportTaskResponse(**inbox_service.report_to_dict(task)) for task in tasks])


def _get_report(db: Session, report_id: str) -> InboxReport:
    report = db.query(InboxReport).filter(InboxReport.public_id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report task not found")
    return report


@router.post("/reports/tasks/{report_id}/reject", response_model=InboxReportTaskResponse)
async def reject_report_task(report_id: str, request: InboxReportDecisionRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_cs_or_above(current_user)
    report = inbox_service.decide_report(db, _get_report(db, report_id), accepted=False, cs_note=request.cs_note)
    await _broadcast_report_task(report)
    return InboxReportTaskResponse(**inbox_service.report_to_dict(report))


@router.post("/reports/tasks/{report_id}/accept", response_model=InboxReportTaskResponse)
async def accept_report_task(report_id: str, request: InboxReportDecisionRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_cs_or_above(current_user)
    report = inbox_service.decide_report(db, _get_report(db, report_id), accepted=True, cs_note=request.cs_note)
    await _broadcast_report_task(report)
    return InboxReportTaskResponse(**inbox_service.report_to_dict(report))


@router.post("/reports/tasks/{report_id}/monitor-action", response_model=InboxReportTaskResponse)
async def apply_monitor_action(report_id: str, request: InboxMonitorActionRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_monitor_or_above(current_user)
    report = inbox_service.apply_monitor_action(db, _get_report(db, report_id), request.action_label)
    await _broadcast_report_task(report)
    return InboxReportTaskResponse(**inbox_service.report_to_dict(report))
