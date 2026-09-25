import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/app/runtime/game_bundle_cache_resource_participant.dart';
import 'package:vibematch_app/app/runtime/media_resource_coordinator.dart';
import 'package:vibematch_app/game_platform/data/game_bundle_cache.dart';
import 'package:vibematch_app/game_platform/domain/game_manifest.dart';

/// Chunk 34-M4 behavioral coverage for verified game-bundle cache lifecycle.
void main() {
  test('exposes stable reconstructable game-cache resource identity', () {
    final cache = GameBundleCache();
    final participant = GameBundleCacheResourceParticipant(cache: cache);

    expect(participant.resourceId, 'app-shell:verified-game-bundle-cache');
    expect(participant.kind, MediaResourceKind.gameBundleCache);
  });

  test('memory pressure clears verified warm bundles', () async {
    final cache = GameBundleCache();
    final fixture = _bundleFixture();
    cache.put(fixture.bundle);
    final participant = GameBundleCacheResourceParticipant(cache: cache);

    expect(cache.get(fixture.manifest), same(fixture.bundle));

    await participant.onMemoryPressure();

    expect(cache.get(fixture.manifest), isNull);
  });

  test('foreground transitions do not evict passive warm cache', () async {
    final cache = GameBundleCache();
    final fixture = _bundleFixture();
    cache.put(fixture.bundle);
    final participant = GameBundleCacheResourceParticipant(cache: cache);

    await participant.onForegroundChanged(false);
    await participant.onForegroundChanged(true);

    expect(cache.get(fixture.manifest), same(fixture.bundle));
  });

  test('session release clears cache once and makes adapter terminal', () async {
    final cache = GameBundleCache();
    final fixture = _bundleFixture();
    cache.put(fixture.bundle);
    final participant = GameBundleCacheResourceParticipant(cache: cache);

    await participant.release();
    await participant.release();

    expect(cache.get(fixture.manifest), isNull);

    // A released registration must not mutate a newly repopulated cache.
    cache.put(fixture.bundle);
    await participant.onMemoryPressure();
    expect(cache.get(fixture.manifest), same(fixture.bundle));
  });
}

({GameManifest manifest, VerifiedGameBundle bundle}) _bundleFixture() {
  final catalog = GameCatalogEntry(
    gameKey: 'demo-game',
    displayName: 'Demo Game',
    enabled: true,
    coinGame: false,
    minAppVersion: '1.0.0',
    configVersion: 7,
    cdnBaseUri: Uri.parse('https://cdn.example.com/games/demo/'),
    assetManifestUri: Uri.parse(
      'https://cdn.example.com/games/demo/manifest.json',
    ),
  );
  final manifest = GameManifest(
    schemaVersion: GameManifest.supportedSchemaVersion,
    gameId: catalog.gameKey,
    configVersion: catalog.configVersion,
    bridgeVersion: GameManifest.supportedBridgeVersion,
    bundleFormat: GameManifest.supportedBundleFormat,
    entryUri: Uri.parse('https://cdn.example.com/games/demo/index.html'),
    entrySha256: 'a' * 64,
    allowedOrigins: <String>{'https://cdn.example.com'},
  );
  final bundle = VerifiedGameBundle(
    catalog: catalog,
    manifest: manifest,
    html: '<!doctype html><html><body>demo</body></html>',
  );
  return (manifest: manifest, bundle: bundle);
}
