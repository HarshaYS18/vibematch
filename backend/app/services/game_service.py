import hashlib
import json
import random
from datetime import datetime, timedelta
from typing import Any

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.economy import EconomyCurrency, EconomyDirection, GameRound, GameRoundStatus, UserWallet, WalletLedger
from app.models.game import GameBet, GameDefinition, GameRiskAudit
from app.models.user import User
from app.services import economy_service

DEFAULT_TARGETS = [
    {"id": 0, "label": "Rabbit", "emoji": "🐰", "multiplier": 5, "theme_color": "#FF5CA8"},
    {"id": 1, "label": "Cat", "emoji": "🐱", "multiplier": 5, "theme_color": "#FF9F43"},
    {"id": 2, "label": "Dog", "emoji": "🐶", "multiplier": 5, "theme_color": "#A66A43"},
    {"id": 3, "label": "Sheep", "emoji": "🐑", "multiplier": 5, "theme_color": "#F5F7FA"},
    {"id": 4, "label": "Dolphin", "emoji": "🐬", "multiplier": 10, "theme_color": "#38BDF8"},
    {"id": 5, "label": "Panda", "emoji": "🐼", "multiplier": 15, "theme_color": "#E5E7EB"},
    {"id": 6, "label": "Eagle", "emoji": "🦅", "multiplier": 25, "theme_color": "#FBBF24"},
    {"id": 7, "label": "Lion", "emoji": "🦁", "multiplier": 45, "theme_color": "#F43F5E"},
]

DEFAULT_RULES = {
    "round_seconds": 24,
    "lock_seconds": 1,
    "result_seconds": 5,
    "allowed_bets": [400, 10_000, 100_000],
    "custom_bet_enabled": True,
    "min_bet": 100,
    "max_bet": 100_000,
    "max_total_bet_per_round": 300_000,
    "platform_fee_basis_points": 500,
    "targets": DEFAULT_TARGETS,
}

DEFAULT_RISK = {
    "enabled": True,
    "max_daily_loss": 500_000,
    "max_daily_bet_volume": 2_000_000,
    "max_single_bet_low": 100_000,
    "max_single_bet_medium": 50_000,
    "max_single_bet_high": 10_000,
    "force_min_bet_extreme": 400,
    "cooldown_seconds_high_risk": 300,
    "manual_review_score": 90,
    "block_score": 120,
}

DEFAULT_UI = {
    "title": "Jackpot King",
    "subtitle": "ZyloVibes Room Game",
    "theme": "zylovibes_luxury_dark",
    "layout": "room_overlay_60_percent",
    "currency_label": "coins",
}


def _loads(raw: str | None, fallback: dict[str, Any]) -> dict[str, Any]:
    if not raw:
        return dict(fallback)
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            merged = dict(fallback)
            merged.update(parsed)
            return merged
    except json.JSONDecodeError:
        pass
    return dict(fallback)


def _dumps(data: dict[str, Any]) -> str:
    return json.dumps(data, ensure_ascii=False, separators=(",", ":"))


def _definition_payload(definition: GameDefinition) -> dict[str, Any]:
    return {
        "game_key": definition.game_key,
        "display_name": definition.display_name,
        "category": definition.category,
        "is_enabled": definition.is_enabled,
        "is_coin_game": definition.is_coin_game,
        "min_app_version": definition.min_app_version,
        "config_version": definition.config_version,
        "cdn_base_url": definition.cdn_base_url,
        "config_url": definition.config_url,
        "asset_manifest_url": definition.asset_manifest_url,
        "ui_config": _loads(definition.ui_config_json, DEFAULT_UI),
        "rules": _loads(definition.rules_json, DEFAULT_RULES),
        "risk": _loads(definition.risk_config_json, DEFAULT_RISK),
    }


