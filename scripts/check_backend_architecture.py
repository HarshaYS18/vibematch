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

AUTHORITY_REGISTRY = ROOT / "contracts" / "architecture" / "authorities.yaml"
REDIS_TOPOLOGY = ROOT / "contracts" / "redis" / "topology.json"
REQUIRED_REDIS_ROLES = {
    "app_cache_rate_limit",
    "realtime_presence",
    "media_registry",
}
ROOM_STATE_ENGINE_MIGRATION = (
    ROOT / "backend" / "alembic" / "versions" /
    "20260923_0200_room_state_engine_v2.py"
)
ALLOWED_STATE_CLASSES = {"AUTHORITY", "PROJECTION", "CACHE", "EPHEMERAL"}
REQUIRED_AUTHORITY_STATE_IDS = {
    "identity.accounts", "identity.sessions", "profiles.public", "rooms.definition",
    "rooms.membership", "rooms.permissions", "rooms.seats", "presence.online_lease",
    "rooms.watch_party", "rooms.activity", "inbox.conversations", "vibes.content",
    "economy.wallet_ledger", "gifts.settlement", "games.catalog_rounds",
    "games.financial_settlement", "missions.progress", "missions.reward_claims",
    "families.membership", "notifications.in_app", "media.metadata", "media.objects",
    "search.index", "analytics.event_stream", "recommendations.ranking",
    "client.room_session_cache",
}
FINANCIAL_AUTHORITY_STATE_IDS = {
    "economy.wallet_ledger", "economy.supply_ledger", "gifts.settlement",
    "games.financial_settlement", "missions.reward_claims",
}
FORBIDDEN_DURABLE_AUTHORITY_OWNERS = {
    "realtime", "search-projection", "analytics", "recommendation", "flutter",
}


def _validate_authority_registry(errors: list[str]) -> None:
    if not AUTHORITY_REGISTRY.exists():
        errors.append("machine-readable authority registry is missing")
        return
    try:
        payload = json.loads(AUTHORITY_REGISTRY.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"authority registry is not valid JSON-compatible YAML: {exc}")
        return
    if payload.get("schema_version") != 1:
        errors.append("authority registry schema_version must be 1")
    states = payload.get("states")
    if not isinstance(states, list) or not states:
        errors.append("authority registry must contain a non-empty states list")
        return

    by_id: dict[str, dict] = {}
    for index, item in enumerate(states):
        if not isinstance(item, dict):
            errors.append(f"authority registry state #{index} must be an object")
            continue
        state_id = str(item.get("id") or "").strip()
        if not state_id:
            errors.append(f"authority registry state #{index} is missing id")
            continue
        if state_id in by_id:
            errors.append(f"duplicate authority registry state id: {state_id}")
            continue
        by_id[state_id] = item
        kind = item.get("classification")
        if kind not in ALLOWED_STATE_CLASSES:
            errors.append(f"{state_id}: invalid classification {kind!r}")
        if not str(item.get("logical_owner") or "").strip():
            errors.append(f"{state_id}: logical_owner is required")
        if not str(item.get("current_deployable") or "").strip():
            errors.append(f"{state_id}: current_deployable is required")
        if not isinstance(item.get("current_storage"), list) or not item["current_storage"]:
            errors.append(f"{state_id}: current_storage must be non-empty")
        if not isinstance(item.get("target_storage"), list) or not item["target_storage"]:
            errors.append(f"{state_id}: target_storage must be non-empty")
        if kind == "AUTHORITY":
            if not isinstance(item.get("mutated_by"), list) or not item["mutated_by"]:
                errors.append(f"{state_id}: authority must declare mutated_by")
            if item.get("logical_owner") in FORBIDDEN_DURABLE_AUTHORITY_OWNERS:
                errors.append(f"{state_id}: transport/projection/client owner cannot own durable truth")
        elif kind in {"PROJECTION", "CACHE"}:
            if not isinstance(item.get("source_states"), list) or not item["source_states"]:
                errors.append(f"{state_id}: {kind} must declare source_states")
        elif kind == "EPHEMERAL":
            if not isinstance(item.get("rebuild_from"), list) or not item["rebuild_from"]:
                errors.append(f"{state_id}: EPHEMERAL state must declare rebuild_from")

    missing = REQUIRED_AUTHORITY_STATE_IDS.difference(by_id)
    if missing:
        errors.append("authority registry missing required states: " + ", ".join(sorted(missing)))
    for state_id, item in by_id.items():
        for source in item.get("source_states") or []:
            if source not in by_id:
                errors.append(f"{state_id}: unknown source_state {source}")
    for state_id in FINANCIAL_AUTHORITY_STATE_IDS:
        item = by_id.get(state_id)
        if item and (item.get("classification") != "AUTHORITY" or item.get("logical_owner") != "economy"):
            errors.append(f"{state_id}: financial truth must be AUTHORITY owned by economy")



