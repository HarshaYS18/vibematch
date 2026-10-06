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
DATABASE_STORAGE_POLICY = ROOT / "contracts" / "database" / "storage-policy.json"
QUERY_BUDGET_MODULE = ROOT / "backend" / "app" / "core" / "query_budget.py"
POSTGRES_HOT_PATH_MIGRATION = (
    ROOT / "backend" / "alembic" / "versions" /
    "20260924_0200_postgres_hot_path_indexes.py"
)
REQUIRED_REDIS_ROLES = {
    "app_cache_rate_limit",
    "realtime_presence",
    "media_registry",
}
ROOM_STATE_ENGINE_MIGRATION = (
    ROOT / "backend" / "alembic" / "versions" /
    "20260923_0200_room_state_engine_v2.py"
)
INBOX_SERVICE_MIGRATION = (
    ROOT / "backend" / "alembic" / "versions" /
    "20260923_0300_inbox_service_extraction.py"
)
INBOX_OWNERSHIP_SQL = ROOT / "deploy" / "postgres" / "inbox-ownership.sql"
INBOX_SERVICE_ROOT = ROOT / "apps" / "inbox-service"
VIBES_SERVICE_MIGRATION = (
    ROOT / "backend" / "alembic" / "versions" /
    "20260924_0100_vibes_feed_service.py"
)
VIBES_OWNERSHIP_SQL = ROOT / "deploy" / "postgres" / "vibes-ownership.sql"
VIBES_SERVICE_ROOT = ROOT / "apps" / "vibes-service"
ROOM_CONTROL_SERVICE_ROOT = ROOT / "apps" / "room-control-service"
ROOM_CONTROL_OWNERSHIP_SQL = ROOT / "deploy" / "postgres" / "room-control-ownership.sql"
IDENTITY_SERVICE_ROOT = ROOT / "apps" / "identity-service"
PROFILE_SOCIAL_SERVICE_ROOT = ROOT / "apps" / "profile-social-service"
IDENTITY_OWNERSHIP_SQL = ROOT / "deploy" / "postgres" / "identity-ownership.sql"
PROFILE_SOCIAL_OWNERSHIP_SQL = ROOT / "deploy" / "postgres" / "profile-social-ownership.sql"
IDENTITY_PROFILE_SOCIAL_MIGRATION = ROOT / "backend" / "alembic" / "versions" / "20260924_0300_identity_profile_social_boundaries.py"
GAME_PLATFORM_SERVICE_ROOT = ROOT / "apps" / "game-platform-service"
GAME_PLATFORM_OWNERSHIP_SQL = ROOT / "deploy" / "postgres" / "game-platform-ownership.sql"
GAME_PLATFORM_RUNTIME_MIGRATION = ROOT / "backend" / "alembic" / "versions" / "20260924_0800_game_platform_runtime.py"
ALLOWED_STATE_CLASSES = {"AUTHORITY", "PROJECTION", "CACHE", "EPHEMERAL"}
REQUIRED_AUTHORITY_STATE_IDS = {
    "identity.accounts", "identity.sessions", "profiles.public", "rooms.definition",
    "rooms.membership", "rooms.permissions", "rooms.seats", "presence.online_lease",
    "rooms.watch_party", "rooms.activity", "inbox.conversations", "vibes.content",
    "economy.wallet_ledger", "gifts.settlement", "games.catalog_rounds",
    "games.financial_settlement", "missions.progress", "missions.reward_claims",
    "families.membership", "notifications.in_app", "media.metadata", "media.objects",
    "search.index", "analytics.event_stream", "analytics.warehouse",
    "recommendations.ranking", "client.room_session_cache",
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
    updated_for_chunk = payload.get("updated_for_chunk")
    if not isinstance(updated_for_chunk, int) or updated_for_chunk < 56:
        errors.append("authority registry must reflect repository reality through Chunk 56")
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

    deployed_projection_expectations = {
        "analytics.event_stream": ("kafka-event-bridge", "Chunk 37"),
        "search.index": ("search-service", "Chunk 38"),
        "recommendations.ranking": ("recommendation-service", "Chunk 39"),
        "analytics.warehouse": ("analytics-sink", "Chunk 48"),
    }
    for state_id, (deployable_marker, chunk_marker) in deployed_projection_expectations.items():
        item = by_id.get(state_id)
        if not item:
            continue
        current_deployable = str(item.get("current_deployable") or "")
        current_storage = " ".join(str(value) for value in (item.get("current_storage") or []))
        migration_status = str(item.get("migration_status") or "")
        change_status = str((item.get("change_contract") or {}).get("status") or "")
        if deployable_marker not in current_deployable:
            errors.append(
                f"{state_id}: current_deployable must include {deployable_marker} after {chunk_marker}"
            )
        if "not deployed" in current_deployable.lower() or "no " in current_storage.lower():
            errors.append(f"{state_id}: stale pre-deployment authority registry state remains")
        if change_status != "live":
            errors.append(f"{state_id}: change contract must be live after {chunk_marker}")
        if chunk_marker not in migration_status:
            errors.append(f"{state_id}: migration_status must record {chunk_marker} completion")



def _validate_database_hardening(errors: list[str]) -> None:
    required = (
        DATABASE_STORAGE_POLICY,
        QUERY_BUDGET_MODULE,
        POSTGRES_HOT_PATH_MIGRATION,
        ROOT / "backend" / "tests" / "test_postgres_query_plans.py",
        ROOT / "backend" / "tests" / "test_query_budget_contract.py",
    )
    for path in required:
        if not path.exists():
            errors.append(
                "Chunk 25 database hardening path is missing: "
                + str(path.relative_to(ROOT))
            )

    if DATABASE_STORAGE_POLICY.exists():
        try:
            policy = json.loads(DATABASE_STORAGE_POLICY.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"database storage policy is invalid JSON: {exc}")
            policy = {}
        if policy.get("schema_version") != 1:
            errors.append("database storage policy schema_version must be 1")
        if policy.get("durable_business_authority") != "postgresql":
            errors.append("PostgreSQL must remain durable business authority")
        replica = policy.get("read_replicas") or {}
        if replica.get("enabled") is not False:
            approved = replica.get("approved_stale_tolerant_routes") or []
            if not approved:
                errors.append(
                    "read replicas cannot be enabled without approved stale-tolerant routes"
                )
        partitioning = policy.get("partitioning") or {}
        enabled_tables = partitioning.get("enabled_tables")
        if not isinstance(enabled_tables, list):
            errors.append("partitioning.enabled_tables must be a list")
            enabled_tables = []
        cache = policy.get("redis_cache_policy") or {}
        for key in (
            "ttl_required_for_business_projection_keys",
            "version_required_for_business_projection_payloads",
            "loss_must_preserve_postgres_correctness",
        ):
            if cache.get(key) is not True:
                errors.append("database cache policy must require " + key)
        if cache.get("durable_authority") is not False:
            errors.append("Redis/cache must never be durable business authority")

        versions = ROOT / "backend" / "alembic" / "versions"
        if versions.exists() and not enabled_tables:
            for migration in versions.glob("*.py"):
                text = migration.read_text(encoding="utf-8-sig").upper()
                if "PARTITION BY" in text:
                    errors.append(
                        "table partitioning requires storage-policy evidence: "
                        + str(migration.relative_to(ROOT))
                    )

    if QUERY_BUDGET_MODULE.exists():
        text = QUERY_BUDGET_MODULE.read_text(encoding="utf-8")
        for route in (
            "/api/v1/vibes/feed",
            "/api/v1/vibes/friends",
            "/api/v1/vibes/saved",
            "/api/v1/inbox/conversations",
            "/api/v1/inbox/conversations/{conversation_id}/messages",
        ):
            if route not in text:
                errors.append("hot route is missing a DB query budget: " + route)

    if POSTGRES_HOT_PATH_MIGRATION.exists():
        text = POSTGRES_HOT_PATH_MIGRATION.read_text(encoding="utf-8")
        for index_name in (
            "ix_vibe_posts_live_feed_cursor",
            "ix_inbox_messages_conversation_cursor",
        ):
            if index_name not in text:
                errors.append("Chunk 25 hot-path index missing: " + index_name)


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

def _validate_inbox_service_extraction(errors: list[str]) -> None:
    required = (
        INBOX_SERVICE_ROOT / "main.py",
        INBOX_SERVICE_ROOT / "database.py",
        INBOX_SERVICE_ROOT / "internal.py",
        INBOX_SERVICE_ROOT / "realtime.py",
        INBOX_SERVICE_ROOT / "Dockerfile",
        INBOX_SERVICE_MIGRATION,
        INBOX_OWNERSHIP_SQL,
    )
    for path in required:
        if not path.exists():
            errors.append(
                "Chunk 23 Inbox extraction path is missing: "
                + str(path.relative_to(ROOT))
            )

    router_path = ROOT / "backend" / "app" / "api" / "router.py"
    if router_path.exists():
        text = router_path.read_text(encoding="utf-8")
        if "inbox_proxy.router" not in text:
            errors.append("core API must use the Inbox service compatibility proxy")
        for forbidden in (
            "api_router.include_router(inbox.router)",
            "api_router.include_router(inbox_preferences.router",
            "api_router.include_router(inbox_calls.router",
            "api_router.include_router(inbox_message_tools.router",
        ):
            if forbidden in text:
                errors.append(
                    "core API must not mount Inbox chat write authority: " + forbidden
                )

    route_path = ROOT / "backend" / "app" / "api" / "routes" / "inbox.py"
    if route_path.exists():
        text = route_path.read_text(encoding="utf-8")
        for function_name in ("list_conversations", "get_conversation"):
            source = _function_source(text, function_name)
            for forbidden in (
                "ensure_team_conversation(",
                "_merge_duplicate_direct_conversations_for_user(",
                "mark_messages_read_for_user(",
                "mark_secret_drift_open(",
                ".commit(",
            ):
                if forbidden in source:
                    errors.append(
                        f"Inbox {function_name} GET must be read-only; found {forbidden}"
                    )
        for required_token in (
            "list_conversations_page(",
            "list_messages_page(",
            "limit=1",
            "include_messages=False",
            '"/conversations/{conversation_id}/read"',
        ):
            if required_token not in text:
                errors.append(
                    "Inbox public API missing bounded/explicit read contract: "
                    + required_token
                )

    service_path = ROOT / "backend" / "app" / "services" / "inbox_service.py"
    if service_path.exists():
        text = service_path.read_text(encoding="utf-8")
        list_source = _function_source(text, "list_conversations")
        if (
            "ensure_team_conversation(" in list_source
            or "_merge_duplicate_direct_conversations_for_user(" in list_source
        ):
            errors.append("Inbox list_conversations must never repair/bootstrap during reads")
        for required_token in (
            "ACTIVE_MESSAGE_WINDOW",
            "def list_conversations_page(",
            "def list_messages_page(",
            "InboxReadReceipt",
        ):
            if required_token not in text:
                errors.append(
                    "Inbox service missing Chunk 23 bounded state contract: "
                    + required_token
                )

    # Direct Inbox ORM/service writes are legal only inside the extracted
    # module implementation. Other domains must cross the authenticated
    # service client boundary.
    backend_app = ROOT / "backend" / "app"
    allowed_direct = {
        Path("models/__init__.py"),
        Path("models/inbox.py"),
        Path("models/inbox_backup.py"),
        Path("models/inbox_preferences.py"),
        Path("models/call_session.py"),
        Path("services/inbox_service.py"),
        Path("services/inbox_preference_service.py"),
        Path("services/inbox_backup_service.py"),
        Path("services/inbox_lock_service.py"),
        Path("services/inbox_call_service.py"),
        Path("services/inbox_call_contract_service.py"),
        Path("services/inbox_realtime_command_service.py"),
        Path("services/inbox_ai_service.py"),
        Path("services/message_search_service.py"),
        Path("services/call_session_service.py"),
        Path("api/routes/inbox.py"),
        Path("api/routes/inbox_preferences.py"),
        Path("api/routes/inbox_backup_google.py"),
        Path("api/routes/inbox_message_tools.py"),
        Path("api/routes/inbox_calls.py"),
        Path("api/routes/inbox_ai.py"),
        Path("api/routes/calls.py"),
        Path("websocket/inbox_ws.py"),
    }
    direct_tokens = (
        "from app.models.inbox import",
        "from app.models.inbox_preferences import",
        "from app.services.inbox_service import",
    )
    if backend_app.exists():
        for source in backend_app.rglob("*.py"):
            relative = source.relative_to(backend_app)
            if relative in allowed_direct:
                continue
            text = source.read_text(encoding="utf-8-sig")
            imports_direct_service = re.search(
                r"from app\.services import(?:\s*\([^)]*)?\binbox_service\b",
                text,
                flags=re.DOTALL,
            )
            if any(token in text for token in direct_tokens) or imports_direct_service:
                errors.append(
                    "cross-domain direct Inbox access is forbidden; use "
                    "inbox_service_client: "
                    + str(source.relative_to(ROOT))
                )
            chat_owned_fk_targets = (
                "inbox_conversations.",
                "inbox_participants.",
                "inbox_messages.",
                "inbox_read_receipts.",
                "inbox_reports.",
                "inbox_lock_settings.",
                "inbox_lock_otps.",
                "inbox_user_preferences.",
                "inbox_conversation_user_settings.",
                "inbox_message_user_states.",
                "inbox_backup_settings.",
                "inbox_backup_jobs.",
            )
            if any(
                f'ForeignKey("{target}' in text
                or f"ForeignKey('{target}" in text
                for target in chat_owned_fk_targets
            ):
                errors.append(
                    "cross-domain Inbox foreign key is forbidden after extraction: "
                    + str(source.relative_to(ROOT))
                )

    realtime_auth_path = (
        ROOT / "backend" / "app" / "api" / "routes" /
        "realtime_gateway_auth.py"
    )
    if realtime_auth_path.exists():
        text = realtime_auth_path.read_text(encoding="utf-8")
        if "room_control_service_client.authorize_room_action" not in text:
            errors.append("core realtime authorization must use Room Control")
        if "room_control_service_client.execute_realtime_command" not in text:
            errors.append("core realtime commands must execute through Room Control")
        for forbidden in (
            "from app.models.room import Room",
            "evaluate_media_room_permission(",
            "db.query(Room)",
        ):
            if forbidden in text:
                errors.append(
                    "core realtime auth must not bypass Room Control: " + forbidden
                )

    media_auth_path = (
        ROOT / "backend" / "app" / "services" /
        "media_realtime_auth_service.py"
    )
    if media_auth_path.exists():
        text = media_auth_path.read_text(encoding="utf-8")
        if "room_control_service_client.authorize_room_action" not in text:
            errors.append("ordinary room media authorization must use Room Control")
        for forbidden in (
            "from app.models.room import Room",
            "evaluate_media_room_permission(",
            "db.query(Room)",
        ):
            if forbidden in text:
                errors.append(
                    "core media auth must not bypass Room Control: " + forbidden
                )

    internal_path = ROOM_CONTROL_SERVICE_ROOT / "internal.py"
    if internal_path.exists():
        text = internal_path.read_text(encoding="utf-8")
        for required_token in (
            '"/authorize"',
            '"/command"',
            "evaluate_media_room_permission(",
            "execute_application_realtime_command(",
        ):
            if required_token not in text:
                errors.append(
                    "Room Control internal authority API missing: " + required_token
                )

    authority = json.loads(AUTHORITY_REGISTRY.read_text(encoding="utf-8"))
    inbox = next(
        (state for state in authority.get("states", [])
         if state.get("id") == "inbox.conversations"),
        None,
    )
    if not inbox or inbox.get("current_deployable") != "inbox-service":
        errors.append("authority registry must declare inbox-service as current Inbox deployable")

    gateway_server = (
        ROOT / "apps" / "realtime-gateway" / "internal" / "gateway" / "server.go"
    )
    if gateway_server.exists():
        text = gateway_server.read_text(encoding="utf-8")
        for token in ("ConsumeNATSEvents", "NATSInboxSubject"):
            if token not in text:
                errors.append("Go realtime missing Inbox NATS fanout: " + token)


def _validate_vibes_service_extraction(errors: list[str]) -> None:
    required = (
        VIBES_SERVICE_ROOT / "main.py",
        VIBES_SERVICE_ROOT / "database.py",
        VIBES_SERVICE_ROOT / "internal.py",
        VIBES_SERVICE_ROOT / "Dockerfile",
        VIBES_SERVICE_MIGRATION,
        VIBES_OWNERSHIP_SQL,
        ROOT / "backend" / "app" / "services" / "vibes_feed_service.py",
    )
    for path in required:
        if not path.exists():
            errors.append(
                "Chunk 24 Vibes extraction path is missing: "
                + str(path.relative_to(ROOT))
            )

    router_path = ROOT / "backend" / "app" / "api" / "router.py"
    if router_path.exists():
        text = router_path.read_text(encoding="utf-8")
        if "vibes_proxy.router" not in text or "vibes_proxy.admin_router" not in text:
            errors.append("core API must use the Vibes service compatibility proxy")
        for forbidden in (
            "api_router.include_router(vibes.router)",
            "vibes.admin_router",
        ):
            if forbidden in text:
                errors.append(
                    "core API must not mount Vibes write authority: " + forbidden
                )

    model_path = ROOT / "backend" / "app" / "models" / "vibe.py"
    if model_path.exists():
        text = model_path.read_text(encoding="utf-8")
        for counter in (
            "likes_count", "comments_count", "shares_count",
            "saves_count", "reports_count",
        ):
            if counter not in text:
                errors.append("VibePost missing denormalized counter: " + counter)

    route_path = ROOT / "backend" / "app" / "api" / "routes" / "vibes.py"
    if route_path.exists():
        text = route_path.read_text(encoding="utf-8")
        post_response = _function_source(text, "_post_response")
        if "func.count(" in post_response or ".query(" in post_response:
            errors.append("Vibes _post_response must not execute per-post SQL")
        for token in (
            "cursor: str | None",
            'mode="global"',
            'mode="friends"',
            'event_type="vibes.post.published"',
        ):
            if token not in text:
                errors.append("Vibes Chunk 24 route contract missing: " + token)
        for forbidden in ("_send_vibe_notifications(", "notification_service.create_notification("):
            if forbidden in text:
                errors.append("Vibes request path must not synchronously fan out: " + forbidden)

    feed_path = ROOT / "backend" / "app" / "services" / "vibes_feed_service.py"
    if feed_path.exists():
        text = feed_path.read_text(encoding="utf-8")
        for token in (
            "class FeedCandidateProvider", "class FeedRanker",
            "class FeedPolicy", "class FeedRepository",
            "VibeReaction.post_id.in_(post_ids)",
            "VibeSave.post_id.in_(post_ids)",
        ):
            if token not in text:
                errors.append("Vibes feed seam missing: " + token)

    authority = json.loads(AUTHORITY_REGISTRY.read_text(encoding="utf-8"))
    vibes = next(
        (state for state in authority.get("states", [])
         if state.get("id") == "vibes.content"),
        None,
    )
    if not vibes or vibes.get("current_deployable") != "vibes-service":
        errors.append("authority registry must declare vibes-service as current Vibes deployable")



def _validate_room_control_extraction(errors: list[str]) -> None:
    required = (
        ROOM_CONTROL_SERVICE_ROOT / "main.py",
        ROOM_CONTROL_SERVICE_ROOT / "database.py",
        ROOM_CONTROL_SERVICE_ROOT / "internal.py",
        ROOM_CONTROL_SERVICE_ROOT / "Dockerfile",
        ROOM_CONTROL_OWNERSHIP_SQL,
        ROOT / "backend" / "app" / "api" / "routes" / "room_control_proxy.py",
        ROOT / "backend" / "app" / "api" / "routes" / "room_cross_domain.py",
        ROOT / "backend" / "app" / "services" / "room_control_service_client.py",
        ROOT / "backend" / "app" / "services" / "rooms" / "room_db_context.py",
    )
    for path in required:
        if not path.exists():
            errors.append(
                "Chunk 26 Room Control extraction path is missing: "
                + str(path.relative_to(ROOT))
            )

    router_path = ROOT / "backend" / "app" / "api" / "router.py"
    if router_path.exists():
        text = router_path.read_text(encoding="utf-8")
        for required_token in (
            "room_control_proxy.router",
            "room_control_proxy.admin_router",
            "room_cross_domain.router",
        ):
            if required_token not in text:
                errors.append("core API missing Room Control boundary: " + required_token)
        for forbidden in (
            "rooms.router",
            "rooms.admin_router",
            "room_realtime_commands.router",
        ):
            if forbidden in text:
                errors.append(
                    "core API must not mount Room Control authority directly: "
                    + forbidden
                )
        if (
            "media_control.router" in text
            and "room_control_proxy.router" in text
            and text.index("media_control.router") > text.index("room_control_proxy.router")
        ):
            errors.append(
                "media_control must be registered before the Room Control catch-all proxy"
            )

    command_path = (
        ROOT / "backend" / "app" / "api" / "routes" /
        "room_realtime_commands.py"
    )
    if command_path.exists():
        text = command_path.read_text(encoding="utf-8")
        if "SessionLocal" in text:
            errors.append(
                "Room realtime commands must use room_session(), not core SessionLocal"
            )
        if "with room_session() as db:" not in text:
            errors.append("Room realtime command transaction missing room_session()")

    rooms_path = ROOT / "backend" / "app" / "api" / "routes" / "rooms" / "rooms.py"
    if rooms_path.exists():
        text = rooms_path.read_text(encoding="utf-8")
        for forbidden in (
            '"/themes/purchase"',
            '"/{room_public_id}/contributions"',
            "purchase_room_theme(",
            "room_contribution_rankings(",
        ):
            if forbidden in text:
                errors.append(
                    "cross-domain room route must stay in core orchestration: "
                    + forbidden
                )
        if "room_session()" not in text:
            errors.append("Room snapshot background work must use room_session()")

    theme_path = (
        ROOT / "backend" / "app" / "services" / "rooms" /
        "room_theme_service.py"
    )
    if theme_path.exists():
        text = theme_path.read_text(encoding="utf-8")
        for forbidden in ("UserWallet", "WalletLedger", "EconomyCurrency", "EconomyDirection"):
            if forbidden in text:
                errors.append(
                    "Room Control theme service must not write economy authority: "
                    + forbidden
                )
        for required_token in (
            "room_theme_purchase_quote",
            "grant_room_theme_inventory",
        ):
            if required_token not in text:
                errors.append("Room theme authority seam missing: " + required_token)

    for relative in (
        "backend/app/services/rooms/room_service.py",
        "backend/app/services/rooms/room_action_service.py",
    ):
        path = ROOT / relative
        if path.exists() and re.search(
            r"\b(?:user|current_user)\.last_seen_at\s*=",
            path.read_text(encoding="utf-8"),
        ):
            errors.append(
                "Room Control must not mutate identity last_seen_at: " + relative
            )

    if ROOM_CONTROL_OWNERSHIP_SQL.exists():
        text = ROOM_CONTROL_OWNERSHIP_SQL.read_text(encoding="utf-8")
        for table in (
            "rooms",
            "room_participants",
            "room_seat_states",
            "room_realtime_events",
            "room_member_requests",
            "room_seat_applications",
            "room_chat_messages",
            "room_kickouts",
            "room_themes",
            "user_room_theme_inventory",
            "room_theme_reviews",
            "cricket_tournaments",
            "cricket_matches",
            "cricket_ball_events",
        ):
            if f"ALTER TABLE {table} OWNER TO funkey_room_control_owner" not in text:
                errors.append("Room Control ownership missing table: " + table)
        if "REVOKE ALL ON TABLE user_room_presence FROM funkey_room_control_runtime" not in text:
            errors.append("Room Control must revoke legacy PostgreSQL presence writes")
        if "GRANT SELECT, INSERT, UPDATE ON TABLE user_room_presence" in text:
            errors.append("Room Control must not retain writable PostgreSQL presence authority")
        if "GRANT INSERT ON TABLE event_outbox" not in text:
            errors.append("Room Control transactional outbox grant is missing")

    authority = json.loads(AUTHORITY_REGISTRY.read_text(encoding="utf-8"))
    for state in authority.get("states", []):
        state_id = str(state.get("id") or "")
        if state_id.startswith("rooms.") and state.get("current_deployable") != "room-control-service":
            errors.append(
                state_id + ": authority registry must declare room-control-service"
            )


def _validate_identity_profile_social_extraction(errors: list[str]) -> None:
    required = (
        IDENTITY_SERVICE_ROOT / "main.py",
        IDENTITY_SERVICE_ROOT / "database.py",
        IDENTITY_SERVICE_ROOT / "internal.py",
        PROFILE_SOCIAL_SERVICE_ROOT / "main.py",
        PROFILE_SOCIAL_SERVICE_ROOT / "database.py",
        PROFILE_SOCIAL_SERVICE_ROOT / "internal.py",
        IDENTITY_OWNERSHIP_SQL,
        PROFILE_SOCIAL_OWNERSHIP_SQL,
        IDENTITY_PROFILE_SOCIAL_MIGRATION,
        ROOT / "backend" / "app" / "api" / "routes" / "identity_proxy.py",
        ROOT / "backend" / "app" / "api" / "routes" / "profile_social_proxy.py",
    )
    for path in required:
        if not path.exists():
            errors.append(
                "Chunk 27 identity/profile-social path is missing: "
                + str(path.relative_to(ROOT))
            )

    router_path = ROOT / "backend" / "app" / "api" / "router.py"
    if router_path.exists():
        router_text = router_path.read_text(encoding="utf-8")
        for token in ("identity_proxy.router", "profile_social_proxy.router"):
            if token not in router_text:
                errors.append("Chunk 27 compatibility proxy missing: " + token)
        for token in (
            "auth.router",
            "admin.router",
            "moderation.router",
            "social.router",
            "love_bonds.router",
            "families.router",
            "profile_display.router",
        ):
            if re.search(rf"(?<![A-Za-z0-9_]){re.escape(token)}\\b", router_text):
                errors.append(
                    "Chunk 27 extracted public router still mounted in core: " + token
                )

    users_path = ROOT / "backend" / "app" / "api" / "routes" / "users.py"
    if users_path.exists():
        users_text = users_path.read_text(encoding="utf-8")
        if "profile_social_service_client.update_profile" not in users_text:
            errors.append("Profile mutation must route through Profile/Social service")
        if "identity_service_client.verify_access_token" not in users_text:
            errors.append("JWT validation must delegate durable session verification to Identity")
        if "identity_session_service.is_session_active" in users_text:
            errors.append("Non-Identity request auth must not read Identity session tables directly")

    identity_main = IDENTITY_SERVICE_ROOT / "main.py"
    if identity_main.exists():
        identity_text = identity_main.read_text(encoding="utf-8")
        for token in ("api.include_router(admin.router)", "api.include_router(moderation.router)"):
            if token not in identity_text:
                errors.append("Identity privileged route ownership missing: " + token)

    permission_service = ROOT / "backend" / "app" / "services" / "special_permission_service.py"
    if permission_service.exists():
        permission_text = permission_service.read_text(encoding="utf-8")
        if "Authorization reads are side-effect free" not in permission_text:
            errors.append("Special-permission expiration checks must be side-effect free")

    super_owner_path = ROOT / "backend" / "app" / "api" / "routes" / "super_owner.py"
    if super_owner_path.exists():
        super_owner_text = super_owner_path.read_text(encoding="utf-8")
        for forbidden in ("target.display_custom_id =", "target.interests ="):
            if forbidden in super_owner_text:
                errors.append(
                    "Core super-owner route must delegate profile mutation: " + forbidden
                )
        for required in (
            "profile_social_service_client.assign_custom_id",
            "profile_social_service_client.set_stealth",
        ):
            if required not in super_owner_text:
                errors.append(
                    "Core super-owner profile delegation is missing: " + required
                )

    security_path = ROOT / "backend" / "app" / "core" / "security.py"
    if security_path.exists():
        security_text = security_path.read_text(encoding="utf-8")
        if 'payload["sid"] = session_id' not in security_text:
            errors.append("New access tokens must carry durable Identity session id")

    if IDENTITY_OWNERSHIP_SQL.exists():
        identity_sql = IDENTITY_OWNERSHIP_SQL.read_text(encoding="utf-8")
        for table in (
            "users",
            "auth_identities",
            "login_history",
            "identity_devices",
            "identity_sessions",
            "user_roles",
            "special_permissions",
            "user_bans",
            "device_bans",
        ):
            token = f"ALTER TABLE {table} OWNER TO funkey_identity_owner"
            if token not in identity_sql:
                errors.append("Identity ownership missing table: " + table)

    if PROFILE_SOCIAL_OWNERSHIP_SQL.exists():
        social_sql = PROFILE_SOCIAL_OWNERSHIP_SQL.read_text(encoding="utf-8")
        for table in (
            "user_follows",
            "user_blocks",
            "love_bonds",
            "love_bond_requests",
            "profile_visits",
            "family_economy_stats",
            "family_member_stats",
        ):
            token = f"ALTER TABLE {table} OWNER TO funkey_profile_social_owner"
            if token not in social_sql:
                errors.append("Profile/Social ownership missing table: " + table)
        if "GRANT UPDATE (" not in social_sql:
            errors.append("Profile/Social users mutation must be column scoped")
        if "funkey_profile_social_reader" not in social_sql:
            errors.append("Profile/Social read compatibility role is missing")
        for table in ("user_wallets", "wallet_ledger", "gift_transactions", "economy_rule_sets", "economy_rule_levels"):
            token = "GRANT SELECT ON TABLE"
            if table not in social_sql or token not in social_sql:
                errors.append("Profile/Social economy projection read grant missing: " + table)

    if IDENTITY_OWNERSHIP_SQL.exists():
        identity_sql = IDENTITY_OWNERSHIP_SQL.read_text(encoding="utf-8")
        if "funkey_identity_reader" not in identity_sql:
            errors.append("Identity read compatibility role is missing")

    profile_service_path = ROOT / "backend" / "app" / "services" / "profile_service.py"
    if profile_service_path.exists():
        profile_text = profile_service_path.read_text(encoding="utf-8")
        wallet_source = _function_source(profile_text, "wallet_summary")
        for forbidden in ("get_or_create_wallet(", "sync_vip_status("):
            if forbidden in wallet_source:
                errors.append("Profile wallet summary must be read-only; found " + forbidden)

    profile_internal = PROFILE_SOCIAL_SERVICE_ROOT / "internal.py"
    if profile_internal.exists():
        internal_text = profile_internal.read_text(encoding="utf-8")
        if "return users._user_me_response" in internal_text:
            errors.append("Profile/Social mutation response must not compose cross-domain wallet/VIP state")

    if AUTHORITY_REGISTRY.exists():
        payload = json.loads(AUTHORITY_REGISTRY.read_text(encoding="utf-8"))
        states = {str(item.get("id")): item for item in payload.get("states", [])}
        expected = {
            "identity.accounts": "identity-service",
            "identity.sessions": "identity-service",
            "profiles.public": "profile-social-service",
            "social.graph": "profile-social-service",
            "families.membership": "profile-social-service",
        }
        for state_id, deployable in expected.items():
            if states.get(state_id, {}).get("current_deployable") != deployable:
                errors.append(
                    f"{state_id}: Chunk 27 deployable must be {deployable}"
                )


def _has_tracked_content(path: Path) -> bool:
    return path.exists() and any(item.is_file() for item in path.rglob("*"))


def _validate_game_platform_extraction(errors: list[str]) -> None:
    required = (
        GAME_PLATFORM_SERVICE_ROOT / "main.py",
        GAME_PLATFORM_SERVICE_ROOT / "database.py",
        GAME_PLATFORM_SERVICE_ROOT / "Dockerfile",
        GAME_PLATFORM_OWNERSHIP_SQL,
        GAME_PLATFORM_RUNTIME_MIGRATION,
        ROOT / "backend" / "app" / "api" / "routes" / "game_platform_proxy.py",
        ROOT / "backend" / "app" / "services" / "game_platform_runtime_service.py",
        ROOT / "backend" / "app" / "services" / "game_platform_service_client.py",
        GAME_PLATFORM_SERVICE_ROOT / "admin_props.py",
    )
    for path in required:
        if not path.exists():
            errors.append(
                "Chunk 28 Game Platform path is missing: "
                + str(path.relative_to(ROOT))
            )

    router_path = ROOT / "backend" / "app" / "api" / "router.py"
    if router_path.exists():
        text = router_path.read_text(encoding="utf-8")
        for token in ("game_platform_proxy.router", "game_platform_proxy.admin_router"):
            if token not in text:
                errors.append("Chunk 28 Game Platform compatibility proxy missing: " + token)
        for forbidden in ("games.router", "games_master.router", "games.admin_router"):
            if re.search(rf"(?<![A-Za-z0-9_]){re.escape(forbidden)}\\b", text):
                errors.append("core API must not mount Game Platform authority directly: " + forbidden)
        if (
            "game_settlements.router" not in text
            or text.index("game_settlements.router") > text.index("game_platform_proxy.router")
        ):
            errors.append("Economy-backed /games financial facade must precede Game Platform catch-all")
        if (
            "game_props_admin.router" not in text
            or text.index("game_props_admin.router") > text.index("game_platform_proxy.admin_router")
        ):
            errors.append("game props authority facade must precede Game Platform admin catch-all")

    legacy_finance = ROOT / "backend" / "app" / "api" / "routes" / "game_settlements.py"
    if legacy_finance.exists():
        text = legacy_finance.read_text(encoding="utf-8")
        for required_token in (
            "economy_service_client.game_wager",
            "economy_service_client.game_settle",
            'Header(default=None, alias="Idempotency-Key")',
        ):
            if required_token not in text:
                errors.append("legacy game financial facade must delegate to Economy: " + required_token)
        if "game_settlement_service" in text:
            errors.append("core legacy game facade must not use direct game_settlement_service")

    core_props = ROOT / "backend" / "app" / "api" / "routes" / "game_props_admin.py"
    platform_props = GAME_PLATFORM_SERVICE_ROOT / "admin_props.py"
    proxy_path = ROOT / "backend" / "app" / "api" / "routes" / "game_platform_proxy.py"
    if core_props.exists() and "jungle_hunt_props_runtime_service" in core_props.read_text(encoding="utf-8"):
        errors.append("core must not mutate Game Platform Jungle Hunt configuration")
    if platform_props.exists():
        text = platform_props.read_text(encoding="utf-8")
        for required_token in (
            "jungle_hunt_props_runtime_service.get_props",
            "jungle_hunt_props_runtime_service.update_props",
            "game.props.updated.v1",
        ):
            if required_token not in text:
                errors.append("Game Platform Jungle Hunt props authority missing: " + required_token)
    if proxy_path.exists() and "/admin/games/props/jungle-hunt" not in proxy_path.read_text(encoding="utf-8"):
        errors.append("Game Platform proxy must preserve canonical Jungle Hunt props path")

    economy_admin = ROOT / "backend" / "app" / "api" / "routes" / "economy_admin.py"
    if economy_admin.exists():
        text = economy_admin.read_text(encoding="utf-8")
        start = text.find('@router.post("/gaming/rounds")')
        block = text[start:] if start >= 0 else ""
        if "game_platform_service_client.create_round" not in block:
            errors.append("legacy admin round facade must delegate lifecycle to Game Platform")
        if "economy_service.create_game_round" in block:
            errors.append("core/Economy admin must not create Game Platform round rows directly")

    games_master = ROOT / "backend" / "app" / "api" / "routes" / "games_master.py"
    if games_master.exists():
        text = games_master.read_text(encoding="utf-8")
        if "game_platform_runtime_service as game_service" not in text:
            errors.append("Game Platform master/rankings must use game_platform_runtime_service")
        if "global_jungle_game_service_v2" in text:
            errors.append("Game Platform master/rankings must not trigger legacy Economy game-pool writes")

    runtime = ROOT / "backend" / "app" / "services" / "game_platform_runtime_service.py"
    if runtime.exists():
        text = runtime.read_text(encoding="utf-8")
        for required_token in (
            "economy_service_client.game_wager",
            "economy_service_client.game_settle",
            "game.session.opened.v1",
            "game.bet.accepted.v1",
            "game.round.settled.v1",
        ):
            if required_token not in text:
                errors.append("Game Platform runtime boundary missing: " + required_token)
        for forbidden in ("UserWallet", "WalletLedger", "game_pool_service"):
            if forbidden in text:
                errors.append("Game Platform must not mutate Economy authority: " + forbidden)

    if GAME_PLATFORM_OWNERSHIP_SQL.exists():
        sql = GAME_PLATFORM_OWNERSHIP_SQL.read_text(encoding="utf-8")
        for table in (
            "game_definitions",
            "game_sessions",
            "game_rounds",
            "game_round_players",
            "game_bets",
            "game_risk_audits",
            "user_game_stats",
        ):
            if f"ALTER TABLE {table} OWNER TO funkey_game_platform_owner" not in sql:
                errors.append("Game Platform ownership missing table: " + table)
        for forbidden in ("ALTER TABLE user_wallets", "ALTER TABLE wallet_ledger", "ALTER TABLE game_pools", "ALTER TABLE game_pool_ledger"):
            if forbidden in sql:
                errors.append("Game Platform ownership must exclude financial table: " + forbidden)
        if "GRANT SELECT,INSERT ON TABLE admin_logs TO funkey_game_platform_runtime" not in sql:
            errors.append("Game Platform admin audit grant is missing")

    if AUTHORITY_REGISTRY.exists():
        payload = json.loads(AUTHORITY_REGISTRY.read_text(encoding="utf-8"))
        states = {str(item.get("id")): item for item in payload.get("states", [])}
        if states.get("games.catalog_rounds", {}).get("current_deployable") != "game-platform-service":
            errors.append("games.catalog_rounds: Chunk 28 deployable must be game-platform-service")
        if "postgres:user_game_stats" not in states.get("games.catalog_rounds", {}).get("current_storage", []):
            errors.append("games.catalog_rounds: user_game_stats must be declared as Game Platform storage")
        if states.get("games.financial_settlement", {}).get("current_deployable") != "economy-service":
            errors.append("games.financial_settlement: current deployable must be economy-service")



def _validate_economy_service_cutover(errors: list[str]) -> None:
    required = (
        ROOT / "apps" / "economy-service" / "main.py",
        ROOT / "apps" / "economy-service" / "internal.py",
        ROOT / "apps" / "economy-service" / "database.py",
        ROOT / "apps" / "economy-service" / "README.md",
        ROOT / "deploy" / "postgres" / "economy-ownership.sql",
        ROOT / "backend" / "app" / "models" / "economy_journal.py",
        ROOT / "backend" / "app" / "models" / "economy_house_reservation.py",
        ROOT / "backend" / "app" / "services" / "economy_reconciliation_service.py",
        ROOT / "backend" / "alembic" / "versions" / "20260924_1100_economy_authority_cutover.py",
        ROOT / "backend" / "alembic" / "versions" / "20260924_1200_economy_house_reservations.py",
        ROOT / "docs" / "architecture" / "economy-service.md",
        ROOT / "docs" / "runbooks" / "economy-service.md",
    )
    for required_path in required:
        if not required_path.exists():
            errors.append(
                "Economy authority cutover path is missing: "
                + str(required_path.relative_to(ROOT))
            )

    authority = json.loads(AUTHORITY_REGISTRY.read_text(encoding="utf-8"))
    states = {str(item.get("id")): item for item in authority.get("states", [])}
    for state_id in (
        "economy.wallet_ledger",
        "economy.supply_ledger",
        "economy.house_liability",
        "economy.lucky_packets",
        "gifts.catalog",
        "gifts.settlement",
        "games.financial_settlement",
        "missions.reward_claims",
    ):
        if states.get(state_id, {}).get("current_deployable") != "economy-service":
            errors.append(
                f"{state_id}: Economy authority must be deployed by economy-service"
            )

    ownership = ROOT / "deploy" / "postgres" / "economy-ownership.sql"
    if ownership.exists():
        text = ownership.read_text(encoding="utf-8")
        for table in (
            "user_wallets",
            "wallet_ledger",
            "coin_supply_pools",
            "coin_pool_ledger",
            "game_pools",
            "game_pool_ledger",
            "gift_transactions",
            "economy_transactions",
            "economy_journal_entries",
            "economy_house_reservations",
            "lucky_packets",
            "lucky_packet_claims",
            "user_vip_statuses",
            "user_vip_overrides",
        ):
            if f"ALTER TABLE {table} OWNER TO funkey_economy_owner" not in text:
                errors.append("Economy ownership missing table: " + table)
        if "GRANT funkey_economy_reader TO <production_core_api_login>" not in text:
            errors.append("Economy ownership must document SELECT-only core reader binding")
        if "Never grant funkey_economy_runtime to core-api" not in text:
            errors.append("Economy ownership must explicitly forbid core mutation role")

    tx_service = ROOT / "backend" / "app" / "services" / "economy_transaction_service.py"
    if tx_service.exists():
        text = tx_service.read_text(encoding="utf-8")
        for token in (
            "EconomyJournalEntry",
            "record_balanced_transfer",
            "_assert_journal_balanced",
            "event_outbox_service.enqueue_event",
        ):
            if token not in text:
                errors.append("Economy transaction invariant missing: " + token)

    bulk_worker = ROOT / "apps" / "economy-service" / "bulk_worker.py"
    if bulk_worker.exists():
        text = bulk_worker.read_text(encoding="utf-8")
        for token in (
            "economy_reconciliation_service.reconcile",
            "lucky_packet_service.finalize_expired_packets",
            "funkey_economy_reconciliation_supply_pool_mismatches",
            "funkey_economy_reconciliation_game_pool_mismatches",
            "funkey_economy_reconciliation_reservation_mismatches",
        ):
            if token not in text:
                errors.append("Economy worker invariant missing: " + token)

    forbidden_mutations = (
        "economy_service.credit_social_mission_reward(",
        "economy_service.send_gift(",
        "economy_service.convert_rubies_to_coins(",
        "economy_service.create_withdraw_request(",
        "get_or_create_wallet(",
        "sync_vip_status(",
        "wallet.coin_balance =",
        "wallet.ruby_balance =",
        "wallet.lifetime_coins_spent =",
        "wallet.lifetime_coins_received_as_gifts =",
        "wallet.lifetime_rubies_earned =",
        "WalletLedger(",
        "UserWallet(",
    )
    core_economy_surfaces = (
        ROOT / "backend" / "app" / "api" / "routes" / "wallet" / "__init__.py",
        ROOT / "backend" / "app" / "api" / "routes" / "economy.py",
        ROOT / "backend" / "app" / "api" / "routes" / "economy_admin.py",
        ROOT / "backend" / "app" / "api" / "routes" / "experience.py",
        ROOT / "backend" / "app" / "api" / "routes" / "super_owner.py",
        ROOT / "backend" / "app" / "api" / "routes" / "control_center.py",
        ROOT / "backend" / "app" / "api" / "routes" / "lucky_gift_admin.py",
        ROOT / "backend" / "app" / "api" / "routes" / "room_cross_domain.py",
    )
    for source in core_economy_surfaces:
        if not source.exists():
            continue
        text = source.read_text(encoding="utf-8-sig")
        for token in forbidden_mutations:
            if token in text:
                errors.append(
                    "core route bypasses Economy mutation authority: "
                    + str(source.relative_to(ROOT))
                    + " contains "
                    + token
                )


    value_routes = (
        ROOT / "backend" / "app" / "api" / "routes" / "coin_sales.py",
        ROOT / "backend" / "app" / "api" / "routes" / "lucky_coins.py",
        ROOT / "backend" / "app" / "api" / "routes" / "lucky_packets.py",
        ROOT / "backend" / "app" / "api" / "routes" / "game_pool_admin.py",
    )
    for source in value_routes:
        if not source.exists():
            errors.append(
                "Economy value route is missing: " + str(source.relative_to(ROOT))
            )
            continue
        text = source.read_text(encoding="utf-8-sig")
        for required_token in (
            "economy_transaction_service.begin",
            "economy_transaction_service.complete",
        ):
            if required_token not in text:
                errors.append(
                    "Economy value route must use canonical transaction semantics: "
                    + str(source.relative_to(ROOT))
                    + " missing "
                    + required_token
                )
        for forbidden in (
            "economy_service._credit_wallet(",
            "economy_service._debit_wallet(",
            "WalletLedger(",
            "UserWallet(",
        ):
            if forbidden in text:
                errors.append(
                    "Economy value route bypasses transaction layer: "
                    + str(source.relative_to(ROOT))
                    + " contains "
                    + forbidden
                )

    lucky_gift_route = (
        ROOT / "backend" / "app" / "api" / "routes" / "lucky_gifts.py"
    )
    if lucky_gift_route.exists():
        text = lucky_gift_route.read_text(encoding="utf-8")
        result_source = _function_source(text, "record_lucky_gift_result")
        for forbidden in (
            "lucky_gift_stats_service.record_lucky_gift_result(",
            ".commit(",
            ".add(",
        ):
            if forbidden in result_source:
                errors.append(
                    "Lucky Gift client result endpoint must remain lookup-only: "
                    + forbidden
                )
        if "_recent_matching_transaction(" not in result_source:
            errors.append(
                "Lucky Gift compatibility result endpoint must resolve authoritative history"
            )

    lucky_packet_service = (
        ROOT / "backend" / "app" / "services" / "lucky_packet_service.py"
    )
    if lucky_packet_service.exists():
        text = lucky_packet_service.read_text(encoding="utf-8")
        active_read = _function_source(text, "get_active_packet")
        for forbidden in ("_finalize_locked(", ".commit(", "_credit_wallet(", "_debit_wallet("):
            if forbidden in active_read:
                errors.append(
                    "Lucky Packet active GET contract must remain read-only: " + forbidden
                )
        for required_token in (
            "economy_transaction_service.debit(",
            "economy_transaction_service.credit(",
            "finalize_expired_packets(",
        ):
            if required_token not in text:
                errors.append("Lucky Packet Economy invariant missing: " + required_token)

    economy_route = ROOT / "backend" / "app" / "api" / "routes" / "economy.py"
    if economy_route.exists():
        text = economy_route.read_text(encoding="utf-8")
        for function_name in (
            "_public_wallet_summary",
            "_private_wallet_payload",
        ):
            source = _function_source(text, function_name)
            for forbidden in ("get_or_create_wallet(", "sync_vip_status(", ".commit("):
                if forbidden in source:
                    errors.append(
                        "Economy read projection must remain read-only: "
                        + function_name
                        + " contains "
                        + forbidden
                    )

    economy_service_source = (
        ROOT / "backend" / "app" / "services" / "economy_service.py"
    )
    if economy_service_source.exists():
        text = economy_service_source.read_text(encoding="utf-8")
        dashboard_source = _function_source(text, "dashboard_for_user")
        for forbidden in ("get_or_create_wallet(", ".commit(", ".flush("):
            if forbidden in dashboard_source:
                errors.append(
                    "Economy dashboard GET projection must remain read-only: "
                    + forbidden
                )

    bulk_grant = (
        ROOT / "backend" / "app" / "services" / "economy_bulk_grant_service.py"
    )
    if bulk_grant.exists():
        text = bulk_grant.read_text(encoding="utf-8")
        for required_token in (
            "economy_transaction_service.begin(",
            "economy_transaction_service.record_balanced_transfer(",
            "economy_transaction_service.complete(",
        ):
            if required_token not in text:
                errors.append("Economy bulk-grant invariant missing: " + required_token)


def _validate_post_chunk28_platforms(errors: list[str]) -> None:
    notification_required = (
        ROOT / "apps" / "notification-service" / "main.py",
        ROOT / "apps" / "notification-service" / "provider_worker.py",
        ROOT / "deploy" / "postgres" / "notification-ownership.sql",
        ROOT / "docs" / "modules" / "notification" / "README.md",
        ROOT / "docs" / "runbooks" / "notification-service.md",
    )
    for required_path in notification_required:
        if not required_path.exists():
            errors.append(
                "Notification Service path is missing: "
                + str(required_path.relative_to(ROOT))
            )

    worker_required = (
        ROOT / "apps" / "worker" / "pools.py",
        ROOT / "apps" / "worker" / "handlers.py",
        ROOT / "apps" / "worker" / "README.md",
        ROOT / "docs" / "modules" / "worker" / "README.md",
        ROOT / "docs" / "runbooks" / "worker-platform.md",
    )
    for required_path in worker_required:
        if not required_path.exists():
            errors.append(
                "Worker Platform path is missing: "
                + str(required_path.relative_to(ROOT))
            )

    media_required = (
        ROOT / "backend" / "app" / "api" / "routes" / "media_uploads_v2.py",
        ROOT / "backend" / "app" / "services" / "media_upload_session_service.py",
        ROOT / "backend" / "alembic" / "versions" / "20260924_1000_media_v2.py",
        ROOT / "docs" / "architecture" / "media-v2-upload.md",
        ROOT / "docs" / "modules" / "media-upload-v2" / "README.md",
        ROOT / "docs" / "runbooks" / "media-v2-upload.md",
    )
    for required_path in media_required:
        if not required_path.exists():
            errors.append(
                "Media v2 path is missing: "
                + str(required_path.relative_to(ROOT))
            )

    authority = json.loads(AUTHORITY_REGISTRY.read_text(encoding="utf-8"))
    states = {str(item.get("id")): item for item in authority.get("states", [])}
    for state_id in ("notifications.in_app", "notifications.delivery"):
        if states.get(state_id, {}).get("current_deployable") != "notification-service":
            errors.append(
                f"{state_id}: Notification authority must be notification-service"
            )
    for state_id in ("media.metadata", "media.objects"):
        if states.get(state_id, {}).get("change_contract", {}).get("status") != "live":
            errors.append(f"{state_id}: Chunk 31 contract status must be live")



def _validate_post_chunk32_repair_wave(errors: list[str]) -> None:
    """Lock the complete post-Chunk-32 anomaly repair into CI."""
    required = (
        ROOT / "backend" / "alembic" / "versions" / "20260925_0100_normalize_cricket_ball_events.py",
        ROOT / "backend" / "alembic" / "versions" / "20260925_0200_user_vip_overrides.py",
        ROOT / "backend" / "alembic" / "versions" / "20260925_0300_inbox_source_dedupe_key.py",
        ROOT / "backend" / "alembic" / "versions" / "20260925_0400_cricket_ball_event_identity.py",
        ROOT / "backend" / "tests" / "test_cricket_authority_repair.py",
        ROOT / "backend" / "tests" / "test_rankings_read_only_projection.py",
        ROOT / "backend" / "tests" / "test_vibes_inbox_fanout_idempotency.py",
        ROOT / "backend" / "tests" / "test_media_multipart_retry_recovery.py",
        ROOT / "frontend" / "vibematch_app" / "test" / "realtime_single_socket_source_test.dart",
    )
    for path in required:
        if not path.exists():
            errors.append(
                "post-Chunk-32 repair evidence is missing: "
                + str(path.relative_to(ROOT))
            )

    # Presence: Go/Redis is the sole connected-liveness authority.
    presence_route = ROOT / "backend" / "app" / "api" / "routes" / "presence.py"
    room_service = ROOT / "backend" / "app" / "services" / "rooms" / "room_service.py"
    room_action = ROOT / "backend" / "app" / "services" / "rooms" / "room_action_service.py"
    presence_projection = ROOT / "backend" / "app" / "services" / "presence_projection_service.py"
    realtime_gateway = ROOT / "apps" / "realtime-gateway" / "internal" / "gateway" / "server.go"
    app_shell = ROOT / "frontend" / "vibematch_app" / "lib" / "app" / "app_shell.dart"
    room_shell = (
        ROOT / "frontend" / "vibematch_app" / "lib" / "features" / "rooms" /
        "presentation" / "live_room_presence_shell_page.dart"
    )
    room_repository = (
        ROOT / "frontend" / "vibematch_app" / "lib" /
        "room_session" / "data" / "room_session_repository.dart"
    )
    for path in (presence_route, room_service, room_action):
        if path.exists():
            text = path.read_text(encoding="utf-8")
            for forbidden in (
                "UserRoomPresence",
                "last_heartbeat_at",
                "mark_user_room_presence_active",
                "_ACTIVE_PARTICIPANT_WINDOW",
            ):
                if forbidden in text:
                    errors.append(
                        "legacy PostgreSQL presence authority remains in "
                        + str(path.relative_to(ROOT))
                        + ": "
                        + forbidden
                    )
    if presence_route.exists():
        text = presence_route.read_text(encoding="utf-8")
        if "project_user_presence(" not in text:
            errors.append("public presence reads must project from realtime leases")
    if presence_projection.exists():
        text = presence_projection.read_text(encoding="utf-8")
        for required_token in (
            "funkey:realtime:gateway:user-active",
            "funkey:realtime:gateway:user-rooms",
            "funkey:realtime:gateway:room-users",
            "RoomParticipant.is_active.is_(True)",
            "active_memberships",
        ):
            if required_token not in text:
                errors.append("presence projection invariant missing: " + required_token)
    if realtime_gateway.exists():
        text = realtime_gateway.read_text(encoding="utf-8")
        for required_token in ("userRoomPresenceLeaseKey", "roomUserPresenceLeaseKey"):
            if required_token not in text:
                errors.append("Go realtime gateway missing presence lease index: " + required_token)
    if app_shell.exists():
        text = app_shell.read_text(encoding="utf-8")
        for forbidden in ("AppPresenceRuntime", "appPresenceRuntimeProvider"):
            if forbidden in text:
                errors.append("Flutter app shell retains retired DB presence runtime: " + forbidden)
    if room_shell.exists():
        text = room_shell.read_text(encoding="utf-8")
        for forbidden in ("_heartbeatTimer", "Duration(seconds: 12)", "_startHeartbeat"):
            if forbidden in text:
                errors.append("live room still polls REST heartbeat: " + forbidden)
    if room_repository.exists() and "/realtime/heartbeat" in room_repository.read_text(encoding="utf-8"):
        errors.append("canonical RoomSessionRepository must not call REST heartbeat")

    # Cricket: Room Control is the only durable writer; scoring is serialized.
    cricket_route = ROOT / "backend" / "app" / "api" / "routes" / "rooms" / "cricket.py"
    cricket_service = ROOT / "backend" / "app" / "services" / "rooms" / "cricket_service.py"
    room_control_internal = ROOM_CONTROL_SERVICE_ROOT / "internal.py"
    if cricket_route.exists():
        text = cricket_route.read_text(encoding="utf-8")
        if "room_control_service_client.execute_cricket_operation" not in text:
            errors.append("core Cricket routes must proxy to Room Control")
        for forbidden in ("Depends(get_db)", "services.rooms.cricket_service"):
            if forbidden in text:
                errors.append("core Cricket route retains durable authority: " + forbidden)
    if cricket_service.exists():
        text = cricket_service.read_text(encoding="utf-8")
        for required_token in (
            "require_room_admin",
            "require_room_view",
            "with_for_update()",
            "CricketBallEvent(",
            "func.max(CricketBallEvent.sequence)",
            "CricketBallEvent.source_event_id == source_event_id",
        ):
            if required_token not in text:
                errors.append("Cricket authority/serialization invariant missing: " + required_token)
        if "events.append(event)" in text:
            errors.append("Cricket ball log must not use a growing mutable JSON array")
    if room_control_internal.exists() and '"/cricket/operation"' not in room_control_internal.read_text(encoding="utf-8"):
        errors.append("Room Control internal API must own Cricket operations")

    # VIP/SVIP: manual adjustments and effective projection are Economy-owned.
    super_owner = ROOT / "backend" / "app" / "api" / "routes" / "super_owner.py"
    vip_status_service = ROOT / "backend" / "app" / "services" / "vip_status_service.py"
    economy_level = ROOT / "backend" / "app" / "services" / "economy_level_service.py"
    economy_internal = ROOT / "apps" / "economy-service" / "internal.py"
    economy_ownership = ROOT / "deploy" / "postgres" / "economy-ownership.sql"
    if super_owner.exists():
        text = super_owner.read_text(encoding="utf-8")
        if "db.query(UserVipStatus)" in text:
            errors.append("Super Owner must not write VIP projection directly")
        if "economy_service_client.adjust_vip_override" not in text:
            errors.append("Super Owner VIP changes must route through Economy")
    if vip_status_service.exists():
        text = vip_status_service.read_text(encoding="utf-8")
        if "economy_service_client.adjust_vip_override" not in text:
            errors.append("VIP admin mutation must route through Economy")
        if "get_or_create_vip_status" in text:
            errors.append("VIP GET path must remain read-only")
    if economy_level.exists():
        text = economy_level.read_text(encoding="utf-8")
        for required_token in (
            "UserVipOverride",
            "def set_vip_override(",
            'event_type="economy.vip_projection.updated.v1"',
        ):
            if required_token not in text:
                errors.append("Economy VIP projection invariant missing: " + required_token)
    if economy_internal.exists() and '"/vip/admin-override"' not in economy_internal.read_text(encoding="utf-8"):
        errors.append("Economy service must expose the idempotent VIP override command")
    if economy_ownership.exists():
        text = economy_ownership.read_text(encoding="utf-8")
        for table in ("user_vip_statuses", "user_vip_overrides"):
            if f"ALTER TABLE {table} OWNER TO funkey_economy_owner" not in text:
                errors.append("Economy VIP ownership missing table: " + table)

    # Vibes fanout: all side effects are idempotent and processed last.
    worker = ROOT / "apps" / "worker" / "handlers.py"
    inbox_model = ROOT / "backend" / "app" / "models" / "inbox.py"
    if worker.exists():
        handler = _function_source(worker.read_text(encoding="utf-8"), "handle_vibes_post_published")
        send_at = handler.find("inbox_service_client.send_direct_message")
        mark_at = handler.rfind("_mark_processed(event,handler_name)")
        if send_at < 0 or mark_at < 0 or send_at > mark_at:
            errors.append("Vibes worker must mark processed only after Inbox fanout")
        if "source_dedupe_key=" not in handler:
            errors.append("Vibes Inbox fanout must carry an idempotent source-effect key")
        if "except (inbox_service_client.InboxServiceUnavailable" in handler:
            errors.append("Vibes worker must not swallow Inbox delivery failures")
    if inbox_model.exists():
        text = inbox_model.read_text(encoding="utf-8")
        if "source_dedupe_key" not in text or "unique=True" not in text:
            errors.append("Inbox message source-effect dedupe key must be unique")

    # Media: retry after successful S3 completion must recover from NoSuchUpload.
    media_storage = ROOT / "backend" / "app" / "services" / "media_storage_service.py"
    if media_storage.exists():
        source = _function_source(
            media_storage.read_text(encoding="utf-8"),
            "complete_multipart_upload",
        )
        for required_token in ("NoSuchUpload", "head_object("):
            if required_token not in source:
                errors.append("multipart retry recovery missing: " + required_token)

    # Rankings: bounded batched projection only; no read-side writes/N+1 helpers.
    rankings = ROOT / "backend" / "app" / "api" / "routes" / "rankings.py"
    if rankings.exists():
        text = rankings.read_text(encoding="utf-8")
        for forbidden in (
            "get_or_create_user_exp",
            "profile_service.vip_summary",
            "db.add(",
            "db.commit(",
            "db.flush(",
        ):
            if forbidden in text:
                errors.append("rankings projection must remain read-only: " + forbidden)
        for required_token in (
            "UserExperienceStatus.user_id.in_(resolved_ids)",
            "UserVipStatus.user_id.in_(resolved_ids)",
            "limit: int = Query(default=100, ge=1, le=100)",
        ):
            if required_token not in text:
                errors.append("rankings bounded batch invariant missing: " + required_token)

    # Repair migrations must form one linear deployment chain.
    migration_chain = (
        ("20260925_0100_normalize_cricket_ball_events.py", 'down_revision = "20260924_1200"'),
        ("20260925_0200_user_vip_overrides.py", 'down_revision = "20260925_0100"'),
        ("20260925_0300_inbox_source_dedupe_key.py", 'down_revision = "20260925_0200"'),
        ("20260925_0400_cricket_ball_event_identity.py", 'down_revision = "20260925_0300"'),
    )
    versions = ROOT / "backend" / "alembic" / "versions"
    for filename, expected in migration_chain:
        path = versions / filename
        if path.exists() and expected not in path.read_text(encoding="utf-8"):
            errors.append("repair migration chain is broken: " + filename)


def main() -> int:
    errors: list[str] = []
    _validate_authority_registry(errors)
    _validate_database_hardening(errors)
    _validate_redis_topology(errors)
    _validate_room_state_engine(errors)
    _validate_inbox_service_extraction(errors)
    _validate_vibes_service_extraction(errors)
    _validate_room_control_extraction(errors)
    _validate_identity_profile_social_extraction(errors)
    _validate_game_platform_extraction(errors)
    _validate_economy_service_cutover(errors)
    _validate_post_chunk28_platforms(errors)
    _validate_post_chunk32_repair_wave(errors)

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
        if "/lucky-gifts/results/record" in text:
            errors.append(
                "client-authored Lucky Gift ranking truth is forbidden: "
                + str(source.relative_to(ROOT))
            )
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
    print(" - PostgreSQL query budgets, plan-backed indexes and storage policy are enforced")
    print(" - Room State Engine v2 heartbeat/snapshot/current-state invariants hold")
    print(" - legacy FastAPI application websocket routes are not mounted")
    print(" - Inbox chat authority is isolated, bounded, and routed through NATS/Go")
    print(" - Vibes authority is isolated with bounded cursor feeds and async fanout")
    print(" - Room Control owns durable room state behind a core compatibility proxy")
    print(" - Identity and Profile/Social mutation authorities are physically extracted")
    print(" - Game Platform owns game lifecycle while Economy owns all game value movement")
    print(" - Economy Service is the exclusive financial writer with balanced journal reconciliation")
    print(" - Notification, Worker Platform and Media v2 post-extraction boundaries are present")
    print(" - post-Chunk-32 presence/Cricket/VIP/fanout/media/rankings repair invariants are enforced")
    return 0


if __name__ == "__main__":
    sys.exit(main())
