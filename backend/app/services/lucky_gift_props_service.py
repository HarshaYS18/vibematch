from __future__ import annotations

import json
from random import choices
from typing import Any

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.economy_stats import LuckyGiftTransaction
from app.models.game import GameDefinition
from app.models.user import User

LUCKY_GIFT_KEY = "lucky_gifts"

DEFAULT_MULTIPLIERS: list[dict[str, Any]] = [
    {"multiplier": 1, "weight": 7200, "difficulty": "easy"},
    {"multiplier": 2, "weight": 1500, "difficulty": "easy"},
    {"multiplier": 5, "weight": 760, "difficulty": "normal"},
    {"multiplier": 10, "weight": 330, "difficulty": "normal"},
    {"multiplier": 20, "weight": 130, "difficulty": "medium"},
    {"multiplier": 50, "weight": 55, "difficulty": "medium"},
    {"multiplier": 100, "weight": 18, "difficulty": "medium_hard"},
    {"multiplier": 500, "weight": 5, "difficulty": "hard"},
    {"multiplier": 1000, "weight": 2, "difficulty": "very_hard"},
]

DEFAULT_RULES: dict[str, Any] = {
    "min_multiplier": 1,
    "max_multiplier": 1000,
    "broadcast_min_reward": 10000,
    "big_win_min_multiplier": 100,
    "payout_pool_safe_ratio_basis_points": 6500,
    "whale_medium_multiplier_weight_basis_points": 1000,
    "whale_high_multiplier_weight_basis_points": 250,
    "whale_block_multiplier_weight_basis_points": 50,
    "multipliers": DEFAULT_MULTIPLIERS,
}

DEFAULT_RISK: dict[str, Any] = {
    "testing_mode_enabled": False,
    "max_daily_spend": 6_000_000,
    "max_daily_loss": 1_500_000,
    "whale_daily_spend": 4_000_000,
    "whale_single_spend": 500_000,
    "whale_recent_count": 8,
    "whale_recent_window_minutes": 5,
    "manual_review_score": 70,
    "block_score": 95,
    "whale_probability_mode_enabled": True,
}


def _loads(raw: str | None) -> dict[str, Any]:
    if not raw:
        return {}
    try:
        data = json.loads(raw)
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def _dumps(data: dict[str, Any]) -> str:
    return json.dumps(data, ensure_ascii=False, separators=(",", ":"))


def _merged(defaults: dict[str, Any], raw: str | None) -> dict[str, Any]:
    return {**defaults, **_loads(raw)}


def _as_int(payload: dict[str, Any], key: str, fallback: int) -> int:
    if key not in payload:
        return int(fallback)
    try:
        return int(payload.get(key))
    except Exception:
        return int(fallback)


def _as_bool(payload: dict[str, Any], key: str, fallback: bool) -> bool:
    if key not in payload:
        return fallback
    value = payload.get(key)
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"true", "1", "yes", "on"}
    return bool(value)


def _difficulty_for_multiplier(multiplier: int) -> str:
    if multiplier >= 1000:
        return "very_hard"
    if multiplier >= 500:
        return "hard"
    if multiplier >= 100:
        return "medium_hard"
    if multiplier >= 20:
        return "medium"
    if multiplier >= 5:
        return "normal"
    return "easy"


def _normalized_multiplier_rows(raw: Any) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    source = raw if isinstance(raw, list) else DEFAULT_MULTIPLIERS
    for item in source:
        if not isinstance(item, dict):
            continue
        try:
            multiplier = int(item.get("multiplier"))
            weight = max(int(item.get("weight", 0)), 0)
        except Exception:
            continue
        if multiplier < 1 or multiplier > 1000:
            continue
        rows.append(
            {
                "multiplier": multiplier,
                "weight": weight,
                "difficulty": str(item.get("difficulty") or _difficulty_for_multiplier(multiplier)),
            }
        )
    if not rows or sum(int(item["weight"]) for item in rows) <= 0:
        return [dict(item) for item in DEFAULT_MULTIPLIERS]
    return sorted(rows, key=lambda item: int(item["multiplier"]))


