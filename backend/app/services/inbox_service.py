from datetime import datetime
from uuid import uuid4

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.inbox import InboxConversation, InboxConversationType, InboxMessage, InboxMessageStatus, InboxMessageType, InboxParticipant, InboxReport, InboxReportStatus
from app.models.user import User

DEFAULT_COLORS = ["#6D5DF6", "#E84C72"]
TEAM_PUBLIC_ID_PREFIX = "team_official"


def _public_id(prefix: str) -> str:
    return f"{prefix}_{uuid4().hex[:20]}"


def _team_public_id(user: User) -> str:
    return f"{TEAM_PUBLIC_ID_PREFIX}_{user.id}"


def _time_label(value: datetime | None) -> str:
    if value is None:
        return "Now"
    diff = datetime.utcnow() - value
    if diff.total_seconds() < 60:
        return "Now"
    if diff.total_seconds() < 3600:
        return f"{int(diff.total_seconds() // 60)}m"
    if diff.total_seconds() < 86400:
        return f"{int(diff.total_seconds() // 3600)}h"
    return f"{diff.days}d"


def _display_name(user: User | None) -> str:
    if user is None:
        return "Vibe Match Team"
    return user.display_name or user.username or f"User {user.public_user_id}"


def _avatar_text(title: str) -> str:
    parts = [part for part in title.strip().split(" ") if part]
    if not parts:
        return "VM"
    if len(parts) == 1:
        return parts[0][:2].upper()
    return f"{parts[0][0]}{parts[1][0]}".upper()


def participant_user_ids(conversation: InboxConversation) -> list[int]:
    return [participant.user_id for participant in conversation.participants]


def ensure_team_conversation(db: Session, user: User) -> InboxConversation:
    user_team_public_id = _team_public_id(user)

    conversation = (
        db.query(InboxConversation)
        .join(InboxParticipant)
        .filter(
            InboxConversation.conversation_type == InboxConversationType.OFFICIAL.value,
            InboxConversation.is_official.is_(True),
            InboxParticipant.user_id == user.id,
        )
        .first()
    )
    if conversation:
        return conversation

    conversation = db.query(InboxConversation).filter(InboxConversation.public_id == user_team_public_id).first()
    if conversation:
        participant = db.query(InboxParticipant).filter(InboxParticipant.conversation_id == conversation.id, InboxParticipant.user_id == user.id).first()
        if participant is None:
            db.add(InboxParticipant(conversation_id=conversation.id, user_id=user.id))
            db.commit()
            db.refresh(conversation)
        return conversation

    conversation = InboxConversation(
        public_id=user_team_public_id,
        title="Vibe Match Team",
        avatar_text="VM",
        conversation_type=InboxConversationType.OFFICIAL.value,
        is_official=True,
        metadata_json={"colors": ["#251538", "#C99A3B"]},
    )
    db.add(conversation)

    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        existing = db.query(InboxConversation).filter(InboxConversation.public_id == user_team_public_id).first()
        if existing:
            participant = db.query(InboxParticipant).filter(InboxParticipant.conversation_id == existing.id, InboxParticipant.user_id == user.id).first()
            if participant is None:
                db.add(InboxParticipant(conversation_id=existing.id, user_id=user.id))
                db.commit()
                db.refresh(existing)
            return existing
        raise

    db.add(InboxParticipant(conversation_id=conversation.id, user_id=user.id))
    db.add(
        InboxMessage(
            public_id=_public_id("msg"),
            conversation_id=conversation.id,
            sender_user_id=None,
            sender_name="Vibe Match Team",
            message_type=InboxMessageType.SYSTEM.value,
            text="Welcome to Vibe Match Team. Official safety, account, report, and system updates appear here.",
            status=InboxMessageStatus.READ.value,
        )
    )
    db.commit()
    db.refresh(conversation)
    return conversation


