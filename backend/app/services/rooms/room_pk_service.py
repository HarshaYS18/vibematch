from __future__ import annotations

from datetime import datetime, timedelta
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.room import Room
from app.models.room_pk import RoomPkMatch, RoomPkScoreReceipt
from app.models.user import User
from app.services.rooms import room_permission_service


OPEN_MATCH_STATUSES = ("challenged", "active")
FINAL_MATCH_STATUSES = ("finished", "declined", "cancelled")


def _room(db: Session, room_public_id: str, *, lock: bool = False) -> Room:
    query = db.query(Room).filter(
        Room.room_public_id == room_public_id.strip(),
        Room.is_active.is_(True),
    )
    if lock:
        query = query.with_for_update()
    room = query.first()
    if room is None:
        raise HTTPException(status_code=404, detail="Room not found")
    return room


def _match_for_room(
    db: Session,
    room: Room,
    *,
    statuses: tuple[str, ...] | None = None,
    lock: bool = False,
) -> RoomPkMatch | None:
    query = db.query(RoomPkMatch).filter(
        or_(
            RoomPkMatch.challenger_room_id == room.id,
            RoomPkMatch.opponent_room_id == room.id,
        )
    )
    if statuses:
        query = query.filter(RoomPkMatch.status.in_(statuses))
    if lock:
        query = query.with_for_update()
    return query.order_by(RoomPkMatch.id.desc()).first()


def _get_match(db: Session, match_public_id: str, *, lock: bool = False) -> RoomPkMatch:
    query = db.query(RoomPkMatch).filter(
        RoomPkMatch.match_public_id == match_public_id.strip()
    )
    if lock:
        query = query.with_for_update()
    match = query.first()
    if match is None:
        raise HTTPException(status_code=404, detail="PK match not found")
    return match


def _room_summary(room: Room) -> dict:
    return {
        "room_id": room.room_public_id,
        "room_name": room.name,
        "cover_photo_url": room.cover_photo_url or room.avatar_url,
        "online_count": max(0, int(room.online_count or 0)),
    }


def _winner_public_id(db: Session, match: RoomPkMatch) -> str | None:
    if match.winner_room_id is None:
        return None
    room = db.query(Room).filter(Room.id == match.winner_room_id).first()
    return room.room_public_id if room is not None else None


def match_payload(db: Session, match: RoomPkMatch) -> dict:
    challenger = db.query(Room).filter(Room.id == match.challenger_room_id).one()
    opponent = db.query(Room).filter(Room.id == match.opponent_room_id).one()
    return {
        "match_id": match.match_public_id,
        "status": match.status,
        "challenger": _room_summary(challenger),
        "opponent": _room_summary(opponent),
        "duration_seconds": int(match.duration_seconds),
        "challenger_score": int(match.challenger_score or 0),
        "opponent_score": int(match.opponent_score or 0),
        "winner_room_id": _winner_public_id(db, match),
        "challenge_expires_at": match.challenge_expires_at,
        "started_at": match.started_at,
        "ends_at": match.ends_at,
        "finished_at": match.finished_at,
        "finished_reason": match.finished_reason,
    }


def affected_room_ids(db: Session, match: RoomPkMatch) -> tuple[str, str]:
    challenger = db.query(Room).filter(Room.id == match.challenger_room_id).one()
    opponent = db.query(Room).filter(Room.id == match.opponent_room_id).one()
    return challenger.room_public_id, opponent.room_public_id


def _ensure_not_busy(db: Session, room: Room) -> None:
    current = _match_for_room(db, room, statuses=OPEN_MATCH_STATUSES)
    if current is not None:
        _expire_if_needed(db, current)
        if current.status in OPEN_MATCH_STATUSES:
            raise HTTPException(status_code=409, detail="Room is already in a PK challenge or battle")


def list_candidates(
    db: Session,
    room_public_id: str,
    actor: User,
    *,
    limit: int = 30,
) -> list[dict]:
    room = _room(db, room_public_id)
    room_permission_service.require_room_admin(db, room, actor)
    busy_ids = set()
    for match in db.query(RoomPkMatch).filter(RoomPkMatch.status.in_(OPEN_MATCH_STATUSES)).all():
        _expire_if_needed(db, match)
        if match.status in OPEN_MATCH_STATUSES:
            busy_ids.add(int(match.challenger_room_id))
            busy_ids.add(int(match.opponent_room_id))

    rows = (
        db.query(Room)
        .filter(
            Room.is_active.is_(True),
            Room.id != room.id,
            Room.is_secret.is_(False),
            Room.is_locked.is_(False),
            Room.is_members_only.is_(False),
        )
        .order_by(Room.online_count.desc(), Room.trending_score.desc(), Room.id.asc())
        .limit(max(1, min(limit * 2, 100)))
        .all()
    )
    result = []
    for candidate in rows:
        if candidate.id in busy_ids:
            continue
        result.append(_room_summary(candidate))
        if len(result) >= max(1, min(limit, 50)):
            break
    return result


def create_challenge(
    db: Session,
    *,
    room_public_id: str,
    opponent_room_public_id: str,
    duration_seconds: int,
    actor: User,
) -> RoomPkMatch:
    source = _room(db, room_public_id, lock=True)
    target = _room(db, opponent_room_public_id, lock=True)
    room_permission_service.require_room_admin(db, source, actor)

    if source.id == target.id:
        raise HTTPException(status_code=400, detail="Choose a different room for PK")
    if target.is_secret or target.is_locked or target.is_members_only:
        raise HTTPException(status_code=409, detail="This room is not available for public PK")

    _ensure_not_busy(db, source)
    _ensure_not_busy(db, target)

    now = datetime.utcnow()
    match = RoomPkMatch(
        match_public_id=f"pk_{uuid4().hex}",
        challenger_room_id=source.id,
        opponent_room_id=target.id,
        created_by_user_id=actor.id,
        status="challenged",
        duration_seconds=max(60, min(int(duration_seconds), 600)),
        challenger_score=0,
        opponent_score=0,
        challenge_expires_at=now + timedelta(seconds=60),
        created_at=now,
        updated_at=now,
    )
    db.add(match)
    db.commit()
    db.refresh(match)
    return match


