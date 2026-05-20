from datetime import datetime
from uuid import uuid4

from sqlalchemy.orm import Session

from app.models.call_session import (
    CallParticipant,
    CallParticipantStatus,
    CallSession,
    CallSessionStatus,
    CallSessionType,
)
from app.models.inbox import InboxConversation, InboxMessage, InboxMessageStatus, InboxMessageType
from app.models.user import User
from app.services import inbox_service


def _public_id() -> str:
    return f"call_{uuid4().hex[:22]}"


def _now() -> datetime:
    return datetime.utcnow()


def _display_name(user: User | None) -> str:
    if user is None:
        return "User"
    return user.display_name or user.username or f"User {user.public_user_id}"


def _call_type(is_video: bool) -> CallSessionType:
    return CallSessionType.DIRECT_VIDEO if is_video else CallSessionType.DIRECT_AUDIO


def _is_video(call: CallSession) -> bool:
    return call.call_type in {CallSessionType.DIRECT_VIDEO, CallSessionType.GROUP_VIDEO}


def _active_call_statuses() -> set[CallSessionStatus]:
    return {
        CallSessionStatus.RINGING,
        CallSessionStatus.CONNECTING,
        CallSessionStatus.ACTIVE,
    }


def _status_for_response(status: CallSessionStatus) -> str:
    return {
        CallSessionStatus.RINGING: "ringing",
        CallSessionStatus.CONNECTING: "accepted",
        CallSessionStatus.ACTIVE: "accepted",
        CallSessionStatus.DECLINED: "declined",
        CallSessionStatus.MISSED: "missed",
        CallSessionStatus.ENDED: "ended",
        CallSessionStatus.FAILED: "failed",
        CallSessionStatus.CANCELLED: "cancelled",
    }.get(status, "failed")


def participant_ids(conversation: InboxConversation) -> list[int]:
    return [participant.user_id for participant in conversation.participants]


def peer_ids(conversation: InboxConversation, current_user: User) -> list[int]:
    return [user_id for user_id in participant_ids(conversation) if user_id != current_user.id]


def call_to_dict(call: CallSession) -> dict:
    return {
        "id": call.call_public_id,
        "conversation_id": call.conversation.public_id if call.conversation else "",
        "call_type": "video" if _is_video(call) else "audio",
        "status": _status_for_response(call.status),
        "started_by_user_id": call.started_by_user_id,
        "peer_user_ids": [participant.user_id for participant in call.participants] if hasattr(call, "participants") else [],
        "started_at": call.started_at,
        "answered_at": call.answered_at,
        "ended_at": call.ended_at,
        "duration_seconds": call.duration_seconds,
        "end_reason": call.end_reason,
        "mediasoup_room_id": call.room_public_id,
    }


def start_call(db: Session, conversation: InboxConversation, caller: User, call_type: str) -> CallSession:
    existing = (
        db.query(CallSession)
        .filter(
            CallSession.conversation_id == conversation.id,
            CallSession.status.in_(_active_call_statuses()),
        )
        .order_by(CallSession.started_at.desc())
        .first()
    )
    if existing is not None:
        raise ValueError("A call is already active in this conversation.")

    is_video = call_type == "video"
    peers = peer_ids(conversation, caller)
    if not peers:
        raise ValueError("Cannot start a call without another participant.")

    call = CallSession(
        call_public_id=_public_id(),
        conversation_id=conversation.id,
        call_type=_call_type(is_video),
        status=CallSessionStatus.RINGING,
        started_by_user_id=caller.id,
        started_at=_now(),
        is_video_enabled=is_video,
        is_group_call=len(peers) > 1,
        room_public_id=f"call_room_{uuid4().hex[:18]}",
    )
    db.add(call)
    db.flush()

    db.add(CallParticipant(call_session_id=call.id, user_id=caller.id, status=CallParticipantStatus.JOINED, invited_at=call.started_at, joined_at=call.started_at, is_camera_enabled=is_video))
    for peer_id in peers:
        db.add(CallParticipant(call_session_id=call.id, user_id=peer_id, status=CallParticipantStatus.RINGING, invited_at=call.started_at, is_camera_enabled=is_video))

    conversation.updated_at = _now()
    db.commit()
    db.refresh(call)
    return call


def get_call_for_conversation(db: Session, conversation: InboxConversation, call_public_id: str) -> CallSession | None:
    return db.query(CallSession).filter(CallSession.call_public_id == call_public_id, CallSession.conversation_id == conversation.id).first()


