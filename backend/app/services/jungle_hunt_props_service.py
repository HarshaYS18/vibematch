from __future__ import annotations

from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.game import GameDefinition
from app.models.user import User
from app.services import game_service as base
from app.services import global_jungle_game_service as jungle

GAME_KEY = jungle.JUNGLE_HUNT_KEY


def _definition(db: Session, actor: User | None = None) -> GameDefinition:
    jungle._sync_jungle_definition(db, actor)
    definition = db.query(GameDefinition).filter(GameDefinition.game_key == GAME_KEY).first()
    if not definition:
        raise HTTPException(status_code=404, detail="Jungle Hunt definition not found")
    return definition


def _rules(definition: GameDefinition) -> dict[str, Any]:
    current = base._loads(definition.rules_json, {})
    return {**jungle.JUNGLE_RULES, **current}


def _risk(definition: GameDefinition) -> dict[str, Any]:
    current = base._loads(definition.risk_config_json, {})
    return {**jungle.JUNGLE_RISK, **current}


def _target_weight_rows(rules: dict[str, Any]) -> list[dict[str, Any]]:
    raw = rules.get("target_probability_weights") or {}
    rows: list[dict[str, Any]] = []
    for item in jungle.JUNGLE_TARGETS:
        target_id = int(item["id"])
        rows.append(
            {
                "target_id": target_id,
                "label": str(item["label"]),
                "multiplier": int(item["multiplier"]),
                "weight": int(raw.get(str(target_id), raw.get(target_id, 100))),
            }
        )
    return rows


def get_jungle_hunt_props(db: Session) -> dict[str, Any]:
    definition = _definition(db)
    rules = _rules(definition)
    risk = _risk(definition)

    basket_weights = rules.get("basket_probability_weights") or {}
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
        "left_basket_weight": int(basket_weights.get("left", 50)),
        "right_basket_weight": int(basket_weights.get("right", 50)),
        "target_weights": _target_weight_rows(rules),
    }


def update_jungle_hunt_props(db: Session, actor: User, payload) -> dict[str, Any]:
    definition = _definition(db, actor)
    rules = _rules(definition)
    risk = _risk(definition)

    rules.update(
        {
            "round_seconds": int(payload.round_seconds),
            "lock_seconds": int(payload.lock_seconds),
            "reveal_seconds": int(payload.reveal_seconds),
            "result_seconds": int(payload.result_seconds),
            "close_betting_last_seconds": int(payload.close_betting_last_seconds),

            "max_total_bet_per_round": int(payload.max_total_bet_per_round),
            "max_targets_per_user_round": int(payload.max_targets_per_user_round),
            "max_round_liability": int(payload.max_round_liability),
            "max_target_liability": int(payload.max_target_liability),

            "rare_basket_probability_basis_points": int(payload.rare_basket_probability_basis_points),
            "basket_probability_weights": {
                "left": int(payload.left_basket_weight),
                "right": int(payload.right_basket_weight),
            },
            "target_probability_weights": {
                str(item.target_id): int(item.weight) for item in payload.target_weights
            },
        }
    )

    risk.update(
        {
            "testing_mode_enabled": payload.testing_mode_enabled is True,
            "testing_mode_reason": payload.reason,

            "max_daily_loss": int(payload.max_daily_loss),
            "max_daily_bet_volume": int(payload.max_daily_bet_volume),
            "whale_daily_volume": int(payload.whale_daily_volume),
            "whale_single_bet": int(payload.whale_single_bet),
            "whale_recent_bet_count": int(payload.whale_recent_bet_count),
        }
    )

    definition.game_key = GAME_KEY
    definition.display_name = "Jungle Hunt"
    definition.rules_json = base._dumps(rules)
    definition.risk_config_json = base._dumps(risk)
    definition.config_version = max(int(definition.config_version or 1), 5)
    definition.updated_by_user_id = actor.id

    db.commit()
    return get_jungle_hunt_props(db)



