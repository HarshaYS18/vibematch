from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.economy import EconomyCurrency, EconomyDirection, GameRound, WalletLedger
from app.models.game import GameBet, GameDefinition
from app.models.user import User
from app.services import economy_service
from app.services import game_service as base

JUNGLE_HUNT_KEY = base.JUNGLE_HUNT_KEY

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
    "platform_fee_basis_points": 500,
    "targets": JUNGLE_TARGETS,
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
}

JUNGLE_UI: dict[str, Any] = {
    **base.DEFAULT_UI,
    "title": "Jungle Hunt",
    "subtitle": "Global Vibe Match Game",
    "layout": "global_room_overlay_70_percent",
}


def _sync_jungle_definition(db: Session, actor: User | None = None) -> GameDefinition:
    definition = db.query(GameDefinition).filter(GameDefinition.game_key == JUNGLE_HUNT_KEY).first()
    if not definition:
        definition = GameDefinition(
            game_key=JUNGLE_HUNT_KEY,
            display_name="Jungle Hunt",
            category="coin",
            is_enabled=True,
            is_coin_game=True,
            min_app_version="1.0.0",
            config_version=3,
            ui_config_json=base._dumps(JUNGLE_UI),
            rules_json=base._dumps(JUNGLE_RULES),
            risk_config_json=base._dumps(JUNGLE_RISK),
            created_by_user_id=actor.id if actor else None,
            updated_by_user_id=actor.id if actor else None,
        )
        db.add(definition)
    else:
        definition.display_name = "Jungle Hunt"
        definition.is_enabled = True
        definition.is_coin_game = True
        definition.config_version = max(int(definition.config_version or 1), 3)
        definition.ui_config_json = base._dumps(JUNGLE_UI)
        definition.rules_json = base._dumps(JUNGLE_RULES)
        definition.risk_config_json = base._dumps(JUNGLE_RISK)
        if actor:
            definition.updated_by_user_id = actor.id
    db.commit()
    db.refresh(definition)
    return definition


def seed_default_games(db: Session, actor: User | None = None) -> GameDefinition:
    return _sync_jungle_definition(db, actor)


def list_catalog(db: Session, include_disabled: bool = False) -> list[dict[str, Any]]:
    _sync_jungle_definition(db)
    return base.list_catalog(db, include_disabled=include_disabled)


def get_definition(db: Session, game_key: str, include_disabled: bool = False) -> GameDefinition:
    if game_key in {"jungle_hunt", JUNGLE_HUNT_KEY}:
        _sync_jungle_definition(db)
        game_key = JUNGLE_HUNT_KEY
    return base.get_definition(db, game_key, include_disabled=include_disabled)


def _definition_payload(definition: GameDefinition) -> dict[str, Any]:
    return base._definition_payload(definition)


def upsert_definition(db: Session, actor: User, game_key: str, payload: dict[str, Any]) -> GameDefinition:
    return base.upsert_definition(db, actor, game_key, payload)


def create_round(db: Session, game_key: str, user: User, room_id: int | None = None) -> GameRound:
    if game_key in {"jungle_hunt", JUNGLE_HUNT_KEY}:
        _sync_jungle_definition(db)
        return base.get_or_create_global_round(db, JUNGLE_HUNT_KEY, user)
    return base.create_round(db, game_key, user, room_id)


def get_round_payload(db: Session, round_id: int, user: User | None = None) -> dict[str, Any]:
    return base.get_round_payload(db, round_id, user)


def _reject_bet(db: Session, round_obj: GameRound, user: User, target_id: int, amount: int, action: str, message: str, metadata: dict[str, Any] | None = None) -> dict[str, Any]:
    wallet = economy_service.get_or_create_wallet(db, user.id)
    base.audit(db, round_obj.game_key, round_obj.id, user.id, "BET_REJECTED", "HIGH", 0, action, message, {"requested_amount": amount, "target_id": target_id, **(metadata or {})}, user.id)
    db.commit()
    return {
        "bet_id": None,
        "round_id": round_obj.id,
        "target_id": target_id,
        "requested_amount": amount,
        "accepted_amount": 0,
        "wallet_coin_balance": wallet.coin_balance,
        "risk_level": "HIGH",
        "risk_score": 0,
        "risk_action": action,
        "message": message,
    }


