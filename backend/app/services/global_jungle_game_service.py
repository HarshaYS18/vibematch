from __future__ import annotations

import hashlib
import random
from datetime import datetime, timedelta
from typing import Any

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.economy import EconomyCurrency, EconomyDirection, GameRound, GameRoundStatus, WalletLedger
from app.models.game import GameBet, GameDefinition
from app.models.user import User
from app.services import economy_service, game_stats_service
from app.services import game_service as base

JUNGLE_HUNT_KEY = base.JUNGLE_HUNT_KEY
LEFT_BASKET_ID = 100
RIGHT_BASKET_ID = 101
LEFT_BASKET_TARGET_IDS = [4, 5, 6, 7]
RIGHT_BASKET_TARGET_IDS = [0, 1, 2, 3]

JUNGLE_TARGETS: list[dict[str, Any]] = [
    {"id": 0, "label": "Rabbit", "emoji": "🐰", "multiplier": 5, "theme_color": "#FF5CA8"},
    {"id": 1, "label": "Monkey", "emoji": "🐵", "multiplier": 5, "theme_color": "#FF9F43"},
    {"id": 2, "label": "Wolf", "emoji": "🐺", "multiplier": 5, "theme_color": "#9CA3AF"},
    {"id": 3, "label": "Deer", "emoji": "🦌", "multiplier": 5, "theme_color": "#B87938"},
    {"id": 4, "label": "Dragon", "emoji": "🐉", "multiplier": 10, "theme_color": "#34D399"},
    {"id": 5, "label": "Panda", "emoji": "🐼", "multiplier": 15, "theme_color": "#E5E7EB"},
    {"id": 6, "label": "Eagle", "emoji": "🦅", "multiplier": 25, "theme_color": "#A855F7"},
    {"id": 7, "label": "Lion", "emoji": "🦁", "multiplier": 45, "theme_color": "#F43F5E"},
]

JUNGLE_RULES: dict[str, Any] = {
    **base.DEFAULT_RULES,
    "round_seconds": 30,
    "lock_seconds": 2,
    "reveal_seconds": 15,
    "result_seconds": 3,
    "allowed_bets": [10_000, 50_000, 100_000, 500_000, 1_000_000],
    "custom_bet_enabled": False,
    "min_bet": 10_000,
    "max_bet": 1_000_000,
    "max_total_bet_per_round": 6_000_000,
    "max_targets_per_user_round": 6,
    "close_betting_last_seconds": 2,
    "max_round_liability": 60_000_000,
    "max_target_liability": 45_000_000,
    "rare_basket_probability_basis_points": 120,
    "platform_fee_basis_points": 500,
    "whale_medium_target_weight_basis_points": 1000,
    "whale_high_target_weight_basis_points": 250,
    "whale_block_target_weight_basis_points": 50,
    "targets": JUNGLE_TARGETS,
    "rare_baskets": [
        {"id": LEFT_BASKET_ID, "side": "left", "target_ids": LEFT_BASKET_TARGET_IDS},
        {"id": RIGHT_BASKET_ID, "side": "right", "target_ids": RIGHT_BASKET_TARGET_IDS},
    ],
}

JUNGLE_RISK: dict[str, Any] = {
    **base.DEFAULT_RISK,
    "max_daily_loss": 1_500_000,
    "max_daily_bet_volume": 6_000_000,
    "manual_review_score": 70,
    "block_score": 95,
    "whale_daily_volume": 4_000_000,
    "whale_single_bet": 500_000,
    "whale_recent_bet_count": 8,
    "whale_probability_mode_enabled": True,
}

JUNGLE_UI: dict[str, Any] = {
    **base.DEFAULT_UI,
    "title": "Jungle Hunt",
    "subtitle": "Global Vibe Match Game",
    "layout": "global_room_overlay_70_percent",
}


def _target_by_id(target_id: int) -> dict[str, Any]:
    if target_id == LEFT_BASKET_ID:
        return {"id": LEFT_BASKET_ID, "label": "Left Basket", "emoji": "🧺", "multiplier": 0}
    if target_id == RIGHT_BASKET_ID:
        return {"id": RIGHT_BASKET_ID, "label": "Right Basket", "emoji": "🧺", "multiplier": 0}
    return next((item for item in JUNGLE_TARGETS if int(item["id"]) == target_id), JUNGLE_TARGETS[0])


