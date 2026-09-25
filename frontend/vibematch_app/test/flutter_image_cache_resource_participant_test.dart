import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/app/runtime/flutter_image_cache_resource_participant.dart';
import 'package:vibematch_app/app/runtime/media_resource_coordinator.dart';

/// Chunk 34-M5 behavioral coverage for Flutter image-cache lifecycle.
void main() {
  test('exposes a stable Flutter image-cache resource identity', () {
    final participant = FlutterImageCacheResourceParticipant(
      clearLiveImages: () {},
    );

    expect(participant.resourceId, 'app-shell:flutter-live-image-cache');
    expect(participant.kind, MediaResourceKind.flutterImageCache);
  });

  test('memory pressure trims live decoded images exactly once per signal', () async {
    var clears = 0;
    final participant = FlutterImageCacheResourceParticipant(
      clearLiveImages: () => clears += 1,
    );

    await participant.onMemoryPressure();
    await participant.onMemoryPressure();

    expect(clears, 2);
  });

  test('foreground transitions do not evict image cache', () async {
    var clears = 0;
    final participant = FlutterImageCacheResourceParticipant(
      clearLiveImages: () => clears += 1,
    );

    await participant.onForegroundChanged(false);
    await participant.onForegroundChanged(true);

    expect(clears, 0);
  });

  test('release trims once and makes participant terminal', () async {
    var clears = 0;
    final participant = FlutterImageCacheResourceParticipant(
      clearLiveImages: () => clears += 1,
    );

    await participant.release();
    await participant.release();
    await participant.onMemoryPressure();

    expect(clears, 1);
  });
}
