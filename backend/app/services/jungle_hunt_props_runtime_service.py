from __future__ import annotations

import json
from typing import Any

from sqlalchemy.orm import Session

from app.models.game import GameDefinition
from app.models.user import User

GAME_KEY = "jungle_hunt"
LEGACY_KEYS = {"jungle_hunt", "jackpot_king"}


def _jungle_service():
    from app.services import global_jungle_game_service as jungle

    return jungle


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


def _default_rules() -> dict[str, Any]:
    return dict(getattr(_jungle_service(), "JUNGLE_RULES", {}))


def _default_risk() -> dict[str, Any]:
    return {**dict(getattr(_jungle_service(), "JUNGLE_RISK", {})), "testing_mode_enabled": False}


def _default_ui() -> dict[str, Any]:
    return dict(getattr(_jungle_service(), "JUNGLE_UI", {}))


def _definition_rows(db: Session) -> list[GameDefinition]:
    return (
        db.query(GameDefinition)
        .filter(GameDefinition.game_key.in_(list(LEGACY_KEYS)))
        .order_by(GameDefinition.id.asc())
        .all()
    )


def _merged(defaults: dict[str, Any], raw: str | None) -> dict[str, Any]:
    return {**defaults, **_loads(raw)}


def _is_empty_or_default(raw: str | None, defaults: dict[str, Any]) -> bool:
    data = _loads(raw)
    if not data:
        return True
    return {**defaults, **data} == defaults


def _has_saved_config(raw: str | None, defaults: dict[str, Any]) -> bool:
    data = _loads(raw)
    if not data:
        return False
    return {**defaults, **data} != defaults


def _copy_if_canonical_default(
    canonical: GameDefinition,
    legacy: GameDefinition,
    attr: str,
    defaults: dict[str, Any],
) -> bool:
    canonical_raw = getattr(canonical, attr)
    legacy_raw = getattr(legacy, attr)
    if _is_empty_or_default(canonical_raw, defaults) and _has_saved_config(legacy_raw, defaults):
        setattr(canonical, attr, _dumps(_merged(defaults, legacy_raw)))
        return True
    return False


def normalize_legacy_rows(db: Session) -> GameDefinition | None:
    rows = _definition_rows(db)
    canonical = next((row for row in rows if row.game_key == GAME_KEY), None)
    legacy = next((row for row in rows if row.game_key == "jackpot_king"), None)
    changed = False

    if legacy is not None and canonical is None:
        legacy.game_key = GAME_KEY
        canonical = legacy
        changed = True
    elif canonical is not None and legacy is not None:
        changed = _copy_if_canonical_default(canonical, legacy, "rules_json", _default_rules()) or changed
        changed = _copy_if_canonical_default(canonical, legacy, "risk_config_json", _default_risk()) or changed
        changed = _copy_if_canonical_default(canonical, legacy, "ui_config_json", _default_ui()) or changed

    if changed:
        db.commit()
        if canonical is not None:
            db.refresh(canonical)
    return canonical


def _set_if_changed(definition: GameDefinition, attr: str, value: Any) -> bool:
    if getattr(definition, attr) == value:
        return False
    setattr(definition, attr, value)
    return True


def get_or_create_definition(db: Session, actor: User | None = None) -> GameDefinition:
    definition = normalize_legacy_rows(db)
    if definition is None:
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

    changed = False
    changed = _set_if_changed(definition, "game_key", GAME_KEY) or changed
    changed = _set_if_changed(definition, "display_name", "Jungle Hunt") or changed
    changed = _set_if_changed(definition, "category", "coin") or changed
    changed = _set_if_changed(definition, "is_enabled", True) or changed
    changed = _set_if_changed(definition, "is_coin_game", True) or changed
    changed = _set_if_changed(definition, "min_app_version", definition.min_app_version or "1.0.0") or changed
    changed = _set_if_changed(definition, "config_version", max(int(definition.config_version or 1), 20)) or changed
    changed = _set_if_changed(definition, "ui_config_json", _dumps(_merged(_default_ui(), definition.ui_config_json))) or changed
    changed = _set_if_changed(definition, "rules_json", _dumps(_merged(_default_rules(), definition.rules_json))) or changed
    changed = _set_if_changed(definition, "risk_config_json", _dumps(_merged(_default_risk(), definition.risk_config_json))) or changed
    if actor is not None:
        changed = _set_if_changed(definition, "updated_by_user_id", actor.id) or changed

    if changed:
        db.commit()
        db.refresh(definition)
    return definition


def load_rules(db: Session) -> dict[str, Any]:
    definition = get_or_create_definition(db)
    return _merged(_default_rules(), definition.rules_json)


def load_risk(db: Session) -> dict[str, Any]:
    definition = get_or_create_definition(db)
    return _merged(_default_risk(), definition.risk_config_json)


def get_testing_mode(db: Session, game_key: str = GAME_KEY) -> bool:
    if game_key not in LEGACY_KEYS:
        return False
    definition = get_or_create_definition(db)
    risk = _loads(definition.risk_config_json)
    return risk.get("testing_mode_enabled") is True


def _target_rows(rules: dict[str, Any]) -> list[dict[str, Any]]:
    targets = getattr(_jungle_service(), "JUNGLE_TARGETS", [])
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


def get_props(db: Session) -> dict[str, Any]:
    rules = load_rules(db)
    risk = load_risk(db)
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


def _target_weights_from_payload(payload: dict[str, Any], existing: dict[Any, Any]) -> dict[str, int]:
    weights: dict[str, int] = {}
    for key, value in existing.items():
        try:
            weights[str(key)] = int(value)
        except Exception:
            continue
    raw_targets = payload.get("target_weights")
    if not isinstance(raw_targets, list):
        return weights
    for item in raw_targets:
        if not isinstance(item, dict):
            continue
        try:
            target_id = int(item.get("target_id"))
            weight = max(int(item.get("weight", weights.get(str(target_id), 100))), 0)
        except Exception:
            continue
        if 0 <= target_id <= 7:
            weights[str(target_id)] = weight
    return weights


def update_props(db: Session, actor: User, payload: dict[str, Any]) -> dict[str, Any]:
    definition = get_or_create_definition(db, actor)
    current = get_props(db)
    rules = _merged(_default_rules(), definition.rules_json)
    risk = _merged(_default_risk(), definition.risk_config_json)

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
        "left": _as_int(payload, "left_basket_weight", int(current["left_basket_weight"])),
        "right": _as_int(payload, "right_basket_weight", int(current["right_basket_weight"])),
    }
    rules["target_probability_weights"] = _target_weights_from_payload(
        payload,
        rules.get("target_probability_weights") or {},
    )

    risk["testing_mode_enabled"] = _as_bool(
        payload,
        "testing_mode_enabled",
        bool(current["testing_mode_enabled"]),
    )
    if "reason" in payload:
        risk["testing_mode_reason"] = str(payload.get("reason") or "Super Owner Jungle Hunt props update")

    for key in [
        "max_daily_loss",
        "max_daily_bet_volume",
        "whale_daily_volume",
        "whale_single_bet",
        "whale_recent_bet_count",
    ]:
        risk[key] = _as_int(payload, key, int(current[key]))

    definition.rules_json = _dumps(rules)
    definition.risk_config_json = _dumps(risk)
    definition.ui_config_json = _dumps(_merged(_default_ui(), definition.ui_config_json))
    definition.updated_by_user_id = actor.id
    db.commit()
    db.refresh(definition)
    return get_props(db)
