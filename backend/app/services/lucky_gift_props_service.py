from __future__ import annotations

import json
import secrets
from typing import Any

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.economy_stats import LuckyGiftTransaction
from app.models.game import GameDefinition
from app.models.user import User

LUCKY_GIFT_KEY = "lucky_gifts"
_SECURE_RANDOM = secrets.SystemRandom()

DEFAULT_MULTIPLIERS: list[dict[str, Any]] = [
    {"multiplier": 0, "weight": 3600, "difficulty": "miss", "tier": "miss"},
    {"multiplier": 1, "weight": 4700, "difficulty": "easy", "tier": "small"},
    {"multiplier": 2, "weight": 1050, "difficulty": "easy", "tier": "small"},
    {"multiplier": 5, "weight": 450, "difficulty": "normal", "tier": "normal"},
    {"multiplier": 10, "weight": 150, "difficulty": "normal", "tier": "good"},
    {"multiplier": 20, "weight": 40, "difficulty": "medium", "tier": "big"},
    {"multiplier": 50, "weight": 8, "difficulty": "medium", "tier": "big"},
    {"multiplier": 100, "weight": 2, "difficulty": "hard", "tier": "mega"},
    {"multiplier": 500, "weight": 1, "difficulty": "very_hard", "tier": "legendary"},
    {"multiplier": 1000, "weight": 1, "difficulty": "mythic", "tier": "mythic"},
]