def _basket_target_ids(outcome_id: int) -> list[int]:
    if outcome_id == LEFT_BASKET_ID:
        return LEFT_BASKET_TARGET_IDS
    if outcome_id == RIGHT_BASKET_ID:
        return RIGHT_BASKET_TARGET_IDS
    return [outcome_id]


def _sync_jungle_definition(db: Session, actor: User | None = None) -> GameDefinition:
    rows = (
        db.query(GameDefinition)
        .filter(GameDefinition.game_key.in_([JUNGLE_HUNT_KEY, "jackpot_king"]))
        .order_by(GameDefinition.id.asc())
        .all()
    )
    definition = next((row for row in rows if row.game_key == JUNGLE_HUNT_KEY), None)
    legacy_definition = next((row for row in rows if row.game_key == "jackpot_king"), None)

    if definition is None and legacy_definition is not None:
        definition = legacy_definition
        definition.game_key = JUNGLE_HUNT_KEY

    existing_ui = base._loads(definition.ui_config_json, {}) if definition else {}
    existing_rules = base._loads(definition.rules_json, {}) if definition else {}
    existing_risk = base._loads(definition.risk_config_json, {}) if definition else {}

    if not definition:
        definition = GameDefinition(
            game_key=JUNGLE_HUNT_KEY,
            display_name="Jungle Hunt",
            category="coin",
            is_enabled=True,
            is_coin_game=True,
            min_app_version="1.0.0",
            config_version=4,
            ui_config_json=base._dumps({**JUNGLE_UI, **existing_ui}),
            rules_json=base._dumps({**JUNGLE_RULES, **existing_rules}),
            risk_config_json=base._dumps({**JUNGLE_RISK, **existing_risk}),
            created_by_user_id=actor.id if actor else None,
            updated_by_user_id=actor.id if actor else None,
        )
        db.add(definition)
    else:
        definition.display_name = "Jungle Hunt"
        definition.is_enabled = True
        definition.is_coin_game = True
        definition.config_version = max(int(definition.config_version or 1), 4)
        definition.ui_config_json = base._dumps({**JUNGLE_UI, **existing_ui})
        definition.rules_json = base._dumps({**JUNGLE_RULES, **existing_rules})
        definition.risk_config_json = base._dumps({**JUNGLE_RISK, **existing_risk})
        if actor:
            definition.updated_by_user_id = actor.id
    db.commit()
    db.refresh(definition)
    return definition


def seed_default_games(db: Session, actor: User | None = None) -> GameDefinition:
    return _sync_jungle_definition(db, actor)


def list_catalog(db: Session, include_disabled: bool = False) -> list[dict[str, Any]]:
    _sync_jungle_definition(db)
    query = db.query(GameDefinition)
    if not include_disabled:
        query = query.filter(GameDefinition.is_enabled.is_(True))
    definitions = query.order_by(GameDefinition.category.asc(), GameDefinition.display_name.asc()).all()
    return [base._definition_payload(item) for item in definitions]


def get_definition(db: Session, game_key: str, include_disabled: bool = False) -> GameDefinition:
    if game_key in {"jungle_hunt", "jackpot_king", JUNGLE_HUNT_KEY}:
        _sync_jungle_definition(db)
        game_key = JUNGLE_HUNT_KEY
    return base.get_definition(db, game_key, include_disabled=include_disabled)


def _definition_payload(definition: GameDefinition) -> dict[str, Any]:
    return base._definition_payload(definition)


def upsert_definition(db: Session, actor: User, game_key: str, payload: dict[str, Any]) -> GameDefinition:
    return base.upsert_definition(db, actor, game_key, payload)


def create_round(db: Session, game_key: str, user: User, room_id: int | None = None) -> GameRound:
    if game_key in {"jungle_hunt", "jackpot_king", JUNGLE_HUNT_KEY}:
        _sync_jungle_definition(db)
        return base.get_or_create_global_round(db, JUNGLE_HUNT_KEY, user)
    return base.create_round(db, game_key, user, room_id)


def get_round_payload(db: Session, round_id: int, user: User | None = None) -> dict[str, Any]:
    return base.get_round_payload(db, round_id, user)


