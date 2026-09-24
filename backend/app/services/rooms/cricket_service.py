from __future__ import annotations

from datetime import datetime

from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.cricket import (
    CricketBallEvent,
    CricketMatch,
    CricketMatchStatus,
    CricketTournament,
    CricketTournamentStatus,
)
from app.models.user import User
from app.schemas.rooms.cricket import (
    CricketBallEventRequest,
    CricketMatchCreateRequest,
    CricketMatchLineupRequest,
    CricketMatchScorePatchRequest,
    CricketMatchTossRequest,
    CricketTournamentCreateRequest,
    CricketTournamentUpdateRequest,
)
from app.services.permissions import room_permission_service
from app.services.rooms.room_service import get_room_by_public_id


def _require_room(
    db: Session,
    room_public_id: str,
    current_user: User,
    *,
    admin: bool,
):
    room = get_room_by_public_id(db=db, room_public_id=room_public_id)
    if room is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found",
        )
    if admin:
        room_permission_service.require_room_admin(db, room, current_user)
    else:
        room_permission_service.require_room_view(db, room, current_user)
    return room


def _tournament_entity(
    *,
    db: Session,
    room_public_id: str,
    tournament_id: int,
    for_update: bool = False,
) -> CricketTournament:
    query = db.query(CricketTournament).filter(
        CricketTournament.id == tournament_id,
        CricketTournament.room_public_id == room_public_id,
        CricketTournament.status != CricketTournamentStatus.DELETED,
    )
    if for_update:
        query = query.with_for_update()
    tournament = query.first()
    if tournament is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tournament not found",
        )
    return tournament


def _match_entity(
    *,
    db: Session,
    room_public_id: str,
    match_id: int,
    for_update: bool = False,
) -> CricketMatch:
    query = db.query(CricketMatch).filter(
        CricketMatch.id == match_id,
        CricketMatch.room_public_id == room_public_id,
        CricketMatch.status != CricketMatchStatus.DELETED,
    )
    if for_update:
        query = query.with_for_update()
    match = query.first()
    if match is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cricket match not found",
        )
    return match


def _ball_events(db: Session, match: CricketMatch) -> list[dict]:
    rows = (
        db.query(CricketBallEvent)
        .filter(CricketBallEvent.match_id == match.id)
        .order_by(CricketBallEvent.sequence.asc())
        .all()
    )
    if rows:
        return [dict(row.event_json or {}) for row in rows]
    # Compatibility fallback for pre-migration fixtures/tests. New writes never
    # append to this growing JSON column.
    return [dict(item) for item in (match.ball_events_json or []) if isinstance(item, dict)]


def _tournament_payload(tournament: CricketTournament) -> dict:
    return {
        "id": tournament.id,
        "room_public_id": tournament.room_public_id,
        "created_by_user_id": tournament.created_by_user_id,
        "name": tournament.name,
        "status": tournament.status,
        "team_count": tournament.team_count,
        "players_per_team": tournament.players_per_team,
        "overs_per_innings": tournament.overs_per_innings,
        "wickets_per_side": tournament.wickets_per_side,
        "matches_per_team": tournament.matches_per_team,
        "matches_vs_each_team": tournament.matches_vs_each_team,
        "allow_same_player_across_teams": tournament.allow_same_player_across_teams,
        "rules": tournament.rules_json or {},
        "teams": tournament.teams_json or [],
        "fixtures": tournament.fixtures_json or [],
        "points_table": tournament.points_table_json or [],
        "created_at": tournament.created_at,
        "updated_at": tournament.updated_at,
    }


def _match_payload(db: Session, match: CricketMatch) -> dict:
    return {
        "id": match.id,
        "tournament_id": match.tournament_id,
        "room_public_id": match.room_public_id,
        "created_by_user_id": match.created_by_user_id,
        "status": match.status,
        "match_type": match.match_type,
        "team_a": match.team_a_json or {},
        "team_b": match.team_b_json or {},
        "toss": match.toss_json or {},
        "lineup": match.lineup_json or {},
        "score": match.score_json or {},
        "ball_events": _ball_events(db, match),
        "result": match.result_json or {},
        "created_at": match.created_at,
        "updated_at": match.updated_at,
    }


