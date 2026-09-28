import '../../foundation/runtime/media_resource_lifecycle.dart';

/// Callback used to trim Flutter's live decoded image entries.
typedef ClearLiveImages = void Function();

/// Chunk 34-M5 lifecycle adapter for Flutter's shared decoded image cache.
///
/// The cache is presentation-only reconstructable memory. This adapter owns no
/// image URLs, content state, prefetch policy or domain state; it only invokes
/// the cleanup callback supplied by AppShell.
class FlutterImageCacheResourceParticipant
    implements MediaResourceParticipant {
  FlutterImageCacheResourceParticipant({
    required ClearLiveImages clearLiveImages,
  }) : _clearLiveImages = clearLiveImages;

  final ClearLiveImages _clearLiveImages;
  bool _released = false;

  @override
  String get resourceId => 'app-shell:flutter-live-image-cache';

  @override
  MediaResourceKind get kind => MediaResourceKind.flutterImageCache;

  /// Decoded image cache does not require foreground transition work.
  @override
  Future<void> onForegroundChanged(bool isForeground) async {}

  /// Clears live decoded/network image entries under memory pressure.
  @override
  Future<void> onMemoryPressure() async {
    if (_released) return;
    _clearLiveImages();
  }

  /// Session teardown performs one final trim and makes this registration
  /// terminal.
  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _clearLiveImages();
  }
}
