from datetime import datetime, timedelta

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.inbox import InboxConversation, InboxMessage, InboxReport
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
    InboxLockOwnerResetByIdentifierRequest,
    InboxLockRecoveryRequestResponse,
    InboxLockRecoveryStartRequest,
    InboxLockRecoveryVerifyRequest,
    InboxLockStartSetupRequest,
    InboxLockStatusResponse,
    InboxLockVerifyRequest,
    InboxLockVerifySetupRequest,
    InboxMessageActionRequest,
    InboxMessagePageResponse,
    InboxMessageResponse,
    InboxReadReceiptResponse,
    InboxMonitorActionRequest,
    InboxReportCreateRequest,
    InboxReportDecisionRequest,
    InboxReportTaskListResponse,
    InboxReportTaskResponse,
    InboxRoomInviteRequest,
    InboxSecretDriftRequest,
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


def _conversation_payload(
    conversation: InboxConversation,
    user: User,
    db: Session | None = None,
    *,
    participant=None,
) -> dict:
    return inbox_service.conversation_to_dict(
        conversation,
        user,
        db=db,
        participant=participant,
    )


def _find_user_by_visible_id(db: Session, value: str) -> User | None:
    clean = (value or "").strip()
    if not clean:
        return None
    numeric = int(clean) if clean.isdigit() else None
    query = db.query(User)
    if numeric is not None:
        return query.filter((User.public_user_id == numeric) | (User.display_custom_id == numeric)).first()
    return None


def _conversation_event(conversation: InboxConversation) -> tuple[list[int], dict]:
    return (
        inbox_service.participant_user_ids(conversation),
        {
            "event": "inbox_conversation_updated",
            "conversation_id": conversation.public_id,
        },
    )


def _message_deliveries(
    conversation: InboxConversation,
    message,
    *,
    event: str = "inbox_message_created",
) -> list[tuple[int, dict]]:
    deliveries: list[tuple[int, dict]] = []
    for participant in conversation.participants:
        if participant.user is None:
            continue
        deliveries.append(
            (
                participant.user_id,
                {
                    "event": event,
                    "conversation_id": conversation.public_id,
                    "message": inbox_service.message_to_dict(
                        message,
                        participant.user,
                    ),
                },
            )
        )
    return deliveries


async def _send_deliveries(deliveries: list[tuple[int, dict]]) -> None:
    for user_id, payload in deliveries:
        await inbox_ws_manager.send_to_user(user_id, payload)


async def _broadcast_report_payload(payload: dict, reporter_user_id: int) -> None:
    await inbox_ws_manager.broadcast_all_staff(
        {"event": "inbox_report_task_updated", "task": payload}
    )
    await inbox_ws_manager.send_to_user(
        reporter_user_id,
        {"event": "inbox_report_status_updated", "task": payload},
    )

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
    try:
        otp = inbox_lock_service.start_setup(db, current_user, request.mobile_number)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
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
    return InboxLockRecoveryRequestResponse(status="submitted", message="Recovery request submitted. Vibe Match Team / CS can verify identity and escalate owner reset if OTP recovery is unavailable.")


