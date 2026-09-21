#!/usr/bin/env python3
"""Fail CI when backend/media architecture drifts from the canonical layout."""

from __future__ import annotations

from pathlib import Path
import ast
import json
import re
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
            # Some historical source files include a UTF-8 BOM. It is valid
            # Python source and must not hide architecture violations.
            text = source.read_text(encoding="utf-8-sig")
            try:
                tree = ast.parse(text, filename=str(source))
            except SyntaxError as exc:
                errors.append(f"invalid Python: {source.relative_to(ROOT)}:{exc.lineno}: {exc.msg}")
                continue
            upper = re.sub(r"\s+", " ", text.upper())
            for token in DDL_TOKENS:
                if token in upper:
                    errors.append(
                        "runtime DDL is forbidden outside Alembic migrations: "
                        f"{source.relative_to(ROOT)} contains {token}"
                    )
            for node in ast.walk(tree):
                if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr in {"create_all", "drop_all", "create_table", "add_column", "create_index"}:
                    errors.append(f"runtime schema mutation: {source.relative_to(ROOT)}:{node.lineno}")
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and re.search(r"ensure_.*schema", node.name):
                    errors.append(f"runtime schema repair function: {source.relative_to(ROOT)}:{node.lineno}")
                if isinstance(node, ast.Call) and any(k.arg == "prefix" and isinstance(k.value, ast.Constant) and k.value.value == "/api/v1" for k in node.keywords):
                    if source != backend_app / "api" / "router.py":
                        errors.append(f"duplicate API root ownership: {source.relative_to(ROOT)}")

    # Detect executable implementations under arbitrary new directory names.
    for manifest in ROOT.rglob("package.json"):
        if any(part in {"node_modules", ".git", "build", ".dart_tool"} for part in manifest.parts):
            continue
        data = json.loads(manifest.read_text(encoding="utf-8"))
        dependencies = {**data.get("dependencies", {}), **data.get("devDependencies", {})}
        if "mediasoup" in dependencies and manifest.parent != ROOT / "backend_media":
            errors.append(f"noncanonical media executable: {manifest.relative_to(ROOT)}")

    retired_paths = ("/games/admin", "/economy/admin", "/super-owner/game-pools", "/super-owner/game-props", "/gifts/admin")
    for source in (ROOT / "frontend" / "vibematch_app" / "lib").rglob("*.dart"):
        text = source.read_text(encoding="utf-8")
        if any(path in text for path in retired_paths):
            errors.append(f"retired API consumer: {source.relative_to(ROOT)}")
        if re.search(r"https?://[^\s'\"]+:(4000|4100|9000)", text):
            errors.append(f"hard-coded media host: {source.relative_to(ROOT)}")

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
