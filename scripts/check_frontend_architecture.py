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


# Chunk 33: mutable feature state must be scoped instead of process-global.
#
# This intentionally scans the whole Flutter app, including legacy feature
# directories. Constants and immutable service singletons are allowed. Static
# or top-level ValueNotifier/ChangeNotifier instances are forbidden because
# both forms create hidden process-wide state authorities that outlive a
# room/page/provider scope.
_TOP_LEVEL_VALUE_NOTIFIER = re.compile(
    r"(?m)^(?:late\s+)?final\s+(?:ValueNotifier(?:<[^\n;=]+>)?\s+\w+|\w+\s*=\s*ValueNotifier(?:<[^\n;=]+>)?)"
)
_TOP_LEVEL_CHANGE_NOTIFIER = re.compile(
    r"(?m)^(?:late\s+)?final\s+(?:ChangeNotifier\s+\w+|\w+\s*=\s*ChangeNotifier\s*\()"
)

for path in APP.rglob("*.dart"):
    text = path.read_text(encoding="utf-8-sig")
    rel = path.relative_to(ROOT).as_posix()

    if re.search(r"\bstatic\s+(?:final\s+)?ValueNotifier\b", text):
        violations.append(
            f"{rel}: Chunk 33 forbids process-global static ValueNotifier state"
        )

    if re.search(r"\bstatic\s+(?:final\s+)?ChangeNotifier\b", text):
        violations.append(
            f"{rel}: Chunk 33 forbids process-global static ChangeNotifier state"
        )

    if _TOP_LEVEL_VALUE_NOTIFIER.search(text):
        violations.append(
            f"{rel}: Chunk 33 forbids process-global top-level ValueNotifier state"
        )

    if _TOP_LEVEL_CHANGE_NOTIFIER.search(text):
        violations.append(
            f"{rel}: Chunk 33 forbids process-global top-level ChangeNotifier state"
        )

    if "class LiveRoomRestrictionsService" in text:
        violations.append(
            f"{rel}: room restrictions must come from RoomSessionRepository, not a parallel cache"
        )

    if "class CricketRoomModeSignal" in text:
        violations.append(
            f"{rel}: Cricket Mode runtime must be room-scoped, not a static signal"
        )

    # Post-M6 closure: references to retired room-global presentation/state
    # helpers must fail at architecture-guard time instead of surfacing later
    # as broad Flutter compilation failures.
    for retired_identifier in (
        "ActiveRoomContext",
        "dismissRoomSeatActionPill",
        "activeRoomBackgroundTheme",
    ):
        if retired_identifier in text:
            violations.append(
                f"{rel}: retired Chunk 33 identifier {retired_identifier} is forbidden"
            )


# Chunk 33 final closure: the media compatibility facade may not originate
# durable room/chat/settings mutations, and retired global compatibility files
# must stay deleted. These markers are intentionally specific to paths that
# were removed after canonical RoomSessionRepository/settings migration.
_RETIRED_ROOM_COMPAT_FILES = (
    APP / "features" / "rooms" / "data" / "active_room_context.dart",
    APP / "features" / "rooms" / "data" / "room_seat_layout_sync_service.dart",
)
for retired_path in _RETIRED_ROOM_COMPAT_FILES:
    if retired_path.exists():
        rel = retired_path.relative_to(ROOT).as_posix()
        violations.append(
            f"{rel}: retired Chunk 33 room compatibility file must remain deleted"
        )

_MEDIA_FACADE = (
    APP
    / "features"
    / "rooms"
    / "data"
    / "live_room_media_signaling_service.dart"
)
if _MEDIA_FACADE.exists():
    media_text = _MEDIA_FACADE.read_text(encoding="utf-8-sig")
    durable_markers = (
        "void sendRoomChat(",
        "void setRoomImagesEnabled(",
        "void setGuestMessagesEnabled(",
        "void setRoomApplyOnlyMode(",
        "void setRoomBackgroundTheme(",
        "void setRoomAnnouncement(",
    )
    for durable_marker in durable_markers:
        if durable_marker in media_text:
            violations.append(
                "features/rooms/data/live_room_media_signaling_service.dart: "
                f"media facade must not own durable mutation {durable_marker}"
            )


