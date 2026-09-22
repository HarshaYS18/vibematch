import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Watch Party keeps one provider-independent core', () {
    final repository = File(
      'lib/watch_party/data/watch_party_repository.dart',
    ).readAsStringSync();
    final coordinator = File(
      'lib/watch_party/application/watch_party_coordinator.dart',
    ).readAsStringSync();
    final adapter = File(
      'lib/watch_party/domain/watch_provider_adapter.dart',
    ).readAsStringSync();
    final youtubeAdapter = File(
      'lib/watch_party/providers/youtube/youtube_watch_adapter.dart',
    ).readAsStringSync();
    final ottAdapter = File(
      'lib/watch_party/providers/web/supported_web_playback_adapter.dart',
    ).readAsStringSync();
    final ottHost = File(
      'lib/watch_party/providers/web/ott_web_playback_host.dart',
    ).readAsStringSync();
    final netflixAdapter = File(
      'lib/watch_party/providers/netflix/netflix_provider_adapter.dart',
    ).readAsStringSync();
    final primeAdapter = File(
      'lib/watch_party/providers/prime_video/prime_video_provider_adapter.dart',
    ).readAsStringSync();
    final hotstarAdapter = File(
      'lib/watch_party/providers/jiohotstar/jiohotstar_provider_adapter.dart',
    ).readAsStringSync();
    final roomRouter = File(
      'lib/features/rooms/presentation/modules/watch_party/'
      'live_room_watch_party_router_sheet.dart',
    ).readAsStringSync();
    final guard = File(
      '../../scripts/check_frontend_architecture.py',
    ).readAsStringSync();

    expect(repository, contains('WatchPartyRepository'));
    expect(repository, contains('/realtime/watch-party/command'));
    expect(repository, contains('expected_revision'));
    expect(coordinator, contains('ignoreDriftMs = 250'));
    expect(coordinator, contains('largeDriftMs = 1500'));
    expect(adapter, contains('WatchProviderAdapter'));
    expect(adapter, contains('WatchProviderCapabilities'));
    expect(adapter, contains('LiveWatchProviderAdapter'));
    expect(adapter, contains('ExternalWatchProviderAdapter'));
    expect(youtubeAdapter, contains('implements WatchProviderAdapter'));
    expect(youtubeAdapter, contains("providerId => 'youtube'"));

    for (final providerAdapter in <String>[
      netflixAdapter,
      primeAdapter,
      hotstarAdapter,
    ]) {
      expect(providerAdapter, contains('SupportedWebPlaybackAdapter'));
      expect(providerAdapter, isNot(contains('WatchPartyRepository')));
      expect(providerAdapter, isNot(contains('WebSocketChannel')));
    }

    expect(ottAdapter, contains('OttRuntimeMode'));
    expect(ottAdapter, contains('CompanionPlaybackAdapter'));
    expect(ottHost, contains('InAppWebViewOttPlaybackHost'));
    expect(ottHost, isNot(contains('WatchPartyRepository')));
    expect(roomRouter, contains('watchPartyRepositoryProvider'));
    expect(repository, isNot(contains('WebSocketChannel')));
    expect(coordinator, isNot(contains('YoutubePlayerController')));
    expect(coordinator, isNot(contains('netflix')));
    expect(coordinator, isNot(contains('prime_video')));
    expect(coordinator, isNot(contains('jiohotstar')));
    expect(youtubeAdapter, isNot(contains('WatchPartyRepository')));
    expect(guard, contains('APP / "watch_party"'));
  });

  test('OTT integration does not contain protected-provider bypasses', () {
    final roots = <File>[
      File('lib/watch_party/providers/web/html5_video_playback_driver.dart'),
      File('lib/watch_party/providers/web/ott_web_playback_host.dart'),
      File('lib/watch_party/providers/web/supported_web_playback_adapter.dart'),
      File('lib/watch_party/providers/netflix/netflix_provider_adapter.dart'),
      File(
        'lib/watch_party/providers/prime_video/'
        'prime_video_provider_adapter.dart',
      ),
      File(
        'lib/watch_party/providers/jiohotstar/'
        'jiohotstar_provider_adapter.dart',
      ),
    ];
    final combined = roots.map((file) => file.readAsStringSync()).join('\n');

    expect(combined, isNot(contains('window.netflix.appContext')));
    expect(combined, isNot(contains('document.cookie')));
    expect(combined, isNot(contains('licenseRequest')));
    expect(combined, isNot(contains('widevine')));
    expect(combined, isNot(contains('providerPassword')));
    expect(combined, isNot(contains('eval(')));
  });
}