def _evaluate_whale_risk(db: Session, user: User, amount: int) -> tuple[bool, str, dict[str, Any]]:
    since_day = datetime.utcnow() - timedelta(hours=24)
    since_recent = datetime.utcnow() - timedelta(minutes=5)
    daily_volume = int(db.query(func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.user_id == user.id, GameBet.created_at >= since_day).scalar() or 0)
    debits = int(db.query(func.coalesce(func.sum(WalletLedger.amount), 0)).filter(WalletLedger.user_id == user.id, WalletLedger.source_type == "GAME_BET", WalletLedger.created_at >= since_day).scalar() or 0)
    credits = int(db.query(func.coalesce(func.sum(WalletLedger.amount), 0)).filter(WalletLedger.user_id == user.id, WalletLedger.source_type == "GAME_WIN", WalletLedger.created_at >= since_day).scalar() or 0)
    recent_count = db.query(GameBet).filter(GameBet.user_id == user.id, GameBet.created_at >= since_recent).count()
    daily_loss = max(debits - credits, 0)
    reasons: list[str] = []
    if amount >= int(JUNGLE_RISK["whale_single_bet"]):
        reasons.append("large_single_bet")
    if daily_volume + amount > int(JUNGLE_RISK["max_daily_bet_volume"]):
        reasons.append("daily_volume_limit")
    if daily_loss > int(JUNGLE_RISK["max_daily_loss"]):
        reasons.append("daily_loss_limit")
    if recent_count >= int(JUNGLE_RISK["whale_recent_bet_count"]):
        reasons.append("high_velocity")
    blocked = "daily_volume_limit" in reasons or "daily_loss_limit" in reasons or len(reasons) >= 2
    return blocked, ",".join(reasons), {"daily_volume": daily_volume, "daily_loss": daily_loss, "recent_count": recent_count, "reasons": reasons}


