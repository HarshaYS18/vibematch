#!/usr/bin/env python3
"""Fail CI when backend/media architecture drifts from the canonical layout."""

from __future__ import annotations

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]

LEGACY_MEDIA_DIRS = (
    ROOT / "audio-server",
    ROOT / "media-server",
    ROOT / "services" / "mediasoup-audio-server",
)

REQUIRED_PATHS = (
    ROOT / "backend" / "app" / "main.py",
    ROOT / "backend" / "app" / "api" / "router.py",
    ROOT / "backend" / "alembic.ini",
    ROOT / "backend" / "alembic" / "env.py",
    ROOT / "backend" / "alembic" / "versions",
    ROOT / "backend_media" / "package.json",
    ROOT / "backend_media" / "src" / "server.ts",
)

DDL_TOKENS = (
    "ALTER TABLE",
    "CREATE TABLE",
    "CREATE INDEX",
    "DROP TABLE",
    "ALTER TYPE",
)

STARTUP_FORBIDDEN = (
    "Base.metadata.create_all",
    "_ensure_runtime_schema",
)


def _has_tracked_content(path: Path) -> bool:
    return path.exists() and any(item.is_file() for item in path.rglob("*"))


def main() -> int:
    errors: list[str] = []

    for path in REQUIRED_PATHS:
        if not path.exists():
            errors.append(f"required canonical path is missing: {path.relative_to(ROOT)}")

    for path in LEGACY_MEDIA_DIRS:
        if _has_tracked_content(path):
            errors.append(
                "legacy executable media implementation must not exist: "
                f"{path.relative_to(ROOT)}"
            )

    main_py = ROOT / "backend" / "app" / "main.py"
    if main_py.exists():
        startup = main_py.read_text(encoding="utf-8")
        for token in STARTUP_FORBIDDEN:
            if token in startup:
                errors.append(
                    f"backend/app/main.py must not mutate/bootstrap schema at runtime: {token}"
                )

    backend_app = ROOT / "backend" / "app"
    if backend_app.exists():
        for source in backend_app.rglob("*.py"):
            text = source.read_text(encoding="utf-8")
            upper = text.upper()
            for token in DDL_TOKENS:
                if token in upper:
                    errors.append(
                        "runtime DDL is forbidden outside Alembic migrations: "
                        f"{source.relative_to(ROOT)} contains {token}"
                    )

    router_py = ROOT / "backend" / "app" / "api" / "router.py"
    if router_py.exists():
        router_text = router_py.read_text(encoding="utf-8")
        if 'APIRouter(prefix="/api/v1")' not in router_text:
            errors.append("backend/app/api/router.py must own the /api/v1 root prefix")

    versions = ROOT / "backend" / "alembic" / "versions"
    if versions.exists() and not any(versions.glob("*.py")):
        errors.append("Alembic versions directory contains no migrations")

    if errors:
        print("Backend architecture check FAILED:")
        for error in errors:
            print(f" - {error}")
        return 1

    print("Backend architecture check passed.")
    print(" - FastAPI owns the control/API plane")
    print(" - backend_media is the sole executable mediasoup implementation")
    print(" - Alembic is the sole schema mutation path")
    print(" - /api/v1 is owned by the canonical router")
    return 0


if __name__ == "__main__":
    sys.exit(main())