def get_history(db: Session, limit: int = 30) -> dict[str, Any]:
    safe_limit = max(1, min(limit, 30))
    rows = (
        db.query(GameRound)
        .filter(GameRound.game_key == JUNGLE_HUNT_KEY, GameRound.status == GameRoundStatus.COMPLETED.value)
        .order_by(GameRound.id.desc())
        .limit(safe_limit)
        .all()
    )
    items: list[dict[str, Any]] = []
    for round_obj in rows:
        metadata = base._loads(round_obj.metadata_json, {})
        raw_target = metadata.get("winning_target_id")
        if raw_target is None:
            continue
        target = _target_by_id(int(raw_target))
        completed_at = round_obj.ended_at or round_obj.created_at
        items.append(
            {
                "round_id": round_obj.id,
                "winning_target_id": int(target["id"]),
                "label": str(target["label"]),
                "emoji": target.get("emoji"),
                "multiplier": int(target["multiplier"]),
                "completed_at": completed_at.replace(microsecond=0).isoformat() + "Z" if completed_at else None,
            }
        )
    return {"items": items}


def _reject_bet(db: Session, round_obj: GameRound, user: User, target_id: int, amount: int, action: str, message: str, metadata: dict[str, Any] | None = None) -> dict[str, Any]:
    wallet = economy_service.get_or_create_wallet(db, user.id)
    base.audit(db, round_obj.game_key, round_obj.id, user.id, "BET_REJECTED", "HIGH", 0, action, message, {"requested_amount": amount, "target_id": target_id, **(metadata or {})}, user.id)
    db.commit()
    return {"bet_id": None, "round_id": round_obj.id, "target_id": target_id, "requested_amount": amount, "accepted_amount": 0, "spent_coins": 0, "reward_coins": 0, "net_win_coins": 0, "wallet_coin_balance": wallet.coin_balance, "winner_coin_balance": None, "risk_level": "HIGH", "risk_score": 0, "risk_action": action, "message": message}


def _evaluate_whale_risk(db: Session, user: User, amount: int, risk: dict[str, Any]) -> tuple[bool, str, dict[str, Any]]:
    if risk.get("testing_mode_enabled") is True:
        return False, "testing_mode_bypass", {"testing_mode_enabled": True, "score": 0, "level": "LOW", "probability_mode": "NORMAL", "reasons": ["testing_mode_enabled"]}

    since_day = datetime.utcnow() - timedelta(hours=24)
    since_recent = datetime.utcnow() - timedelta(minutes=5)
    daily_volume = int(db.query(func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.user_id == user.id, GameBet.created_at >= since_day).scalar() or 0)
    debits = int(db.query(func.coalesce(func.sum(WalletLedger.amount), 0)).filter(WalletLedger.user_id == user.id, WalletLedger.source_type == "GAME_BET", WalletLedger.created_at >= since_day).scalar() or 0)
    credits = int(db.query(func.coalesce(func.sum(WalletLedger.amount), 0)).filter(WalletLedger.user_id == user.id, WalletLedger.source_type == "GAME_WIN", WalletLedger.created_at >= since_day).scalar() or 0)
    recent_count = db.query(GameBet).filter(GameBet.user_id == user.id, GameBet.created_at >= since_recent).count()
    daily_loss = max(debits - credits, 0)
    score = 0
    reasons: list[str] = []
    if amount >= int(risk.get("whale_single_bet", JUNGLE_RISK["whale_single_bet"])):
        score += 35
        reasons.append("large_single_bet")
    if daily_volume + amount > int(risk.get("whale_daily_volume", JUNGLE_RISK["whale_daily_volume"])):
        score += 35
        reasons.append("whale_daily_volume")
    if daily_volume + amount > int(risk.get("max_daily_bet_volume", JUNGLE_RISK["max_daily_bet_volume"])):
        score += 55
        reasons.append("daily_volume_limit")
    if daily_loss > int(risk.get("max_daily_loss", JUNGLE_RISK["max_daily_loss"])):
        score += 45
        reasons.append("daily_loss_limit")
    if recent_count >= int(risk.get("whale_recent_bet_count", JUNGLE_RISK["whale_recent_bet_count"])):
        score += 35
        reasons.append("high_velocity")

    if score >= int(risk.get("block_score", JUNGLE_RISK["block_score"])):
        level = "WHALE_BLOCK_TIER"
        probability_mode = "VERY_LOW_WHALE"
    elif score >= int(risk.get("manual_review_score", JUNGLE_RISK["manual_review_score"])):
        level = "WHALE_HIGH_TIER"
        probability_mode = "LOW_WHALE"
    elif score >= 35:
        level = "WHALE_MEDIUM_TIER"
        probability_mode = "MEDIUM_WHALE"
    else:
        level = "LOW"
        probability_mode = "NORMAL"
    whale_adjusted = probability_mode != "NORMAL"
    return whale_adjusted, ",".join(reasons), {"daily_volume": daily_volume, "daily_loss": daily_loss, "recent_count": recent_count, "reasons": reasons, "score": score, "level": level, "probability_mode": probability_mode, "action": "ALLOW_WHALE_PROBABILITY_REDUCED" if whale_adjusted else "ALLOW"}