def place_bet(db: Session, round_id: int, user: User, target_id: int, amount: int) -> dict[str, Any]:
    round_obj = db.query(GameRound).filter(GameRound.id == round_id).first()
    if not round_obj:
        raise HTTPException(status_code=404, detail="Game round not found")
    if round_obj.game_key != JUNGLE_HUNT_KEY:
        return base.place_bet(db, round_id, user, target_id, amount)
    _sync_jungle_definition(db)
    phase = base._phase_metadata(round_obj, JUNGLE_RULES)
    if phase["phase"] != "BETTING":
        return _reject_bet(db, round_obj, user, target_id, amount, "BETTING_CLOSED", "Betting is closed for this round", phase)
    if int(phase.get("betting_seconds_left", 0)) <= int(JUNGLE_RULES["close_betting_last_seconds"]):
        return _reject_bet(db, round_obj, user, target_id, amount, "LAST_SECONDS_LOCKED", "Betting is locked in the last 2 seconds", phase)
    target_map = {int(item["id"]): item for item in JUNGLE_TARGETS}
    if target_id not in target_map:
        raise HTTPException(status_code=400, detail="Invalid game target")
    if amount not in {10_000, 50_000, 100_000, 500_000, 1_000_000}:
        return _reject_bet(db, round_obj, user, target_id, amount, "INVALID_BET_AMOUNT", "Use one of the allowed bet chips")
    distinct_targets = {row[0] for row in db.query(GameBet.target_id).filter(GameBet.round_id == round_id, GameBet.user_id == user.id).distinct().all()}
    if target_id not in distinct_targets and len(distinct_targets) >= 6:
        return _reject_bet(db, round_obj, user, target_id, amount, "TARGET_LIMIT_REACHED", "You can bid on only 6 items per round")
    existing_total = int(db.query(func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.round_id == round_id, GameBet.user_id == user.id).scalar() or 0)
    if existing_total + amount > int(JUNGLE_RULES["max_total_bet_per_round"]):
        return _reject_bet(db, round_obj, user, target_id, amount, "ROUND_USER_LIMIT", "Round bet limit reached")
    blocked, reason, risk_meta = _evaluate_whale_risk(db, user, amount)
    if blocked:
        return _reject_bet(db, round_obj, user, target_id, amount, "REJECT_WHALE_RISK", "Bet rejected by strict whale detection", risk_meta)
    multiplier = int(target_map[target_id]["multiplier"])
    target_total_after = int(db.query(func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.round_id == round_id, GameBet.target_id == target_id).scalar() or 0) + amount
    target_liability = target_total_after * multiplier
    if target_liability > int(JUNGLE_RULES["max_target_liability"]):
        return _reject_bet(db, round_obj, user, target_id, amount, "HIGH_TARGET_LIABILITY", "Bet not accepted because this item liability is too high", {"target_liability": target_liability, "multiplier": multiplier})
    all_target_totals = dict(db.query(GameBet.target_id, func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.round_id == round_id).group_by(GameBet.target_id).all())
    all_target_totals[target_id] = target_total_after
    worst_liability = 0
    for item in JUNGLE_TARGETS:
        worst_liability = max(worst_liability, int(all_target_totals.get(item["id"], 0)) * int(item["multiplier"]))
    if worst_liability > int(JUNGLE_RULES["max_round_liability"]):
        return _reject_bet(db, round_obj, user, target_id, amount, "HIGH_ROUND_LIABILITY", "Bet not accepted because round liability is too high", {"worst_liability": worst_liability})
    wallet = economy_service.get_or_create_wallet(db, user.id)
    if wallet.coin_balance < amount:
        raise HTTPException(status_code=400, detail="Insufficient coin balance")
    before = wallet.coin_balance
    wallet.coin_balance -= amount
    wallet.lifetime_coins_spent += amount
    db.add(WalletLedger(user_id=user.id, currency_type=EconomyCurrency.COIN.value, direction=EconomyDirection.DEBIT.value, amount=amount, before_balance=before, after_balance=wallet.coin_balance, source_type="GAME_BET", source_id=str(round_id), created_by_user_id=user.id, reason=f"Bet on Jungle Hunt:{target_id}"))
    bet = GameBet(round_id=round_id, user_id=user.id, target_id=target_id, amount=amount, accepted_amount=amount, risk_level="LOW", risk_score=0, risk_action="ALLOW", metadata_json=base._dumps({"scope": "GLOBAL", "whale_reason": reason}))
    db.add(bet)
    round_obj.round_pool_amount += amount
    platform_fee = amount * int(JUNGLE_RULES["platform_fee_basis_points"]) // 10_000
    round_obj.platform_fee_amount += platform_fee
    round_obj.reward_pool_amount += max(amount - platform_fee, 0)
    base.audit(db, round_obj.game_key, round_obj.id, user.id, "BET_ACCEPTED", "LOW", 0, "ALLOW", "Bet accepted after strict whale and liability checks", {"amount": amount, "target_id": target_id, "scope": "GLOBAL"}, user.id)
    db.commit()
    db.refresh(bet)
    db.refresh(wallet)
    return {"bet_id": bet.id, "round_id": round_id, "target_id": target_id, "requested_amount": amount, "accepted_amount": amount, "wallet_coin_balance": wallet.coin_balance, "risk_level": "LOW", "risk_score": 0, "risk_action": "ALLOW", "message": "Bet accepted"}


def settle_round(db: Session, round_id: int, user: User) -> dict[str, Any]:
    return base.settle_round(db, round_id, user)
