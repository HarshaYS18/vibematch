"""Chunk 56 dependency-hygiene guard."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

DEPENDABOT_DIRECTORIES = {
    "/backend",
    "/apps/graphql-bff",
    "/apps/inbox-service",
    "/apps/worker",
    "/apps/kafka-event-bridge",
    "/apps/search-service",
    "/apps/recommendation-service",
    "/apps/analytics-sink",
    "/backend_media",
    "/frontend/vibematch_app",
    "/apps/realtime-gateway",
    "/infra/terraform",
}


def main() -> None:
    dependabot = ROOT / ".github/dependabot.yml"
    if not dependabot.is_file():
        raise SystemExit("Dependabot configuration missing")
    text = dependabot.read_text(encoding="utf-8")
    directories = set(re.findall(r'directory:\s*["\']?([^"\'\s]+)', text))
    missing = DEPENDABOT_DIRECTORIES - directories
    if missing:
        raise SystemExit(
            "Dependabot does not cover direct dependency manifests: "
            + ", ".join(sorted(missing))
        )

    flutter_pubspec = (
        ROOT / "frontend/vibematch_app/pubspec.yaml"
    ).read_text(encoding="utf-8")
    if re.search(r"(?m)^\s{2}http:\s", flutter_pubspec):
        raise SystemExit(
            "direct package:http dependency is obsolete; canonical networking uses Dio"
        )

    raw_http_imports: list[str] = []
    app_root = ROOT / "frontend/vibematch_app"
    for path in [*app_root.rglob("*.dart")]:
        body = path.read_text(encoding="utf-8", errors="replace")
        if "package:http/http.dart" in body:
            raw_http_imports.append(str(path.relative_to(ROOT)))
    if raw_http_imports:
        raise SystemExit(
            "raw package:http imports remain: " + ", ".join(sorted(raw_http_imports))
        )

    docs = (ROOT / "docs/architecture/dependency-hygiene.md").read_text(
        encoding="utf-8"
    )
    for marker in ("Dependabot", "Major-version", "lockfiles", "removed"):
        if marker.lower() not in docs.lower():
            raise SystemExit(f"dependency hygiene docs missing {marker}")

    print("Dependency hygiene guard: OK")


if __name__ == "__main__":
    main()
