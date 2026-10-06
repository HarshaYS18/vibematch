import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/inbox/data/runtime/call_audio_input_resource_participant.dart';
import 'package:vibematch_app/foundation/runtime/media_resource_lifecycle.dart';

void main() {
  test('Inbox call microphone uses audio-input resource kind', () {
    final participant = CallAudioInputResourceParticipant(
      resourceId: 'call-audio-input:call-1',
      releaseInput: () async {},
    );
    expect(participant.kind, MediaResourceKind.audioInput);
  });

  test('background and memory pressure preserve active call audio', () async {
    var releaseCount = 0;
    final participant = CallAudioInputResourceParticipant(
      resourceId: 'call-audio-input:call-1',
      releaseInput: () async => releaseCount += 1,
    );

    await participant.onForegroundChanged(false);
    await participant.onMemoryPressure();
    expect(releaseCount, 0);
  });

  test('session teardown releases call microphone once', () async {
    var releaseCount = 0;
    final participant = CallAudioInputResourceParticipant(
      resourceId: 'call-audio-input:call-1',
      releaseInput: () async => releaseCount += 1,
    );

    await participant.release();
    await participant.release();
    expect(releaseCount, 1);
  });
}
