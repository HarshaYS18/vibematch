"""Chunk 40 multi-region architecture guard."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(path: Path, markers: tuple[str, ...]) -> str:
    if not path.is_file():
        raise SystemExit(f"missing multi-region file: {path.relative_to(ROOT)}")
    text = path.read_text(encoding="utf-8")
    for marker in markers:
        if marker not in text:
            raise SystemExit(f"{path.relative_to(ROOT)} missing marker: {marker}")
    return text


def main() -> None:
    policy = json.loads((ROOT / "contracts/platform/region-policy-v1.json").read_text())
    if policy["state_policy"].get("economy") != "single_writer_region":
        raise SystemExit("Economy must remain single-writer across regions")
    if policy["state_policy"].get("postgresql") != "single_writable_primary_unless_separately_proven":
        raise SystemExit("PostgreSQL multi-writer is forbidden by default")

    require(
        ROOT / "apps/economy-service/main.py",
        ("ECONOMY_WRITER_REGION", "REGION_NOT_WRITER", "FUNKEY_REGION"),
    )
    require(
        ROOT / "backend/app/core/config.py",
        ("FUNKEY_REGION", "FUNKEY_HOME_REGION", "ECONOMY_WRITER_REGION"),
    )
    require(
        ROOT / "docs/architecture/multi-region.md",
        ("nearest healthy region", "single-writer"),
    )
    require(ROOT / "docs/runbooks/region-failure.md", ("Economy", "RPO", "RTO"))
    require(ROOT / "docs/platform/chunk40-multi-region.md", ("Chunk 40",))

    print("Multi-region architecture guard: OK")


if __name__ == "__main__":
    main()
