"""Final static closure gate for the complete FunKey Chunks 15-56 roadmap."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

ROADMAP_MANIFEST = ROOT / "contracts" / "architecture" / "roadmap-closure-v1.json"

GUARDS = (
    "check_backend_architecture.py",
    "check_frontend_architecture.py",
    "check_contracts.py",
    "check_gateway_architecture.py",
    "check_graphql_bff_architecture.py",
    "check_kafka_data_platform.py",
    "check_search_platform.py",
    "check_recommendation_platform.py",
    "check_multiregion_architecture.py",
    "check_disaster_recovery.py",
    "check_supply_chain.py",
    "check_privacy_governance.py",
    "check_trust_safety_integrity.py",
    "check_realtime_media_qos.py",
    "check_mobile_runtime.py",
    "check_cache_edge_architecture.py",
    "check_analytics_platform.py",
    "check_release_safety.py",
    "check_sre_finops.py",
    "check_documentation_platform.py",
    "check_ownership_governance.py",
    "check_developer_experience.py",
    "check_architecture_conformance.py",
    "check_release_management.py",
    "check_decommissioning.py",
    "check_dependency_hygiene.py",
    "check_docs_links.py",
)


def validate_roadmap_manifest() -> None:
    if not ROADMAP_MANIFEST.is_file():
        raise SystemExit("roadmap closure manifest missing")

    payload = json.loads(ROADMAP_MANIFEST.read_text(encoding="utf-8"))
    if payload.get("schema_version") != 1:
        raise SystemExit("unsupported roadmap closure manifest schema")

    roadmap = payload.get("roadmap") or {}
    if roadmap.get("start_chunk") != 15 or roadmap.get("end_chunk") != 56:
        raise SystemExit("roadmap closure manifest must cover Chunks 15-56")

    chunks = payload.get("chunks")
    if not isinstance(chunks, list):
        raise SystemExit("roadmap closure manifest chunks must be a list")

    expected = set(range(15, 57))
    seen: set[int] = set()
    for item in chunks:
        if not isinstance(item, dict):
            raise SystemExit("roadmap closure entries must be objects")
        chunk = item.get("chunk")
        if not isinstance(chunk, int):
            raise SystemExit("roadmap closure entry missing integer chunk")
        if chunk in seen:
            raise SystemExit(f"duplicate roadmap closure entry for Chunk {chunk}")
        seen.add(chunk)
        if item.get("status") != "complete":
            raise SystemExit(f"Chunk {chunk} is not marked complete")

        for field in ("docs", "evidence"):
            paths = item.get(field)
            if not isinstance(paths, list) or not paths:
                raise SystemExit(f"Chunk {chunk} must declare non-empty {field}")
            for raw in paths:
                target = ROOT / str(raw)
                if not target.exists():
                    raise SystemExit(
                        f"Chunk {chunk} {field} path is missing: {raw}"
                    )

    missing = expected - seen
    extra = seen - expected
    if missing or extra:
        raise SystemExit(
            "roadmap closure chunk coverage mismatch: "
            f"missing={sorted(missing)} extra={sorted(extra)}"
        )


def main() -> None:
    validate_roadmap_manifest()

    expected_docs = {
        chunk: list((ROOT / "docs/platform").glob(f"chunk{chunk}-*.md"))
        for chunk in range(37, 57)
    }
    missing_docs = [str(chunk) for chunk, matches in expected_docs.items() if not matches]
    if missing_docs:
        raise SystemExit(
            "each roadmap chunk 37-56 must have at least one platform closure doc; missing chunks: "
            + ", ".join(missing_docs)
        )

    for guard in GUARDS:
        path = ROOT / "scripts" / guard
        if not path.is_file():
            raise SystemExit(f"roadmap closure guard missing: {guard}")
        result = subprocess.run(
            [sys.executable, str(path)],
            cwd=ROOT,
            check=False,
        )
        if result.returncode:
            raise SystemExit(f"roadmap closure failed at {guard}")

    print("FunKey roadmap static closure 15-56: OK")


if __name__ == "__main__":
    main()
