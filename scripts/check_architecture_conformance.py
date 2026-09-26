"""Chunk 54 high-level architecture conformance gate."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

COMPOSED_GUARDS = (
    "check_backend_architecture.py",
    "check_frontend_architecture.py",
    "check_contracts.py",
    "check_documentation_platform.py",
    "check_ownership_governance.py",
)


def run_guard(name: str) -> None:
    path = ROOT / "scripts" / name
    if not path.is_file():
        raise SystemExit(f"missing composed architecture guard: {name}")
    result = subprocess.run([sys.executable, str(path)], cwd=ROOT, check=False)
    if result.returncode:
        raise SystemExit(f"composed architecture guard failed: {name}")


def check_frontend_network_boundary() -> None:
    features = ROOT / "frontend" / "vibematch_app" / "lib" / "features"
    forbidden = (
        "package:dio/dio.dart",
        "package:http/http.dart",
        "dart:io';",
    )
    offenders: list[str] = []
    for path in features.rglob("*.dart"):
        text = path.read_text(encoding="utf-8", errors="replace")
        if any(marker in text for marker in forbidden):
            offenders.append(str(path.relative_to(ROOT)))
    if offenders:
        raise SystemExit(
            "feature-local raw networking is forbidden; use canonical networking: "
            + ", ".join(sorted(offenders))
        )


def check_room_session_authority() -> None:
    lib = ROOT / "frontend" / "vibematch_app" / "lib"
    definitions: list[str] = []
    pattern = re.compile(r"\bclass\s+RoomSessionRepository\b")
    for path in lib.rglob("*.dart"):
        if pattern.search(path.read_text(encoding="utf-8", errors="replace")):
            definitions.append(str(path.relative_to(ROOT)))
    if len(definitions) != 1:
        raise SystemExit(
            f"expected exactly one RoomSessionRepository definition, found {definitions}"
        )


def check_system_map() -> None:
    path = ROOT / "docs" / "architecture" / "system-map.md"
    text = path.read_text(encoding="utf-8") if path.is_file() else ""
    for marker in ("mermaid", "Economy", "NATS JetStream", "Kafka", "OpenSearch", "ClickHouse"):
        if marker not in text:
            raise SystemExit(f"system architecture map missing {marker}")


def main() -> None:
    for guard in COMPOSED_GUARDS:
        run_guard(guard)
    check_frontend_network_boundary()
    check_room_session_authority()
    check_system_map()
    print("Architecture conformance: OK")


if __name__ == "__main__":
    main()
