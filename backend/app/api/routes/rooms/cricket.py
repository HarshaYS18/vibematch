from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.routes.users import get_current_user
from app.models.user import User
from app.schemas.rooms.cricket import (
    CricketBallEventRequest,
    CricketMatchCreateRequest,
    CricketMatchLineupRequest,
    CricketMatchResponse,
    CricketMatchScorePatchRequest,
    CricketMatchTossRequest,
    CricketTournamentCreateRequest,
    CricketTournamentDeleteResponse,
    CricketTournamentResponse,
    CricketTournamentUpdateRequest,
)
from app.services import room_control_service_client


router = APIRouter(prefix="/rooms/{room_public_id}/cricket", tags=["Room Cricket"])


def _operation(
    *,
    current_user: User,
    room_public_id: str,
    operation: str,
    resource_id: int | None = None,
    payload: dict[str, Any] | None = None,
    offset: int = 0,
    limit: int = 50,
) -> Any:
    try:
        return room_control_service_client.execute_cricket_operation(
            user_id=int(current_user.id),
            room_public_id=room_public_id,
            operation=operation,
            resource_id=resource_id,
            payload=payload,
            offset=offset,
            limit=limit,
        )
    except room_control_service_client.RoomControlServiceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc
    except room_control_service_client.RoomControlServiceUnavailable as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Room Control service unavailable",
        ) from exc


@router.post(
    "/tournaments",
    response_model=CricketTournamentResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_room_cricket_tournament(
    room_public_id: str,
    payload: CricketTournamentCreateRequest,
    current_user: User = Depends(get_current_user),
):
    return _operation(
        current_user=current_user,
        room_public_id=room_public_id,
        operation="create_tournament",
        payload=payload.model_dump(),
    )


@router.get("/tournaments", response_model=list[CricketTournamentResponse])
def list_room_cricket_tournaments(
    room_public_id: str,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
):
    return _operation(
        current_user=current_user,
        room_public_id=room_public_id,
        operation="list_tournaments",
        offset=offset,
        limit=limit,
    )


@router.get("/tournaments/{tournament_id}", response_model=CricketTournamentResponse)
def get_room_cricket_tournament(
    room_public_id: str,
    tournament_id: int,
    current_user: User = Depends(get_current_user),
):
    return _operation(
        current_user=current_user,
        room_public_id=room_public_id,
        operation="get_tournament",
        resource_id=tournament_id,
    )


@router.patch("/tournaments/{tournament_id}", response_model=CricketTournamentResponse)
def update_room_cricket_tournament(
    room_public_id: str,
    tournament_id: int,
    payload: CricketTournamentUpdateRequest,
    current_user: User = Depends(get_current_user),
):
    return _operation(
        current_user=current_user,
        room_public_id=room_public_id,
        operation="update_tournament",
        resource_id=tournament_id,
        payload=payload.model_dump(exclude_none=True),
    )


@router.delete(
    "/tournaments/{tournament_id}",
    response_model=CricketTournamentDeleteResponse,
)
def delete_room_cricket_tournament(
    room_public_id: str,
    tournament_id: int,
    reason: str | None = Query(default=None, max_length=240),
    current_user: User = Depends(get_current_user),
):
    return _operation(
        current_user=current_user,
        room_public_id=room_public_id,
        operation="delete_tournament",
        resource_id=tournament_id,
        payload={"reason": reason} if reason is not None else {},
    )


@router.post(
    "/matches",
    response_model=CricketMatchResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_room_cricket_match(
    room_public_id: str,
    payload: CricketMatchCreateRequest,
    current_user: User = Depends(get_current_user),
):
    return _operation(
        current_user=current_user,
        room_public_id=room_public_id,
        operation="create_match",
        payload=payload.model_dump(),
    )


@router.get("/matches/{match_id}", response_model=CricketMatchResponse)
def get_room_cricket_match(
    room_public_id: str,
    match_id: int,
    current_user: User = Depends(get_current_user),
):
    return _operation(
        current_user=current_user,
        room_public_id=room_public_id,
        operation="get_match",
        resource_id=match_id,
    )


@router.patch("/matches/{match_id}/toss", response_model=CricketMatchResponse)
def set_room_cricket_match_toss(
    room_public_id: str,
    match_id: int,
    payload: CricketMatchTossRequest,
    current_user: User = Depends(get_current_user),
):
    return _operation(
        current_user=current_user,
        room_public_id=room_public_id,
        operation="update_match_toss",
        resource_id=match_id,
        payload=payload.model_dump(),
    )


@router.patch("/matches/{match_id}/lineup", response_model=CricketMatchResponse)
def set_room_cricket_match_lineup(
    room_public_id: str,
    match_id: int,
    payload: CricketMatchLineupRequest,
    current_user: User = Depends(get_current_user),
):
    return _operation(
        current_user=current_user,
        room_public_id=room_public_id,
        operation="update_match_lineup",
        resource_id=match_id,
        payload=payload.model_dump(),
    )


@router.post("/matches/{match_id}/balls", response_model=CricketMatchResponse)
def add_room_cricket_ball_event(
    room_public_id: str,
    match_id: int,
    payload: CricketBallEventRequest,
    current_user: User = Depends(get_current_user),
):
    return _operation(
        current_user=current_user,
        room_public_id=room_public_id,
        operation="append_ball_event",
        resource_id=match_id,
        payload=payload.model_dump(),
    )


@router.patch("/matches/{match_id}/score", response_model=CricketMatchResponse)
def patch_room_cricket_match_score(
    room_public_id: str,
    match_id: int,
    payload: CricketMatchScorePatchRequest,
    current_user: User = Depends(get_current_user),
):
    return _operation(
        current_user=current_user,
        room_public_id=room_public_id,
        operation="patch_match_score",
        resource_id=match_id,
        payload=payload.model_dump(exclude_none=True),
    )


@router.post("/matches/{match_id}/complete", response_model=CricketMatchResponse)
def complete_room_cricket_match(
    room_public_id: str,
    match_id: int,
    payload: CricketMatchScorePatchRequest,
    current_user: User = Depends(get_current_user),
):
    return _operation(
        current_user=current_user,
        room_public_id=room_public_id,
        operation="complete_match",
        resource_id=match_id,
        payload=payload.model_dump(exclude_none=True),
    )