def create_tournament(
    *,
    db: Session,
    room_public_id: str,
    current_user: User,
    payload: CricketTournamentCreateRequest,
) -> dict:
    _require_room(db, room_public_id, current_user, admin=True)
    tournament = CricketTournament(
        room_public_id=room_public_id,
        created_by_user_id=current_user.id,
        name=payload.name.strip(),
        team_count=payload.team_count,
        players_per_team=payload.players_per_team,
        overs_per_innings=payload.overs_per_innings,
        wickets_per_side=payload.wickets_per_side,
        matches_per_team=payload.matches_per_team,
        matches_vs_each_team=payload.matches_vs_each_team,
        allow_same_player_across_teams=payload.allow_same_player_across_teams,
        rules_json=payload.rules,
        teams_json=payload.teams,
        fixtures_json=payload.fixtures,
        points_table_json=[],
    )
    db.add(tournament)
    db.commit()
    db.refresh(tournament)
    return _tournament_payload(tournament)


def list_tournaments(
    *,
    db: Session,
    room_public_id: str,
    current_user: User,
    offset: int = 0,
    limit: int = 50,
) -> list[dict]:
    _require_room(db, room_public_id, current_user, admin=False)
    tournaments = (
        db.query(CricketTournament)
        .filter(
            CricketTournament.room_public_id == room_public_id,
            CricketTournament.status != CricketTournamentStatus.DELETED,
        )
        .order_by(CricketTournament.created_at.desc(), CricketTournament.id.desc())
        .offset(max(0, offset))
        .limit(min(max(1, limit), 100))
        .all()
    )
    return [_tournament_payload(tournament) for tournament in tournaments]


def get_tournament(
    *,
    db: Session,
    room_public_id: str,
    tournament_id: int,
    current_user: User,
) -> dict:
    _require_room(db, room_public_id, current_user, admin=False)
    return _tournament_payload(
        _tournament_entity(
            db=db,
            room_public_id=room_public_id,
            tournament_id=tournament_id,
        )
    )


def update_tournament(
    *,
    db: Session,
    room_public_id: str,
    tournament_id: int,
    current_user: User,
    payload: CricketTournamentUpdateRequest,
) -> dict:
    _require_room(db, room_public_id, current_user, admin=True)
    tournament = _tournament_entity(
        db=db,
        room_public_id=room_public_id,
        tournament_id=tournament_id,
        for_update=True,
    )
    if payload.name is not None:
        tournament.name = payload.name.strip()
    if payload.rules is not None:
        tournament.rules_json = payload.rules
    if payload.teams is not None:
        tournament.teams_json = payload.teams
        tournament.team_count = len(payload.teams)
    if payload.fixtures is not None:
        tournament.fixtures_json = payload.fixtures
    if payload.points_table is not None:
        tournament.points_table_json = payload.points_table
    tournament.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(tournament)
    return _tournament_payload(tournament)


def delete_tournament(
    *,
    db: Session,
    room_public_id: str,
    tournament_id: int,
    current_user: User,
    reason: str | None = None,
) -> dict:
    _require_room(db, room_public_id, current_user, admin=True)
    tournament = _tournament_entity(
        db=db,
        room_public_id=room_public_id,
        tournament_id=tournament_id,
        for_update=True,
    )
    tournament.status = CricketTournamentStatus.DELETED
    tournament.deleted_at = datetime.utcnow()
    tournament.deleted_reason = reason
    tournament.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(tournament)
    return {
        "id": tournament.id,
        "room_public_id": tournament.room_public_id,
        "status": tournament.status,
        "deleted_reason": tournament.deleted_reason,
        "deleted_at": tournament.deleted_at,
    }


def create_match(
    *,
    db: Session,
    room_public_id: str,
    current_user: User,
    payload: CricketMatchCreateRequest,
) -> dict:
    _require_room(db, room_public_id, current_user, admin=True)
    if payload.tournament_id is not None:
        _tournament_entity(
            db=db,
            room_public_id=room_public_id,
            tournament_id=payload.tournament_id,
        )
    match = CricketMatch(
        tournament_id=payload.tournament_id,
        room_public_id=room_public_id,
        created_by_user_id=current_user.id,
        match_type=payload.match_type,
        team_a_json=payload.team_a,
        team_b_json=payload.team_b,
        status=CricketMatchStatus.TOSS_PENDING,
    )
    db.add(match)
    db.commit()
    db.refresh(match)
    return _match_payload(db, match)


def get_match(
    *,
    db: Session,
    room_public_id: str,
    match_id: int,
    current_user: User,
) -> dict:
    _require_room(db, room_public_id, current_user, admin=False)
    match = _match_entity(db=db, room_public_id=room_public_id, match_id=match_id)
    return _match_payload(db, match)


