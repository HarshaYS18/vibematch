from datetime import datetime, timedelta
from uuid import uuid4

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.inbox import InboxConversation, InboxConversationType, InboxMessage, InboxMessageStatus, InboxMessageType, InboxParticipant, InboxReport, InboxReportStatus
from app.models.user import User

DEFAULT_COLORS = ["#6D5DF6", "#E84C72"]
TEAM_PUBLIC_ID_PREFIX = "team_official"
OFFICIAL_TEAM_NAME = "FunKey Team"
OFFICIAL_TEAM_AVATAR_TEXT = "FK"
OFFICIAL_TEAM_LOGO_ASSET = "assets/branding/funkey_logo.png"


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
        return OFFICIAL_TEAM_NAME
    return user.display_name or user.username or f"User {user.public_user_id}"


def _avatar_text(title: str) -> str:
    parts = [part for part in title.strip().split(" ") if part]
    if not parts:
        return OFFICIAL_TEAM_AVATAR_TEXT
    if len(parts) == 1:
        return parts[0][:2].upper()
    return f"{parts[0][0]}{parts[1][0]}".upper()


def _official_team_metadata(existing: dict | None = None) -> dict:
    metadata = dict(existing or {})
    metadata["colors"] = ["#008069", "#25D366"]
    metadata["avatar_url"] = OFFICIAL_TEAM_LOGO_ASSET
    metadata["avatar_asset"] = OFFICIAL_TEAM_LOGO_ASSET
    metadata["brand_name"] = "FunKey"
    return metadata


def _other_participant_user(conversation: InboxConversation, current_user: User) -> User | None:
    for participant in conversation.participants:
        if participant.user_id != current_user.id:
            return participant.user
    return None


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
        needs_update = (
            conversation.title != OFFICIAL_TEAM_NAME
            or conversation.avatar_text != OFFICIAL_TEAM_AVATAR_TEXT
            or (conversation.metadata_json or {}).get("avatar_url") != OFFICIAL_TEAM_LOGO_ASSET
        )
        if needs_update:
            conversation.title = OFFICIAL_TEAM_NAME
            conversation.avatar_text = OFFICIAL_TEAM_AVATAR_TEXT
            conversation.metadata_json = _official_team_metadata(conversation.metadata_json)
            db.add(conversation)
            db.commit()
            db.refresh(conversation)
        return conversation

    conversation = db.query(InboxConversation).filter(InboxConversation.public_id == user_team_public_id).first()
    if conversation:
        conversation.title = OFFICIAL_TEAM_NAME
        conversation.avatar_text = OFFICIAL_TEAM_AVATAR_TEXT
        conversation.metadata_json = _official_team_metadata(conversation.metadata_json)
        participant = db.query(InboxParticipant).filter(InboxParticipant.conversation_id == conversation.id, InboxParticipant.user_id == user.id).first()
        if participant is None:
            db.add(InboxParticipant(conversation_id=conversation.id, user_id=user.id))
        db.add(conversation)
        db.commit()
        db.refresh(conversation)
        return conversation

    conversation = InboxConversation(
        public_id=user_team_public_id,
        title=OFFICIAL_TEAM_NAME,
        avatar_text=OFFICIAL_TEAM_AVATAR_TEXT,
        conversation_type=InboxConversationType.OFFICIAL.value,
        is_official=True,
        metadata_json=_official_team_metadata(),
    )
    db.add(conversation)

    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        existing = db.query(InboxConversation).filter(InboxConversation.public_id == user_team_public_id).first()
        if existing:
            existing.title = OFFICIAL_TEAM_NAME
            existing.avatar_text = OFFICIAL_TEAM_AVATAR_TEXT
            existing.metadata_json = _official_team_metadata(existing.metadata_json)
            participant = db.query(InboxParticipant).filter(InboxParticipant.conversation_id == existing.id, InboxParticipant.user_id == user.id).first()
            if participant is None:
                db.add(InboxParticipant(conversation_id=existing.id, user_id=user.id))
            db.add(existing)
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
            sender_name=OFFICIAL_TEAM_NAME,
            message_type=InboxMessageType.SYSTEM.value,
            text="Welcome to FunKey Team. Official safety, account, report, and system updates appear here.",
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
    conversation = InboxConversation(
        public_id=_public_id("chat"),
        title=title,
        avatar_text=_avatar_text(title),
        conversation_type=InboxConversationType.CHAT.value,
        metadata_json={"colors": DEFAULT_COLORS, "avatar_url": target_user.avatar_url},
    )
    db.add(conversation)
    db.flush()
    db.add_all([InboxParticipant(conversation_id=conversation.id, user_id=current_user.id), InboxParticipant(conversation_id=conversation.id, user_id=target_user.id)])
    db.commit()
    db.refresh(conversation)
    return conversation


