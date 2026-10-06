"""Chunk 44 trust/safety/fraud/economy-integrity guard."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    policy = json.loads((ROOT / "contracts/trust/risk-policy-v1.json").read_text())
    if "duplicate settlement and negative-balance creation are forbidden" not in policy.get("principles", []):
        raise SystemExit("economy integrity principle missing")

    required = (
        ROOT / "backend/app/services/risk_policy_service.py",
        ROOT / "backend/tests/test_risk_policy_service.py",
        ROOT / "docs/architecture/trust-safety-integrity.md",
        ROOT / "docs/runbooks/fraud-economy-integrity.md",
        ROOT / "docs/platform/chunk44-trust-safety-fraud-economy.md",
    )
    for path in required:
        if not path.is_file():
            raise SystemExit(f"missing trust/safety artifact: {path.relative_to(ROOT)}")

    risk = (ROOT / "backend/app/services/risk_policy_service.py").read_text()
    if "temporary_hold_and_manual_review" not in risk or "RiskDecision" not in risk:
        raise SystemExit("risk engine must preserve auditable review semantics")

    # Existing Economy idempotency/reconciliation infrastructure is mandatory.
    for path, marker in (
        (ROOT / "backend/app/models/economy_transaction.py", "idempot"),
        (ROOT / "apps/economy-service/main.py", "funkey-economy"),
        (ROOT / "docs/runbooks/economy-service.md", "reconcil"),
    ):
        text = path.read_text(encoding="utf-8").lower()
        if marker not in text:
            raise SystemExit(f"{path.relative_to(ROOT)} missing integrity marker {marker}")

    print("Trust/safety/economy integrity guard: OK")


if __name__ == "__main__":
    main()
