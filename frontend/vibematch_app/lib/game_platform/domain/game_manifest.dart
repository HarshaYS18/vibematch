import 'dart:collection';

class GameCatalogEntry {
  const GameCatalogEntry({
    required this.gameKey,
    required this.displayName,
    required this.enabled,
    required this.coinGame,
    required this.minAppVersion,
    required this.configVersion,
    required this.cdnBaseUri,
    required this.assetManifestUri,
  });

  final String gameKey;
  final String displayName;
  final bool enabled;
  final bool coinGame;
  final String minAppVersion;
  final int configVersion;
  final Uri? cdnBaseUri;
  final Uri? assetManifestUri;

  factory GameCatalogEntry.fromJson(Map<String, dynamic> json) {
    return GameCatalogEntry(
      gameKey: _requiredText(json['game_key'], 'game_key'),
      displayName: _requiredText(json['display_name'], 'display_name'),
      enabled: json['is_enabled'] == true,
      coinGame: json['is_coin_game'] == true,
      minAppVersion: _requiredText(
        json['min_app_version'] ?? '1.0.0',
        'min_app_version',
      ),
      configVersion: _positiveInt(json['config_version'], 'config_version'),
      cdnBaseUri: _optionalHttpsUri(json['cdn_base_url'], 'cdn_base_url'),
      assetManifestUri: _optionalHttpsUri(
        json['asset_manifest_url'],
        'asset_manifest_url',
      ),
    );
  }
}

class GameManifest {
  const GameManifest({
    required this.schemaVersion,
    required this.gameId,
    required this.configVersion,
    required this.bridgeVersion,
    required this.bundleFormat,
    required this.entryUri,
    required this.entrySha256,
    required this.allowedOrigins,
  });

  static const int supportedSchemaVersion = 1;
  static const int supportedBridgeVersion = 1;
  static const String supportedBundleFormat = 'single_html';

  final int schemaVersion;
  final String gameId;
  final int configVersion;
  final int bridgeVersion;
  final String bundleFormat;
  final Uri entryUri;
  final String entrySha256;
  final Set<String> allowedOrigins;

  String get cacheKey => '$gameId:$configVersion:$entrySha256';

  factory GameManifest.fromJson(
    Map<String, dynamic> json, {
    required Uri manifestUri,
    required GameCatalogEntry catalog,
  }) {
    if (manifestUri.scheme.toLowerCase() != 'https') {
      throw const GameManifestException('Game manifest URL must use HTTPS.');
    }

    final schemaVersion = _positiveInt(json['schema_version'], 'schema_version');
    if (schemaVersion != supportedSchemaVersion) {
      throw GameManifestException(
        'Unsupported game manifest schema version $schemaVersion.',
      );
    }

    final gameId = _requiredText(json['game_id'], 'game_id');
    if (gameId != catalog.gameKey) {
      throw GameManifestException(
        'Manifest game_id "$gameId" does not match catalog game "${catalog.gameKey}".',
      );
    }

    final configVersion = _positiveInt(json['config_version'], 'config_version');
    if (configVersion != catalog.configVersion) {
      throw GameManifestException(
        'Manifest config version $configVersion does not match catalog version ${catalog.configVersion}.',
      );
    }

    final bridgeVersion = _positiveInt(json['bridge_version'], 'bridge_version');
    if (bridgeVersion != supportedBridgeVersion) {
      throw GameManifestException(
        'Unsupported game bridge version $bridgeVersion.',
      );
    }

    final bundleFormat =
        _requiredText(json['bundle_format'], 'bundle_format').toLowerCase();
    if (bundleFormat != supportedBundleFormat) {
      throw GameManifestException(
        'Unsupported game bundle format "$bundleFormat".',
      );
    }

    final rawEntryUrl = _optionalText(json['entry_url']);
    final rawEntryPath = _optionalText(json['entry_path']);
    if (rawEntryUrl == null && rawEntryPath == null) {
      throw const GameManifestException(
        'Game manifest must provide entry_url or entry_path.',
      );
    }

    final Uri entryUri;
    if (rawEntryUrl != null) {
      entryUri = manifestUri.resolve(rawEntryUrl);
    } else {
      final base = catalog.cdnBaseUri ?? manifestUri.resolve('.');
      entryUri = base.resolve(rawEntryPath!);
    }
    if (entryUri.scheme.toLowerCase() != 'https' || entryUri.host.isEmpty) {
      throw const GameManifestException(
        'Game entry URL must be an absolute HTTPS URL.',
      );
    }

    final sha = _requiredText(json['entry_sha256'], 'entry_sha256').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
      throw const GameManifestException(
        'entry_sha256 must be a lowercase SHA-256 hex digest.',
      );
    }

    final origins = <String>{};
    final rawOrigins = json['allowed_origins'];
    if (rawOrigins is List) {
      for (final item in rawOrigins) {
        final text = item?.toString().trim();
        if (text == null || text.isEmpty) continue;
        final uri = Uri.tryParse(text);
        if (uri == null ||
            uri.scheme.toLowerCase() != 'https' ||
            uri.host.isEmpty ||
            (uri.path.isNotEmpty && uri.path != '/') ||
            uri.hasQuery ||
            uri.hasFragment) {
          throw GameManifestException('Invalid allowed game origin "$text".');
        }
        origins.add(originOf(uri));
      }
    }
    origins.add(originOf(entryUri));
    origins.add(originOf(manifestUri));

    return GameManifest(
      schemaVersion: schemaVersion,
      gameId: gameId,
      configVersion: configVersion,
      bridgeVersion: bridgeVersion,
      bundleFormat: bundleFormat,
      entryUri: entryUri,
      entrySha256: sha,
      allowedOrigins: UnmodifiableSetView<String>(origins),
    );
  }

  bool allowsNavigation(Uri uri) {
    if (uri.scheme == 'about') return uri.toString() == 'about:blank';
    if (uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) return false;
    return allowedOrigins.contains(originOf(uri));
  }

  static String originOf(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final defaultPort = switch (scheme) {
      'https' => 443,
      'http' => 80,
      _ => 0,
    };
    final port = uri.port;
    final portSuffix = port == 0 || port == defaultPort ? '' : ':$port';
    return '$scheme://$host$portSuffix';
  }
}

class VerifiedGameBundle {
  const VerifiedGameBundle({
    required this.catalog,
    required this.manifest,
    required this.html,
  });

  final GameCatalogEntry catalog;
  final GameManifest manifest;
  final String html;
}

class GameManifestException implements Exception {
  const GameManifestException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _requiredText(dynamic value, String field) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    throw GameManifestException('Missing required field "$field".');
  }
  return text;
}

String? _optionalText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _positiveInt(dynamic value, String field) {
  final parsed = switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text),
    _ => null,
  };
  if (parsed == null || parsed <= 0) {
    throw GameManifestException('Field "$field" must be a positive integer.');
  }
  return parsed;
}

Uri? _optionalHttpsUri(dynamic value, String field) {
  final text = _optionalText(value);
  if (text == null) return null;
  final uri = Uri.tryParse(text);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty) {
    throw GameManifestException('$field must be an absolute HTTPS URL.');
  }
  return uri;
}