def _validate_redis_topology(errors: list[str]) -> None:
    if not REDIS_TOPOLOGY.exists():
        errors.append("machine-readable Redis topology contract is missing")
        return
    try:
        payload = json.loads(REDIS_TOPOLOGY.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"Redis topology contract is invalid JSON: {exc}")
        return
    if payload.get("authority") != "EPHEMERAL_OR_CACHE_ONLY":
        errors.append("Redis topology must never declare durable business authority")
    roles = payload.get("roles")
    if not isinstance(roles, dict):
        errors.append("Redis topology roles must be an object")
        return
    missing = REQUIRED_REDIS_ROLES.difference(roles)
    if missing:
        errors.append("Redis topology missing roles: " + ", ".join(sorted(missing)))
    endpoint_envs = []
    for role_name in REQUIRED_REDIS_ROLES.intersection(roles):
        role = roles[role_name]
        endpoint_env = str(role.get("endpoint_env") or "").strip()
        if not endpoint_env:
            errors.append(f"{role_name}: endpoint_env is required")
        endpoint_envs.append(endpoint_env)
        if not role.get("ha_required"):
            errors.append(f"{role_name}: HA is required")
        if not role.get("maxmemory_required"):
            errors.append(f"{role_name}: maxmemory ceiling is required")
        if role.get("redis_cluster_supported_by_current_client") is not False:
            errors.append(f"{role_name}: current clients must not claim Redis Cluster support")
    if len(endpoint_envs) != len(set(endpoint_envs)):
        errors.append("Redis roles must use distinct endpoint environment variables")

    forbidden_generic = {
        ROOT / "backend" / "app" / "realtime" / "connection_manager.py": "settings.redis_url",
        ROOT / "backend" / "app" / "websocket" / "inbox_ws.py": "settings.redis_url",
        ROOT / "backend" / "app" / "api" / "routes" / "media_control.py": "get_redis",
        ROOT / "backend" / "app" / "api" / "routes" / "media_realtime_auth.py": "get_redis",
    }
    for path, token in forbidden_generic.items():
        if path.exists() and token in path.read_text(encoding="utf-8"):
            errors.append(
                f"{path.relative_to(ROOT)} must use its explicit Redis role instead of {token}"
            )


def _function_source(text: str, name: str) -> str:
    match = re.search(
        rf"^def {re.escape(name)}\(.*?(?=^def |^async def |\Z)",
        text,
        flags=re.MULTILINE | re.DOTALL,
    )
    return match.group(0) if match else ""


