"""Client/server compatibility and public feature-flag evaluation."""

from __future__ import annotations

import json
from pathlib import Path

from fastapi import APIRouter, Header, HTTPException, Query

from app.services.feature_flag_service import (
    EvaluationContext,
    client_visible_flags,
    evaluate_boolean,
)

router = APIRouter(tags=["Compatibility"])
_CONTRACT_PATH = Path(__file__).resolve().parents[4] / "contracts" / "compatibility" / "version-matrix-v1.json"


def _compatibility_payload() -> dict[str, object]:
    if _CONTRACT_PATH.is_file():
        return json.loads(_CONTRACT_PATH.read_text(encoding="utf-8"))
    # Container builds intentionally do not depend on the repository contracts
    # directory. Keep the runtime response explicit and versioned.
    return {
        "schema_version": 1,
        "server_contracts": {
            "rest": {"current": "v1", "supported": ["v1"]},
            "realtime_envelope": {"current": 1, "supported": [1]},
            "graphql_persisted_operations": {"current": 1, "minimum_supported": 1},
            "game_bridge": {"current": 1, "supported": [1]},
            "asset_manifest": {"current": 1, "supported": [1]},
        },
        "mobile": {"minimum_supported": "1.0.0", "recommended": "1.0.0"},
    }


@router.get("/compatibility")
def compatibility() -> dict[str, object]:
    return _compatibility_payload()


@router.get("/feature-flags/{flag_key}")
def evaluate_feature_flag(
    flag_key: str,
    targeting_key: str = Query(default="", max_length=160),
    x_funkey_platform: str = Header(default="", max_length=32),
    x_funkey_app_version: str = Header(default="", max_length=32),
    x_funkey_region: str = Header(default="", max_length=64),
    x_funkey_cohort: str = Header(default="", max_length=64),
) -> dict[str, object]:
    if flag_key not in client_visible_flags():
        raise HTTPException(status_code=404, detail="Feature flag not found")
    result = evaluate_boolean(
        flag_key,
        EvaluationContext(
            targeting_key=targeting_key,
            platform=x_funkey_platform,
            app_version=x_funkey_app_version,
            region=x_funkey_region,
            cohort=x_funkey_cohort,
        ),
    )
    return {
        "flagKey": result.flag_key,
        "value": result.value,
        "variant": result.variant,
        "reason": result.reason,
        "flagMetadata": result.metadata,
    }
