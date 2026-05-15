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
from app.services import economy_service, game_stats_service

JUNGLE_HUNT_KEY = "jungle_hunt"
LEGACY_JUNGLE_HUNT_KEYS = {"jackpot_king", "jungle_hunt"}

DEFAULT_TARGETS = [
    {"id": 0, "label": "Rabbit", "emoji": "🐰", "multiplier": 5, "theme_color": "#FF5CA8"},
    {"id": 1, "label": "Panda", "emoji": "🐼", "multiplier": 8, "theme_color": "#E5E7EB"},
    {"id": 2, "label": "Shark", "emoji": "🦈", "multiplier": 10, "theme_color": "#38BDF8"},
    {"id": 3, "label": "Monkey", "emoji": "🐵", "multiplier": 12, "theme_color": "#FF9F43"},
    {"id": 4, "label": "Fox", "emoji": "🦊", "multiplier": 15, "theme_color": "#F97316"},
    {"id": 5, "label": "Tiger", "emoji": "🐯", "multiplier": 25, "theme_color": "#FBBF24"},
    {"id": 6, "label": "Eagle", "emoji": "🦅", "multiplier": 30, "theme_color": "#A855F7"},
    {"id": 7, "label": "Lion", "emoji": "🦁", "multiplier": 45, "theme_color": "#F43F5E"},
]

DEFAULT_RULES = {
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
    "soft_cap_ignore_after_taps": 1,
    "soft_cap_loading_message": "Bet rejected for round safety",
    "platform_fee_basis_points": 500,
    "max_round_liability": 30_000_000,
    "max_target_liability": 12_000_000,
    "max_liability_to_pool_ratio_basis_points": 6500,
    "targets": DEFAULT_TARGETS,
}

DEFAULT_RISK = {
    "enabled": True,
    "max_daily_loss": 1_500_000,
    "max_daily_bet_volume": 6_000_000,
    "max_single_bet_low": 100_000,
    "max_single_bet_medium": 50_000,
    "max_single_bet_high": 10_000,
    "force_min_bet_extreme": 10_000,
    "cooldown_seconds_high_risk": 300,
    "manual_review_score": 70,
    "block_score": 95,
    "whale_daily_volume": 4_000_000,
    "whale_single_bet": 500_000,
    "whale_recent_bet_count": 8,
}

