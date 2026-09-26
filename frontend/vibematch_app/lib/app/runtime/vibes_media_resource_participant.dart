import '../../features/vibes/presentation/widgets/vibe_media_playback_gate.dart';
import '../../foundation/runtime/media_resource_lifecycle.dart';

/// App-runtime lifecycle adapter for the existing Vibes playback gate.
///
/// The playback gate remains the Vibes feature's arbitration owner. This
/// adapter only translates generic authenticated-app lifecycle pressure into
/// the gate's existing pause-lock and memory-pressure APIs.
class VibesMediaResourceParticipant implements MediaResourceParticipant {
  VibesMediaResourceParticipant({
    required VibeMediaPlaybackGate playbackGate,
  }) : _playbackGate = playbackGate;

  static const String _appBackgroundPauseLock =
      'resource-runtime:app-background';

  final VibeMediaPlaybackGate _playbackGate;

  @override
  String get resourceId => 'app-shell:vibes-video-decoder';

  @override
  MediaResourceKind get kind => MediaResourceKind.vibesVideoDecoder;

  @override
  Future<void> onForegroundChanged(bool isForeground) async {
    if (isForeground) {
      _playbackGate.releasePauseLock(_appBackgroundPauseLock);
      return;
    }
    _playbackGate.acquirePauseLock(_appBackgroundPauseLock);
  }

  @override
  Future<void> onMemoryPressure() async {
    _playbackGate.handleMemoryPressure();
  }

  @override
  Future<void> release() async {
    _playbackGate.acquirePauseLock(_appBackgroundPauseLock);
    _playbackGate.handleMemoryPressure();
  }
}
