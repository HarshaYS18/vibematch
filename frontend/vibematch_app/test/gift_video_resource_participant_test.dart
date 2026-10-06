import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/foundation/runtime/media_resource_lifecycle.dart';
import 'package:vibematch_app/features/rooms/modules/video_gift/runtime/gift_video_resource_participant.dart';

void main() {
  test('gift video exposes resource kind', () {
    final participant = GiftVideoResourceParticipant(
      resourceId: 'gift-video:room-1:slide-1',
      pause: () async => false,
      resume: () async {},
      releaseResource: () async {},
    );
    expect(participant.kind, MediaResourceKind.giftVideo);
  });

  test('background resumes only when lifecycle paused active playback', () async {
    var pauseCount = 0;
    var resumeCount = 0;
    final participant = GiftVideoResourceParticipant(
      resourceId: 'gift-video:room-1:slide-1',
      pause: () async {
        pauseCount += 1;
        return true;
      },
      resume: () async => resumeCount += 1,
      releaseResource: () async {},
    );

    await participant.onForegroundChanged(false);
    await participant.onForegroundChanged(true);

    expect(pauseCount, 1);
    expect(resumeCount, 1);
  });

  test('memory pressure terminally releases ephemeral decoder once', () async {
    var releaseCount = 0;
    final participant = GiftVideoResourceParticipant(
      resourceId: 'gift-video:room-1:slide-1',
      pause: () async => true,
      resume: () async {},
      releaseResource: () async => releaseCount += 1,
    );

    await participant.onMemoryPressure();
    await participant.onMemoryPressure();
    await participant.release();
    await participant.onForegroundChanged(true);

    expect(releaseCount, 1);
  });
}