def _whale_weight_scale_basis_points(rules: dict[str, Any], risk_score: int) -> tuple[int, str]:
    safe_score = max(int(risk_score or 0), 0)
    if safe_score >= 95:
        return max(int(rules.get("whale_block_multiplier_weight_basis_points", 50)), 0), "VERY_LOW_WHALE"
    if safe_score >= 70:
        return max(int(rules.get("whale_high_multiplier_weight_basis_points", 250)), 0), "LOW_WHALE"
    if safe_score >= 35:
        return max(int(rules.get("whale_medium_multiplier_weight_basis_points", 1000)), 0), "MEDIUM_WHALE"
    return 10_000, "NORMAL"


def _apply_whale_probability_reduction(rows: list[dict[str, Any]], rules: dict[str, Any], risk_score: int) -> tuple[list[dict[str, Any]], str, int]:
    scale_bp, mode = _whale_weight_scale_basis_points(rules, risk_score)
    if mode == "NORMAL":
        return rows, mode, scale_bp

    adjusted: list[dict[str, Any]] = []
    for item in rows:
        multiplier = int(item["multiplier"])
        weight = int(item["weight"])
        if multiplier >= 10:
            weight = max(1, weight * scale_bp // 10_000)
        elif multiplier >= 5 and scale_bp <= 250:
            weight = max(1, weight * 1000 // 10_000)
        adjusted.append({**item, "weight": weight})
    return adjusted, mode, scale_bp


def get_or_create_definition(db: Session, actor: User | None = None) -> GameDefinition:
    definition = db.query(GameDefinition).filter(GameDefinition.game_key == LUCKY_GIFT_KEY).first()
    if definition is None:
        definition = GameDefinition(
            game_key=LUCKY_GIFT_KEY,
            display_name="Lucky Gifts",
            category="lucky_gift",
            is_enabled=True,
            is_coin_game=True,
            min_app_version="1.0.0",
            config_version=1,
            ui_config_json="{}",
            rules_json=_dumps(DEFAULT_RULES),
            risk_config_json=_dumps(DEFAULT_RISK),
            created_by_user_id=actor.id if actor else None,
            updated_by_user_id=actor.id if actor else None,
        )
        db.add(definition)
        db.flush()
        return definition

    rules = _merged(DEFAULT_RULES, definition.rules_json)
    risk = _merged(DEFAULT_RISK, definition.risk_config_json)
    rules["multipliers"] = _normalized_multiplier_rows(rules.get("multipliers"))
    definition.display_name = "Lucky Gifts"
    definition.category = "lucky_gift"
    definition.is_enabled = True
    definition.is_coin_game = True
    definition.config_version = max(int(definition.config_version or 1), 1)
    definition.rules_json = _dumps(rules)
    definition.risk_config_json = _dumps(risk)
    if actor is not None:
        definition.updated_by_user_id = actor.id
    db.flush()
    return definition


def load_rules(db: Session) -> dict[str, Any]:
    definition = get_or_create_definition(db)
    rules = _merged(DEFAULT_RULES, definition.rules_json)
    rules["multipliers"] = _normalized_multiplier_rows(rules.get("multipliers"))
    return rules


def load_risk(db: Session) -> dict[str, Any]:
    definition = get_or_create_definition(db)
    return _merged(DEFAULT_RISK, definition.risk_config_json)


def get_props(db: Session) -> dict[str, Any]:
    rules = load_rules(db)
    risk = load_risk(db)
    return {
        "game_key": LUCKY_GIFT_KEY,
        "testing_mode_enabled": risk.get("testing_mode_enabled") is True,
        "min_multiplier": int(rules.get("min_multiplier", 1)),
        "max_multiplier": int(rules.get("max_multiplier", 1000)),
        "broadcast_min_reward": int(rules.get("broadcast_min_reward", 10000)),
        "big_win_min_multiplier": int(rules.get("big_win_min_multiplier", 100)),
        "payout_pool_safe_ratio_basis_points": int(rules.get("payout_pool_safe_ratio_basis_points", 6500)),
        "max_daily_spend": int(risk.get("max_daily_spend", DEFAULT_RISK["max_daily_spend"])),
        "max_daily_loss": int(risk.get("max_daily_loss", DEFAULT_RISK["max_daily_loss"])),
        "whale_daily_spend": int(risk.get("whale_daily_spend", DEFAULT_RISK["whale_daily_spend"])),
        "whale_single_spend": int(risk.get("whale_single_spend", DEFAULT_RISK["whale_single_spend"])),
        "whale_recent_count": int(risk.get("whale_recent_count", DEFAULT_RISK["whale_recent_count"])),
        "whale_recent_window_minutes": int(risk.get("whale_recent_window_minutes", DEFAULT_RISK["whale_recent_window_minutes"])),
        "manual_review_score": int(risk.get("manual_review_score", DEFAULT_RISK["manual_review_score"])),
        "block_score": int(risk.get("block_score", DEFAULT_RISK["block_score"])),
        "multipliers": _normalized_multiplier_rows(rules.get("multipliers")),
    }


def update_props(db: Session, actor: User, payload: dict[str, Any]) -> dict[str, Any]:
    definition = get_or_create_definition(db, actor)
    current = get_props(db)
    rules = _merged(DEFAULT_RULES, definition.rules_json)
    risk = _merged(DEFAULT_RISK, definition.risk_config_json)

    for key in ["broadcast_min_reward", "big_win_min_multiplier", "payout_pool_safe_ratio_basis_points"]:
        rules[key] = _as_int(payload, key, int(current[key]))
    for key in ["whale_medium_multiplier_weight_basis_points", "whale_high_multiplier_weight_basis_points", "whale_block_multiplier_weight_basis_points"]:
        rules[key] = _as_int(payload, key, int(rules.get(key, DEFAULT_RULES[key])))
    rules["min_multiplier"] = 1
    rules["max_multiplier"] = 1000
    rules["multipliers"] = _normalized_multiplier_rows(payload.get("multipliers", current["multipliers"]))

    risk["testing_mode_enabled"] = _as_bool(payload, "testing_mode_enabled", bool(current["testing_mode_enabled"]))
    risk["whale_probability_mode_enabled"] = _as_bool(payload, "whale_probability_mode_enabled", bool(risk.get("whale_probability_mode_enabled", True)))
    if "reason" in payload:
        risk["testing_mode_reason"] = str(payload.get("reason") or "Super Owner lucky gift props update")
    for key in [
        "max_daily_spend",
        "max_daily_loss",
        "whale_daily_spend",
        "whale_single_spend",
        "whale_recent_count",
        "whale_recent_window_minutes",
        "manual_review_score",
        "block_score",
    ]:
        risk[key] = _as_int(payload, key, int(current[key]))

    definition.rules_json = _dumps(rules)
    definition.risk_config_json = _dumps(risk)
    definition.updated_by_user_id = actor.id
    db.commit()
    db.refresh(definition)
    return get_props(db)


def roll_lucky_gift(
    db: Session,
    *,
    gift_id: str,
    gift_name: str,
    base_coin_value: int,
    quantity: int,
    house_risk_score: int = 0,
) -> dict[str, Any]:
    rules = load_rules(db)
    rows = _normalized_multiplier_rows(rules.get("multipliers"))
    rows, probability_mode, whale_weight_scale_basis_points = _apply_whale_probability_reduction(rows, rules, house_risk_score)
    multiplier = int(choices([item["multiplier"] for item in rows], weights=[item["weight"] for item in rows], k=1)[0])
    selected = next((item for item in rows if int(item["multiplier"]) == multiplier), {"difficulty": _difficulty_for_multiplier(multiplier)})
    spent = max(int(base_coin_value or 0), 0) * max(int(quantity or 1), 1)
    reward = spent * multiplier
    return {
        "gift_id": gift_id,
        "gift_name": gift_name,
        "multiplier": multiplier,
        "difficulty": str(selected.get("difficulty") or _difficulty_for_multiplier(multiplier)),
        "reward_coin_amount": reward,
        "spent_coin_amount": spent,
        "house_risk_score": house_risk_score,
        "probability_mode": probability_mode,
        "whale_weight_scale_basis_points": whale_weight_scale_basis_points,
    }


def evaluate_whale_risk(db: Session, *, user_id: int, spend_amount: int) -> dict[str, Any]:
    risk = load_risk(db)
    if risk.get("testing_mode_enabled") is True:
        return {"level": "LOW", "score": 0, "action": "ALLOW", "probability_mode": "NORMAL", "reasons": ["testing_mode_enabled"]}

    from datetime import datetime, timedelta

    since_day = datetime.utcnow() - timedelta(hours=24)
    since_recent = datetime.utcnow() - timedelta(minutes=max(int(risk.get("whale_recent_window_minutes", 5)), 1))
    daily_spent = int(db.query(func.coalesce(func.sum(LuckyGiftTransaction.spent_coins), 0)).filter(LuckyGiftTransaction.sender_user_id == user_id, LuckyGiftTransaction.created_at >= since_day).scalar() or 0)
    daily_reward = int(db.query(func.coalesce(func.sum(LuckyGiftTransaction.reward_coins), 0)).filter(LuckyGiftTransaction.sender_user_id == user_id, LuckyGiftTransaction.created_at >= since_day).scalar() or 0)
    recent_count = int(db.query(func.count(LuckyGiftTransaction.id)).filter(LuckyGiftTransaction.sender_user_id == user_id, LuckyGiftTransaction.created_at >= since_recent).scalar() or 0)
    projected_spend = daily_spent + max(int(spend_amount or 0), 0)
    projected_loss = max(projected_spend - daily_reward, 0)

    score = 0
    reasons: list[str] = []
    if spend_amount >= int(risk.get("whale_single_spend", DEFAULT_RISK["whale_single_spend"])):
        score += 35
        reasons.append("whale_single_spend")
    if projected_spend > int(risk.get("whale_daily_spend", DEFAULT_RISK["whale_daily_spend"])):
        score += 35
        reasons.append("whale_daily_spend")
    if projected_spend > int(risk.get("max_daily_spend", DEFAULT_RISK["max_daily_spend"])):
        score += 55
        reasons.append("max_daily_spend")
    if projected_loss > int(risk.get("max_daily_loss", DEFAULT_RISK["max_daily_loss"])):
        score += 45
        reasons.append("max_daily_loss")
    if recent_count >= int(risk.get("whale_recent_count", DEFAULT_RISK["whale_recent_count"])):
        score += 35
        reasons.append("recent_velocity")

    block_score = int(risk.get("block_score", DEFAULT_RISK["block_score"]))
    manual_score = int(risk.get("manual_review_score", DEFAULT_RISK["manual_review_score"]))
    if score >= block_score:
        level = "WHALE_BLOCK_TIER"
        probability_mode = "VERY_LOW_WHALE"
    elif score >= manual_score:
        level = "WHALE_HIGH_TIER"
        probability_mode = "LOW_WHALE"
    elif score >= 35:
        level = "WHALE_MEDIUM_TIER"
        probability_mode = "MEDIUM_WHALE"
    else:
        level = "LOW"
        probability_mode = "NORMAL"

    return {
        "level": level,
        "score": score,
        "action": "ALLOW",
        "probability_mode": probability_mode,
        "reasons": reasons,
        "daily_spent": daily_spent,
        "daily_reward": daily_reward,
        "projected_spend": projected_spend,
        "projected_loss": projected_loss,
        "recent_count": recent_count,
        "rule": "Whale behavior accepts coins but reduces high-multiplier probability instead of blocking the send.",
    }
