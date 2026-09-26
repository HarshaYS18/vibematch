"""Chunk 49 compatibility/feature-flag/release-safety guard."""
from __future__ import annotations
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    matrix=json.loads((ROOT/"contracts/compatibility/version-matrix-v1.json").read_text())
    for key in ("rest","realtime_envelope","domain_events","graphql_persisted_operations","game_bridge","asset_manifest"):
        if key not in matrix["server_contracts"]: raise SystemExit(f"missing compatibility contract {key}")
    if matrix["deprecation"]["minimum_notice_days"] < 30: raise SystemExit("deprecation notice window regressed")
    flags=json.loads((ROOT/"backend/app/config/feature_flags_v1.json").read_text())
    for flag in flags["flags"]:
        if "kill_switch" not in flag or "rollout_percentage" not in flag:
            raise SystemExit(f"flag lacks release-safety controls: {flag.get('key')}")
    evaluator=(ROOT/"backend/app/services/feature_flag_service.py").read_text()
    for marker in ("sha256","TARGETING_MATCH","kill_switch","rollout_percentage"):
        if marker not in evaluator: raise SystemExit(f"feature flag evaluator missing {marker}")
    docs=(ROOT/"docs/architecture/release-safety.md").read_text()
    if "mobile skew" not in docs.lower() or "kill switch" not in docs.lower():
        raise SystemExit("release safety docs incomplete")
    print("Compatibility/feature-flag/release-safety guard: OK")
if __name__=="__main__": main()