def place_bet(db: Session, round_id: int, user: User, target_id: int, amount: int, *, commit: bool = True) -> dict[str, Any]:
    round_obj = db.query(GameRound).filter(GameRound.id == round_id).first()
    if not round_obj:
        raise HTTPException(status_code=404, detail="Game round not found")
    if round_obj.game_key != JUNGLE_HUNT_KEY:
        return base.place_bet(db, round_id, user, target_id, amount)
    definition = _sync_jungle_definition(db)
    rules = {**JUNGLE_RULES, **base._loads(definition.rules_json, {})}
    risk = {**JUNGLE_RISK, **base._loads(definition.risk_config_json, {})}
    phase = base._phase_metadata(round_obj, rules)
    if phase["phase"] != "BETTING":
        return _reject_bet(db, round_obj, user, target_id, amount, "BETTING_CLOSED", "Betting is closed for this round", phase)
    if int(phase.get("betting_seconds_left", 0)) <= int(rules.get("close_betting_last_seconds", JUNGLE_RULES["close_betting_last_seconds"])):
        return _reject_bet(db, round_obj, user, target_id, amount, "LAST_SECONDS_LOCKED", "Betting is locked in the last 2 seconds", phase)
    targets = rules.get("targets") or JUNGLE_TARGETS
    target_map = {int(item["id"]): item for item in targets}
    if target_id not in target_map:
        raise HTTPException(status_code=400, detail="Invalid game target")
    allowed_bets = {int(item) for item in rules.get("allowed_bets", JUNGLE_RULES["allowed_bets"])}
    if amount not in allowed_bets:
        return _reject_bet(db, round_obj, user, target_id, amount, "INVALID_BET_AMOUNT", "Use one of the allowed bet chips")
    distinct_targets = {row[0] for row in db.query(GameBet.target_id).filter(GameBet.round_id == round_id, GameBet.user_id == user.id).distinct().all()}
    if target_id not in distinct_targets and len(distinct_targets) >= int(rules.get("max_targets_per_user_round", JUNGLE_RULES["max_targets_per_user_round"])):
        return _reject_bet(db, round_obj, user, target_id, amount, "TARGET_LIMIT_REACHED", "You can bid on only 6 items per round")
    existing_total = int(db.query(func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.round_id == round_id, GameBet.user_id == user.id).scalar() or 0)
    if existing_total + amount > int(rules.get("max_total_bet_per_round", JUNGLE_RULES["max_total_bet_per_round"])):
        return _reject_bet(db, round_obj, user, target_id, amount, "ROUND_USER_LIMIT", "Round bet limit reached")
    whale_adjusted, reason, risk_meta = _evaluate_whale_risk(db, user, amount, risk)
    multiplier = int(target_map[target_id]["multiplier"])
    target_total_after = int(db.query(func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.round_id == round_id, GameBet.target_id == target_id).scalar() or 0) + amount
    target_liability = target_total_after * multiplier
    if target_liability > int(rules.get("max_target_liability", JUNGLE_RULES["max_target_liability"])):
        return _reject_bet(db, round_obj, user, target_id, amount, "HIGH_TARGET_LIABILITY", "Bet not accepted because this item liability is too high", {"target_liability": target_liability, "multiplier": multiplier})
    all_target_totals = dict(db.query(GameBet.target_id, func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.round_id == round_id).group_by(GameBet.target_id).all())
    all_target_totals[target_id] = target_total_after
    worst_liability = 0
    for item in targets:
        worst_liability = max(worst_liability, int(all_target_totals.get(item["id"], 0)) * int(item["multiplier"]))
    if worst_liability > int(rules.get("max_round_liability", JUNGLE_RULES["max_round_liability"])):
        return _reject_bet(db, round_obj, user, target_id, amount, "HIGH_ROUND_LIABILITY", "Bet not accepted because round liability is too high", {"worst_liability": worst_liability})
    wallet = economy_service.get_or_create_wallet(db, user.id)
    if wallet.coin_balance < amount:
        raise HTTPException(status_code=400, detail="Insufficient coin balance")
    before = wallet.coin_balance
    wallet.coin_balance -= amount
    wallet.lifetime_coins_spent += amount
    db.add(WalletLedger(user_id=user.id, currency_type=EconomyCurrency.COIN.value, direction=EconomyDirection.DEBIT.value, amount=amount, before_balance=before, after_balance=wallet.coin_balance, source_type="GAME_BET", source_id=str(round_id), created_by_user_id=user.id, reason=f"Bet on Jungle Hunt:{target_id}"))
    risk_level = str(risk_meta.get("level") or "LOW")
    risk_score = int(risk_meta.get("score") or 0)
    risk_action = str(risk_meta.get("action") or "ALLOW")
    bet = GameBet(round_id=round_id, user_id=user.id, target_id=target_id, amount=amount, accepted_amount=amount, risk_level=risk_level, risk_score=risk_score, risk_action=risk_action, metadata_json=base._dumps({"scope": "GLOBAL", "whale_reason": reason, "whale_adjusted": whale_adjusted, "probability_mode": risk_meta.get("probability_mode", "NORMAL"), "risk": risk_meta}))
    db.add(bet)
    round_obj.round_pool_amount += amount
    platform_fee = amount * int(rules.get("platform_fee_basis_points", JUNGLE_RULES["platform_fee_basis_points"])) // 10_000
    round_obj.platform_fee_amount += platform_fee
    round_obj.reward_pool_amount += max(amount - platform_fee, 0)
    game_stats_service.record_game_bet(db, user_id=user.id, game_id=round_obj.game_key, amount=amount)
    base.audit(db, round_obj.game_key, round_obj.id, user.id, "BET_ACCEPTED", risk_level, risk_score, risk_action, "Bet accepted; whale tiers reduce win probability instead of blocking coins", {"amount": amount, "target_id": target_id, "scope": "GLOBAL", "probability_mode": risk_meta.get("probability_mode", "NORMAL")}, user.id)
    if commit:
        db.commit()
        db.refresh(bet)
        db.refresh(wallet)
    else:
        db.flush()
    return {"bet_id": bet.id, "round_id": round_id, "target_id": target_id, "requested_amount": amount, "accepted_amount": amount, "spent_coins": amount, "reward_coins": 0, "net_win_coins": -amount, "wallet_coin_balance": wallet.coin_balance, "winner_coin_balance": None, "risk_level": risk_level, "risk_score": risk_score, "risk_action": risk_action, "probability_mode": risk_meta.get("probability_mode", "NORMAL"), "message": "Bet accepted"}


