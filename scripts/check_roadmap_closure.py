"""Final static closure gate for FunKey Chunks 37-56."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

GUARDS = (
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


def main() -> None:
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

    print("FunKey roadmap static closure 37-56: OK")


if __name__ == "__main__":
    main()
