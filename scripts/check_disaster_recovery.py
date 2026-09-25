"""Chunk 41 disaster-recovery contract guard."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    path = ROOT / "contracts/platform/recovery-objectives-v1.json"
    if not path.is_file():
        raise SystemExit("recovery-objectives contract missing")
    payload = json.loads(path.read_text())
    tiers = payload.get("tiers") or {}
    for name, tier in tiers.items():
        if int(tier.get("rpo_seconds") or 0) <= 0:
            raise SystemExit(f"{name}: RPO must be positive")
        if int(tier.get("rto_seconds") or 0) <= 0:
            raise SystemExit(f"{name}: RTO must be positive")

    required = (
        ROOT / "docs/runbooks/database-restore.md",
        ROOT / "docs/runbooks/region-failure.md",
        ROOT / "docs/runbooks/disaster-recovery.md",
        ROOT / "docs/platform/chunk41-disaster-recovery.md",
    )
    for doc in required:
        if not doc.is_file():
            raise SystemExit(f"missing DR document: {doc.relative_to(ROOT)}")
        text = doc.read_text(encoding="utf-8")
        if "restore" not in text.lower():
            raise SystemExit(f"{doc.relative_to(ROOT)} must describe restore validation")

    print("Disaster-recovery contract guard: OK")


if __name__ == "__main__":
    main()