def send_message(
    db: Session,
    conversation: InboxConversation,
    sender: User,
    text: str,
    message_type: str = InboxMessageType.TEXT.value,
    reply_to_text: str | None = None,
    invite_room_name: str | None = None,
    invite_room_id: str | None = None,
    attachment_url: str | None = None,
    metadata: dict | None = None,
) -> InboxMessage:
    safe_text = text.strip()
    message_metadata = dict(metadata or {})
    if message_type == InboxMessageType.ROOM_INVITE.value:
        if invite_room_name:
            message_metadata["invite_room_name"] = invite_room_name
        if invite_room_id:
            message_metadata["invite_room_id"] = invite_room_id
        message_metadata["action"] = "join_room"

    message = InboxMessage(
        public_id=_public_id("msg"),
        conversation_id=conversation.id,
        sender_user_id=sender.id,
        sender_name=_display_name(sender),
        message_type=message_type,
        text=safe_text,
        status=InboxMessageStatus.SENT.value,
        reply_to_text=reply_to_text,
        invite_room_name=invite_room_name,
        attachment_url=attachment_url,
        metadata_json=message_metadata or None,
    )
    conversation.updated_at = datetime.utcnow()
    if message_type == InboxMessageType.ROOM_INVITE.value:
        conversation.conversation_type = InboxConversationType.ROOM_INVITE.value
        conversation.current_room_name = invite_room_name
        conversation.room_public_id = invite_room_id
    db.add(message)
    for participant in conversation.participants:
        if participant.user_id != sender.id:
            participant.unread_count += 1
    db.commit()
    db.refresh(message)
    return message


def send_room_invite_message(
    db: Session,
    sender: User,
    target_user: User,
    room_name: str,
    room_public_id: str | None = None,
    room_language: str | None = None,
    mode_title: str | None = None,
) -> tuple[InboxConversation, InboxMessage]:
    conversation = create_direct_conversation(db, sender, target_user)
    safe_room_name = room_name.strip()
    inviter_name = _display_name(sender)
    message_text = f"{inviter_name} invited you to {safe_room_name}."
    metadata = {
        "action": "join_room",
        "room_name": safe_room_name,
        "room_public_id": room_public_id,
        "invite_room_id": room_public_id,
        "room_language": room_language or "Telugu",
        "mode_title": mode_title or "Open",
        "inviter_user_id": sender.id,
        "inviter_public_user_id": sender.public_user_id,
    }
    message = send_message(
        db=db,
        conversation=conversation,
        sender=sender,
        text=message_text,
        message_type=InboxMessageType.ROOM_INVITE.value,
        invite_room_name=safe_room_name,
        invite_room_id=room_public_id,
        metadata=metadata,
    )
    return conversation, message


def send_team_system_message(db: Session, user: User, text: str) -> InboxMessage:
    conversation = ensure_team_conversation(db, user)
    message = InboxMessage(public_id=_public_id("system"), conversation_id=conversation.id, sender_user_id=None, sender_name=OFFICIAL_TEAM_NAME, message_type=InboxMessageType.SYSTEM.value, text=text, status=InboxMessageStatus.READ.value)
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
    message = db.query(InboxMessage).filter(InboxMessage.public_id == message_public_id, InboxMessage.conversation_id == conversation.id).first()
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


def _chat_streak_participant_user_ids(conversation: InboxConversation) -> set[int]:
    if conversation.is_official:
        return set()
    return {
        participant.user_id
        for participant in conversation.participants
        if participant.user_id is not None
    }


def _chat_streak_day(value: datetime):
    # Current app-local day basis. Later this should use each user's saved timezone.
    return (value + timedelta(hours=5, minutes=30)).date()


def _chat_streak_today():
    return _chat_streak_day(datetime.utcnow())


def _two_way_streak_days(
    conversation: InboxConversation,
    messages: list[InboxMessage],
) -> list:
    participant_ids = _chat_streak_participant_user_ids(conversation)
    if len(participant_ids) != 2:
        return []

    senders_by_day: dict = {}
    for message in messages:
        if message.created_at is None or message.sender_user_id is None:
            continue
        if message.sender_user_id not in participant_ids:
            continue
        day = _chat_streak_day(message.created_at)
        senders_by_day.setdefault(day, set()).add(message.sender_user_id)

    return sorted(
        [day for day, sender_ids in senders_by_day.items() if participant_ids.issubset(sender_ids)],
        reverse=True,
    )


def _chat_streak_count(conversation: InboxConversation, messages: list[InboxMessage]) -> int:
    two_way_days = _two_way_streak_days(conversation, messages)
    if not two_way_days:
        return 0

    today = _chat_streak_today()
    latest_day = two_way_days[0]
    if latest_day < today - timedelta(days=1):
        return 0

    streak = 1
    expected_day = latest_day - timedelta(days=1)
    for day in two_way_days[1:]:
        if day == expected_day:
            streak += 1
            expected_day -= timedelta(days=1)
            continue
        if day < expected_day:
            break
    return streak


def _chat_streak_active_today(conversation: InboxConversation, messages: list[InboxMessage]) -> bool:
    return _chat_streak_today() in _two_way_streak_days(conversation, messages)