# Chunk 34-M6 foundation boundary: feature-owned heavy resources depend on a
# foundation lifecycle/registry contract, never the concrete App runtime.
_RESOURCE_LIFECYCLE_CONTRACT = (
    APP / "foundation" / "runtime" / "media_resource_lifecycle.dart"
)
if not _RESOURCE_LIFECYCLE_CONTRACT.exists():
    violations.append(
        "foundation/runtime/media_resource_lifecycle.dart: Chunk 34-M6 lifecycle contract is required"
    )
else:
    resource_contract_text = _RESOURCE_LIFECYCLE_CONTRACT.read_text(
        encoding="utf-8-sig"
    )
    for marker in (
        "enum MediaResourceKind",
        "abstract interface class MediaResourceParticipant",
        "abstract interface class MediaResourceRegistry",
        "mediaResourceRegistryProvider",
    ):
        if marker not in resource_contract_text:
            violations.append(
                "foundation/runtime/media_resource_lifecycle.dart: "
                f"missing Chunk 34-M6 contract marker: {marker}"
            )

for resource_root in (
    APP / "features",
    APP / "game_platform",
    APP / "watch_party",
    APP / "room_media",
):
    if not resource_root.exists():
        continue
    for path in resource_root.rglob("*.dart"):
        text = path.read_text(encoding="utf-8-sig")
        if "media_resource_coordinator.dart" in text:
            rel = path.relative_to(ROOT).as_posix()
            violations.append(
                f"{rel}: feature-owned resources must depend on foundation media_resource_lifecycle.dart, not app/runtime coordinator"
            )

# Chunk 34-M7: the remote game WebView is feature-owned and registers through
# the foundation resource port. It must never import the concrete App runtime.
_GAME_WEBVIEW_RESOURCE = (
    APP / "game_platform" / "runtime" / "game_webview_resource_participant.dart"
)
if not _GAME_WEBVIEW_RESOURCE.exists():
    violations.append(
        "game_platform/runtime/game_webview_resource_participant.dart: Chunk 34-M7 game WebView participant is required"
    )
else:
    game_webview_resource_text = _GAME_WEBVIEW_RESOURCE.read_text(
        encoding="utf-8-sig"
    )
    for marker in (
        "implements MediaResourceParticipant",
        "MediaResourceKind.gameWebView",
        "'app.lifecycle'",
        "'app.memory_pressure'",
        "_runtime.dispose()",
    ):
        if marker not in game_webview_resource_text:
            violations.append(
                "game_platform/runtime/game_webview_resource_participant.dart: "
                f"missing Chunk 34-M7 lifecycle marker: {marker}"
            )

_REMOTE_GAME_PLAYER = (
    APP / "game_platform" / "presentation" / "remote_game_player_page.dart"
)
if _REMOTE_GAME_PLAYER.exists():
    remote_game_text = _REMOTE_GAME_PLAYER.read_text(encoding="utf-8-sig")
    for marker in (
        "mediaResourceRegistryProvider",
        "GameWebViewResourceParticipant",
        "registry.register(participant)",
        "registry.unregister(",
        "onReady:",
    ):
        if marker not in remote_game_text:
            violations.append(
                "game_platform/presentation/remote_game_player_page.dart: "
                f"missing Chunk 34-M7 resource marker: {marker}"
            )


# Chunk 34-M8: embedded OTT Watch Party WebViews register through the
# foundation lifecycle port and never import the concrete App coordinator.
_WATCH_PARTY_WEBVIEW_RESOURCE = (
    APP
    / "watch_party"
    / "providers"
    / "web"
    / "watch_party_webview_resource_participant.dart"
)
if not _WATCH_PARTY_WEBVIEW_RESOURCE.exists():
    violations.append(
        "watch_party/providers/web/watch_party_webview_resource_participant.dart: Chunk 34-M8 participant is required"
    )
else:
    watch_resource_text = _WATCH_PARTY_WEBVIEW_RESOURCE.read_text(
        encoding="utf-8-sig"
    )
    for marker in (
        "implements MediaResourceParticipant",
        "MediaResourceKind.watchPartyWebView",
        "await _host.pause()",
        "await _host.dispose()",
    ):
        if marker not in watch_resource_text:
            violations.append(
                "watch_party/providers/web/watch_party_webview_resource_participant.dart: "
                f"missing Chunk 34-M8 lifecycle marker: {marker}"
            )

