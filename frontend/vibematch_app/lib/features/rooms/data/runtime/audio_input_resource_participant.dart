import '../../../../foundation/runtime/media_resource_lifecycle.dart';

typedef AudioInputRelease = Future<void> Function();

/// Lifecycle adapter for one active local microphone capture stream.
///
/// Active room voice is high-priority: background and memory pressure do not
/// silently mute a seated user. Session teardown releases the device.
class AudioInputResourceParticipant implements MediaResourceParticipant {
  AudioInputResourceParticipant({
    required this.resourceId,
    required AudioInputRelease releaseInput,
  }) : _releaseInput = releaseInput;

  @override
  final String resourceId;

  final AudioInputRelease _releaseInput;
  bool _released = false;

  @override
  MediaResourceKind get kind => MediaResourceKind.audioInput;

  @override
  Future<void> onForegroundChanged(bool isForeground) async {}

  @override
  Future<void> onMemoryPressure() async {}

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _releaseInput();
  }
}
