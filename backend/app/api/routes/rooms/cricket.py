from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
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
from app.services.rooms.cricket_service import (
    append_ball_event,
    complete_match,
    create_match,
    create_tournament,
    delete_tournament,
    get_match,
    get_tournament,
    list_tournaments,
    patch_match_score,
    update_match_lineup,
    update_match_toss,
    update_tournament,
)


router = APIRouter(prefix="/rooms/{room_public_id}/cricket", tags=["Room Cricket"])


@router.post(
    "/tournaments",
    response_model=CricketTournamentResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_room_cricket_tournament(
    room_public_id: str,
    payload: CricketTournamentCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_tournament(
        db=db,
        room_public_id=room_public_id,
        current_user=current_user,
        payload=payload,
    )


@router.get("/tournaments", response_model=list[CricketTournamentResponse])
def list_room_cricket_tournaments(
    room_public_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return list_tournaments(db=db, room_public_id=room_public_id)


@router.get("/tournaments/{tournament_id}", response_model=CricketTournamentResponse)
def get_room_cricket_tournament(
    room_public_id: str,
    tournament_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_tournament(db=db, room_public_id=room_public_id, tournament_id=tournament_id)


@router.patch("/tournaments/{tournament_id}", response_model=CricketTournamentResponse)
def update_room_cricket_tournament(
    room_public_id: str,
    tournament_id: int,
    payload: CricketTournamentUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return update_tournament(
        db=db,
        room_public_id=room_public_id,
        tournament_id=tournament_id,
        payload=payload,
    )


@router.delete("/tournaments/{tournament_id}", response_model=CricketTournamentDeleteResponse)
def delete_room_cricket_tournament(
    room_public_id: str,
    tournament_id: int,
    reason: str | None = Query(default=None, max_length=240),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return delete_tournament(
        db=db,
        room_public_id=room_public_id,
        tournament_id=tournament_id,
        reason=reason,
    )


@router.post("/matches", response_model=CricketMatchResponse, status_code=status.HTTP_201_CREATED)
def create_room_cricket_match(
    room_public_id: str,
    payload: CricketMatchCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return create_match(
        db=db,
        room_public_id=room_public_id,
        current_user=current_user,
        payload=payload,
    )


@router.get("/matches/{match_id}", response_model=CricketMatchResponse)
def get_room_cricket_match(
    room_public_id: str,
    match_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_match(db=db, room_public_id=room_public_id, match_id=match_id)


@router.patch("/matches/{match_id}/toss", response_model=CricketMatchResponse)
def set_room_cricket_match_toss(
    room_public_id: str,
    match_id: int,
    payload: CricketMatchTossRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return update_match_toss(db=db, room_public_id=room_public_id, match_id=match_id, payload=payload)


@router.patch("/matches/{match_id}/lineup", response_model=CricketMatchResponse)
def set_room_cricket_match_lineup(
    room_public_id: str,
    match_id: int,
    payload: CricketMatchLineupRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return update_match_lineup(db=db, room_public_id=room_public_id, match_id=match_id, payload=payload)


@router.post("/matches/{match_id}/balls", response_model=CricketMatchResponse)
def add_room_cricket_ball_event(
    room_public_id: str,
    match_id: int,
    payload: CricketBallEventRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return append_ball_event(db=db, room_public_id=room_public_id, match_id=match_id, payload=payload)


@router.patch("/matches/{match_id}/score", response_model=CricketMatchResponse)
def patch_room_cricket_match_score(
    room_public_id: str,
    match_id: int,
    payload: CricketMatchScorePatchRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return patch_match_score(db=db, room_public_id=room_public_id, match_id=match_id, payload=payload)


@router.post("/matches/{match_id}/complete", response_model=CricketMatchResponse)
def complete_room_cricket_match(
    room_public_id: str,
    match_id: int,
    payload: CricketMatchScorePatchRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return complete_match(db=db, room_public_id=room_public_id, match_id=match_id, payload=payload)