DEFAULT_UI = {
    "title": "Jungle Hunt",
    "subtitle": "Global Vibe Match Game",
    "theme": "jungle_hunt_premium",
    "layout": "global_room_overlay_70_percent",
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


def _utc_iso(value: datetime) -> str:
    return value.replace(microsecond=0).isoformat() + "Z"


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
    existing = db.query(GameDefinition).filter(GameDefinition.game_key.in_(LEGACY_JUNGLE_HUNT_KEYS)).first()
    if existing:
        existing.game_key = JUNGLE_HUNT_KEY
        existing.display_name = "Jungle Hunt"
        existing.ui_config_json = _dumps(DEFAULT_UI)
        existing.rules_json = _dumps(DEFAULT_RULES)
        existing.risk_config_json = _dumps(DEFAULT_RISK)
        existing.is_enabled = True
        existing.is_coin_game = True
        existing.updated_by_user_id = actor.id if actor else existing.updated_by_user_id
        db.commit()
        db.refresh(existing)
        return existing
    definition = GameDefinition(
        game_key=JUNGLE_HUNT_KEY,
        display_name="Jungle Hunt",
        category="coin",
        is_enabled=True,
        is_coin_game=True,
        min_app_version="1.0.0",
        config_version=2,
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
    seed_default_games(db)
    query = db.query(GameDefinition)
    if not include_disabled:
        query = query.filter(GameDefinition.is_enabled.is_(True))
    definitions = query.order_by(GameDefinition.category.asc(), GameDefinition.display_name.asc()).all()
    return [_definition_payload(item) for item in definitions]


def get_definition(db: Session, game_key: str, include_disabled: bool = False) -> GameDefinition:
    normalized = JUNGLE_HUNT_KEY if game_key in LEGACY_JUNGLE_HUNT_KEYS else game_key
    definition = db.query(GameDefinition).filter(GameDefinition.game_key == normalized).first()
    if not definition and normalized == JUNGLE_HUNT_KEY:
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
    db.commit()
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


def _phase_metadata(round_obj: GameRound, rules: dict[str, Any]) -> dict[str, Any]:
    now = datetime.utcnow()
    start = round_obj.started_at or round_obj.created_at
    round_seconds = int(rules.get("round_seconds", 30))
    lock_seconds = int(rules.get("lock_seconds", 2))
    reveal_seconds = int(rules.get("reveal_seconds", 15))
    result_seconds = int(rules.get("result_seconds", 3))
    elapsed = max(int((now - start).total_seconds()), 0)
    betting_left = max(round_seconds - elapsed, 0)
    reveal_left = max(round_seconds + reveal_seconds - elapsed, 0) if elapsed >= round_seconds else reveal_seconds
    total_cycle = round_seconds + lock_seconds + reveal_seconds + result_seconds
    if round_obj.status == GameRoundStatus.COMPLETED.value:
        phase = "RESULT"
    elif elapsed < round_seconds - int(rules.get("close_betting_last_seconds", 2)):
        phase = "BETTING"
    elif elapsed < round_seconds:
        phase = "LOCKED"
    elif elapsed < round_seconds + reveal_seconds:
        phase = "REVEALING"
    else:
        phase = "RESULT"
    return {
        "scope": "GLOBAL",
        "phase": phase,
        "server_now": _utc_iso(now),
        "started_at": _utc_iso(start),
        "betting_seconds": round_seconds,
        "lock_seconds": lock_seconds,
        "reveal_seconds": reveal_seconds,
        "result_seconds": result_seconds,
        "betting_seconds_left": betting_left,
        "reveal_seconds_left": reveal_left,
        "cycle_seconds": total_cycle,
    }


def _round_payload(round_obj: GameRound) -> dict[str, Any]:
    definition = None
    try:
        # Kept as defensive fallback for old rounds whose metadata predates the global engine.
        rules = _loads(round_obj.metadata_json, {}).get("rules") or DEFAULT_RULES
    except Exception:
        rules = DEFAULT_RULES
    metadata = _loads(round_obj.metadata_json, {})
    metadata.update(_phase_metadata(round_obj, rules))
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
        "metadata": metadata,
    }


def _create_global_round(db: Session, definition: GameDefinition, user: User | None) -> GameRound:
    rules = _loads(definition.rules_json, DEFAULT_RULES)
    now = datetime.utcnow()
    round_obj = GameRound(
        game_key=definition.game_key,
        room_id=None,
        status=GameRoundStatus.RUNNING.value,
        entry_fee=0,
        max_players=999999,
        started_at=now,
        metadata_json=_dumps({
            "scope": "GLOBAL",
            "game_key": definition.game_key,
            "config_version": definition.config_version,
            "created_by_user_id": user.id if user else None,
            "rules": rules,
            "targets": rules.get("targets") or DEFAULT_TARGETS,
        }),
    )
    db.add(round_obj)
    db.commit()
    db.refresh(round_obj)
    audit(db, definition.game_key, round_obj.id, user.id if user else None, "GLOBAL_ROUND_STARTED", "LOW", 0, "ALLOW", "Global Jungle Hunt round started", {"scope": "GLOBAL"}, user.id if user else None)
    db.commit()
    return round_obj


def create_round(db: Session, game_key: str, user: User, room_id: int | None = None) -> GameRound:
    definition = get_definition(db, game_key)
    if definition.game_key == JUNGLE_HUNT_KEY:
        return get_or_create_global_round(db, definition.game_key, user)
    rules = _loads(definition.rules_json, DEFAULT_RULES)
    round_obj = GameRound(
        game_key=definition.game_key,
        room_id=room_id,
        status=GameRoundStatus.RUNNING.value,
        entry_fee=0,
        max_players=999,
        started_at=datetime.utcnow(),
        metadata_json=_dumps({"config_version": definition.config_version, "created_by_user_id": user.id, "rules": rules}),
    )
    db.add(round_obj)
    db.commit()
    db.refresh(round_obj)
    audit(db, definition.game_key, round_obj.id, user.id, "ROUND_CREATED", "LOW", 0, "ALLOW", "Round created", {"room_id": room_id}, user.id)
    db.commit()
    return round_obj


def get_or_create_global_round(db: Session, game_key: str = JUNGLE_HUNT_KEY, user: User | None = None) -> GameRound:
    definition = get_definition(db, game_key)
    rules = _loads(definition.rules_json, DEFAULT_RULES)
    latest = db.query(GameRound).filter(GameRound.game_key == definition.game_key, GameRound.room_id.is_(None)).order_by(GameRound.id.desc()).first()
    if latest and latest.status != GameRoundStatus.COMPLETED.value:
        phase = _phase_metadata(latest, rules)["phase"]
        if phase in {"BETTING", "LOCKED", "REVEALING", "RESULT"}:
            return latest
    return _create_global_round(db, definition, user)


def get_round_payload(db: Session, round_id: int, user: User | None = None) -> dict[str, Any]:
    round_obj = db.query(GameRound).filter(GameRound.id == round_id).first()
    if not round_obj:
        raise HTTPException(status_code=404, detail="Game round not found")
    return _round_payload(round_obj)


def _user_bet_volume(db: Session, user_id: int, since: datetime) -> int:
    return int(db.query(func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.user_id == user_id, GameBet.created_at >= since).scalar() or 0)


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
    recent_count = db.query(GameBet).filter(GameBet.user_id == user.id, GameBet.created_at >= datetime.utcnow() - timedelta(minutes=5)).count()
    score = 0
    reasons: list[str] = []
    if requested_amount >= int(risk.get("whale_single_bet", 500_000)):
        score += 35
        reasons.append("whale_single_bet")
    if daily_volume + requested_amount > int(risk.get("whale_daily_volume", 4_000_000)):
        score += 35
        reasons.append("whale_daily_volume")
    if daily_volume + requested_amount > int(risk.get("max_daily_bet_volume", 6_000_000)):
        score += 55
        reasons.append("daily_bet_volume_limit")
    if daily_loss > int(risk.get("max_daily_loss", 1_500_000)):
        score += 45
        reasons.append("daily_loss_limit")
    if recent_count >= int(risk.get("whale_recent_bet_count", 8)):
        score += 30
        reasons.append("high_bet_velocity")
    if score >= int(risk.get("block_score", 95)):
        return {"level": "BLOCKED", "score": score, "action": "REJECT_WHALE_RISK", "accepted_amount": 0, "reasons": reasons}
    if score >= int(risk.get("manual_review_score", 70)):
        return {"level": "HIGH", "score": score, "action": "REJECT_REVIEW", "accepted_amount": 0, "reasons": reasons}
    return {"level": "LOW", "score": score, "action": "ALLOW", "accepted_amount": requested_amount, "reasons": reasons}


def _reject_bet(db: Session, round_obj: GameRound, user: User, target_id: int, amount: int, wallet: UserWallet, action: str, message: str, metadata: dict[str, Any] | None = None) -> dict[str, Any]:
    audit(db, round_obj.game_key, round_obj.id, user.id, "BET_REJECTED", "HIGH", 0, action, message, {"requested_amount": amount, "target_id": target_id, **(metadata or {})}, user.id)
    db.commit()
    return {"bet_id": None, "round_id": round_obj.id, "target_id": target_id, "requested_amount": amount, "accepted_amount": 0, "spent_coins": 0, "reward_coins": 0, "net_win_coins": 0, "wallet_coin_balance": wallet.coin_balance, "winner_coin_balance": None, "risk_level": "HIGH", "risk_score": 0, "risk_action": action, "message": message}


def _liability_if_accepted(db: Session, round_id: int, target_id: int, accepted_amount: int, multiplier: int) -> tuple[int, int]:
    target_total = int(db.query(func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.round_id == round_id, GameBet.target_id == target_id).scalar() or 0) + accepted_amount
    round_total = int(db.query(func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.round_id == round_id).scalar() or 0) + accepted_amount
    return target_total * multiplier, round_total


def place_bet(db: Session, round_id: int, user: User, target_id: int, amount: int) -> dict[str, Any]:
    round_obj = db.query(GameRound).filter(GameRound.id == round_id).first()
    if not round_obj:
        raise HTTPException(status_code=404, detail="Game round not found")
    definition = get_definition(db, round_obj.game_key)
    rules = _loads(definition.rules_json, DEFAULT_RULES)
    risk = _loads(definition.risk_config_json, DEFAULT_RISK)
    wallet = economy_service.get_or_create_wallet(db, user.id)
    phase = _phase_metadata(round_obj, rules)
    if phase["phase"] != "BETTING":
        return _reject_bet(db, round_obj, user, target_id, amount, wallet, "BETTING_CLOSED", "Betting is closed for this round", phase)
    if int(phase.get("betting_seconds_left", 0)) <= int(rules.get("close_betting_last_seconds", 2)):
        return _reject_bet(db, round_obj, user, target_id, amount, wallet, "LAST_SECONDS_LOCKED", "Betting is locked in the last 2 seconds", phase)
    targets = rules.get("targets") or DEFAULT_TARGETS
    target_map = {int(item["id"]): item for item in targets}
    if target_id not in target_map:
        raise HTTPException(status_code=400, detail="Invalid game target")
    allowed_bets = {int(item) for item in rules.get("allowed_bets", DEFAULT_RULES["allowed_bets"])}
    if amount not in allowed_bets:
        return _reject_bet(db, round_obj, user, target_id, amount, wallet, "INVALID_BET_AMOUNT", "Use one of the allowed bet chips", {"allowed_bets": sorted(allowed_bets)})
    if amount < int(rules.get("min_bet", 10_000)) or amount > int(rules.get("max_bet", 1_000_000)):
        return _reject_bet(db, round_obj, user, target_id, amount, wallet, "BET_RANGE_REJECTED", "Bet is outside allowed limits")
    distinct_targets = {row[0] for row in db.query(GameBet.target_id).filter(GameBet.round_id == round_id, GameBet.user_id == user.id).distinct().all()}
    if target_id not in distinct_targets and len(distinct_targets) >= int(rules.get("max_targets_per_user_round", 6)):
        return _reject_bet(db, round_obj, user, target_id, amount, wallet, "TARGET_LIMIT_REACHED", "You can bid on only 6 items per round")
    existing_total = int(db.query(func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.round_id == round_id, GameBet.user_id == user.id).scalar() or 0)
    if existing_total + amount > int(rules.get("max_total_bet_per_round", 6_000_000)):
        return _reject_bet(db, round_obj, user, target_id, amount, wallet, "ROUND_USER_LIMIT", "Round bet limit reached")
    risk_result = evaluate_risk(db, user, amount, round_obj, risk, min_bet=int(rules.get("min_bet", 10_000)))
    if int(risk_result["accepted_amount"]) <= 0:
        return _reject_bet(db, round_obj, user, target_id, amount, wallet, risk_result["action"], "Bet rejected by strict whale detection", {"reasons": risk_result["reasons"], "risk_score": risk_result["score"]})
    multiplier = int(target_map[target_id].get("multiplier", 1))
    target_liability, round_total_after = _liability_if_accepted(db, round_id, target_id, amount, multiplier)
    max_target_liability = int(rules.get("max_target_liability", 12_000_000))
    max_round_liability = int(rules.get("max_round_liability", 30_000_000))
    max_ratio = int(rules.get("max_liability_to_pool_ratio_basis_points", 6500))
    round_possible_liability = max(target_liability, round_total_after * multiplier)
    if target_liability > max_target_liability or round_possible_liability > max_round_liability or target_liability * 10_000 > max(round_total_after, 1) * max_ratio:
        return _reject_bet(db, round_obj, user, target_id, amount, wallet, "HIGH_LIABILITY_REJECTED", "Bet not accepted because liability is too high", {"target_liability": target_liability, "round_total_after": round_total_after, "multiplier": multiplier})
    if wallet.coin_balance < amount:
        raise HTTPException(status_code=400, detail="Insufficient coin balance")
    before = wallet.coin_balance
    wallet.coin_balance -= amount
    wallet.lifetime_coins_spent += amount
    db.add(WalletLedger(user_id=user.id, currency_type=EconomyCurrency.COIN.value, direction=EconomyDirection.DEBIT.value, amount=amount, before_balance=before, after_balance=wallet.coin_balance, source_type="GAME_BET", source_id=str(round_id), created_by_user_id=user.id, reason=f"Bet on {round_obj.game_key}:{target_id}"))
    bet = GameBet(round_id=round_id, user_id=user.id, target_id=target_id, amount=amount, accepted_amount=amount, risk_level=risk_result["level"], risk_score=risk_result["score"], risk_action=risk_result["action"], metadata_json=_dumps({"reasons": risk_result["reasons"], "scope": "GLOBAL"}))
    db.add(bet)
    round_obj.round_pool_amount += amount
    platform_fee = amount * int(rules.get("platform_fee_basis_points", 500)) // 10_000
    round_obj.platform_fee_amount += platform_fee
    round_obj.reward_pool_amount += max(amount - platform_fee, 0)
    game_stats_service.record_game_bet(db, user_id=user.id, game_id=round_obj.game_key, amount=amount)
    audit(db, round_obj.game_key, round_obj.id, user.id, "BET_ACCEPTED", risk_result["level"], risk_result["score"], risk_result["action"], "Bet accepted after whale and liability checks", {"amount": amount, "target_id": target_id, "scope": "GLOBAL"}, user.id)
    db.commit()
    db.refresh(bet)
    db.refresh(wallet)
    return {"bet_id": bet.id, "round_id": round_id, "target_id": target_id, "requested_amount": amount, "accepted_amount": amount, "spent_coins": amount, "reward_coins": 0, "net_win_coins": -amount, "wallet_coin_balance": wallet.coin_balance, "winner_coin_balance": None, "risk_level": risk_result["level"], "risk_score": risk_result["score"], "risk_action": risk_result["action"], "message": "Bet accepted"}


def _choose_winner(round_obj: GameRound, targets: list[dict[str, Any]]) -> int:
    seed = f"{round_obj.id}:{round_obj.game_key}:{round_obj.created_at.isoformat()}:{round_obj.round_pool_amount}"
    digest = hashlib.sha256(seed.encode("utf-8")).hexdigest()
    rng = random.Random(int(digest[:16], 16))
    weighted: list[int] = []
    for target in targets:
        multiplier = int(target.get("multiplier", 5))
        accepted_on_target = 1
        weight = max(1, 120 // max(multiplier, 1))
        weighted.extend([int(target["id"])] * max(weight - accepted_on_target, 1))
    return rng.choice(weighted)


def _round_top_winners(db: Session, round_id: int, winning_target_id: int, multiplier: int) -> list[dict[str, Any]]:
    rows = db.query(GameBet.user_id, func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.round_id == round_id, GameBet.target_id == winning_target_id).group_by(GameBet.user_id).order_by(func.coalesce(func.sum(GameBet.accepted_amount), 0).desc()).limit(3).all()
    winners: list[dict[str, Any]] = []
    for user_id, total_bet in rows:
        user = db.query(User).filter(User.id == int(user_id)).first()
        display_name = getattr(user, "display_name", None) or getattr(user, "username", None) or f"User {user_id}"
        avatar = (display_name[:1] or "U").upper()
        winners.append({"user_id": int(user_id), "name": display_name, "avatar": avatar, "coins": int(total_bet or 0) * multiplier})
    return winners


def settle_round(db: Session, round_id: int, user: User) -> dict[str, Any]:
    round_obj = db.query(GameRound).filter(GameRound.id == round_id).first()
    if not round_obj:
        raise HTTPException(status_code=404, detail="Game round not found")
    definition = get_definition(db, round_obj.game_key)
    rules = _loads(definition.rules_json, DEFAULT_RULES)
    risk = _loads(definition.risk_config_json, DEFAULT_RISK)
    targets = rules.get("targets") or DEFAULT_TARGETS
    metadata = _loads(round_obj.metadata_json, {})
    if metadata.get("winning_target_id") is None:
        winning_target_id = _choose_winner(round_obj, targets)
        winning_target = next(item for item in targets if int(item["id"]) == winning_target_id)
        multiplier = int(winning_target.get("multiplier", 1))
        all_rows = db.query(GameBet.user_id, func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.round_id == round_id).group_by(GameBet.user_id).all()
        winning_rows = db.query(GameBet.user_id, func.coalesce(func.sum(GameBet.accepted_amount), 0)).filter(GameBet.round_id == round_id, GameBet.target_id == winning_target_id).group_by(GameBet.user_id).all()
        winning_bets_by_user = {int(user_id): int(total_bet or 0) for user_id, total_bet in winning_rows}
        for user_id, total_bet in all_rows:
            safe_user_id = int(user_id)
            safe_total_bet = int(total_bet or 0)
            payout = winning_bets_by_user.get(safe_user_id, 0) * multiplier
            if payout <= 0:
                game_stats_service.record_game_settlement(db, user_id=safe_user_id, game_id=round_obj.game_key, spent_coins=safe_total_bet, reward_coins=0, multiplier=0)
                continue
            wallet = economy_service.get_or_create_wallet(db, safe_user_id)
            before = wallet.coin_balance
            wallet.coin_balance += payout
            db.add(WalletLedger(user_id=safe_user_id, currency_type=EconomyCurrency.COIN.value, direction=EconomyDirection.CREDIT.value, amount=payout, before_balance=before, after_balance=wallet.coin_balance, source_type="GAME_WIN", source_id=str(round_id), created_by_user_id=user.id, reason=f"Win on {round_obj.game_key}:{winning_target_id}"))
            game_stats_service.record_game_settlement(db, user_id=safe_user_id, game_id=round_obj.game_key, spent_coins=safe_total_bet, reward_coins=payout, multiplier=multiplier)
        top_winners = _round_top_winners(db, round_id, winning_target_id, multiplier)
        metadata.update({"winning_target_id": winning_target_id, "multiplier": multiplier, "settled_by_user_id": user.id, "top_winners": top_winners, "payouts_done": True})
        round_obj.metadata_json = _dumps(metadata)
        round_obj.status = GameRoundStatus.COMPLETED.value
        round_obj.ended_at = datetime.utcnow()
        audit(db, round_obj.game_key, round_obj.id, user.id, "GLOBAL_ROUND_SETTLED", "LOW", 0, "AUDIT", "Global round settled once for all users", {"winning_target_id": winning_target_id, "top_winners": top_winners}, user.id)
        db.commit()
    else:
        winning_target_id = int(metadata["winning_target_id"])
        multiplier = int(metadata.get("multiplier", 1))
        top_winners = metadata.get("top_winners") or _round_top_winners(db, round_id, winning_target_id, multiplier)
    user_bets = db.query(GameBet).filter(GameBet.round_id == round_id, GameBet.user_id == user.id).all()
    total_user_bet = sum(item.accepted_amount for item in user_bets)
    total_user_winnings = sum(item.accepted_amount * multiplier for item in user_bets if item.target_id == winning_target_id)
    wallet = economy_service.get_or_create_wallet(db, user.id)
    risk_result = evaluate_risk(db, user, 0, round_obj, risk)
    return {"round_id": round_id, "game_key": round_obj.game_key, "status": GameRoundStatus.COMPLETED.value, "winning_target_id": winning_target_id, "multiplier": multiplier, "total_user_bet": total_user_bet, "total_user_winnings": total_user_winnings, "spent_coins": total_user_bet, "reward_coins": total_user_winnings, "net_win_coins": total_user_winnings - total_user_bet, "wallet_coin_balance": wallet.coin_balance, "winner_coin_balance": wallet.coin_balance if total_user_winnings > 0 else None, "risk_level": risk_result["level"], "risk_score": risk_result["score"], "risk_action": "AUDIT", "audit_message": "Global round settled server-side. All rooms see the same result.", "top_winners": top_winners}




