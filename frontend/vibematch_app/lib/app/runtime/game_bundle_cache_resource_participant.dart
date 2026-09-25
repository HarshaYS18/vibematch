import '../../game_platform/data/game_bundle_cache.dart';
import '../../foundation/runtime/media_resource_lifecycle.dart';

/// Chunk 34-M4 lifecycle adapter for Game Platform's verified bundle cache.
///
/// The cache is reconstructable warm memory only. Game catalog, manifest,
/// integrity verification and runtime/session authority remain in Game Platform.
class GameBundleCacheResourceParticipant implements MediaResourceParticipant {
  GameBundleCacheResourceParticipant({
    required GameBundleCache cache,
  }) : _cache = cache;

  final GameBundleCache _cache;
  bool _released = false;

  @override
  String get resourceId => 'app-shell:verified-game-bundle-cache';

  @override
  MediaResourceKind get kind => MediaResourceKind.gameBundleCache;

  /// Verified bundle bytes are passive memory, so app foreground state does
  /// not require work for this resource.
  @override
  Future<void> onForegroundChanged(bool isForeground) async {}

  /// Drops reconstructable verified HTML bundles under memory pressure.
  @override
  Future<void> onMemoryPressure() async {
    if (_released) return;
    _cache.clear();
  }

  /// Session teardown clears the warm cache once and makes this adapter
  /// terminal. The cache can be repopulated by a future authenticated session.
  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _cache.clear();
  }
}