def _int_payload(payload: dict, key: str, fallback: int) -> int:
    value = payload.get(key, fallback)
    try:
        return int(value)
    except Exception:
        return int(fallback)


def _bool_payload(payload: dict, key: str, fallback: bool) -> bool:
    value = payload.get(key, fallback)
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"true", "1", "yes", "on"}
    return bool(value)


def update_jungle_hunt_props_from_dict(db: Session, actor: User, payload: dict[str, Any]) -> dict[str, Any]:
    current = get_jungle_hunt_props(db)

    class PayloadObject:
        pass

    obj = PayloadObject()
    obj.reason = str(payload.get("reason") or "Super Owner Jungle Hunt props update").strip()

    obj.testing_mode_enabled = _bool_payload(payload, "testing_mode_enabled", bool(current["testing_mode_enabled"]))

    obj.round_seconds = _int_payload(payload, "round_seconds", current["round_seconds"])
    obj.lock_seconds = _int_payload(payload, "lock_seconds", current["lock_seconds"])
    obj.reveal_seconds = _int_payload(payload, "reveal_seconds", current["reveal_seconds"])
    obj.result_seconds = _int_payload(payload, "result_seconds", current["result_seconds"])
    obj.close_betting_last_seconds = _int_payload(payload, "close_betting_last_seconds", current["close_betting_last_seconds"])

    obj.max_total_bet_per_round = _int_payload(payload, "max_total_bet_per_round", current["max_total_bet_per_round"])
    obj.max_targets_per_user_round = _int_payload(payload, "max_targets_per_user_round", current["max_targets_per_user_round"])
    obj.max_round_liability = _int_payload(payload, "max_round_liability", current["max_round_liability"])
    obj.max_target_liability = _int_payload(payload, "max_target_liability", current["max_target_liability"])

    obj.max_daily_loss = _int_payload(payload, "max_daily_loss", current["max_daily_loss"])
    obj.max_daily_bet_volume = _int_payload(payload, "max_daily_bet_volume", current["max_daily_bet_volume"])
    obj.whale_daily_volume = _int_payload(payload, "whale_daily_volume", current["whale_daily_volume"])
    obj.whale_single_bet = _int_payload(payload, "whale_single_bet", current["whale_single_bet"])
    obj.whale_recent_bet_count = _int_payload(payload, "whale_recent_bet_count", current["whale_recent_bet_count"])

    obj.rare_basket_probability_basis_points = _int_payload(payload, "rare_basket_probability_basis_points", current["rare_basket_probability_basis_points"])
    obj.left_basket_weight = _int_payload(payload, "left_basket_weight", current["left_basket_weight"])
    obj.right_basket_weight = _int_payload(payload, "right_basket_weight", current["right_basket_weight"])

    raw_targets = payload.get("target_weights")
    current_targets = current["target_weights"]

    class TargetObject:
        def __init__(self, target_id: int, label: str, multiplier: int, weight: int):
            self.target_id = target_id
            self.label = label
            self.multiplier = multiplier
            self.weight = weight

    targets = []
    if isinstance(raw_targets, list) and raw_targets:
        for index, item in enumerate(raw_targets):
            if not isinstance(item, dict):
                continue
            fallback = current_targets[index] if index < len(current_targets) else {"target_id": index, "label": f"Target {index}", "multiplier": 1, "weight": 100}
            targets.append(
                TargetObject(
                    target_id=int(item.get("target_id", fallback["target_id"])),
                    label=str(item.get("label", fallback["label"])),
                    multiplier=int(item.get("multiplier", fallback["multiplier"])),
                    weight=int(item.get("weight", fallback["weight"])),
                )
            )

    if not targets:
        targets = [
            TargetObject(
                target_id=int(item["target_id"]),
                label=str(item["label"]),
                multiplier=int(item["multiplier"]),
                weight=int(item["weight"]),
            )
            for item in current_targets
        ]

    obj.target_weights = targets

    return update_jungle_hunt_props(db, actor, obj)