def update_match_toss(
    *,
    db: Session,
    room_public_id: str,
    match_id: int,
    current_user: User,
    payload: CricketMatchTossRequest,
) -> dict:
    _require_room(db, room_public_id, current_user, admin=True)
    match = _match_entity(
        db=db,
        room_public_id=room_public_id,
        match_id=match_id,
        for_update=True,
    )
    match.toss_json = {
        "winner_team_id": payload.toss_winner_team_id,
        "decision": "ball" if payload.decision == "bowl" else payload.decision,
        "confirmed_at": datetime.utcnow().isoformat(),
    }
    match.status = CricketMatchStatus.LINEUP_PENDING
    match.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(match)
    return _match_payload(db, match)


def update_match_lineup(
    *,
    db: Session,
    room_public_id: str,
    match_id: int,
    current_user: User,
    payload: CricketMatchLineupRequest,
) -> dict:
    _require_room(db, room_public_id, current_user, admin=True)
    match = _match_entity(
        db=db,
        room_public_id=room_public_id,
        match_id=match_id,
        for_update=True,
    )
    match.lineup_json = payload.model_dump()
    match.status = CricketMatchStatus.LIVE
    match.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(match)
    return _match_payload(db, match)


def append_ball_event(
    *,
    db: Session,
    room_public_id: str,
    match_id: int,
    current_user: User,
    payload: CricketBallEventRequest,
) -> dict:
    _require_room(db, room_public_id, current_user, admin=True)
    match = _match_entity(
        db=db,
        room_public_id=room_public_id,
        match_id=match_id,
        for_update=True,
    )

    current_sequence = int(
        db.query(func.max(CricketBallEvent.sequence))
        .filter(CricketBallEvent.match_id == match.id)
        .scalar()
        or 0
    )
    sequence = int(payload.sequence or (current_sequence + 1))
    if sequence <= current_sequence:
        existing = (
            db.query(CricketBallEvent)
            .filter(
                CricketBallEvent.match_id == match.id,
                CricketBallEvent.sequence == sequence,
            )
            .first()
        )
        if existing is not None:
            expected = payload.model_dump(exclude_none=True)
            actual = dict(existing.event_json or {})
            comparable = {
                key: actual.get(key)
                for key in expected
                if key not in {"sequence", "created_at"}
            }
            expected_comparable = {
                key: value
                for key, value in expected.items()
                if key not in {"sequence", "created_at"}
            }
            if comparable == expected_comparable:
                return _match_payload(db, match)
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cricket ball sequence already exists with different data",
        )
    if sequence != current_sequence + 1:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Expected cricket ball sequence {current_sequence + 1}",
        )

    event = payload.model_dump()
    event["sequence"] = sequence
    event["created_at"] = datetime.utcnow().isoformat()
    db.add(
        CricketBallEvent(
            match_id=match.id,
            sequence=sequence,
            event_json=event,
        )
    )
    match.status = CricketMatchStatus.LIVE
    match.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(match)
    return _match_payload(db, match)


def _apply_points_table(
    db: Session,
    match: CricketMatch,
    points_table: list[dict] | None,
) -> None:
    if points_table is None or match.tournament_id is None:
        return
    tournament = (
        db.query(CricketTournament)
        .filter(CricketTournament.id == match.tournament_id)
        .with_for_update()
        .first()
    )
    if tournament is not None:
        tournament.points_table_json = points_table
        tournament.updated_at = datetime.utcnow()


def patch_match_score(
    *,
    db: Session,
    room_public_id: str,
    match_id: int,
    current_user: User,
    payload: CricketMatchScorePatchRequest,
) -> dict:
    _require_room(db, room_public_id, current_user, admin=True)
    match = _match_entity(
        db=db,
        room_public_id=room_public_id,
        match_id=match_id,
        for_update=True,
    )
    match.score_json = payload.score
    if payload.result is not None:
        match.result_json = payload.result
    _apply_points_table(db, match, payload.points_table)
    match.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(match)
    return _match_payload(db, match)


def complete_match(
    *,
    db: Session,
    room_public_id: str,
    match_id: int,
    current_user: User,
    payload: CricketMatchScorePatchRequest,
) -> dict:
    _require_room(db, room_public_id, current_user, admin=True)
    match = _match_entity(
        db=db,
        room_public_id=room_public_id,
        match_id=match_id,
        for_update=True,
    )
    match.score_json = payload.score
    match.result_json = payload.result or {}
    match.status = CricketMatchStatus.COMPLETED
    _apply_points_table(db, match, payload.points_table)
    match.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(match)
    return _match_payload(db, match)