def seed_default_games(db: Session, actor: User | None = None) -> GameDefinition:
    existing = db.query(GameDefinition).filter(GameDefinition.game_key == "jackpot_king").first()
    if existing:
        return existing
    definition = GameDefinition(
        game_key="jackpot_king",
        display_name="Jackpot King",
        category="coin",
        is_enabled=True,
        is_coin_game=True,
        min_app_version="1.0.0",
        config_version=1,
        cdn_base_url=None,
        config_url=None,
        asset_manifest_url=None,
        ui_config_json=_dumps(DEFAULT_UI),
        rules_json=_dumps(DEFAULT_RULES),
        risk_config_json=_dumps(DEFAULT_RISK),
        created_by_user_id=actor.id if actor else None,
        updated_by_user_id=actor.id if actor else None,
    )
    db.add(definition)
    db.commit()
    db.refresh(definition)
    return definition


def list_catalog(db: Session, include_disabled: bool = False) -> list[dict[str, Any]]:
    query = db.query(GameDefinition)
    if not include_disabled:
        query = query.filter(GameDefinition.is_enabled.is_(True))
    definitions = query.order_by(GameDefinition.category.asc(), GameDefinition.display_name.asc()).all()
    if not definitions and not include_disabled:
        definitions = [seed_default_games(db)]
    return [_definition_payload(item) for item in definitions]


def get_definition(db: Session, game_key: str, include_disabled: bool = False) -> GameDefinition:
    definition = db.query(GameDefinition).filter(GameDefinition.game_key == game_key).first()
    if not definition and game_key == "jackpot_king":
        definition = seed_default_games(db)
    if not definition:
        raise HTTPException(status_code=404, detail="Game not found")
    if not include_disabled and not definition.is_enabled:
        raise HTTPException(status_code=403, detail="Game is disabled")
    return definition


def upsert_definition(db: Session, actor: User, game_key: str, payload: dict[str, Any]) -> GameDefinition:
    definition = db.query(GameDefinition).filter(GameDefinition.game_key == game_key).first()
    if not definition:
        definition = GameDefinition(
            game_key=game_key,
            display_name=payload["display_name"],
            category=payload.get("category", "coin"),
            created_by_user_id=actor.id,
            ui_config_json="{}",
            rules_json="{}",
            risk_config_json="{}",
        )
        db.add(definition)
    definition.display_name = payload["display_name"]
    definition.category = payload.get("category", definition.category)
    definition.is_enabled = payload.get("is_enabled", definition.is_enabled)
    definition.is_coin_game = payload.get("is_coin_game", definition.is_coin_game)
    definition.min_app_version = payload.get("min_app_version", definition.min_app_version)
    definition.config_version = payload.get("config_version", definition.config_version)
    definition.cdn_base_url = payload.get("cdn_base_url")
    definition.config_url = payload.get("config_url")
    definition.asset_manifest_url = payload.get("asset_manifest_url")
    definition.ui_config_json = _dumps(payload.get("ui_config") or DEFAULT_UI)
    definition.rules_json = _dumps(payload.get("rules") or DEFAULT_RULES)
    definition.risk_config_json = _dumps(payload.get("risk") or DEFAULT_RISK)
    definition.updated_by_user_id = actor.id
    db.commit()
    db.refresh(definition)
    audit(db, game_key, None, actor.id, "GAME_CONFIG_UPDATED", "LOW", 0, "ALLOW", "Game config updated", {"config_version": definition.config_version}, actor.id)
    return definition


def audit(db: Session, game_key: str, round_id: int | None, user_id: int | None, event_type: str, risk_level: str, risk_score: int, action: str, reason: str | None, metadata: dict[str, Any] | None, created_by_user_id: int | None = None) -> None:
    db.add(GameRiskAudit(
        game_key=game_key,
        round_id=round_id,
        user_id=user_id,
        event_type=event_type,
        risk_level=risk_level,
        risk_score=risk_score,
        action=action,
        reason=reason,
        metadata_json=_dumps(metadata or {}),
        created_by_user_id=created_by_user_id,
    ))


def create_round(db: Session, game_key: str, user: User, room_id: int | None = None) -> GameRound:
    definition = get_definition(db, game_key)
    rules = _loads(definition.rules_json, DEFAULT_RULES)
    round_obj = GameRound(
        game_key=game_key,
        room_id=room_id,
        status=GameRoundStatus.WAITING.value,
        entry_fee=0,
        max_players=999,
        metadata_json=_dumps({
            "config_version": definition.config_version,
            "created_by_user_id": user.id,
            "round_seconds": rules.get("round_seconds", 24),
            "cdn_base_url": definition.cdn_base_url,
        }),
    )
    db.add(round_obj)
    db.commit()
    db.refresh(round_obj)
    audit(db, game_key, round_obj.id, user.id, "ROUND_CREATED", "LOW", 0, "ALLOW", "Round created", {"room_id": room_id}, user.id)
    db.commit()
    return round_obj


