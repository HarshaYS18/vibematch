import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/inbox/data/runtime/camera_input_resource_participant.dart';
import 'package:vibematch_app/foundation/runtime/media_resource_lifecycle.dart';

void main() {
  test('camera exposes camera input resource kind', () {
    final participant = CameraInputResourceParticipant(
      resourceId: 'camera-input:call-1',
      pauseCamera: () async => false,
      resumeCamera: () async {},
      releaseCamera: () async {},
    );
    expect(participant.kind, MediaResourceKind.cameraInput);
  });

  test('background resumes only a camera lifecycle actually paused', () async {
    var resumeCount = 0;
    final participant = CameraInputResourceParticipant(
      resourceId: 'camera-input:call-1',
      pauseCamera: () async => true,
      resumeCamera: () async => resumeCount += 1,
      releaseCamera: () async {},
    );

    await participant.onForegroundChanged(false);
    await participant.onForegroundChanged(true);

    expect(resumeCount, 1);
  });

  test('user-disabled camera is not auto-enabled on foreground', () async {
    var resumeCount = 0;
    final participant = CameraInputResourceParticipant(
      resourceId: 'camera-input:call-1',
      pauseCamera: () async => false,
      resumeCamera: () async => resumeCount += 1,
      releaseCamera: () async {},
    );

    await participant.onForegroundChanged(false);
    await participant.onForegroundChanged(true);

    expect(resumeCount, 0);
  });

  test('memory pressure preserves call, session release stops camera once', () async {
    var releaseCount = 0;
    final participant = CameraInputResourceParticipant(
      resourceId: 'camera-input:call-1',
      pauseCamera: () async => true,
      resumeCamera: () async {},
      releaseCamera: () async => releaseCount += 1,
    );

    await participant.onMemoryPressure();
    expect(releaseCount, 0);

    await participant.release();
    await participant.release();
    expect(releaseCount, 1);
  });
}
