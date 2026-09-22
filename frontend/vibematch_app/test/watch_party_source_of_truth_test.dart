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
    expect(youtubeAdapter, contains('implements WatchProviderAdapter'));
    expect(youtubeAdapter, contains("providerId => 'youtube'"));
    expect(repository, isNot(contains('WebSocketChannel')));
    expect(coordinator, isNot(contains('YoutubePlayerController')));
    expect(coordinator, isNot(contains('netflix')));
    expect(youtubeAdapter, isNot(contains('WatchPartyRepository')));
    expect(guard, contains('APP / "watch_party"'));
  });
}