def _round_payload(round_obj: GameRound) -> dict[str, Any]:
    return {
        "id": round_obj.id,
        "game_key": round_obj.game_key,
        "room_id": round_obj.room_id,
        "status": round_obj.status,
        "entry_fee": round_obj.entry_fee,
        "max_players": round_obj.max_players,
        "round_pool_amount": round_obj.round_pool_amount,
        "platform_fee_amount": round_obj.platform_fee_amount,
        "reward_pool_amount": round_obj.reward_pool_amount,
        "metadata": _loads(round_obj.metadata_json, {}),
    }


def get_round_payload(db: Session, round_id: int, user: User | None = None) -> dict[str, Any]:
    round_obj = db.query(GameRound).filter(GameRound.id == round_id).first()
    if not round_obj:
        raise HTTPException(status_code=404, detail="Game round not found")
    return _round_payload(round_obj)


def _user_bet_volume(db: Session, user_id: int, since: datetime) -> int:
    value = db.query(func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.user_id == user_id, GameBet.created_at >= since).scalar()
    return int(value or 0)


def _user_wallet_net_loss(db: Session, user_id: int, since: datetime) -> int:
    debits = db.query(func.coalesce(func.sum(WalletLedger.amount), 0)).filter(WalletLedger.user_id == user_id, WalletLedger.source_type == "GAME_BET", WalletLedger.created_at >= since).scalar()
    credits = db.query(func.coalesce(func.sum(WalletLedger.amount), 0)).filter(WalletLedger.user_id == user_id, WalletLedger.source_type == "GAME_WIN", WalletLedger.created_at >= since).scalar()
    return max(int(debits or 0) - int(credits or 0), 0)


def evaluate_risk(db: Session, user: User, requested_amount: int, round_obj: GameRound, risk: dict[str, Any], min_bet: int = 100) -> dict[str, Any]:
    if not risk.get("enabled", True):
        return {"level": "LOW", "score": 0, "action": "ALLOW", "accepted_amount": requested_amount, "reasons": []}

    since = datetime.utcnow() - timedelta(hours=24)
    daily_volume = _user_bet_volume(db, user.id, since)
    daily_loss = _user_wallet_net_loss(db, user.id, since)
    score = 0
    reasons: list[str] = []

    if requested_amount >= risk.get("max_single_bet_low", 100_000):
        score += 25
        reasons.append("large_single_bet")
    if requested_amount >= risk.get("max_single_bet_low", 100_000) * 3:
        score += 35
        reasons.append("extreme_single_bet")
    if daily_volume + requested_amount > risk.get("max_daily_bet_volume", 2_000_000):
        score += 45
        reasons.append("daily_bet_volume_limit")
    if daily_loss > risk.get("max_daily_loss", 500_000):
        score += 55
        reasons.append("daily_loss_limit")

    recent_count = db.query(GameBet).filter(GameBet.user_id == user.id, GameBet.created_at >= datetime.utcnow() - timedelta(minutes=5)).count()
    if recent_count >= 10:
        score += 30
        reasons.append("high_bet_velocity")

    if score >= risk.get("block_score", 120):
        safe_min = max(int(risk.get("force_min_bet_extreme", 400)), int(min_bet))
        accepted = min(requested_amount, safe_min)
        return {"level": "EXTREME", "score": score, "action": "FORCE_MIN_LIMIT_AND_REVIEW", "accepted_amount": accepted, "reasons": reasons}
    if score >= risk.get("manual_review_score", 90):
        accepted = min(requested_amount, risk.get("max_single_bet_high", 10_000))
        accepted = max(min(accepted, requested_amount), min_bet)
        return {"level": "HIGH", "score": score, "action": "LIMIT_AND_REVIEW", "accepted_amount": accepted, "reasons": reasons}
    if score >= 50:
        accepted = min(requested_amount, risk.get("max_single_bet_medium", 50_000))
        accepted = max(min(accepted, requested_amount), min_bet)
        return {"level": "MEDIUM", "score": score, "action": "LIMIT", "accepted_amount": accepted, "reasons": reasons}
    accepted = min(requested_amount, risk.get("max_single_bet_low", 100_000))
    accepted = max(min(accepted, requested_amount), min_bet)
    return {"level": "LOW", "score": score, "action": "ALLOW", "accepted_amount": accepted, "reasons": reasons}


