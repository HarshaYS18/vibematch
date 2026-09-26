import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/rooms/data/runtime/audio_input_resource_participant.dart';
import 'package:vibematch_app/foundation/runtime/media_resource_lifecycle.dart';

void main() {
  test('microphone capture exposes audio input resource kind', () {
    final participant = AudioInputResourceParticipant(
      resourceId: 'audio-input:room-1:user-1',
      releaseInput: () async {},
    );
    expect(participant.kind, MediaResourceKind.audioInput);
  });

  test('background and memory pressure preserve active voice', () async {
    var releaseCount = 0;
    final participant = AudioInputResourceParticipant(
      resourceId: 'audio-input:room-1:user-1',
      releaseInput: () async => releaseCount += 1,
    );

    await participant.onForegroundChanged(false);
    await participant.onMemoryPressure();

    expect(releaseCount, 0);
  });

  test('session release relinquishes microphone exactly once', () async {
    var releaseCount = 0;
    final participant = AudioInputResourceParticipant(
      resourceId: 'audio-input:room-1:user-1',
      releaseInput: () async => releaseCount += 1,
    );

    await participant.release();
    await participant.release();

    expect(releaseCount, 1);
  });
}
