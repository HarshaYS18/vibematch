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
)

violations: list[str] = []

for root in CANONICAL_ROOTS:
    if not root.exists():
        continue
    for path in root.rglob("*.dart"):
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT).as_posix()

        if "package:http/http.dart" in text:
            violations.append(f"{rel}: migrated domain must use AppNetworkClient, not package:http")

        if re.search(r"\bstatic\s+(?:final\s+)?ValueNotifier\b", text):
            violations.append(f"{rel}: static ValueNotifier is forbidden domain state")

        if re.search(r"\bstatic\s+(?:final\s+)?ChangeNotifier\b", text):
            violations.append(f"{rel}: static ChangeNotifier is forbidden domain state")

        if "SharedPreferences.getInstance" in text and "/foundation/persistence/" not in f"/{rel}":
            violations.append(f"{rel}: persistence must flow through AppKeyValueStore")

        if "WebSocketChannel.connect" in text and "/foundation/realtime/" not in f"/{rel}":
            violations.append(f"{rel}: websocket creation belongs in foundation/realtime")

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

if violations:
    print("Frontend architecture guard failed:")
    for violation in violations:
        print(f" - {violation}")
    sys.exit(1)

print("Frontend architecture guard passed.")