def place_bet(db: Session, round_id: int, user: User, target_id: int, amount: int) -> dict[str, Any]:
    round_obj = db.query(GameRound).filter(GameRound.id == round_id).first()
    if not round_obj:
        raise HTTPException(status_code=404, detail="Game round not found")
    if round_obj.status not in {GameRoundStatus.WAITING.value, GameRoundStatus.RUNNING.value}:
        raise HTTPException(status_code=400, detail="Betting is closed for this round")

    definition = get_definition(db, round_obj.game_key)
    rules = _loads(definition.rules_json, DEFAULT_RULES)
    risk = _loads(definition.risk_config_json, DEFAULT_RISK)
    targets = rules.get("targets") or DEFAULT_TARGETS
    valid_target_ids = {int(item["id"]) for item in targets}
    if target_id not in valid_target_ids:
        raise HTTPException(status_code=400, detail="Invalid game target")
    min_bet = int(rules.get("min_bet", 100))
    if amount < min_bet:
        raise HTTPException(status_code=400, detail="Bet is below minimum")
    if amount > int(rules.get("max_bet", 100_000)):
        raise HTTPException(status_code=400, detail="Bet is above game maximum")

    existing_total = db.query(func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.round_id == round_id, GameBet.user_id == user.id).scalar()
    round_limit = int(rules.get("max_total_bet_per_round", 300_000))
    remaining_round_limit = round_limit - int(existing_total or 0)
    if remaining_round_limit < min_bet:
        raise HTTPException(status_code=400, detail="Round bet limit reached")
    risk_input_amount = min(amount, remaining_round_limit)

    risk_result = evaluate_risk(db, user, risk_input_amount, round_obj, risk, min_bet=min_bet)
    accepted_amount = int(risk_result["accepted_amount"])
    accepted_amount = min(accepted_amount, remaining_round_limit, amount)
    if accepted_amount < min_bet:
        accepted_amount = min_bet

    wallet = economy_service.get_or_create_wallet(db, user.id)
    before = wallet.coin_balance
    if before < accepted_amount:
        raise HTTPException(status_code=400, detail="Insufficient coin balance")
    wallet.coin_balance -= accepted_amount
    wallet.lifetime_coins_spent += accepted_amount
    db.add(WalletLedger(user_id=user.id, currency_type=EconomyCurrency.COIN.value, direction=EconomyDirection.DEBIT.value, amount=accepted_amount, before_balance=before, after_balance=wallet.coin_balance, source_type="GAME_BET", source_id=str(round_id), created_by_user_id=user.id, reason=f"Bet on {round_obj.game_key}:{target_id}"))

    bet = GameBet(round_id=round_id, user_id=user.id, target_id=target_id, amount=amount, accepted_amount=accepted_amount, risk_level=risk_result["level"], risk_score=risk_result["score"], risk_action=risk_result["action"], metadata_json=_dumps({"reasons": risk_result["reasons"], "config_version": definition.config_version, "remaining_round_limit_before_bet": remaining_round_limit}))
    db.add(bet)
    round_obj.round_pool_amount += accepted_amount
    platform_fee = accepted_amount * int(rules.get("platform_fee_basis_points", 500)) // 10_000
    round_obj.platform_fee_amount += platform_fee
    round_obj.reward_pool_amount += max(accepted_amount - platform_fee, 0)
    audit(db, round_obj.game_key, round_obj.id, user.id, "BET_ACCEPTED", risk_result["level"], risk_result["score"], risk_result["action"], "Bet accepted with safety auto-limit controls", {"requested_amount": amount, "accepted_amount": accepted_amount, "target_id": target_id, "reasons": risk_result["reasons"]}, user.id)
    db.commit()
    db.refresh(bet)
    db.refresh(wallet)
    message = "Bet accepted" if accepted_amount == amount else "Bet accepted with safety limit"
    return {"bet_id": bet.id, "round_id": round_id, "target_id": target_id, "requested_amount": amount, "accepted_amount": accepted_amount, "wallet_coin_balance": wallet.coin_balance, "risk_level": risk_result["level"], "risk_score": risk_result["score"], "risk_action": risk_result["action"], "message": message}