def mark_messages_delivered_for_user(
    db: Session,
    conversation: InboxConversation,
    user: User,
) -> list[InboxMessage]:
    changed: list[InboxMessage] = []
    for message in conversation.messages:
        if message.sender_user_id is None:
            continue
        if message.sender_user_id == user.id:
            continue
        if message.status == InboxMessageStatus.SENT.value:
            message.status = InboxMessageStatus.DELIVERED.value
            changed.append(message)
    if changed:
        db.commit()
        for message in changed:
            db.refresh(message)
    return changed


def mark_messages_read_for_user(
    db: Session,
    conversation: InboxConversation,
    user: User,
) -> list[InboxMessage]:
    changed: list[InboxMessage] = []
    latest_message_id: int | None = None

    for message in conversation.messages:
        latest_message_id = message.id
        if message.sender_user_id is None:
            continue
        if message.sender_user_id == user.id:
            continue
        if message.status != InboxMessageStatus.READ.value:
            message.status = InboxMessageStatus.READ.value
            changed.append(message)

    participant = next((item for item in conversation.participants if item.user_id == user.id), None)
    if participant is not None:
        participant.unread_count = 0
        participant.last_read_message_id = latest_message_id

    if changed or participant is not None:
        db.commit()
        for message in changed:
            db.refresh(message)

    return changed




def message_to_dict(message: InboxMessage, current_user: User | None) -> dict:
    metadata = message.metadata_json or {}
    invite_room_id = metadata.get("invite_room_id") or metadata.get("room_public_id") or message.conversation.room_public_id
    media_expired = metadata.get("media_expired") is True
    return {
        "id": message.public_id,
        "sender": message.sender_name,
        "text": message.text,
        "time": _time_label(message.created_at),
        "is_mine": current_user is not None and message.sender_user_id == current_user.id,
        "type": message.message_type,
        "status": message.status,
        "reaction": message.reaction,
        "reply_to_text": message.reply_to_text,
        "is_starred": message.is_starred,
        "is_forwarded": message.is_forwarded,
        "invite_room_name": message.invite_room_name or metadata.get("invite_room_name") or metadata.get("room_name"),
        "invite_room_id": invite_room_id,
        "love_bond_request_id": metadata.get("love_bond_request_id"),
        "love_bond_card_name": metadata.get("love_bond_card_name") or metadata.get("card_name"),
        "love_bond_status": metadata.get("love_bond_status") or metadata.get("status"),
        "attachment_url": message.attachment_url or metadata.get("expired_media_url"),
        "media_expired": media_expired,
        "expired_media_url": metadata.get("expired_media_url"),
        "local_first_allowed": bool(metadata.get("local_first_allowed")) or media_expired,
        "created_at": message.created_at.isoformat() if message.created_at else None,
    }


def conversation_to_dict(conversation: InboxConversation, current_user: User) -> dict:
    participant = next((item for item in conversation.participants if item.user_id == current_user.id), None)
    messages = list(conversation.messages)
    last_message = messages[-1] if messages else None
    metadata = conversation.metadata_json or {}
    other_user = _other_participant_user(conversation, current_user)
    uses_live_user_profile = not conversation.is_official and other_user is not None
    title = _display_name(other_user) if uses_live_user_profile else conversation.title
    avatar_url = other_user.avatar_url if uses_live_user_profile else metadata.get("avatar_url")
    streak_count = _chat_streak_count(conversation, messages)
    streak_active_today = _chat_streak_active_today(conversation, messages)

    return {
        "id": conversation.public_id,
        "title": title,
        "subtitle": last_message.text if last_message else "No messages yet",
        "time": _time_label(conversation.updated_at),
        "avatar_text": _avatar_text(title),
        "avatar_url": avatar_url,
        "type": conversation.conversation_type,
        "unread_count": participant.unread_count if participant else 0,
        "is_online": False,
        "last_seen_text": "offline",
        "colors": metadata.get("colors") or DEFAULT_COLORS,
        "messages": [message_to_dict(message, current_user) for message in messages],
        "current_room_name": conversation.current_room_name,
        "current_room_id": conversation.room_public_id,
        "is_locked_by_backend": conversation.is_locked,
        "is_blocked": conversation.is_blocked,
        "is_muted": conversation.is_muted,
        "is_pinned": conversation.is_pinned,
        "is_archived": conversation.is_archived,
        "chat_streak_count": streak_count,
        "chat_streak_active_today": streak_active_today,
    }


def report_to_dict(report: InboxReport) -> dict:
    return {"id": report.public_id, "reported_conversation_id": report.conversation.public_id, "reported_user_name": report.reported_user_name, "reporter_name": _display_name(report.reporter), "reason": report.reason, "snapshot": report.snapshot_json, "created_at_label": _time_label(report.created_at), "status": report.status, "cs_note": report.cs_note, "monitor_action": report.monitor_action}