_OTT_WATCH_SHEET = (
    APP
    / "features"
    / "rooms"
    / "presentation"
    / "modules"
    / "watch_party"
    / "live_room_ott_watch_party_sheet.dart"
)
if _OTT_WATCH_SHEET.exists():
    ott_sheet_text = _OTT_WATCH_SHEET.read_text(encoding="utf-8-sig")
    for marker in (
        "mediaResourceRegistryProvider",
        "WatchPartyWebViewResourceParticipant",
        "registry.register(_webResourceParticipant)",
        "registry.unregister(",
        "onReady: _onWebHostReady",
    ):
        if marker not in ott_sheet_text:
            violations.append(
                "features/rooms/presentation/modules/watch_party/live_room_ott_watch_party_sheet.dart: "
                f"missing Chunk 34-M8 resource marker: {marker}"
            )

_OTT_WEB_HOST = (
    APP / "watch_party" / "providers" / "web" / "ott_web_playback_host.dart"
)
if _OTT_WEB_HOST.exists():
    ott_host_text = _OTT_WEB_HOST.read_text(encoding="utf-8-sig")
    for marker in (
        "OttWebPlaybackReadyHandler? onReady",
        "_onReady?.call();",
    ):
        if marker not in ott_host_text:
            violations.append(
                "watch_party/providers/web/ott_web_playback_host.dart: "
                f"missing Chunk 34-M8 readiness marker: {marker}"
            )


# Chunk 34-M9: the existing canonical RoomMediaEngine registers through the
# foundation lifecycle port. The media singleton remains engine owner because
# minimized rooms can outlive the route widget.
_ROOM_WEBRTC_RESOURCE = (
    APP / "room_media" / "runtime" / "room_media_resource_participant.dart"
)
if not _ROOM_WEBRTC_RESOURCE.exists():
    violations.append(
        "room_media/runtime/room_media_resource_participant.dart: Chunk 34-M9 participant is required"
    )
else:
    room_webrtc_text = _ROOM_WEBRTC_RESOURCE.read_text(encoding="utf-8-sig")
    for marker in (
        "implements MediaResourceParticipant",
        "MediaResourceKind.roomWebRtc",
        "await _engine.reconnect()",
        "await _engine.leave()",
    ):
        if marker not in room_webrtc_text:
            violations.append(
                "room_media/runtime/room_media_resource_participant.dart: "
                f"missing Chunk 34-M9 lifecycle marker: {marker}"
            )
    if "_engine.dispose()" in room_webrtc_text:
        violations.append(
            "room_media/runtime/room_media_resource_participant.dart: session release must leave reusable singleton engine, not terminally dispose it"
        )

_ROOM_MEDIA_SIGNALING = (
    APP / "features" / "rooms" / "data" / "live_room_media_signaling_service.dart"
)
if _ROOM_MEDIA_SIGNALING.exists():
    signaling_text = _ROOM_MEDIA_SIGNALING.read_text(encoding="utf-8-sig")
    for marker in (
        "MediaResourceRegistry? resourceRegistry",
        "RoomMediaResourceParticipant",
        "_configureMediaResourceLifecycle",
        "_detachMediaResourceLifecycle",
        "if (_mediaResourceRegistry == null)",
    ):
        if marker not in signaling_text:
            violations.append(
                "features/rooms/data/live_room_media_signaling_service.dart: "
                f"missing Chunk 34-M9 lifecycle marker: {marker}"
            )

_ROOM_PRESENCE_SHELL = (
    APP / "features" / "rooms" / "presentation" / "live_room_presence_shell_page.dart"
)
if _ROOM_PRESENCE_SHELL.exists():
    room_shell_text = _ROOM_PRESENCE_SHELL.read_text(encoding="utf-8-sig")
    for marker in (
        "mediaResourceRegistryProvider",
        "resourceRegistry: ref.read(mediaResourceRegistryProvider)",
    ):
        if marker not in room_shell_text:
            violations.append(
                "features/rooms/presentation/live_room_presence_shell_page.dart: "
                f"missing Chunk 34-M9 room-media registry marker: {marker}"
            )