def _payout_for_user_bets(user_bets: list[GameBet], winning_target_id: int) -> int:
    payout = 0
    for bet in user_bets:
        if bet.target_id not in _basket_target_ids(winning_target_id):
            continue
        multiplier = int(_target_by_id(int(bet.target_id))["multiplier"])
        payout += int(bet.accepted_amount) * multiplier
    return payout


def _round_top_winners(db: Session, round_id: int, winning_target_id: int) -> list[dict[str, Any]]:
    bet_rows = db.query(GameBet).filter(GameBet.round_id == round_id, GameBet.target_id.in_(_basket_target_ids(winning_target_id))).all()
    payouts: dict[int, int] = {}
    for bet in bet_rows:
        multiplier = int(_target_by_id(int(bet.target_id))["multiplier"])
        payouts[bet.user_id] = payouts.get(bet.user_id, 0) + int(bet.accepted_amount) * multiplier
    winners: list[dict[str, Any]] = []
    for user_id, coins in sorted(payouts.items(), key=lambda item: item[1], reverse=True)[:3]:
        user = db.query(User).filter(User.id == int(user_id)).first()
        display_name = getattr(user, "display_name", None) or getattr(user, "username", None) or f"User {user_id}"
        avatar = (display_name[:1] or "U").upper()
        winners.append({"user_id": int(user_id), "name": display_name, "avatar": avatar, "coins": int(coins)})
    return winners


