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
    forbidden_imports = (
        "package:dio/dio.dart",
        "package:http/http.dart",
    )
    offenders: list[str] = []
    for path in features.rglob("*.dart"):
        text = path.read_text(encoding="utf-8", errors="replace")
        if (
            any(marker in text for marker in forbidden_imports)
            or "HttpClient(" in text
            or "WebSocket.connect" in text
            or "WebSocketChannel.connect" in text
        ):
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



def check_roadmap_documentation_state() -> None:
    authority = (ROOT / "docs" / "architecture" / "authority-registry.md").read_text(
        encoding="utf-8"
    )
    boundaries = (ROOT / "docs" / "architecture" / "service-boundaries.md").read_text(
        encoding="utf-8"
    )
    overview = (ROOT / "docs" / "architecture" / "overview.md").read_text(
        encoding="utf-8"
    )
    deployment = (ROOT / "docs" / "architecture" / "deployment.md").read_text(
        encoding="utf-8"
    )
    master_source = (ROOT / "docs" / "master-source-of-truth-architecture.md").read_text(
        encoding="utf-8"
    )
    capacity = (ROOT / "docs" / "architecture" / "capacity-model.md").read_text(
        encoding="utf-8"
    )

    required = {
        "authority-registry.md": (
            (authority, "Chunk 56"),
            (authority, "search-service"),
            (authority, "kafka-event-bridge"),
            (authority, "recommendation-service"),
            (authority, "analytics-sink"),
        ),
        "service-boundaries.md": (
            (boundaries, "Chunk 56"),
            (boundaries, "search-service"),
            (boundaries, "kafka-event-bridge"),
            (boundaries, "recommendation-service"),
            (boundaries, "analytics-sink"),
        ),
        "overview.md": (
            (overview, "Chunk 56"),
            (overview, "GraphQL Read BFF"),
            (overview, "Kafka Event Bridge"),
            (overview, "Search Service"),
            (overview, "Recommendation Service"),
            (overview, "Analytics Sink"),
        ),
        "deployment.md": (
            (deployment, "Kafka Event Bridge"),
            (deployment, "OpenSearch"),
            (deployment, "Recommendation"),
            (deployment, "Analytics Sink"),
            (deployment, "GraphQL Read BFF"),
        ),
        "master-source-of-truth-architecture.md": (
            (master_source, "Chunks 15–56"),
            (master_source, "GraphQL Read BFF"),
            (master_source, "NATS-to-Kafka bridge"),
            (master_source, "Search/OpenSearch"),
            (master_source, "ClickHouse"),
        ),
        "capacity-model.md": (
            (capacity, "Kafka"),
            (capacity, "Search / OpenSearch"),
            (capacity, "Recommendation"),
            (capacity, "Analytics"),
            (capacity, "GraphQL Read BFF"),
        ),
    }
    for document, checks in required.items():
        for text, marker in checks:
            if marker not in text:
                raise SystemExit(
                    f"canonical roadmap documentation is stale: {document} missing {marker}"
                )

    stale_markers = {
        "authority-registry.md": (
            (authority, "direct DB search today"),
            (authority, "Known future projections"),
        ),
        "service-boundaries.md": (
            (boundaries, "Kafka/ClickHouse/data lake remain future"),
            (boundaries, "Recommendation | not deployed"),
        ),
        "overview.md": (
            (overview, "Repository reality through\nChunk 32"),
            (overview, "remain future chunks"),
        ),
        "master-source-of-truth-architecture.md": (
            (master_source, "Chunk 20–32 architecture work"),
            (master_source, "current room presence in `room_participants`"),
        ),
    }
    for document, checks in stale_markers.items():
        for text, marker in checks:
            if marker in text:
                raise SystemExit(
                    f"canonical roadmap documentation retained stale pre-closure text: "
                    f"{document}: {marker}"
                )


def main() -> None:
    for guard in COMPOSED_GUARDS:
        run_guard(guard)
    check_frontend_network_boundary()
    check_room_session_authority()
    check_system_map()
    check_roadmap_documentation_state()
    print("Architecture conformance: OK")


if __name__ == "__main__":
    main()