# Chunk 34-M10: the production gift-video decoder is feature-owned and
# registers through the foundation resource lifecycle port.
_GIFT_VIDEO_PARTICIPANT = (
    APP
    / "features"
    / "rooms"
    / "modules"
    / "video_gift"
    / "runtime"
    / "gift_video_resource_participant.dart"
)
if not _GIFT_VIDEO_PARTICIPANT.exists():
    violations.append(
        "features/rooms/modules/video_gift/runtime/gift_video_resource_participant.dart: Chunk 34-M10 participant is required"
    )
else:
    gift_video_text = _GIFT_VIDEO_PARTICIPANT.read_text(encoding="utf-8-sig")
    for marker in (
        "implements MediaResourceParticipant",
        "MediaResourceKind.giftVideo",
        "_pause()",
        "_resume()",
        "_releaseResource()",
    ):
        if marker not in gift_video_text:
            violations.append(
                "features/rooms/modules/video_gift/runtime/gift_video_resource_participant.dart: "
                f"missing Chunk 34-M10 lifecycle marker: {marker}"
            )

_CLEAN_GIFT_VIDEO = (
    APP
    / "features"
    / "rooms"
    / "modules"
    / "video_gift"
    / "presentation"
    / "clean_video_gift_overlay.dart"
)
if _CLEAN_GIFT_VIDEO.exists():
    clean_gift_text = _CLEAN_GIFT_VIDEO.read_text(encoding="utf-8-sig")
    for marker in (
        "mediaResourceRegistryProvider",
        "GiftVideoResourceParticipant",
        "registry.register(participant)",
        "registry.unregister(",
    ):
        if marker not in clean_gift_text:
            violations.append(
                "features/rooms/modules/video_gift/presentation/clean_video_gift_overlay.dart: "
                f"missing Chunk 34-M10 resource marker: {marker}"
            )

_LIVE_GIFT_OVERLAY = (
    APP / "features" / "rooms" / "presentation" / "widgets" / "live_room_gift_overlay.dart"
)
if _LIVE_GIFT_OVERLAY.exists():
    live_gift_text = _LIVE_GIFT_OVERLAY.read_text(encoding="utf-8-sig")
    if "roomPublicId: widget.roomPublicId" not in live_gift_text:
        violations.append(
            "features/rooms/presentation/widgets/live_room_gift_overlay.dart: gift-video resource must receive explicit room scope"
        )


# Chunk 34-M11: microphone capture registers at the low-level audio owner
# through the RoomMediaEngine/delegate boundary.
_AUDIO_INPUT_RESOURCE = (
    APP / "features" / "rooms" / "data" / "runtime" / "audio_input_resource_participant.dart"
)
if not _AUDIO_INPUT_RESOURCE.exists():
    violations.append(
        "features/rooms/data/runtime/audio_input_resource_participant.dart: Chunk 34-M11 participant is required"
    )
else:
    audio_input_text = _AUDIO_INPUT_RESOURCE.read_text(encoding="utf-8-sig")
    for marker in (
        "implements MediaResourceParticipant",
        "MediaResourceKind.audioInput",
        "_releaseInput()",
    ):
        if marker not in audio_input_text:
            violations.append(
                "features/rooms/data/runtime/audio_input_resource_participant.dart: "
                f"missing Chunk 34-M11 lifecycle marker: {marker}"
            )

_AUDIO_SERVICE = APP / "features" / "rooms" / "data" / "live_room_audio_service.dart"
if _AUDIO_SERVICE.exists():
    audio_service_text = _AUDIO_SERVICE.read_text(encoding="utf-8-sig")
    for marker in (
        "bindMediaResourceRegistry",
        "_attachAudioInputResource",
        "_detachAudioInputResource",
        "AudioInputResourceParticipant",
    ):
        if marker not in audio_service_text:
            violations.append(
                "features/rooms/data/live_room_audio_service.dart: "
                f"missing Chunk 34-M11 microphone lifecycle marker: {marker}"
            )

