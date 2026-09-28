"""OpenFeature-compatible deterministic boolean flag evaluation."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any


_CONFIG_PATH = Path(__file__).resolve().parents[1] / "config" / "feature_flags_v1.json"


@dataclass(frozen=True)
class EvaluationContext:
    targeting_key: str
    platform: str = ""
    app_version: str = ""
    region: str = ""
    cohort: str = ""


@dataclass(frozen=True)
class FlagEvaluation:
    flag_key: str
    value: bool
    variant: str
    reason: str
    metadata: dict[str, Any]


def _version_tuple(value: str) -> tuple[int, ...]:
    parts: list[int] = []
    for item in value.strip().split("."):
        digits = "".join(ch for ch in item if ch.isdigit())
        if not digits:
            break
        parts.append(int(digits))
    return tuple(parts or [0])


@lru_cache(maxsize=1)
def _definitions() -> dict[str, dict[str, Any]]:
    payload = json.loads(_CONFIG_PATH.read_text(encoding="utf-8"))
    return {item["key"]: item for item in payload.get("flags", [])}


def evaluate_boolean(flag_key: str, context: EvaluationContext) -> FlagEvaluation:
    definition = _definitions().get(flag_key)
    if definition is None or definition.get("type") != "boolean":
        return FlagEvaluation(
            flag_key=flag_key,
            value=False,
            variant="off",
            reason="ERROR",
            metadata={"errorCode": "FLAG_NOT_FOUND"},
        )

    default = bool(definition.get("default", False))
    if bool(definition.get("kill_switch", False)):
        return FlagEvaluation(flag_key, False, "off", "STATIC", {"killSwitch": True})

    platform = context.platform.strip().lower()
    allowed_platforms = {str(x).lower() for x in definition.get("platforms", [])}
    if allowed_platforms and platform not in allowed_platforms:
        return FlagEvaluation(flag_key, default, "default", "TARGETING_MATCH", {"rule": "platform"})

    min_version = str(definition.get("min_app_version") or "").strip()
    if min_version and _version_tuple(context.app_version) < _version_tuple(min_version):
        return FlagEvaluation(flag_key, default, "default", "TARGETING_MATCH", {"rule": "min_app_version"})

    allowed_regions = {str(x).lower() for x in definition.get("regions", [])}
    if allowed_regions and context.region.strip().lower() not in allowed_regions:
        return FlagEvaluation(flag_key, default, "default", "TARGETING_MATCH", {"rule": "region"})

    allowed_cohorts = {str(x).lower() for x in definition.get("cohorts", [])}
    if allowed_cohorts and context.cohort.strip().lower() not in allowed_cohorts:
        return FlagEvaluation(flag_key, default, "default", "TARGETING_MATCH", {"rule": "cohort"})

    rollout = max(0, min(int(definition.get("rollout_percentage", 100)), 100))
    if rollout >= 100:
        return FlagEvaluation(flag_key, True, "on", "STATIC", {"rolloutPercentage": rollout})
    if rollout <= 0 or not context.targeting_key:
        return FlagEvaluation(flag_key, default, "default", "DEFAULT", {"rolloutPercentage": rollout})

    digest = hashlib.sha256(f"{flag_key}:{context.targeting_key}".encode()).digest()
    bucket = int.from_bytes(digest[:4], "big") % 10000
    enabled = bucket < rollout * 100
    return FlagEvaluation(
        flag_key,
        enabled,
        "on" if enabled else "off",
        "TARGETING_MATCH",
        {"rolloutPercentage": rollout, "bucket": bucket},
    )


def client_visible_flags() -> list[str]:
    return sorted(
        key for key, definition in _definitions().items()
        if bool(definition.get("client_visible", False))
    )