DEFAULT_RULES: dict[str, Any] = {
    "min_multiplier": 0,
    "max_multiplier": 1000,
    "broadcast_min_reward": 10000,
    "big_win_min_multiplier": 100,
    "special_scroll_multipliers": [100, 500, 1000],
    "payout_pool_safe_ratio_basis_points": 6500,
    "target_rtp_basis_points": 7200,
    "near_miss_enabled": True,
    "near_miss_min_spend": 99,
    "whale_medium_multiplier_weight_basis_points": 1000,
    "whale_high_multiplier_weight_basis_points": 220,
    "whale_block_multiplier_weight_basis_points": 30,
    "combo_probability_boost_enabled": True,
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
        return "mythic"
    if multiplier >= 500:
        return "very_hard"
    if multiplier >= 100:
        return "hard"
    if multiplier >= 20:
        return "medium"
    if multiplier >= 5:
        return "normal"
    if multiplier >= 1:
        return "easy"
    return "miss"


def _tier_for_multiplier(multiplier: int) -> str:
    if multiplier >= 1000:
        return "mythic"
    if multiplier >= 500:
        return "legendary"
    if multiplier >= 100:
        return "mega"
    if multiplier >= 20:
        return "big"
    if multiplier >= 10:
        return "good"
    if multiplier >= 5:
        return "normal"
    if multiplier >= 1:
        return "small"
    return "miss"


def _default_weight_for_multiplier(multiplier: int) -> int:
    for item in DEFAULT_MULTIPLIERS:
        if int(item["multiplier"]) == int(multiplier):
            return int(item["weight"])
    return 0


def _normalized_multiplier_rows(raw: Any) -> list[dict[str, Any]]:
    rows_by_multiplier: dict[int, dict[str, Any]] = {}
    source = raw if isinstance(raw, list) else DEFAULT_MULTIPLIERS
    for item in source:
        if not isinstance(item, dict):
            continue
        try:
            multiplier = int(item.get("multiplier"))
            weight = max(int(item.get("weight", 0)), 0)
        except Exception:
            continue
        if multiplier < 0 or multiplier > 1000:
            continue
        rows_by_multiplier[multiplier] = {
            "multiplier": multiplier,
            "weight": weight,
            "difficulty": str(item.get("difficulty") or _difficulty_for_multiplier(multiplier)),
            "tier": str(item.get("tier") or _tier_for_multiplier(multiplier)),
        }
    for default_item in DEFAULT_MULTIPLIERS:
        multiplier = int(default_item["multiplier"])
        existing = rows_by_multiplier.get(multiplier)
        if existing is None:
            rows_by_multiplier[multiplier] = dict(default_item)
            continue
        if multiplier in {100, 500, 1000} and int(existing.get("weight") or 0) <= 0:
            rows_by_multiplier[multiplier] = {
                **existing,
                "weight": _default_weight_for_multiplier(multiplier),
            }
    rows = sorted(rows_by_multiplier.values(), key=lambda item: int(item["multiplier"]))
    if not rows or sum(int(item["weight"]) for item in rows) <= 0:
        return [dict(item) for item in DEFAULT_MULTIPLIERS]
    return rows


def _combo_profile(quantity: int) -> tuple[str, dict[int, int]]:
    combo = max(int(quantity or 1), 1)
    if combo >= 999:
        return "MAX_COMBO_BOOST", {0: 7000, 1: 8500, 2: 8500, 5: 10500, 10: 11500, 20: 15000, 50: 17000, 100: 20000, 500: 10000, 1000: 5000}
    if combo >= 99:
        return "HIGH_COMBO_BOOST", {0: 8500, 1: 9500, 2: 9500, 5: 10500, 10: 11000, 20: 12500, 50: 13500, 100: 9000, 500: 2500, 1000: 1200}
    if combo >= 69:
        return "MID_COMBO_BOOST", {0: 9200, 1: 9800, 2: 9800, 5: 10200, 10: 10500, 20: 11200, 50: 12000, 100: 5000, 500: 1200, 1000: 600}
    if combo >= 9:
        return "SMALL_COMBO_HARD", {0: 10000, 1: 10000, 2: 10000, 5: 10000, 10: 10000, 20: 10000, 50: 10000, 100: 10000, 500: 10000, 1000: 10000}
    return "TINY_COMBO_VERY_HARD", {0: 11200, 1: 10200, 2: 9500, 5: 8500, 10: 6000, 20: 3500, 50: 2000, 100: 1000, 500: 300, 1000: 100}


def _apply_combo_probability_boost(rows: list[dict[str, Any]], rules: dict[str, Any], quantity: int) -> tuple[list[dict[str, Any]], str]:
    if rules.get("combo_probability_boost_enabled") is False:
        return rows, "DISABLED"
    profile, scale_by_multiplier = _combo_profile(quantity)
    adjusted: list[dict[str, Any]] = []
    for item in rows:
        multiplier = int(item["multiplier"])
        weight = int(item["weight"])
        scale_bp = int(scale_by_multiplier.get(multiplier, 10_000))
        next_weight = max(0, weight * scale_bp // 10_000)
        if multiplier in {100, 500, 1000} and weight > 0 and next_weight <= 0:
            next_weight = 1
        adjusted.append({**item, "weight": next_weight})
    if sum(int(item["weight"]) for item in adjusted) <= 0:
        return rows, "FALLBACK"
    return adjusted, profile


def _whale_weight_scale_basis_points(rules: dict[str, Any], risk_score: int) -> tuple[int, str]:
    safe_score = max(int(risk_score or 0), 0)
    if safe_score >= 95:
        return max(int(rules.get("whale_block_multiplier_weight_basis_points", 30)), 0), "VERY_LOW_WHALE"
    if safe_score >= 70:
        return max(int(rules.get("whale_high_multiplier_weight_basis_points", 220)), 0), "LOW_WHALE"
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
        if multiplier >= 100:
            weight = max(0, weight * scale_bp // 10_000)
        elif multiplier >= 10:
            weight = max(0, weight * max(scale_bp, 1200) // 10_000)
        elif multiplier >= 5 and scale_bp <= 220:
            weight = max(1, weight * 800 // 10_000)
        elif multiplier == 0:
            weight = max(weight, 3000)
        adjusted.append({**item, "weight": weight})
    return adjusted, mode, scale_bp


def _apply_payout_cap(rows: list[dict[str, Any]], *, spent: int, max_reward_coin_amount: int | None) -> tuple[list[dict[str, Any]], str | None]:
    if max_reward_coin_amount is None or max_reward_coin_amount <= 0:
        return rows, None
    capped: list[dict[str, Any]] = []
    for item in rows:
        multiplier = int(item["multiplier"])
        reward = spent * multiplier
        if reward > max_reward_coin_amount:
            capped.append({**item, "weight": 0})
        else:
            capped.append(item)
    if sum(int(item["weight"]) for item in capped) <= 0:
        return [{**item, "weight": 10000 if int(item["multiplier"]) == 0 else 0} for item in rows], "POOL_CAP_FORCED_MISS"
    return capped, "POOL_CAP_APPLIED"


def _secure_choice(rows: list[dict[str, Any]]) -> dict[str, Any]:
    total = sum(int(item["weight"]) for item in rows)
    if total <= 0:
        return {"multiplier": 0, "weight": 1, "difficulty": "miss", "tier": "miss"}
    pick = _SECURE_RANDOM.randrange(total)
    running = 0
    for item in rows:
        running += int(item["weight"])
        if pick < running:
            return item
    return rows[-1]


def get_or_create_definition(db: Session, actor: User | None = None) -> GameDefinition:
    definition = db.query(GameDefinition).filter(GameDefinition.game_key == LUCKY_GIFT_KEY).first()
    if definition is None:
        definition = GameDefinition(game_key=LUCKY_GIFT_KEY, display_name="Lucky Gifts", category="lucky_gift", is_enabled=True, is_coin_game=True, min_app_version="1.0.0", config_version=1, ui_config_json="{}", rules_json=_dumps(DEFAULT_RULES), risk_config_json=_dumps(DEFAULT_RISK), created_by_user_id=actor.id if actor else None, updated_by_user_id=actor.id if actor else None)
        db.add(definition)
        db.flush()
        return definition
    rules = _merged(DEFAULT_RULES, definition.rules_json)
    risk = _merged(DEFAULT_RISK, definition.risk_config_json)
    rules["multipliers"] = _normalized_multiplier_rows(rules.get("multipliers"))
    rules["min_multiplier"] = 0
    rules["max_multiplier"] = 1000
    rules["special_scroll_multipliers"] = [100, 500, 1000]
    rules.setdefault("combo_probability_boost_enabled", True)
    definition.display_name = "Lucky Gifts"
    definition.category = "lucky_gift"
    definition.is_enabled = True
    definition.is_coin_game = True
    definition.config_version = max(int(definition.config_version or 1), 2)
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
    rules["special_scroll_multipliers"] = [100, 500, 1000]
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
        "min_multiplier": int(rules.get("min_multiplier", 0)),
        "max_multiplier": int(rules.get("max_multiplier", 1000)),
        "broadcast_min_reward": int(rules.get("broadcast_min_reward", 10000)),
        "big_win_min_multiplier": int(rules.get("big_win_min_multiplier", 100)),
        "special_scroll_multipliers": [100, 500, 1000],
        "combo_probability_boost_enabled": bool(rules.get("combo_probability_boost_enabled", True)),
        "payout_pool_safe_ratio_basis_points": int(rules.get("payout_pool_safe_ratio_basis_points", 6500)),
        "target_rtp_basis_points": int(rules.get("target_rtp_basis_points", 7200)),
        "near_miss_enabled": bool(rules.get("near_miss_enabled", True)),
        "near_miss_min_spend": int(rules.get("near_miss_min_spend", 99)),
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
    for key in ["broadcast_min_reward", "big_win_min_multiplier", "payout_pool_safe_ratio_basis_points", "target_rtp_basis_points", "near_miss_min_spend"]:
        rules[key] = _as_int(payload, key, int(current.get(key, DEFAULT_RULES.get(key, 0))))
    rules["near_miss_enabled"] = _as_bool(payload, "near_miss_enabled", bool(current.get("near_miss_enabled", True)))
    rules["combo_probability_boost_enabled"] = _as_bool(payload, "combo_probability_boost_enabled", bool(current.get("combo_probability_boost_enabled", True)))
    for key in ["whale_medium_multiplier_weight_basis_points", "whale_high_multiplier_weight_basis_points", "whale_block_multiplier_weight_basis_points"]:
        rules[key] = _as_int(payload, key, int(rules.get(key, DEFAULT_RULES[key])))
    rules["min_multiplier"] = 0
    rules["max_multiplier"] = 1000
    rules["special_scroll_multipliers"] = [100, 500, 1000]
    rules["multipliers"] = _normalized_multiplier_rows(payload.get("multipliers", current["multipliers"]))
    risk["testing_mode_enabled"] = _as_bool(payload, "testing_mode_enabled", bool(current["testing_mode_enabled"]))
    risk["whale_probability_mode_enabled"] = _as_bool(payload, "whale_probability_mode_enabled", bool(risk.get("whale_probability_mode_enabled", True)))
    if "reason" in payload:
        risk["testing_mode_reason"] = str(payload.get("reason") or "Super Owner lucky gift props update")
    for key in ["max_daily_spend", "max_daily_loss", "whale_daily_spend", "whale_single_spend", "whale_recent_count", "whale_recent_window_minutes", "manual_review_score", "block_score"]:
        risk[key] = _as_int(payload, key, int(current[key]))
    definition.rules_json = _dumps(rules)
    definition.risk_config_json = _dumps(risk)
    definition.updated_by_user_id = actor.id
    db.commit()
    db.refresh(definition)
    return get_props(db)


def roll_lucky_gift(db: Session, *, gift_id: str, gift_name: str, base_coin_value: int, quantity: int, house_risk_score: int = 0, max_reward_coin_amount: int | None = None) -> dict[str, Any]:
    rules = load_rules(db)
    safe_quantity = max(int(quantity or 1), 1)
    spent = max(int(base_coin_value or 0), 0) * safe_quantity
    rows = _normalized_multiplier_rows(rules.get("multipliers"))
    rows, combo_probability_mode = _apply_combo_probability_boost(rows, rules, safe_quantity)
    rows, probability_mode, whale_weight_scale_basis_points = _apply_whale_probability_reduction(rows, rules, house_risk_score)
    rows, cap_mode = _apply_payout_cap(rows, spent=spent, max_reward_coin_amount=max_reward_coin_amount)
    selected = _secure_choice(rows)
    multiplier = int(selected.get("multiplier") or 0)
    reward = spent * multiplier
    tier = str(selected.get("tier") or _tier_for_multiplier(multiplier))
    special_scroll_multipliers = {100, 500, 1000}
    is_special_scroll_win = multiplier in special_scroll_multipliers
    near_miss = bool(rules.get("near_miss_enabled", True)) and multiplier == 0 and spent >= int(rules.get("near_miss_min_spend", 99))
    return {
        "gift_id": gift_id,
        "gift_name": gift_name,
        "multiplier": multiplier,
        "difficulty": str(selected.get("difficulty") or _difficulty_for_multiplier(multiplier)),
        "tier": tier,
        "display_tier": "near_miss" if near_miss else tier,
        "is_big_win": multiplier >= int(rules.get("big_win_min_multiplier", 100)),
        "is_broadcast_win": is_special_scroll_win,
        "is_special_scroll_win": is_special_scroll_win,
        "special_scroll_multipliers": [100, 500, 1000],
        "near_miss": near_miss,
        "reward_coin_amount": reward,
        "spent_coin_amount": spent,
        "net_coin_amount": reward - spent,
        "house_risk_score": house_risk_score,
        "probability_mode": probability_mode,
        "combo_probability_mode": combo_probability_mode,
        "pool_cap_mode": cap_mode,
        "whale_weight_scale_basis_points": whale_weight_scale_basis_points,
        "rng": "server_secure_rng",
        "rule": "Server-side secure lucky gift roll. Multipliers are 0x to 1000x. Combo size increases win probability, whale risk reduces high tiers, pool cap protects exposure, and special scrolls trigger only on 100x, 500x, and 1000x.",
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
        reasons.append("single_spend")
    if projected_spend > int(risk.get("whale_daily_spend", DEFAULT_RISK["whale_daily_spend"])):
        score += 35
        reasons.append("daily_spend")
    if projected_spend > int(risk.get("max_daily_spend", DEFAULT_RISK["max_daily_spend"])):
        score += 55
        reasons.append("max_daily_spend")
    if projected_loss > int(risk.get("max_daily_loss", DEFAULT_RISK["max_daily_loss"])):
        score += 45
        reasons.append("daily_loss")
    if recent_count >= int(risk.get("whale_recent_count", DEFAULT_RISK["whale_recent_count"])):
        score += 35
        reasons.append("velocity")
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
    return {"level": level, "score": score, "action": "ALLOW", "probability_mode": probability_mode, "reasons": reasons, "daily_spent": daily_spent, "daily_reward": daily_reward, "projected_spend": projected_spend, "projected_loss": projected_loss, "recent_count": recent_count, "rule": "Lucky gift accepts valid spend but reduces high-multiplier probability when risk rises."}