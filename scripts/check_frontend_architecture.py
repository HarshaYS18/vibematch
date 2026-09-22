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


if violations:
    print("Frontend architecture guard failed:")
    for violation in violations:
        print(f" - {violation}")
    sys.exit(1)

print("Frontend architecture guard passed.")

