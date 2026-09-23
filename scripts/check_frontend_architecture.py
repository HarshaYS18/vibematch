from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "frontend" / "vibematch_app" / "lib"

CANONICAL_ROOTS = (
    APP / "foundation",
    APP / "session",
    APP / "identity",
    APP / "app" / "runtime",
    APP / "realtime",
    APP / "room_session",
    APP / "room_media",
    APP / "watch_party",
    APP / "game_platform",
)

violations: list[str] = []

for root in CANONICAL_ROOTS:
    if not root.exists():
        continue
    for path in root.rglob("*.dart"):
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT).as_posix()

        if (
            "package:http/http.dart" in text
            and "/foundation/networking/" not in f"/{rel}"
        ):
            violations.append(
                f"{rel}: migrated domain must use AppNetworkClient, not package:http"
            )

        if re.search(r"\bstatic\s+(?:final\s+)?ValueNotifier\b", text):
            violations.append(f"{rel}: static ValueNotifier is forbidden domain state")

        if re.search(r"\bstatic\s+(?:final\s+)?ChangeNotifier\b", text):
            violations.append(f"{rel}: static ChangeNotifier is forbidden domain state")

        if "SharedPreferences.getInstance" in text and "/foundation/persistence/" not in f"/{rel}":
            violations.append(f"{rel}: persistence must flow through AppKeyValueStore")

        if "WebSocketChannel.connect" in text and "/foundation/realtime/" not in f"/{rel}":
            violations.append(f"{rel}: websocket creation belongs in foundation/realtime")


# Chunk 21: one physical application WebSocket.
#
# Application features subscribe through AppRealtimeHub. Raw websocket creation
# belongs only to foundation/realtime. The mediasoup transport is a separate
# media-plane implementation and must not use the retired FastAPI app sockets.
for path in APP.rglob("*.dart"):
    text = path.read_text(encoding="utf-8-sig")
    rel = path.relative_to(ROOT).as_posix()

    if (
        ("WebSocketChannel.connect" in text or "WebSocket.connect" in text)
        and "/foundation/realtime/" not in f"/{rel}"
    ):
        violations.append(
            f"{rel}: raw application websocket creation must stay in foundation/realtime"
        )

    for retired_path in ("/ws/inbox", "/ws/room-realtime"):
        if retired_path in text:
            violations.append(
                f"{rel}: retired FastAPI application websocket path {retired_path} is forbidden"
            )

    if "VmMediaConfig" in text or "vm_media_config.dart" in text:
        violations.append(
            f"{rel}: retired VmMediaConfig must not be referenced after the Go realtime cutover"
        )

# Chunk 6: room feature code must depend on RoomMediaEngine rather than the
# concrete production mediasoup implementation. The implementation itself is
# intentionally retained behind room_media/data as a compatibility delegate.
ROOM_FEATURE_ROOT = APP / "features" / "rooms"
LEGACY_ROOM_AUDIO_IMPLEMENTATION = (
    ROOM_FEATURE_ROOT / "data" / "live_room_audio_service.dart"
)

if ROOM_FEATURE_ROOT.exists():
    for path in ROOM_FEATURE_ROOT.rglob("*.dart"):
        if path == LEGACY_ROOM_AUDIO_IMPLEMENTATION:
            continue
        text = path.read_text(encoding="utf-8-sig")
        if "LiveRoomAudioService" in text:
            rel = path.relative_to(ROOT).as_posix()
            violations.append(
                f"{rel}: room code must use RoomMediaEngine, not LiveRoomAudioService"
            )



# Chunk 7: the provider-independent Watch Party core must not bind itself to
# the legacy room websocket facade. Canonical room snapshots feed the
# WatchPartyRepository and provider playback stays behind WatchProviderAdapter.
WATCH_PARTY_ROOT = APP / "watch_party"
if WATCH_PARTY_ROOT.exists():
    for path in WATCH_PARTY_ROOT.rglob("*.dart"):
        text = path.read_text(encoding="utf-8-sig")
        rel = path.relative_to(ROOT).as_posix()
        if "LiveRoomMediaSignalingService" in text:
            violations.append(
                f"{rel}: Watch Party core must not depend on the legacy room signaling singleton"
            )
        if "WebSocketChannel" in text:
            violations.append(
                f"{rel}: Watch Party core must use canonical room realtime state, not create/use a raw websocket"
            )

        if "package:flutter_inappwebview/flutter_inappwebview.dart" in text and "/watch_party/providers/web/" not in f"/{rel}":
            violations.append(
                f"{rel}: raw OTT WebView access belongs behind watch_party/providers/web"
            )

        if "InAppWebViewController" in text and not rel.endswith(
            "watch_party/providers/web/ott_web_playback_host.dart"
        ):
            violations.append(
                f"{rel}: InAppWebViewController must stay inside OttWebPlaybackHost"
            )

