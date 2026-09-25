import '../../../../../foundation/runtime/media_resource_lifecycle.dart';

typedef GiftVideoPause = Future<bool> Function();
typedef GiftVideoResume = Future<void> Function();
typedef GiftVideoRelease = Future<void> Function();

/// Lifecycle adapter for one ephemeral gift-video decoder.
class GiftVideoResourceParticipant implements MediaResourceParticipant {
  GiftVideoResourceParticipant({
    required this.resourceId,
    required GiftVideoPause pause,
    required GiftVideoResume resume,
    required GiftVideoRelease releaseResource,
  }) : _pause = pause,
       _resume = resume,
       _releaseResource = releaseResource;

  @override
  final String resourceId;

  final GiftVideoPause _pause;
  final GiftVideoResume _resume;
  final GiftVideoRelease _releaseResource;

  bool _resumeOnForeground = false;
  bool _released = false;

  @override
  MediaResourceKind get kind => MediaResourceKind.giftVideo;

  @override
  Future<void> onForegroundChanged(bool isForeground) async {
    if (_released) return;
    if (!isForeground) {
      _resumeOnForeground = await _pause();
      return;
    }
    if (!_resumeOnForeground) return;
    _resumeOnForeground = false;
    await _resume();
  }

  @override
  Future<void> onMemoryPressure() => release();

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _resumeOnForeground = false;
    await _releaseResource();
  }
}
