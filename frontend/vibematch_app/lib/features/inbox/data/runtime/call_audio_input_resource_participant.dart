import '../../../../foundation/runtime/media_resource_lifecycle.dart';

typedef CallAudioInputRelease = Future<void> Function();

/// Lifecycle adapter for the local microphone used by one Inbox call.
class CallAudioInputResourceParticipant
    implements MediaResourceParticipant {
  CallAudioInputResourceParticipant({
    required this.resourceId,
    required CallAudioInputRelease releaseInput,
  }) : _releaseInput = releaseInput;

  @override
  final String resourceId;

  final CallAudioInputRelease _releaseInput;
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