def list_conversations(db: Session, user: User) -> list[InboxConversation]:
    ensure_team_conversation(db, user)
    return db.query(InboxConversation).join(InboxParticipant).filter(InboxParticipant.user_id == user.id, InboxParticipant.is_deleted_for_user.is_(False)).order_by(InboxConversation.is_pinned.desc(), InboxConversation.updated_at.desc()).all()


def get_conversation_for_user(db: Session, user: User, conversation_public_id: str) -> InboxConversation | None:
    return db.query(InboxConversation).join(InboxParticipant).filter(InboxConversation.public_id == conversation_public_id, InboxParticipant.user_id == user.id).first()


def create_direct_conversation(db: Session, current_user: User, target_user: User) -> InboxConversation:
    current_conversations = db.query(InboxConversation).join(InboxParticipant).filter(InboxConversation.conversation_type == InboxConversationType.CHAT.value, InboxParticipant.user_id == current_user.id).all()
    for conversation in current_conversations:
        ids = set(participant_user_ids(conversation))
        if current_user.id in ids and target_user.id in ids:
            return conversation

    title = _display_name(target_user)
    conversation = InboxConversation(public_id=_public_id("chat"), title=title, avatar_text=_avatar_text(title), conversation_type=InboxConversationType.CHAT.value, metadata_json={"colors": DEFAULT_COLORS})
    db.add(conversation)
    db.flush()
    db.add_all([InboxParticipant(conversation_id=conversation.id, user_id=current_user.id), InboxParticipant(conversation_id=conversation.id, user_id=target_user.id)])
    db.commit()
    db.refresh(conversation)
    return conversation


def send_message(db: Session, conversation: InboxConversation, sender: User, text: str, message_type: str = InboxMessageType.TEXT.value, reply_to_text: str | None = None, invite_room_name: str | None = None, attachment_url: str | None = None) -> InboxMessage:
    message = InboxMessage(public_id=_public_id("msg"), conversation_id=conversation.id, sender_user_id=sender.id, sender_name=_display_name(sender), message_type=message_type, text=text.strip(), status=InboxMessageStatus.SENT.value, reply_to_text=reply_to_text, invite_room_name=invite_room_name, attachment_url=attachment_url)
    conversation.updated_at = datetime.utcnow()
    db.add(message)
    for participant in conversation.participants:
        if participant.user_id != sender.id:
            participant.unread_count += 1
    db.commit()
    db.refresh(message)
    return message


def send_team_system_message(db: Session, user: User, text: str) -> InboxMessage:
    conversation = ensure_team_conversation(db, user)
    message = InboxMessage(public_id=_public_id("system"), conversation_id=conversation.id, sender_user_id=None, sender_name="Vibe Match Team", message_type=InboxMessageType.SYSTEM.value, text=text, status=InboxMessageStatus.READ.value)
    conversation.updated_at = datetime.utcnow()
    db.add(message)
    db.commit()
    db.refresh(message)
    return message


def update_conversation_state(db: Session, conversation: InboxConversation, is_muted: bool | None = None, is_pinned: bool | None = None, is_locked: bool | None = None, is_blocked: bool | None = None) -> InboxConversation:
    if is_muted is not None:
        conversation.is_muted = is_muted
    if is_pinned is not None:
        conversation.is_pinned = is_pinned
    if is_locked is not None and not conversation.is_official:
        conversation.is_locked = is_locked
    if is_blocked is not None and not conversation.is_official:
        conversation.is_blocked = is_blocked
    db.commit()
    db.refresh(conversation)
    return conversation


def update_message(db: Session, conversation: InboxConversation, message_public_id: str, reaction: str | None = None, is_starred: bool | None = None) -> InboxMessage | None:
    message = db.query(InboxMessage).filter(InboxMessage.public_id == message_public_id, InboxMessage.conversation_id == conversation.id).first()
    if not message:
        return None
    if reaction is not None:
        message.reaction = reaction
    if is_starred is not None:
        message.is_starred = is_starred
    db.commit()
    db.refresh(message)
    return message


def delete_message(db: Session, conversation: InboxConversation, message_public_id: str) -> bool:
    message = db.query(InboxMessage).filter(InboxMessage.public_id == message_public_id, message.conversation_id == conversation.id).first()
    if not message:
        return False
    db.delete(message)
    db.commit()
    return True