_ROOM_MEDIA_REGISTRY_BINDING = (
    APP / "room_media" / "runtime" / "room_media_resource_registry_binding.dart"
)
if not _ROOM_MEDIA_REGISTRY_BINDING.exists():
    violations.append(
        "room_media/runtime/room_media_resource_registry_binding.dart: Chunk 34-M11 binding is required"
    )


# Chunk 34-M12: Inbox video-call camera capture registers through the
# foundation resource lifecycle port.
_CAMERA_INPUT_RESOURCE = (
    APP / "features" / "inbox" / "data" / "runtime" / "camera_input_resource_participant.dart"
)
if not _CAMERA_INPUT_RESOURCE.exists():
    violations.append(
        "features/inbox/data/runtime/camera_input_resource_participant.dart: Chunk 34-M12 participant is required"
    )
else:
    camera_text = _CAMERA_INPUT_RESOURCE.read_text(encoding="utf-8-sig")
    for marker in (
        "implements MediaResourceParticipant",
        "MediaResourceKind.cameraInput",
        "_pauseCamera()",
        "_resumeCamera()",
        "_releaseCamera()",
    ):
        if marker not in camera_text:
            violations.append(
                "features/inbox/data/runtime/camera_input_resource_participant.dart: "
                f"missing Chunk 34-M12 lifecycle marker: {marker}"
            )

_CALL_MEDIA_BRIDGE = APP / "features" / "inbox" / "data" / "inbox_call_media_bridge.dart"
if _CALL_MEDIA_BRIDGE.exists():
    call_media_text = _CALL_MEDIA_BRIDGE.read_text(encoding="utf-8-sig")
    for marker in (
        "MediaResourceRegistry? resourceRegistry",
        "CameraInputResourceParticipant",
        "_attachCameraResource",
        "_detachCameraResource",
        "_releaseCameraForSession",
    ):
        if marker not in call_media_text:
            violations.append(
                "features/inbox/data/inbox_call_media_bridge.dart: "
                f"missing Chunk 34-M12 camera lifecycle marker: {marker}"
            )

_ACTIVE_CALL_PAGE = (
    APP / "features" / "inbox" / "presentation" / "pages" / "inbox_active_call_page.dart"
)
if _ACTIVE_CALL_PAGE.exists():
    active_call_text = _ACTIVE_CALL_PAGE.read_text(encoding="utf-8-sig")
    if "resourceRegistry: ref.read(mediaResourceRegistryProvider)" not in active_call_text:
        violations.append(
            "features/inbox/presentation/pages/inbox_active_call_page.dart: camera lifecycle registry injection missing"
        )


# Chunk 34-M13: canonical image decode sizing + bounded prefetch runtime.
_APP_IMAGE = APP / "foundation" / "images" / "app_image.dart"
_IMAGE_PREFETCH = APP / "foundation" / "images" / "app_image_prefetch.dart"

if not _APP_IMAGE.exists():
    violations.append(
        "foundation/images/app_image.dart: Chunk 34-M13 canonical AppImage is required"
    )
else:
    app_image_text = _APP_IMAGE.read_text(encoding="utf-8-sig")
    for marker in (
        "class AppImage",
        "AppImageDecodePolicy",
        "cacheWidth:",
        "cacheHeight:",
        "maxDecodeDimension",
    ):
        if marker not in app_image_text:
            violations.append(
                f"foundation/images/app_image.dart: missing Chunk 34-M13 marker: {marker}"
            )

if not _IMAGE_PREFETCH.exists():
    violations.append(
        "foundation/images/app_image_prefetch.dart: Chunk 34-M13 prefetch queue is required"
    )
else:
    prefetch_text = _IMAGE_PREFETCH.read_text(encoding="utf-8-sig")
    for marker in (
        "implements MediaResourceParticipant",
        "MediaResourceKind.imagePrefetch",
        "maxConcurrent = 2",
        "maxQueued = 12",
        "precacheImage",
        "provider.evict",
        "registry.register(queue)",
    ):
        if marker not in prefetch_text:
            violations.append(
                f"foundation/images/app_image_prefetch.dart: missing Chunk 34-M13 marker: {marker}"
            )

