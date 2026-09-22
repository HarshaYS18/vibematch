import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/watch_party/providers/web/ott_playback_probe_result.dart';
import 'package:vibematch_app/watch_party/providers/web/ott_provider_definition.dart';

void main() {
  test('OTT provider catalog normalizes only approved HTTPS hosts', () {
    expect(
      OttProviderCatalog.netflix.normalizeContentInput(
        'https://www.netflix.com/watch/81234567',
      ),
      isNotNull,
    );
    expect(
      OttProviderCatalog.netflix.normalizeContentInput(
        'https://evil.example/watch/81234567',
      ),
      isNull,
    );
    expect(
      OttProviderCatalog.netflix.normalizeContentInput(
        'http://www.netflix.com/watch/81234567',
      ),
      isNull,
    );
    expect(
      OttProviderCatalog.primeVideo.normalizeContentInput(
        'https://www.primevideo.com/detail/0ABC',
      ),
      isNotNull,
    );
    expect(
      OttProviderCatalog.jioHotstar.normalizeContentInput(
        'https://www.jiohotstar.com/sports/example/123',
      ),
      isNotNull,
    );
  });

  test('provider aliases resolve to one canonical adapter id', () {
    expect(OttProviderCatalog.byId('prime')?.id, 'prime_video');
    expect(OttProviderCatalog.byId('PrimeVideo')?.id, 'prime_video');
    expect(OttProviderCatalog.byId('hotstar')?.id, 'jiohotstar');
    expect(OttProviderCatalog.byId('jio_hotstar')?.id, 'jiohotstar');
  });

  test('probe advertises embedded playback only with real controls', () {
    final ready = OttPlaybackProbeResult.fromMap(<String, dynamic>{
      'pageSupported': true,
      'authenticated': true,
      'playerAvailable': true,
      'playbackAvailable': true,
      'positionReadable': true,
      'programmaticPlay': true,
      'programmaticPause': true,
      'programmaticSeek': true,
      'playbackRateControl': true,
      'fineGrainedPlaybackRateControl': false,
      'liveTimelineAvailable': true,
      'fallbackRequired': false,
    });
    expect(ready.embeddedPlaybackReady, isTrue);

    final notReady = OttPlaybackProbeResult.fromMap(<String, dynamic>{
      'pageSupported': true,
      'playerAvailable': true,
      'playbackAvailable': false,
      'positionReadable': true,
      'programmaticPlay': true,
      'programmaticPause': true,
      'programmaticSeek': true,
      'fallbackRequired': false,
    });
    expect(notReady.embeddedPlaybackReady, isFalse);
  });
}
