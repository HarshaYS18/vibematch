import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../foundation/di/app_dependencies.dart';
import '../../foundation/networking/app_network_client.dart';
import '../../foundation/networking/remote_asset_client.dart';
import '../domain/game_manifest.dart';
import 'game_bundle_cache.dart';

const int maxRemoteGameBundleBytes = 5 * 1024 * 1024;

final remoteGameAssetClientProvider = Provider<RemoteAssetClient>((ref) {
  final client = HttpRemoteAssetClient();
  ref.onDispose(client.close);
  return client;
});

final gameBundleCacheProvider = Provider<GameBundleCache>(
  (ref) => GameBundleCache(),
);

final gameManifestRepositoryProvider = Provider<GameManifestRepository>((ref) {
  return GameManifestRepository(
    api: ref.watch(appNetworkClientProvider),
    assets: ref.watch(remoteGameAssetClientProvider),
    cache: ref.watch(gameBundleCacheProvider),
  );
});

class GameManifestRepository {
  const GameManifestRepository({
    required AppNetworkClient api,
    required RemoteAssetClient assets,
    required GameBundleCache cache,
  }) : _api = api,
       _assets = assets,
       _cache = cache;

  final AppNetworkClient _api;
  final RemoteAssetClient _assets;
  final GameBundleCache _cache;

  Future<VerifiedGameBundle> load(String gameId) async {
    final normalizedGameId = gameId.trim();
    if (normalizedGameId.isEmpty) {
      throw const GameManifestException('Game id is required.');
    }

    final catalogJson = await _api.getMap(
      '/games/catalog/${Uri.encodeComponent(normalizedGameId)}',
    );
    final catalog = GameCatalogEntry.fromJson(catalogJson);
    if (!catalog.enabled) {
      _cache.invalidateGame(catalog.gameKey);
      throw GameManifestException(
        'Game "${catalog.displayName}" is currently disabled.',
      );
    }

    final manifestUri = catalog.assetManifestUri;
    if (manifestUri == null) {
      _cache.invalidateGame(catalog.gameKey);
      throw GameManifestException(
        'Game "${catalog.displayName}" is not configured for remote delivery.',
      );
    }

    final manifestBytes = await _assets.getBytes(manifestUri);
    final manifestJson = _decodeJsonMap(
      manifestBytes,
      label: 'game manifest',
    );
    final manifest = GameManifest.fromJson(
      manifestJson,
      manifestUri: manifestUri,
      catalog: catalog,
    );

    final cached = _cache.get(manifest);
    if (cached != null) return cached;

    final bundleBytes = await _assets.getBytes(manifest.entryUri);
    if (bundleBytes.isEmpty) {
      throw const GameManifestException('Remote game bundle is empty.');
    }
    if (bundleBytes.length > maxRemoteGameBundleBytes) {
      throw GameManifestException(
        'Remote game bundle exceeds the ${maxRemoteGameBundleBytes ~/ (1024 * 1024)} MiB limit.',
      );
    }

    final actualSha = sha256.convert(bundleBytes).toString();
    if (actualSha != manifest.entrySha256) {
      throw const GameManifestException(
        'Remote game bundle failed integrity verification.',
      );
    }

    final html = _decodeUtf8(bundleBytes, label: 'game bundle');
    _validateSingleHtmlBundle(html);

    final verified = VerifiedGameBundle(
      catalog: catalog,
      manifest: manifest,
      html: html,
    );
    _cache.put(verified);
    return verified;
  }

  Map<String, dynamic> _decodeJsonMap(
    Uint8List bytes, {
    required String label,
  }) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Normalized below so callers never need transport/parser details.
    }
    throw GameManifestException('Invalid $label JSON.');
  }

  String _decodeUtf8(Uint8List bytes, {required String label}) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      throw GameManifestException('Invalid UTF-8 $label.');
    }
  }

  void _validateSingleHtmlBundle(String html) {
    final normalized = html.toLowerCase();
    if (!normalized.contains('<html') && !normalized.contains('<!doctype html')) {
      throw const GameManifestException(
        'Remote game bundle must be a complete HTML document.',
      );
    }

    final forbidden = <RegExp>[
      RegExp(r'<script\b[^>]*\bsrc\s*=', caseSensitive: false),
      RegExp(r'<iframe\b', caseSensitive: false),
      RegExp(r'<object\b', caseSensitive: false),
      RegExp(r'<embed\b', caseSensitive: false),
    ];
    if (forbidden.any((pattern) => pattern.hasMatch(html))) {
      throw const GameManifestException(
        'Remote game bundle contains unsupported executable dependencies.',
      );
    }
  }
}