def _validate_room_state_engine(errors: list[str]) -> None:
    if not ROOM_STATE_ENGINE_MIGRATION.exists():
        errors.append("Chunk 20 Room State Engine v2 migration is missing")

    room_model = ROOT / "backend" / "app" / "models" / "room.py"
    realtime_model = ROOT / "backend" / "app" / "models" / "room_realtime_state.py"
    state_service = ROOT / "backend" / "app" / "services" / "rooms" / "room_state_service.py"
    command_routes = ROOT / "backend" / "app" / "api" / "routes" / "room_realtime_commands.py"
    socket_routes = ROOT / "backend" / "app" / "api" / "routes" / "room_realtime.py"
    legacy_routes = ROOT / "backend" / "app" / "api" / "routes" / "rooms" / "rooms.py"
    presence_controller = (
        ROOT / "frontend" / "vibematch_app" / "lib" / "features" / "rooms" /
        "presentation" / "controllers" / "live_room_presence_controller.dart"
    )
    room_repository = (
        ROOT / "frontend" / "vibematch_app" / "lib" /
        "room_session" / "data" / "room_session_repository.dart"
    )

    if room_model.exists():
        text = room_model.read_text(encoding="utf-8")
        for token in ("realtime_version", "realtime_event_sequence"):
            if token not in text:
                errors.append(f"rooms model must persist {token}")

    if realtime_model.exists():
        text = realtime_model.read_text(encoding="utf-8")
        for token in (
            "event_id", "room_version", "class RoomMemberRequest",
            "class RoomSeatApplication",
        ):
            if token not in text:
                errors.append(f"room realtime model missing Chunk 20 contract: {token}")

    if state_service.exists():
        text = state_service.read_text(encoding="utf-8")
        snapshot = _function_source(text, "room_snapshot")
        for token in (
            "ensure_room_seats(",
            "cleanup_orphaned_seat_occupants(",
            "cleanup_stale_participants(",
            "db.flush()",
        ):
            if token in snapshot:
                errors.append(f"room_snapshot must be read-only; found {token}")
        for name, required, forbidden in (
            ("pending_room_member_requests", "RoomMemberRequest", "RoomRealtimeEvent"),
            ("pending_seat_applications", "RoomSeatApplication", "RoomRealtimeEvent"),
        ):
            source = _function_source(text, name)
            if required not in source or forbidden in source:
                errors.append(
                    f"{name} must query dedicated current state, not room event history"
                )

    if command_routes.exists():
        heartbeat = _function_source(
            command_routes.read_text(encoding="utf-8"), "heartbeat"
        )
        if "room_snapshot(" in heartbeat or "heartbeat_room(" in heartbeat:
            errors.append("realtime REST heartbeat must not construct a room snapshot")

    if legacy_routes.exists():
        heartbeat = _function_source(
            legacy_routes.read_text(encoding="utf-8"), "heartbeat_live_room"
        )
        if "heartbeat_room(" in heartbeat or "list_room_participants(" in heartbeat:
            errors.append("legacy room heartbeat must not construct a roster snapshot")

    if socket_routes.exists():
        text = socket_routes.read_text(encoding="utf-8")
        if "_room_heartbeat_for_user" in text:
            errors.append("socket heartbeat must not retain the old DB heartbeat helper")
        if "replay_room(" not in text:
            errors.append("room resume must support bounded replay before snapshot fallback")

    if presence_controller.exists():
        text = presence_controller.read_text(encoding="utf-8")
        if "Timer.periodic" in text or "_sendHeartbeat" in text:
            errors.append("live room presence must not poll PostgreSQL with a timer")

    if room_repository.exists():
        text = room_repository.read_text(encoding="utf-8")
        for token in ("reconcileDelta(", "recoverFromRealtimeGap("):
            if token not in text:
                errors.append(f"RoomSessionRepository missing Chunk 20 method {token}")

    flutter_lib = ROOT / "frontend" / "vibematch_app" / "lib"
    if flutter_lib.exists():
        for source in flutter_lib.rglob("*.dart"):
            text = source.read_text(encoding="utf-8")
            if "RoomEngineManager.instance" in text:
                errors.append(
                    "RoomSessionRepository is canonical; RoomEngineManager.instance is forbidden: "
                    f"{source.relative_to(ROOT)}"
                )

def _has_tracked_content(path: Path) -> bool:
    return path.exists() and any(item.is_file() for item in path.rglob("*"))


def main() -> int:
    errors: list[str] = []
    _validate_authority_registry(errors)
    _validate_redis_topology(errors)
    _validate_room_state_engine(errors)

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
        for retired_mount in ("inbox_ws.router", "room_realtime.router"):
            if retired_mount in router_text:
                errors.append(
                    "Chunk 21 one-socket cutover forbids mounted legacy FastAPI websocket: "
                    + retired_mount
                )

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
    print(" - mutable state ownership conforms to contracts/architecture/authorities.yaml")
    print(" - Redis roles conform to contracts/redis/topology.json")
    print(" - Room State Engine v2 heartbeat/snapshot/current-state invariants hold")
    print(" - legacy FastAPI application websocket routes are not mounted")
    return 0


if __name__ == "__main__":
    sys.exit(main())
