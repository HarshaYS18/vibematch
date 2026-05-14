from __future__ import annotations

import json
from typing import Any

from sqlalchemy.orm import Session

from app.models.game import GameDefinition
from app.models.user import User
from app.services import global_jungle_game_service as jungle

GAME_KEY = "jungle_hunt"
LEGACY_KEYS = ["jungle_hunt", "jackpot_king"]


def _loads(raw: str | None) -> dict[str, Any]:
    if not raw:
        return {}
    try:
        data = json.loads(raw)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _dumps(data: dict[str, Any]) -> str:
    return json.dumps(data, ensure_ascii=False, separators=(",", ":"))


def _default_rules() -> dict[str, Any]:
    return dict(getattr(jungle, "JUNGLE_RULES", {}))


def _default_risk() -> dict[str, Any]:
    return dict(getattr(jungle, "JUNGLE_RISK", {}))


def _default_ui() -> dict[str, Any]:
    return dict(getattr(jungle, "JUNGLE_UI", {}))


def _rows(db: Session) -> list[GameDefinition]:
    return (
        db.query(GameDefinition)
        .filter(GameDefinition.game_key.in_(LEGACY_KEYS))
        .order_by(GameDefinition.id.asc())
        .all()
    )


def _primary(db: Session, actor: User | None = None) -> GameDefinition:
    rows = _rows(db)
    canonical = next((row for row in rows if row.game_key == GAME_KEY), None)
    if canonical:
        return canonical
    if rows:
        return rows[0]

    definition = GameDefinition(
        game_key=GAME_KEY,
        display_name="Jungle Hunt",
        category="coin",
        is_enabled=True,
        is_coin_game=True,
        min_app_version="1.0.0",
        config_version=20,
        ui_config_json=_dumps(_default_ui()),
        rules_json=_dumps(_default_rules()),
        risk_config_json=_dumps(_default_risk()),
        created_by_user_id=actor.id if actor else None,
        updated_by_user_id=actor.id if actor else None,
    )
    db.add(definition)
    db.commit()
    db.refresh(definition)
    return definition


def _rules(definition: GameDefinition) -> dict[str, Any]:
    return {**_default_rules(), **_loads(definition.rules_json)}


def _risk(definition: GameDefinition) -> dict[str, Any]:
    return {**_default_risk(), **_loads(definition.risk_config_json)}


def _target_rows(rules: dict[str, Any]) -> list[dict[str, Any]]:
    targets = getattr(jungle, "JUNGLE_TARGETS", [])
    weights = rules.get("target_probability_weights") or {}
    rows: list[dict[str, Any]] = []
    for item in targets:
        target_id = int(item["id"])
        rows.append(
            {
                "target_id": target_id,
                "label": str(item["label"]),
                "multiplier": int(item["multiplier"]),
                "weight": int(weights.get(str(target_id), weights.get(target_id, 100))),
            }
        )
    return rows


def get_jungle_hunt_props(db: Session) -> dict[str, Any]:
    definition = _primary(db)
    rules = _rules(definition)
    risk = _risk(definition)
    basket = rules.get("basket_probability_weights") or {}

    return {
        "game_key": GAME_KEY,
        "testing_mode_enabled": risk.get("testing_mode_enabled") is True,

        "round_seconds": int(rules.get("round_seconds", 30)),
        "lock_seconds": int(rules.get("lock_seconds", 2)),
        "reveal_seconds": int(rules.get("reveal_seconds", 15)),
        "result_seconds": int(rules.get("result_seconds", 3)),
        "close_betting_last_seconds": int(rules.get("close_betting_last_seconds", 2)),

        "max_total_bet_per_round": int(rules.get("max_total_bet_per_round", 6_000_000)),
        "max_targets_per_user_round": int(rules.get("max_targets_per_user_round", 6)),
        "max_round_liability": int(rules.get("max_round_liability", 60_000_000)),
        "max_target_liability": int(rules.get("max_target_liability", 45_000_000)),

        "max_daily_loss": int(risk.get("max_daily_loss", 1_500_000)),
        "max_daily_bet_volume": int(risk.get("max_daily_bet_volume", 6_000_000)),
        "whale_daily_volume": int(risk.get("whale_daily_volume", 4_000_000)),
        "whale_single_bet": int(risk.get("whale_single_bet", 500_000)),
        "whale_recent_bet_count": int(risk.get("whale_recent_bet_count", 8)),

        "rare_basket_probability_basis_points": int(rules.get("rare_basket_probability_basis_points", 120)),
        "left_basket_weight": int(basket.get("left", 50)),
        "right_basket_weight": int(basket.get("right", 50)),
        "target_weights": _target_rows(rules),
    }


def _as_int(payload: dict[str, Any], key: str, fallback: int) -> int:
    try:
        return int(payload.get(key, fallback))
    except Exception:
        return int(fallback)


def _as_bool(payload: dict[str, Any], key: str, fallback: bool) -> bool:
    value = payload.get(key, fallback)
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"true", "1", "yes", "on"}
    return bool(value)


def update_jungle_hunt_props_from_dict(db: Session, actor: User, payload: dict[str, Any]) -> dict[str, Any]:
    primary = _primary(db, actor)
    current = get_jungle_hunt_props(db)

    rules = _rules(primary)
    risk = _risk(primary)

    for key in [
        "round_seconds",
        "lock_seconds",
        "reveal_seconds",
        "result_seconds",
        "close_betting_last_seconds",
        "max_total_bet_per_round",
        "max_targets_per_user_round",
        "max_round_liability",
        "max_target_liability",
        "rare_basket_probability_basis_points",
    ]:
        rules[key] = _as_int(payload, key, int(current[key]))

    rules["basket_probability_weights"] = {
        "left": _as_int(payload, "left_basket_weight", current["left_basket_weight"]),
        "right": _as_int(payload, "right_basket_weight", current["right_basket_weight"]),
    }

    target_weights: dict[str, int] = {}
    raw_targets = payload.get("target_weights")
    if isinstance(raw_targets, list):
        for item in raw_targets:
            if not isinstance(item, dict):
                continue
            target_id = int(item.get("target_id", 0))
            if 0 <= target_id <= 7:
                target_weights[str(target_id)] = max(int(item.get("weight", 100)), 0)

    if target_weights:
        rules["target_probability_weights"] = target_weights

    risk["testing_mode_enabled"] = _as_bool(payload, "testing_mode_enabled", bool(current["testing_mode_enabled"]))
    risk["testing_mode_reason"] = str(payload.get("reason") or "Super Owner Jungle Hunt props update")

    for key in [
        "max_daily_loss",
        "max_daily_bet_volume",
        "whale_daily_volume",
        "whale_single_bet",
        "whale_recent_bet_count",
    ]:
        risk[key] = _as_int(payload, key, int(current[key]))

    rows = _rows(db)
    if not rows:
        rows = [primary]

    for definition in rows:
        definition.display_name = "Jungle Hunt"
        definition.category = "coin"
        definition.is_enabled = True
        definition.is_coin_game = True
        definition.config_version = max(int(definition.config_version or 1), 20)
        definition.ui_config_json = _dumps({**_default_ui(), **_loads(definition.ui_config_json)})
        definition.rules_json = _dumps(rules)
        definition.risk_config_json = _dumps(risk)
        definition.updated_by_user_id = actor.id

    db.commit()
    return get_jungle_hunt_props(db)
