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
from app.models.user import User


def create_call_session(
    *,
    db: Session,
    actor: User,
    participant_user_ids: list[int],
    call_type: CallSessionType,
    conversation_id: int | None = None,
    room_public_id: str | None = None,
) -> CallSession:
    is_video = call_type in {CallSessionType.DIRECT_VIDEO, CallSessionType.GROUP_VIDEO}
    is_group = call_type in {CallSessionType.GROUP_AUDIO, CallSessionType.GROUP_VIDEO}
    participant_ids = _unique_participant_ids([actor.id, *participant_user_ids])

    session = CallSession(
        call_public_id=f"call_{uuid4().hex}",
        conversation_id=conversation_id,
        room_public_id=room_public_id,
        call_type=call_type,
        status=CallSessionStatus.RINGING,
        started_by_user_id=actor.id,
        is_video_enabled=is_video,
        is_group_call=is_group,
    )
    db.add(session)
    db.flush()

    for user_id in participant_ids:
        db.add(
            CallParticipant(
                call_session_id=session.id,
                user_id=user_id,
                status=(
                    CallParticipantStatus.JOINED
                    if user_id == actor.id
                    else CallParticipantStatus.INVITED
                ),
                joined_at=datetime.utcnow() if user_id == actor.id else None,
                is_camera_enabled=is_video,
            )
        )

    db.commit()
    db.refresh(session)
    return session


def get_call_session(*, db: Session, call_public_id: str) -> CallSession | None:
    return (
        db.query(CallSession)
        .filter(CallSession.call_public_id == call_public_id)
        .first()
    )


def list_user_call_sessions(*, db: Session, user: User, limit: int = 30) -> list[CallSession]:
    session_ids = (
        db.query(CallParticipant.call_session_id)
        .filter(CallParticipant.user_id == user.id)
        .subquery()
    )
    return (
        db.query(CallSession)
        .filter(CallSession.id.in_(session_ids))
        .order_by(CallSession.started_at.desc())
        .limit(max(1, min(limit, 100)))
        .all()
    )


def update_call_participant(
    *,
    db: Session,
    session: CallSession,
    user: User,
    status: CallParticipantStatus | None = None,
    is_muted: bool | None = None,
    is_camera_enabled: bool | None = None,
) -> CallSession:
    participant = _participant(db=db, session_id=session.id, user_id=user.id)
    if participant is None:
        participant = CallParticipant(
            call_session_id=session.id,
            user_id=user.id,
            status=CallParticipantStatus.INVITED,
        )
        db.add(participant)
        db.flush()

    now = datetime.utcnow()
    if status is not None:
        participant.status = status
        if status == CallParticipantStatus.JOINED and participant.joined_at is None:
            participant.joined_at = now
            if session.answered_at is None:
                session.answered_at = now
            if session.status in {CallSessionStatus.RINGING, CallSessionStatus.CONNECTING}:
                session.status = CallSessionStatus.ACTIVE
        if status in {
            CallParticipantStatus.LEFT,
            CallParticipantStatus.DECLINED,
            CallParticipantStatus.MISSED,
            CallParticipantStatus.FAILED,
        }:
            participant.left_at = now
    if is_muted is not None:
        participant.is_muted = is_muted
    if is_camera_enabled is not None:
        participant.is_camera_enabled = is_camera_enabled

    db.add(participant)
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


def end_call_session(
    *,
    db: Session,
    session: CallSession,
    actor: User,
    end_reason: str | None = None,
) -> CallSession:
    now = datetime.utcnow()
    session.status = CallSessionStatus.ENDED
    session.ended_at = now
    session.end_reason = end_reason or "ended"
    if session.answered_at is not None:
        session.duration_seconds = max(0, int((now - session.answered_at).total_seconds()))

    participants = (
        db.query(CallParticipant)
        .filter(CallParticipant.call_session_id == session.id)
        .all()
    )
    for participant in participants:
        if participant.left_at is None:
            participant.left_at = now
        if participant.status in {CallParticipantStatus.INVITED, CallParticipantStatus.RINGING}:
            participant.status = (
                CallParticipantStatus.LEFT
                if participant.user_id == actor.id
                else CallParticipantStatus.MISSED
            )
        db.add(participant)

    db.add(session)
    db.commit()
    db.refresh(session)
    return session


def serialize_call_session(*, db: Session, session: CallSession) -> dict:
    participants = (
        db.query(CallParticipant)
        .filter(CallParticipant.call_session_id == session.id)
        .all()
    )
    users = {
        user.id: user
        for user in db.query(User)
        .filter(User.id.in_([participant.user_id for participant in participants] or [0]))
        .all()
    }
    return {
        "id": session.id,
        "call_public_id": session.call_public_id,
        "conversation_id": session.conversation_id,
        "room_public_id": session.room_public_id,
        "call_type": session.call_type,
        "status": session.status,
        "started_by_user_id": session.started_by_user_id,
        "started_at": session.started_at.isoformat(),
        "answered_at": session.answered_at.isoformat() if session.answered_at else None,
        "ended_at": session.ended_at.isoformat() if session.ended_at else None,
        "duration_seconds": session.duration_seconds,
        "end_reason": session.end_reason,
        "is_video_enabled": session.is_video_enabled,
        "is_group_call": session.is_group_call,
        "participants": [
            _serialize_participant(participant=participant, user=users.get(participant.user_id))
            for participant in participants
        ],
    }


def _serialize_participant(*, participant: CallParticipant, user: User | None) -> dict:
    return {
        "user_id": participant.user_id,
        "public_user_id": user.public_user_id if user else 0,
        "display_name": user.display_name if user else None,
        "avatar_url": user.avatar_url if user else None,
        "status": participant.status,
        "is_muted": participant.is_muted,
        "is_camera_enabled": participant.is_camera_enabled,
    }


def _unique_participant_ids(values: list[int]) -> list[int]:
    seen: set[int] = set()
    output: list[int] = []
    for value in values:
        if value in seen:
            continue
        seen.add(value)
        output.append(value)
    return output


def _participant(*, db: Session, session_id: int, user_id: int) -> CallParticipant | None:
    return (
        db.query(CallParticipant)
        .filter(
            CallParticipant.call_session_id == session_id,
            CallParticipant.user_id == user_id,
        )
        .first()
    )
