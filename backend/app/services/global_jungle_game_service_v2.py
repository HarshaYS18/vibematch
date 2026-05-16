from __future__ import annotations

from datetime import date, datetime
from typing import Any

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.economy import GameRound
from app.models.game import GameBet, GameDefinition
from app.models.user import User
from app.services import game_pool_service
from app.services import global_jungle_game_service as old

JUNGLE_HUNT_KEY = old.JUNGLE_HUNT_KEY
LEFT_BASKET_ID = old.LEFT_BASKET_ID
RIGHT_BASKET_ID = old.RIGHT_BASKET_ID
LEGACY_JUNGLE_KEYS = {"jungle_hunt", "jackpot_king", JUNGLE_HUNT_KEY}


def _json_safe(value: Any) -> Any:
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, dict):
        return {str(key): _json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [_json_safe(item) for item in value]
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    return str(value)


def seed_default_games(db: Session, actor: User | None = None) -> GameDefinition:
    game_pool_service.ensure_main_and_game_pools(db, JUNGLE_HUNT_KEY)
    return old.seed_default_games(db, actor)


def list_catalog(db: Session, include_disabled: bool = False) -> list[dict[str, Any]]:
    game_pool_service.ensure_main_and_game_pools(db, JUNGLE_HUNT_KEY)
    return old.list_catalog(db, include_disabled=include_disabled)


def get_definition(db: Session, game_key: str, include_disabled: bool = False) -> GameDefinition:
    if game_key in LEGACY_JUNGLE_KEYS:
        game_pool_service.ensure_main_and_game_pools(db, JUNGLE_HUNT_KEY)
    return old.get_definition(db, game_key, include_disabled=include_disabled)


def _definition_payload(definition: GameDefinition) -> dict[str, Any]:
    return old._definition_payload(definition)


def upsert_definition(db: Session, actor: User, game_key: str, payload: dict[str, Any]) -> GameDefinition:
    return old.upsert_definition(db, actor, game_key, payload)


def create_round(db: Session, game_key: str, user: User, room_id: int | None = None) -> GameRound:
    if game_key in LEGACY_JUNGLE_KEYS:
        game_pool_service.ensure_main_and_game_pools(db, JUNGLE_HUNT_KEY)
    return old.create_round(db, game_key, user, room_id)


def get_round_payload(db: Session, round_id: int, user: User | None = None) -> dict[str, Any]:
    return old.get_round_payload(db, round_id, user)


def get_history(db: Session, limit: int = 30) -> dict[str, Any]:
    return old.get_history(db, limit=limit)


def _candidate_payout_after_bet(db: Session, round_id: int, target_id: int, amount: int, outcome_id: int) -> int:
    total = 0
    for candidate_target_id in old._basket_target_ids(outcome_id):
        accepted = int(
            db.query(func.coalesce(func.sum(GameBet.accepted_amount), 0))
            .filter(GameBet.round_id == round_id, GameBet.target_id == candidate_target_id)
            .scalar()
            or 0
        )
        if candidate_target_id == target_id:
            accepted += amount
        multiplier = int(old._target_by_id(candidate_target_id)["multiplier"])
        total += accepted * multiplier
    return total


def _worst_exposure_after_bet(db: Session, round_id: int, target_id: int, amount: int) -> tuple[int, int]:
    outcomes = [int(item["id"]) for item in old.JUNGLE_TARGETS] + [LEFT_BASKET_ID, RIGHT_BASKET_ID]
    payouts = [_candidate_payout_after_bet(db, round_id, target_id, amount, outcome_id) for outcome_id in outcomes]
    worst = max(payouts) if payouts else 0
    selected_target_payout = _candidate_payout_after_bet(db, round_id, target_id, amount, target_id)
    return worst, selected_target_payout


def _pool_risk_metadata(db: Session, round_id: int, target_id: int, amount: int) -> dict[str, Any]:
    worst_exposure, selected_target_payout = _worst_exposure_after_bet(db, round_id, target_id, amount)
    allowed, reason, metadata = game_pool_service.validate_exposure(
        db=db,
        game_key=JUNGLE_HUNT_KEY,
        proposed_worst_payout=worst_exposure,
        proposed_single_payout=selected_target_payout,
    )
    return {
        "pool_guard_allowed": bool(allowed),
        "pool_guard_reason": reason,
        "pool_guard": _json_safe(metadata),
        "worst_exposure_after_bet": worst_exposure,
        "selected_target_payout_after_bet": selected_target_payout,
    }


def place_bet(db: Session, round_id: int, user: User, target_id: int, amount: int) -> dict[str, Any]:
    round_obj = db.query(GameRound).filter(GameRound.id == round_id).first()
    if not round_obj:
        raise HTTPException(status_code=404, detail="Game round not found")
    if round_obj.game_key != JUNGLE_HUNT_KEY:
        return old.place_bet(db, round_id, user, target_id, amount)

    pool_meta = _pool_risk_metadata(db, round_id, target_id, amount)

    try:
        result = old.place_bet(db, round_id, user, target_id, amount, commit=False)
        if int(result.get("accepted_amount") or 0) > 0:
            game_pool_service.record_bet_income(
                db=db,
                game_key=JUNGLE_HUNT_KEY,
                round_id=round_id,
                user_id=user.id,
                amount=int(result["accepted_amount"]),
                actor=user,
            )
            if not pool_meta["pool_guard_allowed"]:
                old.base.audit(
                    db,
                    round_obj.game_key,
                    round_obj.id,
                    user.id,
                    "BET_ACCEPTED_POOL_RISK_PROBABILITY_REDUCED",
                    "HIGH",
                    int(result.get("risk_score") or 0),
                    "ALLOW_POOL_RISK_PROBABILITY_REDUCED",
                    "Bet accepted even though pool exposure guard was triggered; settlement probability is reduced instead of rejecting the bet.",
                    {"requested_amount": amount, "target_id": target_id, **pool_meta},
                    user.id,
                )
            db.commit()
    except Exception:
        db.rollback()
        raise

    if not pool_meta["pool_guard_allowed"] and int(result.get("accepted_amount") or 0) > 0:
        result["risk_level"] = "HIGH"
        result["risk_action"] = "ALLOW_POOL_RISK_PROBABILITY_REDUCED"
        result["probability_mode"] = result.get("probability_mode") or "VERY_LOW_WHALE"
        result["message"] = "Bet accepted; win probability reduced for pool exposure risk"
        result["pool_guard"] = pool_meta
    return result


def _payouts_by_user(db: Session, round_id: int, winning_target_id: int) -> dict[int, int]:
    bets = db.query(GameBet).filter(GameBet.round_id == round_id).all()
    grouped: dict[int, list[GameBet]] = {}
    for bet in bets:
        grouped.setdefault(bet.user_id, []).append(bet)
    payouts: dict[int, int] = {}
    for user_id, user_bets in grouped.items():
        payout = old._payout_for_user_bets(user_bets, winning_target_id)
        if payout > 0:
            payouts[user_id] = payout
    return payouts


def settle_round(db: Session, round_id: int, user: User) -> dict[str, Any]:
    round_obj = db.query(GameRound).filter(GameRound.id == round_id).first()
    if not round_obj or round_obj.game_key != JUNGLE_HUNT_KEY:
        return old.settle_round(db, round_id, user)

    game_pool_service.ensure_main_and_game_pools(db, JUNGLE_HUNT_KEY)
    metadata_before = old.base._loads(round_obj.metadata_json, {})
    was_unsettled = metadata_before.get("winning_target_id") is None
    try:
        result = old.settle_round(db, round_id, user, commit=False)

        if was_unsettled:
            winning_target_id = int(result["winning_target_id"])
            for winner_user_id, payout in _payouts_by_user(db, round_id, winning_target_id).items():
                game_pool_service.record_payout(
                    db=db,
                    game_key=JUNGLE_HUNT_KEY,
                    round_id=round_id,
                    user_id=winner_user_id,
                    amount=payout,
                    actor=user,
                )
            db.commit()
    except Exception:
        db.rollback()
        raise

    return result