def accept_call(db: Session, call: CallSession, user: User) -> CallSession:
    if call.status not in {CallSessionStatus.RINGING, CallSessionStatus.CONNECTING}:
        raise ValueError("Call is no longer ringing.")
    participant = db.query(CallParticipant).filter(CallParticipant.call_session_id == call.id, CallParticipant.user_id == user.id).first()
    if participant is None:
        raise ValueError("You are not invited to this call.")
    participant.status = CallParticipantStatus.JOINED
    participant.joined_at = _now()
    call.status = CallSessionStatus.ACTIVE
    call.answered_at = call.answered_at or participant.joined_at
    db.add(participant)
    db.add(call)
    db.commit()
    db.refresh(call)
    return call


def decline_call(db: Session, call: CallSession, user: User, reason: str | None = None) -> tuple[CallSession, InboxMessage]:
    participant = db.query(CallParticipant).filter(CallParticipant.call_session_id == call.id, CallParticipant.user_id == user.id).first()
    if participant is None:
        raise ValueError("You are not invited to this call.")
    participant.status = CallParticipantStatus.DECLINED
    participant.left_at = _now()
    call.status = CallSessionStatus.DECLINED
    call.ended_at = participant.left_at
    call.end_reason = reason or "declined"
    db.add(participant)
    db.add(call)
    db.commit()
    db.refresh(call)
    message = create_call_summary_message(db, call, user, status="declined")
    return call, message


def end_call(db: Session, call: CallSession, user: User, reason: str | None = None) -> tuple[CallSession, InboxMessage]:
    ended = _now()
    call.ended_at = ended
    call.end_reason = reason or "ended"
    if call.status == CallSessionStatus.RINGING and call.started_by_user_id != user.id:
        call.status = CallSessionStatus.MISSED
    elif call.status == CallSessionStatus.RINGING and call.started_by_user_id == user.id:
        call.status = CallSessionStatus.CANCELLED
    else:
        call.status = CallSessionStatus.ENDED
    if call.answered_at is not None:
        call.duration_seconds = max(0, int((ended - call.answered_at).total_seconds()))

    for participant in db.query(CallParticipant).filter(CallParticipant.call_session_id == call.id).all():
        if participant.status == CallParticipantStatus.RINGING:
            participant.status = CallParticipantStatus.MISSED if call.status == CallSessionStatus.MISSED else CallParticipantStatus.LEFT
        elif participant.status == CallParticipantStatus.JOINED:
            participant.status = CallParticipantStatus.LEFT
        participant.left_at = participant.left_at or ended
        db.add(participant)

    db.add(call)
    db.commit()
    db.refresh(call)
    message = create_call_summary_message(db, call, user, status=_status_for_response(call.status))
    return call, message


def create_call_summary_message(db: Session, call: CallSession, actor: User, status: str) -> InboxMessage:
    conversation = call.conversation
    if conversation is None:
        raise ValueError("Call conversation is missing.")
    kind = "video" if _is_video(call) else "voice"
    actor_name = _display_name(actor)
    duration = call.duration_seconds or 0
    if status == "missed":
        text = f"Missed {kind} call from {actor_name}."
    elif status == "declined":
        text = f"{actor_name} declined the {kind} call."
    elif status == "cancelled":
        text = f"{actor_name} cancelled the {kind} call."
    elif status == "ended" and duration > 0:
        text = f"{kind.title()} call ended • {_format_duration(duration)}."
    else:
        text = f"{kind.title()} call ended."

    message = InboxMessage(
        public_id=f"call_msg_{uuid4().hex[:18]}",
        conversation_id=conversation.id,
        sender_user_id=actor.id,
        sender_name=actor_name,
        message_type=InboxMessageType.CALL_LOG.value,
        text=text,
        status=InboxMessageStatus.SENT.value,
        metadata_json={
            "call_id": call.call_public_id,
            "call_type": kind,
            "call_status": status,
            "duration_seconds": call.duration_seconds,
            "mediasoup_room_id": call.room_public_id,
        },
    )
    conversation.updated_at = _now()
    db.add(message)
    for participant in conversation.participants:
        if participant.user_id != actor.id:
            participant.unread_count += 1
    db.commit()
    db.refresh(message)
    return message


def _format_duration(seconds: int) -> str:
    minutes = seconds // 60
    remainder = seconds % 60
    if minutes < 60:
        return f"{minutes}:{remainder:02d}"
    hours = minutes // 60
    minute_remainder = minutes % 60
    return f"{hours}:{minute_remainder:02d}:{remainder:02d}"