# Chunk 10: gameplay code is remotely delivered behind the canonical game
# platform. The host owns authenticated API access and the sole game WebView.
GAME_PLATFORM_ROOT = APP / "game_platform"
if GAME_PLATFORM_ROOT.exists():
    for path in GAME_PLATFORM_ROOT.rglob("*.dart"):
        text = path.read_text(encoding="utf-8-sig")
        rel = path.relative_to(ROOT).as_posix()

        if "WebSocketChannel" in text or "WebSocket.connect" in text:
            violations.append(
                f"{rel}: game runtime must not create a second realtime channel"
            )

        if (
            "package:flutter_inappwebview/flutter_inappwebview.dart" in text
            and "/game_platform/runtime/web/" not in f"/{rel}"
        ):
            violations.append(
                f"{rel}: raw game WebView access belongs behind game_platform/runtime/web"
            )

ROOM_GAME_ROOT = APP / "features" / "rooms"
if ROOM_GAME_ROOT.exists():
    legacy_gameplay_imports = (
        "jungle_hunt_global_game_page.dart",
        "jungle_hunt_game_page.dart",
    )
    for path in ROOM_GAME_ROOT.rglob("*.dart"):
        text = path.read_text(encoding="utf-8-sig")
        rel = path.relative_to(ROOT).as_posix()
        if any(marker in text for marker in legacy_gameplay_imports):
            violations.append(
                f"{rel}: room gameplay must launch GameRuntime, not a bundled gameplay page"
            )

PUBSPEC = ROOT / "frontend" / "vibematch_app" / "pubspec.yaml"
if PUBSPEC.exists():
    pubspec_text = PUBSPEC.read_text(encoding="utf-8")
    if "assets/games/" in pubspec_text:
        violations.append(
            "frontend/vibematch_app/pubspec.yaml: gameplay assets must be remotely hosted"
        )
    if "games_raw/" in pubspec_text:
        violations.append(
            "frontend/vibematch_app/pubspec.yaml: raw game packages must not be app dependencies"
        )


# Chunks 11-14: product migration and performance rules.
VIBE_PLAYBACK_GATE = (
    APP / "features" / "vibes" / "presentation" / "widgets" / "vibe_media_playback_gate.dart"
)
if VIBE_PLAYBACK_GATE.exists():
    text = VIBE_PLAYBACK_GATE.read_text(encoding="utf-8-sig")
    if re.search(r"\bstatic\s+(?:final\s+)?ValueNotifier\b", text):
        violations.append(
            "vibe_media_playback_gate.dart: playback arbitration must be AppShell-scoped, not process-global"
        )

APP_SHELL = APP / "app" / "app_shell.dart"
if APP_SHELL.exists():
    text = APP_SHELL.read_text(encoding="utf-8-sig")
    if "_PersistentTabStage" not in text:
        violations.append(
            "app/app_shell.dart: main tabs must remain persistent instead of recreating screens"
        )
    if "didHaveMemoryPressure" not in text:
        violations.append(
            "app/app_shell.dart: shell must release media/image caches under memory pressure"
        )

NETWORK_CLIENT = APP / "foundation" / "networking" / "app_network_client.dart"
if NETWORK_CLIENT.exists():
    text = NETWORK_CLIENT.read_text(encoding="utf-8-sig")
    if "DeduplicatingAppNetworkClient" not in text:
        violations.append(
            "foundation/networking/app_network_client.dart: canonical GET networking must deduplicate in-flight requests"
        )

ROOM_SESSION_REPOSITORY = APP / "room_session" / "data" / "room_session_repository.dart"
if ROOM_SESSION_REPOSITORY.exists():
    text = ROOM_SESSION_REPOSITORY.read_text(encoding="utf-8-sig")
    if "/realtime/activity/command" not in text:
        violations.append(
            "room_session/data/room_session_repository.dart: room activities must remain on RoomSessionRepository authority"
        )

if violations:
    print("Frontend architecture guard failed:")
    for violation in violations:
        print(f" - {violation}")
    sys.exit(1)

print("Frontend architecture guard passed.")

