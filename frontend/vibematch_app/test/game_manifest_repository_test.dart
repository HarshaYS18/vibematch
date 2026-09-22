import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/foundation/networking/app_network_client.dart';
import 'package:vibematch_app/foundation/networking/remote_asset_client.dart';
import 'package:vibematch_app/game_platform/data/game_bundle_cache.dart';
import 'package:vibematch_app/game_platform/data/game_manifest_repository.dart';
import 'package:vibematch_app/game_platform/domain/game_manifest.dart';

void main() {
  const html = '<!doctype html><html><head></head><body>FunKey</body></html>';
  final htmlBytes = Uint8List.fromList(utf8.encode(html));
  final htmlSha = sha256.convert(htmlBytes).toString();
  final manifestUri = Uri.parse(
    'https://cdn.example.com/games/jungle-hunt/manifest.json',
  );
  final entryUri = Uri.parse(
    'https://cdn.example.com/games/jungle-hunt/index.html',
  );

  Map<String, dynamic> catalog() => <String, dynamic>{
    'game_key': 'jungle_hunt',
    'display_name': 'Jungle Hunt',
    'category': 'coin',
    'is_enabled': true,
    'is_coin_game': true,
    'min_app_version': '1.0.0',
    'config_version': 11,
    'cdn_base_url': 'https://cdn.example.com/games/jungle-hunt/',
    'asset_manifest_url': manifestUri.toString(),
  };

  Uint8List manifestBytes({String? sha}) => Uint8List.fromList(
    utf8.encode(
      jsonEncode(<String, dynamic>{
        'schema_version': 1,
        'game_id': 'jungle_hunt',
        'config_version': 11,
        'bridge_version': 1,
        'bundle_format': 'single_html',
        'entry_path': 'index.html',
        'entry_sha256': sha ?? htmlSha,
      }),
    ),
  );

  test('verifies and caches a remote game bundle', () async {
    final api = _FakeNetworkClient(catalog());
    final assets = _FakeRemoteAssetClient(<Uri, Uint8List>{
      manifestUri: manifestBytes(),
      entryUri: htmlBytes,
    });
    final repository = GameManifestRepository(
      api: api,
      assets: assets,
      cache: GameBundleCache(),
    );

    final first = await repository.load('jungle_hunt');
    final second = await repository.load('jungle_hunt');

    expect(first.html, html);
    expect(second.manifest.cacheKey, first.manifest.cacheKey);
    expect(assets.requests.where((uri) => uri == entryUri), hasLength(1));
  });

  test('rejects a bundle that does not match its SHA-256', () async {
    final repository = GameManifestRepository(
      api: _FakeNetworkClient(catalog()),
      assets: _FakeRemoteAssetClient(<Uri, Uint8List>{
        manifestUri: manifestBytes(
          sha: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ),
        entryUri: htmlBytes,
      }),
      cache: GameBundleCache(),
    );

    await expectLater(
      repository.load('jungle_hunt'),
      throwsA(isA<GameManifestException>()),
    );
  });

  test('rejects external executable dependencies', () async {
    const unsafeHtml =
        '<!doctype html><html><head><script src="https://x.test/a.js"></script></head></html>';
    final unsafeBytes = Uint8List.fromList(utf8.encode(unsafeHtml));
    final repository = GameManifestRepository(
      api: _FakeNetworkClient(catalog()),
      assets: _FakeRemoteAssetClient(<Uri, Uint8List>{
        manifestUri: manifestBytes(
          sha: sha256.convert(unsafeBytes).toString(),
        ),
        entryUri: unsafeBytes,
      }),
      cache: GameBundleCache(),
    );

    await expectLater(
      repository.load('jungle_hunt'),
      throwsA(isA<GameManifestException>()),
    );
  });
}

class _FakeNetworkClient implements AppNetworkClient {
  _FakeNetworkClient(this.catalog);

  final Map<String, dynamic> catalog;

  @override
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
  }) async {
    if (path == '/games/catalog/jungle_hunt') return catalog;
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<List<dynamic>> getList(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
  }) async => throw StateError('Unexpected getList $path');

  @override
  Future<Map<String, dynamic>> postMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) async => throw StateError('Unexpected POST $path');

  @override
  Future<Map<String, dynamic>> patchMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) async => throw StateError('Unexpected PATCH $path');

  @override
  Future<Map<String, dynamic>> deleteMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) async => throw StateError('Unexpected DELETE $path');

  @override
  void close() {}
}

class _FakeRemoteAssetClient implements RemoteAssetClient {
  _FakeRemoteAssetClient(this.responses);

  final Map<Uri, Uint8List> responses;
  final List<Uri> requests = <Uri>[];

  @override
  Future<Uint8List> getBytes(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    requests.add(uri);
    final bytes = responses[uri];
    if (bytes == null) throw StateError('Unexpected asset $uri');
    return bytes;
  }

  @override
  void close() {}
}
