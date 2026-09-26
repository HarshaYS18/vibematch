"""Validate production-certification evidence without inventing capacity claims."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLAN = json.loads(
    (ROOT / "contracts/sre/production-certification-plan-v1.json").read_text(encoding="utf-8")
)


def validate_evidence(path: Path) -> None:
    payload = json.loads(path.read_text(encoding="utf-8"))
    missing = [key for key in PLAN["evidence_required"] if key not in payload]
    if missing:
        raise SystemExit("certification evidence missing: " + ", ".join(missing))

    results = payload.get("scenario_results")
    if not isinstance(results, dict):
        raise SystemExit("scenario_results must be an object")
    absent = [name for name in PLAN["required_scenarios"] if name not in results]
    if absent:
        raise SystemExit("certification scenarios missing: " + ", ".join(absent))

    failures = [
        name for name, result in results.items()
        if not isinstance(result, dict) or result.get("status") != "pass"
    ]
    if failures:
        raise SystemExit("certification has non-passing scenarios: " + ", ".join(sorted(failures)))

    print("Production certification evidence: PASS")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    validate_evidence(args.evidence)


if __name__ == "__main__":
    main()