@router.post("/lock/owner-reset/{target_user_id}", response_model=InboxLockStatusResponse)
def owner_reset_lock(target_user_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_owner_or_founder(current_user)
    target_user = db.query(User).filter(User.id == target_user_id).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found")
    inbox_lock_service.owner_reset_lock(db, target_user, "1234")
    return InboxLockStatusResponse(**inbox_lock_service.get_status(db, target_user))


@router.post("/lock/owner-reset-by-id", response_model=InboxLockStatusResponse)
def owner_reset_lock_by_visible_id(request: InboxLockOwnerResetByIdentifierRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_owner_or_founder(current_user)
    target_user = _find_user_by_visible_id(db, request.user_identifier)
    if not target_user:
        raise HTTPException(status_code=404, detail="Target user not found by public ID or custom ID")
    inbox_lock_service.owner_reset_lock(db, target_user, "1234")
    return InboxLockStatusResponse(**inbox_lock_service.get_status(db, target_user))


@router.post("/bootstrap")
def bootstrap_inbox(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Explicit idempotent bootstrap; ordinary GETs remain read-only."""

    conversation = inbox_service.ensure_team_conversation(db, current_user)
    return {"status": "ready", "team_conversation_id": conversation.public_id}


@router.get("/conversations", response_model=InboxConversationListResponse)
def list_conversations(
    limit: int = Query(default=40, ge=1, le=100),
    cursor: str | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        rows, next_cursor = inbox_service.list_conversations_page(
            db,
            current_user,
            limit=limit,
            cursor=cursor,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    conversations = [conversation for conversation, _participant in rows]
    message_windows, message_cursors, has_older, statuses = (
        inbox_service.conversation_message_windows(
            db,
            conversations,
            current_user,
            limit=1,
        )
    )
    return InboxConversationListResponse(
        conversations=[
            InboxConversationResponse(
                **inbox_service.conversation_to_dict(
                    conversation,
                    current_user,
                    participant=participant,
                    messages=message_windows.get(conversation.id, []),
                    messages_next_cursor=message_cursors.get(conversation.id),
                    has_older_messages=has_older.get(conversation.id, False),
                    status_overrides=statuses,
                    include_messages=False,
                )
            )
            for conversation, participant in rows
        ],
        next_cursor=next_cursor,
    )


@router.get("/conversations/{conversation_id}", response_model=InboxConversationResponse)
def get_conversation(
    conversation_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(
        db,
        current_user,
        conversation_id,
    )
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    # Read-only by contract. Read receipts and Secret Drift open state have
    # explicit mutation endpoints below.
    return InboxConversationResponse(
        **_conversation_payload(conversation, current_user, db)
    )


@router.get(
    "/conversations/{conversation_id}/messages",
    response_model=InboxMessagePageResponse,
)
def list_conversation_messages(
    conversation_id: str,
    limit: int = Query(default=50, ge=1, le=100),
    before: str | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(
        db,
        current_user,
        conversation_id,
    )
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    try:
        messages, next_cursor, has_more = inbox_service.list_messages_page(
            db,
            conversation,
            current_user,
            limit=limit,
            before=before,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    statuses = inbox_service.message_statuses_for_user(db, messages, current_user)
    return InboxMessagePageResponse(
        messages=[
            InboxMessageResponse(
                **inbox_service.message_to_dict(
                    message,
                    current_user,
                    status_override=statuses.get(message.id),
                )
            )
            for message in messages
        ],
        next_cursor=next_cursor,
        has_more=has_more,
    )


@router.post(
    "/conversations/{conversation_id}/read",
    response_model=InboxReadReceiptResponse,
)
def mark_conversation_read(
    conversation_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(
        db,
        current_user,
        conversation_id,
    )
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    inbox_service.mark_messages_read_for_user(db, conversation, current_user)
    participant = next(
        (item for item in conversation.participants if item.user_id == current_user.id),
        None,
    )
    latest = (
        db.query(InboxMessage)
        .filter(InboxMessage.conversation_id == conversation.id)
        .order_by(InboxMessage.id.desc())
        .first()
    )
    background_tasks.add_task(
        inbox_ws_manager.broadcast_to_users,
        inbox_service.participant_user_ids(conversation),
        {
            "event": "inbox_messages_read",
            "conversation_id": conversation.public_id,
            "reader_user_id": current_user.id,
        },
    )
    return InboxReadReceiptResponse(
        conversation_id=conversation.public_id,
        last_read_message_id=latest.public_id if latest else None,
        unread_count=participant.unread_count if participant else 0,
    )


@router.post("/conversations/{conversation_id}/secret-drift/open")
def open_secret_drift_session(
    conversation_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(
        db,
        current_user,
        conversation_id,
    )
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    inbox_service.mark_secret_drift_open(db, conversation, current_user)
    return {"status": "opened"}


@router.post("/conversations/direct", response_model=InboxConversationResponse)
def create_direct_conversation(request: InboxDirectConversationRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    target = db.query(User).filter(User.id == request.target_user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="Target user not found")
    conversation = inbox_service.create_direct_conversation(db, current_user, target)
    return InboxConversationResponse(**_conversation_payload(conversation, current_user, db))


@router.post("/conversations/{conversation_id}/messages", response_model=InboxMessageResponse)
def send_message(
    conversation_id: str,
    request: InboxSendMessageRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    message = inbox_service.send_message(
        db,
        conversation,
        current_user,
        text=request.text,
        message_type=request.type,
        reply_to_text=request.reply_to_text,
        invite_room_name=request.invite_room_name,
        invite_room_id=request.invite_room_id,
        attachment_url=request.attachment_url,
    )
    message_payload = inbox_service.message_to_dict(message, current_user)
    deliveries = _message_deliveries(conversation, message)
    participant_ids, conversation_event = _conversation_event(conversation)
    background_tasks.add_task(_send_deliveries, deliveries)
    background_tasks.add_task(
        inbox_ws_manager.broadcast_to_users,
        participant_ids,
        conversation_event,
    )
    return InboxMessageResponse(**message_payload)

@router.patch("/conversations/{conversation_id}/messages/{message_id}", response_model=InboxMessageResponse)
def update_message(
    conversation_id: str,
    message_id: str,
    request: InboxMessageActionRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    message = inbox_service.update_message(
        db,
        conversation,
        message_id,
        reaction=request.reaction,
        is_starred=request.is_starred,
    )
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")
    message_payload = inbox_service.message_to_dict(message, current_user)
    deliveries = _message_deliveries(
        conversation,
        message,
        event="inbox_message_updated",
    )
    background_tasks.add_task(_send_deliveries, deliveries)
    return InboxMessageResponse(**message_payload)

@router.delete("/conversations/{conversation_id}/messages/{message_id}")
def delete_message(
    conversation_id: str,
    message_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    deleted = inbox_service.delete_message(db, conversation, message_id, current_user)
    if not deleted:
        raise HTTPException(status_code=404, detail="Message not found")
    participant_ids, conversation_event = _conversation_event(conversation)
    background_tasks.add_task(
        inbox_ws_manager.broadcast_to_users,
        participant_ids,
        {
            "event": "inbox_message_deleted",
            "conversation_id": conversation.public_id,
            "message_id": message_id,
        },
    )
    background_tasks.add_task(
        inbox_ws_manager.broadcast_to_users,
        participant_ids,
        conversation_event,
    )
    return {"status": "deleted"}

@router.patch("/conversations/{conversation_id}/secret-drift", response_model=InboxConversationResponse)
def update_secret_drift(
    conversation_id: str,
    request: InboxSecretDriftRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    if conversation.is_official:
        raise HTTPException(status_code=403, detail="Secret Drift is not available for official chats.")
    conversation = inbox_service.set_secret_drift_mode(
        db=db,
        conversation=conversation,
        enabled=request.enabled,
        started_by_user_id=current_user.id,
    )
    participant_ids, conversation_event = _conversation_event(conversation)
    background_tasks.add_task(
        inbox_ws_manager.broadcast_to_users,
        participant_ids,
        conversation_event,
    )
    if not request.enabled:
        background_tasks.add_task(
            inbox_ws_manager.broadcast_to_users,
            participant_ids,
            {
                "event": "inbox_secret_drift_cleared",
                "conversation_id": conversation.public_id,
            },
        )
    return InboxConversationResponse(**_conversation_payload(conversation, current_user, db))

@router.post("/conversations/{conversation_id}/secret-drift/close")
def close_secret_drift_session(
    conversation_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    cleared = inbox_service.mark_secret_drift_closed_and_clear(
        db,
        conversation,
        current_user,
    )
    participant_ids, conversation_event = _conversation_event(conversation)
    background_tasks.add_task(
        inbox_ws_manager.broadcast_to_users,
        participant_ids,
        conversation_event,
    )
    if cleared:
        background_tasks.add_task(
            inbox_ws_manager.broadcast_to_users,
            participant_ids,
            {
                "event": "inbox_secret_drift_cleared",
                "conversation_id": conversation.public_id,
            },
        )
    return {"status": "closed", "cleared": cleared}

@router.patch("/conversations/{conversation_id}/state", response_model=InboxConversationResponse)
def update_conversation_state(conversation_id: str, request: InboxConversationStateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    conversation = inbox_service.update_conversation_state(
        db,
        conversation,
        current_user,
        is_muted=request.is_muted,
        is_pinned=request.is_pinned,
        is_archived=request.is_archived,
        is_locked=request.is_locked,
        is_blocked=request.is_blocked,
    )
    return InboxConversationResponse(**_conversation_payload(conversation, current_user, db))


@router.post("/conversations/{conversation_id}/reports", response_model=InboxReportTaskResponse)
def create_report(
    conversation_id: str,
    request: InboxReportCreateRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversation = inbox_service.get_conversation_for_user(db, current_user, conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    report = inbox_service.create_report(db, conversation, current_user, request.reason)
    report_payload = inbox_service.report_to_dict(report)
    background_tasks.add_task(
        _broadcast_report_payload,
        report_payload,
        report.reporter_user_id,
    )
    return InboxReportTaskResponse(**report_payload)

@router.get("/reports/tasks", response_model=InboxReportTaskListResponse)
def list_report_tasks(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_cs_or_above(current_user)
    reports = inbox_service.list_report_tasks(db)
    return InboxReportTaskListResponse(tasks=[InboxReportTaskResponse(**inbox_service.report_to_dict(report)) for report in reports])


@router.post("/reports/tasks/{report_id}/reject", response_model=InboxReportTaskResponse)
def reject_report(
    report_id: str,
    request: InboxReportDecisionRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_cs_or_above(current_user)
    report = inbox_service.decide_report(db, report_id, "rejected_by_cs", cs_note=request.cs_note)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    report_payload = inbox_service.report_to_dict(report)
    background_tasks.add_task(
        _broadcast_report_payload,
        report_payload,
        report.reporter_user_id,
    )
    return InboxReportTaskResponse(**report_payload)

@router.post("/reports/tasks/{report_id}/accept", response_model=InboxReportTaskResponse)
def accept_report(
    report_id: str,
    request: InboxReportDecisionRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_cs_or_above(current_user)
    report = inbox_service.decide_report(db, report_id, "accepted_escalated", cs_note=request.cs_note)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    report_payload = inbox_service.report_to_dict(report)
    background_tasks.add_task(
        _broadcast_report_payload,
        report_payload,
        report.reporter_user_id,
    )
    return InboxReportTaskResponse(**report_payload)

@router.post("/reports/tasks/{report_id}/monitor-action", response_model=InboxReportTaskResponse)
def monitor_action(
    report_id: str,
    request: InboxMonitorActionRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_monitor_or_above(current_user)
    report = inbox_service.apply_monitor_action(db, report_id, request.action_label)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    report_payload = inbox_service.report_to_dict(report)
    background_tasks.add_task(
        _broadcast_report_payload,
        report_payload,
        report.reporter_user_id,
    )
    return InboxReportTaskResponse(**report_payload)
