"""Chunk 39 Recommendation architecture guard."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "apps/recommendation-service"


def require(path: Path, markers: tuple[str, ...]) -> str:
    if not path.is_file():
        raise SystemExit(f"missing Recommendation file: {path.relative_to(ROOT)}")
    text = path.read_text(encoding="utf-8")
    for marker in markers:
        if marker not in text:
            raise SystemExit(f"{path.relative_to(ROOT)} missing marker: {marker}")
    return text


def main() -> None:
    require(APP / "consumer.py", ("enable_auto_commit=False", "OffsetAndMetadata", "await store.apply(signal)"))
    require(APP / "store.py", ("zincrby", "expire", "RecommendationStore"))
    require(APP / "ranker.py", ("HALF_LIFE_SECONDS", "stable_tiebreak"))
    require(APP / "main.py", ("Bearer authentication is required", "/api/v1/recommendations"))
    require(
        ROOT / "backend/app/api/routes/recommendation_proxy.py",
        ("RECOMMENDATION_SERVICE_URL", '"/recommendations"'),
    )

    forbidden = re.compile(r"\b(sqlalchemy|SessionLocal|psycopg|asyncpg)\b")
    combined = "\n".join(p.read_text(encoding="utf-8") for p in APP.glob("*.py"))
    if forbidden.search(combined):
        raise SystemExit("Recommendation service must not gain database authority")

    for path in (
        ROOT / "docs/adr/ADR-019-recommendation-projection.md",
        ROOT / "docs/architecture/recommendation-platform.md",
        ROOT / "docs/modules/recommendation/README.md",
        ROOT / "docs/runbooks/recommendation-platform.md",
        ROOT / "docs/platform/chunk39-recommendation-platform.md",
    ):
        require(path, ("Recommendation",))

    print("Recommendation architecture guard: OK")


if __name__ == "__main__":
    main()
