import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Heavyweight runtime resource classes coordinated for one authenticated app
/// session.
///
/// These values describe lifecycle/memory cost only. They never define domain
/// authority for rooms, games, Watch Party, gifts, identity or wallet state.
enum MediaResourceKind {
  vibesVideoDecoder,
  watchPartyWebView,
  gameWebView,
  roomWebRtc,
  giftVideo,
  audioInput,
  cameraInput,

  /// Flutter's decoded/network image cache owned by PaintingBinding.
  flutterImageCache,

  /// Explicit feature-driven image prefetch work, migrated separately.
  imagePrefetch,
  gameBundleCache,
}

/// Feature-owned lifecycle adapter for one heavyweight runtime resource.
///
/// Resource owners keep responsibility for creation, domain mutation and normal
/// disposal. The app registry only broadcasts foreground/background, memory
/// pressure and authenticated-session teardown.
abstract interface class MediaResourceParticipant {
  String get resourceId;
  MediaResourceKind get kind;

  Future<void> onForegroundChanged(bool isForeground);
  Future<void> onMemoryPressure();
  Future<void> release();
}

/// Foundation port implemented by the authenticated app resource runtime.
///
/// Feature code depends on this interface rather than on
/// `MediaResourceCoordinator`, preserving dependency direction.
abstract interface class MediaResourceRegistry {
  bool get isForeground;

  /// Returns true only when [participant] is newly registered.
  bool register(MediaResourceParticipant participant);

  /// Removes a registration without owning normal feature disposal.
  bool unregister(
    String resourceId, {
    MediaResourceParticipant? expectedParticipant,
  });

  Future<void> setForeground(bool isForeground);
  Future<void> handleMemoryPressure();
}

/// Registry visible to feature-owned resources in the current widget subtree.
///
/// The root/default value is null so features remain usable outside the
/// authenticated AppShell. AppShell overrides it with its session coordinator.
final mediaResourceRegistryProvider = Provider<MediaResourceRegistry?>(
  (ref) => null,
);