def _choose_winner(round_obj: GameRound, targets: list[dict[str, Any]]) -> int:
    seed = f"{round_obj.id}:{round_obj.game_key}:{round_obj.created_at.isoformat()}:{round_obj.round_pool_amount}"
    digest = hashlib.sha256(seed.encode("utf-8")).hexdigest()
    rng = random.Random(int(digest[:16], 16))
    weighted: list[int] = []
    for target in targets:
        multiplier = int(target.get("multiplier", 5))
        weight = max(1, 100 // multiplier)
        weighted.extend([int(target["id"])] * weight)
    return rng.choice(weighted)


def settle_round(db: Session, round_id: int, user: User) -> dict[str, Any]:
    round_obj = db.query(GameRound).filter(GameRound.id == round_id).first()
    if not round_obj:
        raise HTTPException(status_code=404, detail="Game round not found")
    if round_obj.status == GameRoundStatus.COMPLETED.value:
        raise HTTPException(status_code=400, detail="Round already completed")

    definition = get_definition(db, round_obj.game_key)
    rules = _loads(definition.rules_json, DEFAULT_RULES)
    risk = _loads(definition.risk_config_json, DEFAULT_RISK)
    targets = rules.get("targets") or DEFAULT_TARGETS
    winning_target_id = _choose_winner(round_obj, targets)
    winning_target = next(item for item in targets if int(item["id"]) == winning_target_id)
    multiplier = int(winning_target.get("multiplier", 1))

    user_bets = db.query(GameBet).filter(GameBet.round_id == round_id, GameBet.user_id == user.id).all()
    total_user_bet = sum(item.accepted_amount for item in user_bets)
    total_user_winnings = sum(item.accepted_amount * multiplier for item in user_bets if item.target_id == winning_target_id)

    wallet = economy_service.get_or_create_wallet(db, user.id)
    if total_user_winnings > 0:
        before = wallet.coin_balance
        wallet.coin_balance += total_user_winnings
        db.add(WalletLedger(user_id=user.id, currency_type=EconomyCurrency.COIN.value, direction=EconomyDirection.CREDIT.value, amount=total_user_winnings, before_balance=before, after_balance=wallet.coin_balance, source_type="GAME_WIN", source_id=str(round_id), created_by_user_id=user.id, reason=f"Win on {round_obj.game_key}:{winning_target_id}"))

    round_obj.status = GameRoundStatus.COMPLETED.value
    round_obj.ended_at = datetime.utcnow()
    metadata = _loads(round_obj.metadata_json, {})
    metadata.update({"winning_target_id": winning_target_id, "multiplier": multiplier, "settled_by_user_id": user.id})
    round_obj.metadata_json = _dumps(metadata)

    risk_result = evaluate_risk(db, user, 0, round_obj, risk)
    audit(db, round_obj.game_key, round_obj.id, user.id, "ROUND_SETTLED", risk_result["level"], risk_result["score"], "AUDIT", "Round settled server-side with deterministic seed", {"winning_target_id": winning_target_id, "total_user_bet": total_user_bet, "total_user_winnings": total_user_winnings}, user.id)
    db.commit()
    db.refresh(wallet)
    return {"round_id": round_id, "game_key": round_obj.game_key, "status": round_obj.status, "winning_target_id": winning_target_id, "multiplier": multiplier, "total_user_bet": total_user_bet, "total_user_winnings": total_user_winnings, "wallet_coin_balance": wallet.coin_balance, "risk_level": risk_result["level"], "risk_score": risk_result["score"], "risk_action": "AUDIT", "audit_message": "Round settled server-side. Client cannot choose or change the winner."}
