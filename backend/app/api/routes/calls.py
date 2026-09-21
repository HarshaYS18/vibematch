from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.call_session import (
    CallParticipantUpdateRequest,
    CallSessionCreateRequest,
    CallSessionEndRequest,
    CallSessionResponse,
)
from app.services import call_session_service

router = APIRouter(prefix="/calls", tags=["Calls"])


@router.post("", response_model=CallSessionResponse)
def create_call_session(
    request: CallSessionCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    session = call_session_service.create_call_session(
        db=db,
        actor=current_user,
        participant_user_ids=request.participant_user_ids,
        call_type=request.call_type,
        conversation_id=request.conversation_id,
        room_public_id=request.room_public_id,
    )
    return call_session_service.serialize_call_session(db=db, session=session)


@router.get("", response_model=list[CallSessionResponse])
def list_my_call_sessions(
    limit: int = 30,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    sessions = call_session_service.list_user_call_sessions(
        db=db,
        user=current_user,
        limit=limit,
    )
    return [
        call_session_service.serialize_call_session(db=db, session=session)
        for session in sessions
    ]


@router.get("/{call_public_id}", response_model=CallSessionResponse)
def get_call_session(
    call_public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    session = call_session_service.get_call_session(db=db, call_public_id=call_public_id)
    if session is None:
        raise HTTPException(status_code=404, detail="Call session not found.")
    call_session_service.require_call_participant(db=db, session=session, user=current_user)
    return call_session_service.serialize_call_session(db=db, session=session)


@router.patch("/{call_public_id}/participant", response_model=CallSessionResponse)
def update_my_call_participant(
    call_public_id: str,
    request: CallParticipantUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    session = call_session_service.get_call_session(db=db, call_public_id=call_public_id)
    if session is None:
        raise HTTPException(status_code=404, detail="Call session not found.")
    updated = call_session_service.update_call_participant(
        db=db,
        session=session,
        user=current_user,
        status=request.status,
        is_muted=request.is_muted,
        is_camera_enabled=request.is_camera_enabled,
    )
    return call_session_service.serialize_call_session(db=db, session=updated)


@router.post("/{call_public_id}/end", response_model=CallSessionResponse)
def end_call_session(
    call_public_id: str,
    request: CallSessionEndRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    session = call_session_service.get_call_session(db=db, call_public_id=call_public_id)
    if session is None:
        raise HTTPException(status_code=404, detail="Call session not found.")
    updated = call_session_service.end_call_session(
        db=db,
        session=session,
        actor=current_user,
        end_reason=request.end_reason,
    )
    return call_session_service.serialize_call_session(db=db, session=updated)
