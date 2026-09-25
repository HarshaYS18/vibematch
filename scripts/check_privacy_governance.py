"""Chunk 43 privacy/data-governance guard."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    classification = json.loads((ROOT / "contracts/privacy/data-classification-v1.json").read_text())
    retention = json.loads((ROOT / "contracts/privacy/retention-v1.json").read_text())
    if set(classification.get("classes", {})) != {"public", "internal", "restricted", "highly_restricted"}:
        raise SystemExit("privacy classification classes drifted")
    if int(retention.get("dsar_due_days") or 0) <= 0:
        raise SystemExit("DSAR due period must be defined")

    required = (
        ROOT / "apps/identity-service/privacy.py",
        ROOT / "backend/app/models/privacy_request.py",
        ROOT / "backend/alembic/versions/20260926_0100_privacy_requests.py",
        ROOT / "docs/architecture/privacy-data-governance.md",
        ROOT / "docs/runbooks/privacy-request.md",
        ROOT / "docs/platform/chunk43-privacy-data-governance.md",
    )
    for path in required:
        if not path.is_file():
            raise SystemExit(f"missing privacy artifact: {path.relative_to(ROOT)}")
    privacy = (ROOT / "apps/identity-service/privacy.py").read_text()
    for marker in ("privacy.export.requested", "privacy.delete.requested", "due_at", "CANCELLED"):
        if marker not in privacy:
            raise SystemExit(f"privacy workflow missing {marker}")

    print("Privacy/data-governance guard: OK")


if __name__ == "__main__":
    main()
