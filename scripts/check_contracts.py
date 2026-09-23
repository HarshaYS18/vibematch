"""Static contract checks that do not require protoc or Buf."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROTO_ROOT = ROOT / "contracts" / "proto"
EVENT_ROOT = ROOT / "contracts" / "events"

REQUIRED_PROTOS = {
    "common/v1/context.proto",
    "identity/v1/identity.proto",
    "room/v1/room.proto",
    "economy/v1/economy.proto",
    "inbox/v1/inbox.proto",
    "vibes/v1/vibes.proto",
    "game/v1/game.proto",
}
PACKAGE_RE = re.compile(r"^package\s+funkey\.([a-z][a-z0-9_]*)\.v([1-9][0-9]*)\s*;", re.MULTILINE)
SERVICE_RE = re.compile(r"^service\s+[A-Za-z][A-Za-z0-9_]*\s*\{", re.MULTILINE)
REQUEST_MESSAGE_RE = re.compile(r"message\s+([A-Za-z][A-Za-z0-9_]*(?:Request|Command))\s*\{(.*?)\n\}", re.DOTALL)
CONTEXT_FIELD_RE = re.compile(r"funkey\.common\.v1\.RequestContext\s+context\s*=\s*1\s*;")


def _fail(message: str) -> None:
    raise SystemExit(message)


def check_proto_contracts() -> None:
    if not PROTO_ROOT.is_dir():
        _fail("contracts/proto is missing")

    present = {
        path.relative_to(PROTO_ROOT).as_posix()
        for path in PROTO_ROOT.rglob("*.proto")
    }
    missing = REQUIRED_PROTOS - present
    if missing:
        _fail("missing required proto contracts: " + ", ".join(sorted(missing)))

    for relative in sorted(present):
        path = PROTO_ROOT / relative
        text = path.read_text(encoding="utf-8")
        if 'syntax = "proto3";' not in text:
            _fail(f"{relative}: proto3 syntax declaration is required")
        match = PACKAGE_RE.search(text)
        if match is None:
            _fail(f"{relative}: package must be versioned as funkey.<domain>.vN")
        if "/v" not in relative:
            _fail(f"{relative}: file path must include a version directory")
        if "service " in text and SERVICE_RE.search(text) is None:
            _fail(f"{relative}: malformed service declaration")

        if relative != "common/v1/context.proto":
            for message_name, body in REQUEST_MESSAGE_RE.findall(text):
                if not CONTEXT_FIELD_RE.search(body):
                    _fail(
                        f"{relative}: {message_name} must carry "
                        "funkey.common.v1.RequestContext context = 1"
                    )

        forbidden = ("Authorization", "Bearer ", "password", "otp", "secret")
        lowered = text.lower()
        for token in forbidden:
            if token.lower() in lowered:
                _fail(f"{relative}: forbidden credential-like contract token {token!r}")

    generated = PROTO_ROOT / "gen"
    if generated.exists():
        tracked_markers = [
            path for path in generated.rglob("*")
            if path.is_file() and path.name not in {".gitkeep"}
        ]
        if tracked_markers:
            _fail(
                "generated contract clients must not be committed under contracts/proto/gen; "
                "CI produces them as artifacts"
            )


def check_event_contracts() -> None:
    if not EVENT_ROOT.is_dir():
        _fail("contracts/events is missing")
    schemas = sorted(EVENT_ROOT.glob("*.schema.json"))
    if not schemas:
        _fail("at least one event JSON Schema is required")
    for path in schemas:
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            _fail(f"{path.relative_to(ROOT)}: invalid JSON: {exc}")
        if not isinstance(payload, dict):
            _fail(f"{path.relative_to(ROOT)}: schema root must be an object")
        if payload.get("$schema") is None:
            _fail(f"{path.relative_to(ROOT)}: $schema is required")
        if payload.get("type") != "object":
            _fail(f"{path.relative_to(ROOT)}: event schema root type must be object")


def main() -> int:
    check_proto_contracts()
    check_event_contracts()
    print("Contract static checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