for hot_image_path in (
    APP / "features" / "vibes" / "presentation" / "widgets" / "vibe_avatar.dart",
    APP / "core" / "widgets" / "vm_avatar_frame.dart",
    APP / "features" / "stories" / "widgets" / "story_avatar_ring.dart",
):
    if not hot_image_path.exists():
        continue
    hot_image_text = hot_image_path.read_text(encoding="utf-8-sig")
    rel = hot_image_path.relative_to(ROOT).as_posix()
    if "AppImage.network" not in hot_image_text:
        violations.append(f"{rel}: hot network image surface must use AppImage")
    if "Image.network(" in hot_image_text or "NetworkImage(" in hot_image_text:
        violations.append(
            f"{rel}: raw network image decoding is forbidden on guarded hot surfaces"
        )


# Chunk 34-M1: heavyweight media/resource lifecycle coordination must be
# session-scoped. The coordinator is an app/runtime implementation, not a
# feature singleton or a new domain-state authority.
_RESOURCE_COORDINATOR = (
    APP / "app" / "runtime" / "media_resource_coordinator.dart"
)
if not _RESOURCE_COORDINATOR.exists():
    violations.append(
        "app/runtime/media_resource_coordinator.dart: Chunk 34 resource coordinator is required"
    )
else:
    resource_text = _RESOURCE_COORDINATOR.read_text(encoding="utf-8-sig")
    if "implements MediaResourceRegistry" not in resource_text:
        violations.append(
            "app/runtime/media_resource_coordinator.dart: coordinator must implement the foundation MediaResourceRegistry"
        )
    if "Provider.autoDispose<MediaResourceCoordinator>" not in resource_text:
        violations.append(
            "app/runtime/media_resource_coordinator.dart: coordinator must be session-scoped with Provider.autoDispose"
        )
    for forbidden in (
        "MediaResourceCoordinator.instance",
        "static final MediaResourceCoordinator",
        "static MediaResourceCoordinator",
    ):
        if forbidden in resource_text:
            violations.append(
                "app/runtime/media_resource_coordinator.dart: "
                f"process-global resource coordinator is forbidden ({forbidden})"
            )


# Chunk 34-M2: AppShell mirrors lifecycle and memory pressure into the
# coordinator, but legacy/direct cleanup must remain until each resource is
# migrated in its own later micro-chunk.
_APP_SHELL = APP / "app" / "app_shell.dart"
if _APP_SHELL.exists():
    shell_text = _APP_SHELL.read_text(encoding="utf-8-sig")
    required_resource_runtime_markers = (
        "ref.watch(mediaResourceCoordinatorProvider);",
        "mediaResourceRegistryProvider.overrideWithValue(resourceCoordinator)",
        "_notifyResourceMemoryPressure()",
        "_notifyResourceForegroundState(state == AppLifecycleState.resumed)",
        "handleMemoryPressure()",
        "setForeground(isForeground)",
    )
    for marker in required_resource_runtime_markers:
        if marker not in shell_text:
            violations.append(
                f"app/app_shell.dart: Chunk 34-M2 resource mirror marker missing: {marker}"
            )

    # By M5 all original AppShell heavyweight cleanup routes have migrated to
    # resource participants. New direct cleanup calls must not be added here.


# Chunk 34-M3: Vibes decoder lifecycle is migrated through an App-runtime
# participant. The old direct AppShell memory-pressure call must stay removed.
_VIBES_RESOURCE_ADAPTER = (
    APP / "app" / "runtime" / "vibes_media_resource_participant.dart"
)
if not _VIBES_RESOURCE_ADAPTER.exists():
    violations.append(
        "app/runtime/vibes_media_resource_participant.dart: Chunk 34-M3 Vibes resource adapter is required"
    )
else:
    vibes_resource_text = _VIBES_RESOURCE_ADAPTER.read_text(encoding="utf-8-sig")
    for marker in (
        "implements MediaResourceParticipant",
        "MediaResourceKind.vibesVideoDecoder",
        "playbackGate.acquirePauseLock",
        "playbackGate.releasePauseLock",
        "playbackGate.handleMemoryPressure()",
    ):
        if marker not in vibes_resource_text:
            violations.append(
                f"app/runtime/vibes_media_resource_participant.dart: missing Vibes lifecycle marker: {marker}"
            )