def _candidate_payout(db: Session, round_id: int, outcome_id: int) -> int:
    total = 0
    for target_id in _basket_target_ids(outcome_id):
        multiplier = int(_target_by_id(target_id)["multiplier"])
        accepted = int(db.query(func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.round_id == round_id, GameBet.target_id == target_id).scalar() or 0)
        total += accepted * multiplier
    return total


def _bet_probability_mode(bet: GameBet) -> str:
    metadata = base._loads(bet.metadata_json, {})
    return str(metadata.get("probability_mode") or "NORMAL")


def _outcome_probability_mode(db: Session, round_id: int, outcome_id: int) -> str:
    severity = {"NORMAL": 0, "MEDIUM_WHALE": 1, "LOW_WHALE": 2, "VERY_LOW_WHALE": 3}
    selected = "NORMAL"
    rows = db.query(GameBet).filter(GameBet.round_id == round_id, GameBet.target_id.in_(_basket_target_ids(outcome_id))).all()
    for bet in rows:
        mode = _bet_probability_mode(bet)
        if severity.get(mode, 0) > severity.get(selected, 0):
            selected = mode
    return selected


def _mode_weight_scale_basis_points(mode: str, rules: dict[str, Any]) -> int:
    if mode == "VERY_LOW_WHALE":
        return max(int(rules.get("whale_block_target_weight_basis_points", 50)), 0)
    if mode == "LOW_WHALE":
        return max(int(rules.get("whale_high_target_weight_basis_points", 250)), 0)
    if mode == "MEDIUM_WHALE":
        return max(int(rules.get("whale_medium_target_weight_basis_points", 1000)), 0)
    return 10_000


