import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/game_platform/domain/game_manifest.dart';

void main() {
  const hash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  GameCatalogEntry catalog({
    String gameKey = 'jungle_hunt',
    int configVersion = 7,
  }) {
    return GameCatalogEntry(
      gameKey: gameKey,
      displayName: 'Jungle Hunt',
      enabled: true,
      coinGame: true,
      minAppVersion: '1.0.0',
      configVersion: configVersion,
      cdnBaseUri: Uri.parse('https://cdn.example.com/games/jungle-hunt/'),
      assetManifestUri: Uri.parse(
        'https://cdn.example.com/games/jungle-hunt/manifest.json',
      ),
    );
  }

  test('parses a versioned HTTPS single-html manifest', () {
    final manifest = GameManifest.fromJson(
      <String, dynamic>{
        'schema_version': 1,
        'game_id': 'jungle_hunt',
        'config_version': 7,
        'bridge_version': 1,
        'bundle_format': 'single_html',
        'entry_path': 'index.html',
        'entry_sha256': hash,
        'allowed_origins': <String>[
          'https://cdn.example.com',
          'https://media.example.com',
        ],
      },
      manifestUri: Uri.parse(
        'https://cdn.example.com/games/jungle-hunt/manifest.json',
      ),
      catalog: catalog(),
    );

    expect(
      manifest.entryUri,
      Uri.parse('https://cdn.example.com/games/jungle-hunt/index.html'),
    );
    expect(manifest.entrySha256, hash);
    expect(manifest.configVersion, 7);
    expect(manifest.bridgeVersion, 1);
    expect(manifest.allowsNavigation(Uri.parse('https://cdn.example.com/a')), isTrue);
    expect(manifest.allowsNavigation(Uri.parse('http://cdn.example.com/a')), isFalse);
    expect(manifest.allowsNavigation(Uri.parse('https://evil.example/a')), isFalse);
  });

  test('rejects a manifest for a different catalog game', () {
    expect(
      () => GameManifest.fromJson(
        <String, dynamic>{
          'schema_version': 1,
          'game_id': 'other_game',
          'config_version': 7,
          'bridge_version': 1,
          'bundle_format': 'single_html',
          'entry_url': 'https://cdn.example.com/index.html',
          'entry_sha256': hash,
        },
        manifestUri: Uri.parse('https://cdn.example.com/manifest.json'),
        catalog: catalog(),
      ),
      throwsA(isA<GameManifestException>()),
    );
  });

  test('rejects catalog/manifest version drift', () {
    expect(
      () => GameManifest.fromJson(
        <String, dynamic>{
          'schema_version': 1,
          'game_id': 'jungle_hunt',
          'config_version': 8,
          'bridge_version': 1,
          'bundle_format': 'single_html',
          'entry_url': 'https://cdn.example.com/index.html',
          'entry_sha256': hash,
        },
        manifestUri: Uri.parse('https://cdn.example.com/manifest.json'),
        catalog: catalog(),
      ),
      throwsA(isA<GameManifestException>()),
    );
  });

  test('rejects non-HTTPS game entry URLs', () {
    expect(
      () => GameManifest.fromJson(
        <String, dynamic>{
          'schema_version': 1,
          'game_id': 'jungle_hunt',
          'config_version': 7,
          'bridge_version': 1,
          'bundle_format': 'single_html',
          'entry_url': 'http://cdn.example.com/index.html',
          'entry_sha256': hash,
        },
        manifestUri: Uri.parse('https://cdn.example.com/manifest.json'),
        catalog: catalog(),
      ),
      throwsA(isA<GameManifestException>()),
    );
  });

  test('rejects malformed SHA-256 digests', () {
    expect(
      () => GameManifest.fromJson(
        <String, dynamic>{
          'schema_version': 1,
          'game_id': 'jungle_hunt',
          'config_version': 7,
          'bridge_version': 1,
          'bundle_format': 'single_html',
          'entry_url': 'https://cdn.example.com/index.html',
          'entry_sha256': 'not-a-hash',
        },
        manifestUri: Uri.parse('https://cdn.example.com/manifest.json'),
        catalog: catalog(),
      ),
      throwsA(isA<GameManifestException>()),
    );
  });
}