if _APP_SHELL.exists():
    shell_text = _APP_SHELL.read_text(encoding="utf-8-sig")
    for marker in (
        "VibesMediaResourceParticipant",
        "resourceCoordinator.register(_vibesMediaResourceParticipant)",
        "_syncNewResourceParticipant(",
    ):
        if marker not in shell_text:
            violations.append(
                f"app/app_shell.dart: Chunk 34-M3 Vibes resource registration missing: {marker}"
            )
    if "_vibePlaybackGate.handleMemoryPressure();" in shell_text:
        violations.append(
            "app/app_shell.dart: Vibes memory pressure must flow through MediaResourceCoordinator after Chunk 34-M3"
        )


# Chunk 34-M4: verified remote game bundles are reconstructable warm cache and
# clear through a resource participant on memory pressure/session teardown.
_GAME_CACHE_RESOURCE_ADAPTER = (
    APP / "app" / "runtime" / "game_bundle_cache_resource_participant.dart"
)
if not _GAME_CACHE_RESOURCE_ADAPTER.exists():
    violations.append(
        "app/runtime/game_bundle_cache_resource_participant.dart: Chunk 34-M4 game cache participant is required"
    )
else:
    game_cache_resource_text = _GAME_CACHE_RESOURCE_ADAPTER.read_text(
        encoding="utf-8-sig"
    )
    for marker in (
        "implements MediaResourceParticipant",
        "MediaResourceKind.gameBundleCache",
        "_cache.clear()",
    ):
        if marker not in game_cache_resource_text:
            violations.append(
                "app/runtime/game_bundle_cache_resource_participant.dart: "
                f"missing game cache lifecycle marker: {marker}"
            )

if _APP_SHELL.exists():
    shell_text = _APP_SHELL.read_text(encoding="utf-8-sig")
    for marker in (
        "GameBundleCacheResourceParticipant",
        "resourceCoordinator.register(_gameBundleCacheResourceParticipant)",
    ):
        if marker not in shell_text:
            violations.append(
                f"app/app_shell.dart: Chunk 34-M4 game cache registration missing: {marker}"
            )
    if "ref.read(gameBundleCacheProvider).clear();" in shell_text:
        violations.append(
            "app/app_shell.dart: game bundle cache memory pressure must flow through MediaResourceCoordinator after Chunk 34-M4"
        )


# Chunk 34-M5: Flutter's decoded image cache is reconstructable runtime memory
# and clears through a resource participant rather than AppShell directly.
_IMAGE_CACHE_RESOURCE_ADAPTER = (
    APP / "app" / "runtime" / "flutter_image_cache_resource_participant.dart"
)
if not _IMAGE_CACHE_RESOURCE_ADAPTER.exists():
    violations.append(
        "app/runtime/flutter_image_cache_resource_participant.dart: Chunk 34-M5 image cache participant is required"
    )
else:
    image_cache_resource_text = _IMAGE_CACHE_RESOURCE_ADAPTER.read_text(
        encoding="utf-8-sig"
    )
    for marker in (
        "implements MediaResourceParticipant",
        "MediaResourceKind.flutterImageCache",
        "_clearLiveImages()",
    ):
        if marker not in image_cache_resource_text:
            violations.append(
                "app/runtime/flutter_image_cache_resource_participant.dart: "
                f"missing image cache lifecycle marker: {marker}"
            )

if _APP_SHELL.exists():
    shell_text = _APP_SHELL.read_text(encoding="utf-8-sig")
    for marker in (
        "FlutterImageCacheResourceParticipant",
        "resourceCoordinator.register(_flutterImageCacheResourceParticipant)",
    ):
        if marker not in shell_text:
            violations.append(
                f"app/app_shell.dart: Chunk 34-M5 image cache registration missing: {marker}"
            )
    if "PaintingBinding.instance.imageCache.clearLiveImages();" in shell_text:
        violations.append(
            "app/app_shell.dart: Flutter image cache memory pressure must flow through MediaResourceCoordinator after Chunk 34-M5"
        )


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