def _require_match_room(match: RoomPkMatch, room: Room) -> None:
    if room.id not in {match.challenger_room_id, match.opponent_room_id}:
        raise HTTPException(status_code=404, detail="PK match does not belong to this room")


def decide_challenge(
    db: Session,
    *,
    room_public_id: str,
    match_public_id: str,
    actor: User,
    accept: bool,
) -> RoomPkMatch:
    room = _room(db, room_public_id, lock=True)
    room_permission_service.require_room_admin(db, room, actor)
    match = _get_match(db, match_public_id, lock=True)
    _require_match_room(match, room)

    if room.id != match.opponent_room_id:
        raise HTTPException(status_code=403, detail="Only the challenged room can respond")
    _expire_if_needed(db, match)
    if match.status != "challenged":
        raise HTTPException(status_code=409, detail="PK challenge is no longer pending")

    now = datetime.utcnow()
    if not accept:
        match.status = "declined"
        match.finished_at = now
        match.finished_reason = "declined"
    else:
        match.status = "active"
        match.started_at = now
        match.ends_at = now + timedelta(seconds=int(match.duration_seconds))
        match.finished_reason = None
    match.updated_at = now
    db.commit()
    db.refresh(match)
    return match


def cancel_match(
    db: Session,
    *,
    room_public_id: str,
    match_public_id: str,
    actor: User,
) -> RoomPkMatch:
    room = _room(db, room_public_id, lock=True)
    room_permission_service.require_room_admin(db, room, actor)
    match = _get_match(db, match_public_id, lock=True)
    _require_match_room(match, room)
    if match.status not in OPEN_MATCH_STATUSES:
        return match

    if match.status == "challenged" and room.id != match.challenger_room_id:
        raise HTTPException(status_code=403, detail="Only the challenger can cancel this request")

    return _finish(db, match, reason="cancelled" if match.status == "challenged" else "ended_by_host")


def finish_match(
    db: Session,
    *,
    room_public_id: str,
    match_public_id: str,
    actor: User,
) -> RoomPkMatch:
    room = _room(db, room_public_id, lock=True)
    room_permission_service.require_room_admin(db, room, actor)
    match = _get_match(db, match_public_id, lock=True)
    _require_match_room(match, room)
    if match.status != "active":
        return match
    return _finish(db, match, reason="timer_elapsed" if match.ends_at and datetime.utcnow() >= match.ends_at else "ended_by_host")


def _finish(db: Session, match: RoomPkMatch, *, reason: str) -> RoomPkMatch:
    now = datetime.utcnow()
    if match.status == "challenged":
        match.status = "cancelled"
        match.winner_room_id = None
    else:
        match.status = "finished"
        if int(match.challenger_score or 0) > int(match.opponent_score or 0):
            match.winner_room_id = match.challenger_room_id
        elif int(match.opponent_score or 0) > int(match.challenger_score or 0):
            match.winner_room_id = match.opponent_room_id
        else:
            match.winner_room_id = None
    match.finished_at = now
    match.finished_reason = reason
    match.updated_at = now
    db.commit()
    db.refresh(match)
    return match


def _expire_if_needed(db: Session, match: RoomPkMatch) -> RoomPkMatch:
    now = datetime.utcnow()
    if match.status == "challenged" and now >= match.challenge_expires_at:
        match.status = "cancelled"
        match.finished_reason = "challenge_expired"
        match.finished_at = now
        match.updated_at = now
        db.commit()
        db.refresh(match)
    elif match.status == "active" and match.ends_at is not None and now >= match.ends_at:
        _finish(db, match, reason="timer_elapsed")
    return match


def current_match(db: Session, room_public_id: str) -> RoomPkMatch | None:
    room = _room(db, room_public_id)
    match = _match_for_room(db, room)
    if match is None:
        return None
    return _expire_if_needed(db, match)


def apply_gift_score(
    db: Session,
    *,
    room_public_id: str,
    source_event_id: str,
    coin_value: int,
) -> tuple[RoomPkMatch | None, bool]:
    room = _room(db, room_public_id, lock=True)
    match = _match_for_room(db, room, statuses=("active",), lock=True)
    if match is None:
        return None, False
    _expire_if_needed(db, match)
    if match.status != "active":
        return match, False

    existing = (
        db.query(RoomPkScoreReceipt)
        .filter(RoomPkScoreReceipt.source_event_id == source_event_id.strip())
        .first()
    )
    if existing is not None:
        return match, False

    receipt = RoomPkScoreReceipt(
        match_id=match.id,
        room_id=room.id,
        source_event_id=source_event_id.strip(),
        coin_value=max(1, int(coin_value)),
    )
    db.add(receipt)
    if room.id == match.challenger_room_id:
        match.challenger_score = int(match.challenger_score or 0) + int(coin_value)
    else:
        match.opponent_score = int(match.opponent_score or 0) + int(coin_value)
    match.updated_at = datetime.utcnow()
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        match = _get_match(db, match.match_public_id)
        return match, False
    db.refresh(match)
    return match, True