def create_report(db: Session, conversation: InboxConversation, reporter: User, reason: str) -> InboxReport:
    snapshot = [message_to_dict(message, reporter) for message in conversation.messages[-30:]]
    report = InboxReport(public_id=_public_id("report"), conversation_id=conversation.id, reporter_user_id=reporter.id, reported_user_name=conversation.title, reason=reason.strip(), snapshot_json=snapshot, status=InboxReportStatus.PENDING_CS_REVIEW.value)
    db.add(report)
    db.commit()
    db.refresh(report)
    send_team_system_message(db, reporter, "Report submitted. CS will review the conversation snapshot and escalate if action is needed.")
    return report


def list_report_tasks(db: Session) -> list[InboxReport]:
    return db.query(InboxReport).order_by(InboxReport.created_at.desc()).all()


def decide_report(db: Session, report: InboxReport, accepted: bool, cs_note: str | None = None) -> InboxReport:
    report.cs_note = cs_note
    if accepted:
        report.status = InboxReportStatus.ACCEPTED_ESCALATED.value
        report.monitor_action = "Pending Monitor action"
        send_team_system_message(db, report.reporter, f"Report successful. {report.reported_user_name} has been sent to Monitor team for punishment review.")
    else:
        report.status = InboxReportStatus.REJECTED_BY_CS.value
        send_team_system_message(db, report.reporter, f"Report failed. CS reviewed your report about {report.reported_user_name}, but there was not enough evidence to punish the user.")
    db.commit()
    db.refresh(report)
    return report


def apply_monitor_action(db: Session, report: InboxReport, action_label: str) -> InboxReport:
    report.status = InboxReportStatus.MONITOR_ACTION_TAKEN.value
    report.monitor_action = action_label
    send_team_system_message(db, report.reporter, f"Report successful. {report.reported_user_name} has been punished by Monitor team: {action_label}.")
    db.commit()
    db.refresh(report)
    return report


def message_to_dict(message: InboxMessage, current_user: User | None) -> dict:
    return {"id": message.public_id, "sender": message.sender_name, "text": message.text, "time": _time_label(message.created_at), "is_mine": current_user is not None and message.sender_user_id == current_user.id, "type": message.message_type, "status": message.status, "reaction": message.reaction, "reply_to_text": message.reply_to_text, "is_starred": message.is_starred, "is_forwarded": message.is_forwarded, "invite_room_name": message.invite_room_name, "created_at": message.created_at.isoformat() if message.created_at else None}


def conversation_to_dict(conversation: InboxConversation, current_user: User) -> dict:
    participant = next((item for item in conversation.participants if item.user_id == current_user.id), None)
    messages = list(conversation.messages)
    last_message = messages[-1] if messages else None
    metadata = conversation.metadata_json or {}
    return {"id": conversation.public_id, "title": conversation.title, "subtitle": last_message.text if last_message else "No messages yet", "time": _time_label(conversation.updated_at), "avatar_text": conversation.avatar_text, "type": conversation.conversation_type, "unread_count": participant.unread_count if participant else 0, "is_online": False, "last_seen_text": "offline", "colors": metadata.get("colors") or DEFAULT_COLORS, "messages": [message_to_dict(message, current_user) for message in messages], "current_room_name": conversation.current_room_name, "is_locked_by_backend": conversation.is_locked, "is_blocked": conversation.is_blocked, "is_muted": conversation.is_muted, "is_pinned": conversation.is_pinned, "is_archived": conversation.is_archived}


def report_to_dict(report: InboxReport) -> dict:
    return {"id": report.public_id, "reported_conversation_id": report.conversation.public_id, "reported_user_name": report.reported_user_name, "reporter_name": _display_name(report.reporter), "reason": report.reason, "snapshot": report.snapshot_json, "created_at_label": _time_label(report.created_at), "status": report.status, "cs_note": report.cs_note, "monitor_action": report.monitor_action}
