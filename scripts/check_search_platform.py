"""Chunk 38 Search/OpenSearch architecture guard."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEARCH = ROOT / "apps/search-service"


def require(path: Path, markers: tuple[str, ...]) -> str:
    if not path.is_file():
        raise SystemExit(f"missing Search file: {path.relative_to(ROOT)}")
    text = path.read_text(encoding="utf-8")
    for marker in markers:
        if marker not in text:
            raise SystemExit(f"{path.relative_to(ROOT)} missing marker: {marker}")
    return text


def main() -> None:
    require(
        SEARCH / "projector.py",
        ("await store.apply(projection)", "await msg.ack()", "await msg.nak"),
    )
    require(
        SEARCH / "opensearch_store.py",
        ("dynamic", "strict", "multi_match", "popularity"),
    )
    require(
        SEARCH / "contracts.py",
        ("search_projection", "SearchDocument", "deleted"),
    )
    require(
        ROOT / "backend/app/api/routes/search_proxy.py",
        ("SEARCH_SERVICE_URL", '"/search"'),
    )
    require(
        ROOT / "frontend/vibematch_app/lib/features/search/data/search_api_service.dart",
        ("'/search'", "projection"),
    )
    for path in (
        ROOT / "docs/adr/ADR-018-search-opensearch-projection.md",
        ROOT / "docs/architecture/search-platform.md",
        ROOT / "docs/modules/search/README.md",
        ROOT / "docs/runbooks/search-opensearch.md",
        ROOT / "docs/platform/chunk38-search-discovery.md",
    ):
        require(path, ("Search",))

    client_pattern = re.compile(r"\b(OpenSearch|AsyncOpenSearch|opensearchpy|opensearch_py)\b")
    offenders = []
    for base in (ROOT / "backend", ROOT / "apps"):
        for path in base.rglob("*.py"):
            if SEARCH in path.parents:
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            if client_pattern.search(text):
                offenders.append(str(path.relative_to(ROOT)))
    if offenders:
        raise SystemExit("OpenSearch clients are forbidden outside Search service: " + ", ".join(offenders))

    print("Search/OpenSearch architecture guard: OK")


if __name__ == "__main__":
    main()
