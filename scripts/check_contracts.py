"""Static contract checks that do not require protoc or Buf."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROTO_ROOT = ROOT / "contracts" / "proto"
EVENT_ROOT = ROOT / "contracts" / "events"

REQUIRED_PROTOS = {
    "funkey/common/v1/context.proto",
    "funkey/identity/v1/identity.proto",
    "funkey/room/v1/room.proto",
    "funkey/economy/v1/economy.proto",
    "funkey/inbox/v1/inbox.proto",
    "funkey/vibes/v1/vibes.proto",
    "funkey/game/v1/game.proto",
}
PACKAGE_RE = re.compile(r"^package\s+funkey\.([a-z][a-z0-9_]*)\.v([1-9][0-9]*)\s*;", re.MULTILINE)
SERVICE_RE = re.compile(r"^service\s+[A-Za-z][A-Za-z0-9_]*\s*\{", re.MULTILINE)
REQUEST_MESSAGE_RE = re.compile(
    r"message\s+([A-Za-z][A-Za-z0-9_]*(?:Request|Command))\s*\{(.*?)\n\}",
    re.DOTALL,
)
CONTEXT_FIELD_RE = re.compile(
    r"funkey\.common\.v1\.RequestContext\s+context\s*=\s*1\s*;"
)


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
        domain, version = match.groups()
        expected_prefix = f"funkey/{domain}/v{version}/"
        if not relative.startswith(expected_prefix):
            _fail(
                f"{relative}: package path must start with {expected_prefix}"
            )
        if "service " in text and SERVICE_RE.search(text) is None:
            _fail(f"{relative}: malformed service declaration")

        if relative != "funkey/common/v1/context.proto":
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
            path
            for path in generated.rglob("*")
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

    topic_catalogue = EVENT_ROOT / "kafka-topics-v1.json"
    if topic_catalogue.exists():
        try:
            catalogue = json.loads(topic_catalogue.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            _fail(f"{topic_catalogue.relative_to(ROOT)}: invalid JSON: {exc}")
        if catalogue.get("schema_version") != 1:
            _fail("Kafka topic catalogue schema_version must be 1")
        topics = catalogue.get("topics")
        if not isinstance(topics, list) or not topics:
            _fail("Kafka topic catalogue must contain topics")
        names = [item.get("name") for item in topics if isinstance(item, dict)]
        if len(names) != len(set(names)):
            _fail("Kafka topic names must be unique")
        for item in topics:
            if not isinstance(item, dict):
                _fail("Kafka topic catalogue entries must be objects")
            if not str(item.get("name") or "").startswith("funkey."):
                _fail("Kafka topic names must use the funkey.* namespace")
            if int(item.get("partitions") or 0) < 1:
                _fail("Kafka topic partitions must be positive")
            if int(item.get("retention_ms") or 0) < 1:
                _fail("Kafka topic retention_ms must be positive")
            if item.get("data_classification") not in {"internal_analytics", "restricted_analytics"}:
                _fail("Kafka topic data_classification is required")

    acl_policy = EVENT_ROOT / "kafka-acl-policy-v1.json"
    if acl_policy.exists():
        try:
            acl = json.loads(acl_policy.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            _fail(f"{acl_policy.relative_to(ROOT)}: invalid JSON: {exc}")
        if acl.get("schema_version") != 1:
            _fail("Kafka ACL policy schema_version must be 1")
        if not isinstance(acl.get("principals"), list) or not acl["principals"]:
            _fail("Kafka ACL policy must define principals")


def main() -> int:
    check_proto_contracts()
    check_event_contracts()
    print("Contract static checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