def _choose_outcome(db: Session, round_obj: GameRound) -> int:
    metadata = base._loads(round_obj.metadata_json, {})
    rules = {**JUNGLE_RULES, **(metadata.get("rules") or {})}
    seed = f"{round_obj.id}:{round_obj.game_key}:{round_obj.created_at.isoformat()}:{round_obj.round_pool_amount}:basket-v2-whale-adjusted"
    rng = random.Random(int(hashlib.sha256(seed.encode("utf-8")).hexdigest()[:16], 16))
    max_liability = int(rules.get("max_round_liability", JUNGLE_RULES["max_round_liability"]))
    rare_basis_points = int(rules.get("rare_basket_probability_basis_points", JUNGLE_RULES["rare_basket_probability_basis_points"]))
    basket = LEFT_BASKET_ID if rng.random() < 0.5 else RIGHT_BASKET_ID
    basket_mode = _outcome_probability_mode(db, round_obj.id, basket)
    basket_scale = _mode_weight_scale_basis_points(basket_mode, rules)
    adjusted_rare_basis_points = max(1, rare_basis_points * basket_scale // 10_000)
    rare_roll = rng.randint(1, 10_000)
    if rare_roll <= adjusted_rare_basis_points and _candidate_payout(db, round_obj.id, basket) <= max_liability:
        return basket

    weighted: list[int] = []
    for target in JUNGLE_TARGETS:
        target_id = int(target["id"])
        multiplier = max(int(target.get("multiplier", 5)), 1)
        base_weight = max(1, 120 // multiplier)
        mode = _outcome_probability_mode(db, round_obj.id, target_id)
        scale = _mode_weight_scale_basis_points(mode, rules)
        weight = max(1, base_weight * scale // 10_000)
        weighted.extend([target_id] * weight)
    return rng.choice(weighted) if weighted else base._choose_winner(round_obj, JUNGLE_TARGETS)


def settle_round(db: Session, round_id: int, user: User, *, commit: bool = True) -> dict[str, Any]:
    round_obj = db.query(GameRound).filter(GameRound.id == round_id).first()
    if not round_obj:
        raise HTTPException(status_code=404, detail="Game round not found")
    if round_obj.game_key != JUNGLE_HUNT_KEY:
        return base.settle_round(db, round_id, user)
    metadata = base._loads(round_obj.metadata_json, {})
    winning_target_id = metadata.get("winning_target_id")
    if winning_target_id is None:
        winning_target_id = int(_choose_outcome(db, round_obj))
        winning_target = _target_by_id(winning_target_id)
        winning_probability_mode = _outcome_probability_mode(db, round_obj.id, winning_target_id)
        all_user_ids = [row[0] for row in db.query(GameBet.user_id).filter(GameBet.round_id == round_id).distinct().all()]
        settlement_multiplier = max(int(_target_by_id(target_id)["multiplier"]) for target_id in _basket_target_ids(winning_target_id))
        for user_id in all_user_ids:
            safe_user_id = int(user_id)
            user_bets = db.query(GameBet).filter(GameBet.round_id == round_id, GameBet.user_id == safe_user_id).all()
            total_bet = sum(int(bet.accepted_amount or 0) for bet in user_bets)
            payout = _payout_for_user_bets(user_bets, winning_target_id)
            if payout <= 0:
                game_stats_service.record_game_settlement(db, user_id=safe_user_id, game_id=round_obj.game_key, spent_coins=total_bet, reward_coins=0, multiplier=0)
                continue
            wallet = economy_service.get_or_create_wallet(db, safe_user_id)
            before = wallet.coin_balance
            wallet.coin_balance += payout
            db.add(WalletLedger(user_id=safe_user_id, currency_type=EconomyCurrency.COIN.value, direction=EconomyDirection.CREDIT.value, amount=payout, before_balance=before, after_balance=wallet.coin_balance, source_type="GAME_WIN", source_id=str(round_id), created_by_user_id=user.id, reason=f"Jungle Hunt win outcome {winning_target_id}"))
            game_stats_service.record_game_settlement(db, user_id=safe_user_id, game_id=round_obj.game_key, spent_coins=total_bet, reward_coins=payout, multiplier=settlement_multiplier)
        top_winners = _round_top_winners(db, round_id, winning_target_id)
        metadata.update({"winning_target_id": winning_target_id, "multiplier": int(winning_target["multiplier"]), "basket_target_ids": _basket_target_ids(winning_target_id), "top_winners": top_winners, "payouts_done": True, "whale_probability_mode": winning_probability_mode, "whale_probability_rule": "Whale bets are accepted, but targets with whale exposure receive reduced outcome probability."})
        round_obj.metadata_json = base._dumps(metadata)
        round_obj.status = GameRoundStatus.COMPLETED.value
        round_obj.ended_at = datetime.utcnow()
        base.audit(db, round_obj.game_key, round_obj.id, user.id, "GLOBAL_ROUND_SETTLED", "LOW", 0, "AUDIT", "Jungle Hunt round settled with whale probability adjustment instead of whale bet blocking.", {"winning_target_id": winning_target_id, "basket_target_ids": _basket_target_ids(winning_target_id), "top_winners": top_winners, "whale_probability_mode": winning_probability_mode}, user.id)
        if commit:
            db.commit()
        else:
            db.flush()
    else:
        winning_target_id = int(winning_target_id)
        top_winners = metadata.get("top_winners") or _round_top_winners(db, round_id, winning_target_id)
    user_bets = db.query(GameBet).filter(GameBet.round_id == round_id, GameBet.user_id == user.id).all()
    total_user_bet = sum(item.accepted_amount for item in user_bets)
    total_user_winnings = _payout_for_user_bets(user_bets, int(winning_target_id))
    wallet = economy_service.get_or_create_wallet(db, user.id)
    return {"round_id": round_id, "game_key": round_obj.game_key, "status": GameRoundStatus.COMPLETED.value, "winning_target_id": int(winning_target_id), "multiplier": int(_target_by_id(int(winning_target_id))["multiplier"]), "total_user_bet": total_user_bet, "total_user_winnings": total_user_winnings, "spent_coins": total_user_bet, "reward_coins": total_user_winnings, "net_win_coins": total_user_winnings - total_user_bet, "wallet_coin_balance": wallet.coin_balance, "winner_coin_balance": wallet.coin_balance if total_user_winnings > 0 else None, "risk_level": "LOW", "risk_score": 0, "risk_action": "AUDIT", "audit_message": "Payout uses only bets included in the winning outcome. Basket outcomes pay each selected basket item by its own multiplier. Whale tiers reduce probability instead of blocking accepted coins.", "top_winners": top_winners}