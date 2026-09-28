import '../../../../foundation/runtime/media_resource_lifecycle.dart';

typedef CameraPause = Future<bool> Function();
typedef CameraResume = Future<void> Function();
typedef CameraRelease = Future<void> Function();

/// Lifecycle adapter for one local video-call camera input.
class CameraInputResourceParticipant implements MediaResourceParticipant {
  CameraInputResourceParticipant({
    required this.resourceId,
    required CameraPause pauseCamera,
    required CameraResume resumeCamera,
    required CameraRelease releaseCamera,
  }) : _pauseCamera = pauseCamera,
       _resumeCamera = resumeCamera,
       _releaseCamera = releaseCamera;

  @override
  final String resourceId;

  final CameraPause _pauseCamera;
  final CameraResume _resumeCamera;
  final CameraRelease _releaseCamera;

  bool _resumeOnForeground = false;
  bool _released = false;

  @override
  MediaResourceKind get kind => MediaResourceKind.cameraInput;

  @override
  Future<void> onForegroundChanged(bool isForeground) async {
    if (_released) return;
    if (!isForeground) {
      _resumeOnForeground = await _pauseCamera();
      return;
    }
    if (!_resumeOnForeground) return;
    _resumeOnForeground = false;
    await _resumeCamera();
  }

  @override
  Future<void> onMemoryPressure() async {}

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _resumeOnForeground = false;
    await _releaseCamera();
  }
}
