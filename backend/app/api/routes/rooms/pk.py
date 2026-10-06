from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.realtime.connection_manager import room_realtime_connections
from app.schemas.rooms.pk import (
    RoomPkChallengeRequest,
    RoomPkDecisionRequest,
    RoomPkMatchResponse,
    RoomPkRoomSummary,
)
from app.services.rooms import room_pk_service


router = APIRouter(prefix="/rooms/{room_public_id}/pk", tags=["Room PK"])


def _response(db: Session, match) -> RoomPkMatchResponse:
    payload = room_pk_service.match_payload(db, match)
    return RoomPkMatchResponse(
        match_id=payload["match_id"],
        status=payload["status"],
        challenger=RoomPkRoomSummary(**payload["challenger"]),
        opponent=RoomPkRoomSummary(**payload["opponent"]),
        duration_seconds=payload["duration_seconds"],
        challenger_score=payload["challenger_score"],
        opponent_score=payload["opponent_score"],
        winner_room_id=payload["winner_room_id"],
        challenge_expires_at=payload["challenge_expires_at"],
        started_at=payload["started_at"],
        ends_at=payload["ends_at"],
        finished_at=payload["finished_at"],
        finished_reason=payload["finished_reason"],
    )


async def _broadcast(db: Session, match, event_type: str) -> None:
    payload = room_pk_service.match_payload(db, match)
    challenger_room_id, opponent_room_id = room_pk_service.affected_room_ids(db, match)
    event = {
        "type": "room_pk/state",
        "payload": {
            "event_type": event_type,
            "pk": payload,
        },
    }
    await room_realtime_connections.broadcast_room(challenger_room_id, event)
    await room_realtime_connections.broadcast_room(opponent_room_id, event)


@router.get("/candidates", response_model=list[RoomPkRoomSummary])
def list_pk_candidates(
    room_public_id: str,
    limit: int = Query(default=30, ge=1, le=50),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return [
        RoomPkRoomSummary(**item)
        for item in room_pk_service.list_candidates(
            db,
            room_public_id,
            current_user,
            limit=limit,
        )
    ]


@router.get("/current", response_model=RoomPkMatchResponse | None)
async def get_current_pk(
    room_public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    match = room_pk_service.current_match(
        db,
        room_public_id,
        actor=current_user,
    )
    if match is None:
        return None
    return _response(db, match)


@router.post("/challenge", response_model=RoomPkMatchResponse)
async def create_pk_challenge(
    room_public_id: str,
    payload: RoomPkChallengeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    match = room_pk_service.create_challenge(
        db,
        room_public_id=room_public_id,
        opponent_room_public_id=payload.opponent_room_id,
        duration_seconds=payload.duration_seconds,
        actor=current_user,
    )
    await _broadcast(db, match, "challenge_created")
    return _response(db, match)


@router.post("/{match_public_id}/decision", response_model=RoomPkMatchResponse)
async def decide_pk_challenge(
    room_public_id: str,
    match_public_id: str,
    payload: RoomPkDecisionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    match = room_pk_service.decide_challenge(
        db,
        room_public_id=room_public_id,
        match_public_id=match_public_id,
        actor=current_user,
        accept=payload.accept,
    )
    await _broadcast(
        db,
        match,
        "challenge_accepted" if payload.accept else "challenge_declined",
    )
    return _response(db, match)


@router.post("/{match_public_id}/cancel", response_model=RoomPkMatchResponse)
async def cancel_pk(
    room_public_id: str,
    match_public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    match = room_pk_service.cancel_match(
        db,
        room_public_id=room_public_id,
        match_public_id=match_public_id,
        actor=current_user,
    )
    await _broadcast(db, match, "cancelled")
    return _response(db, match)


@router.post("/{match_public_id}/finish", response_model=RoomPkMatchResponse)
async def finish_pk(
    room_public_id: str,
    match_public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    match = room_pk_service.finish_match(
        db,
        room_public_id=room_public_id,
        match_public_id=match_public_id,
        actor=current_user,
    )
    await _broadcast(db, match, "finished")
    return _response(db, match)
