import '../domain/game_manifest.dart';

class GameBundleCache {
  final Map<String, VerifiedGameBundle> _entries =
      <String, VerifiedGameBundle>{};

  VerifiedGameBundle? get(GameManifest manifest) => _entries[manifest.cacheKey];

  VerifiedGameBundle? latestFor({
    required String gameId,
    required int configVersion,
  }) {
    for (final bundle in _entries.values) {
      if (bundle.manifest.gameId == gameId &&
          bundle.manifest.configVersion == configVersion) {
        return bundle;
      }
    }
    return null;
  }

  void put(VerifiedGameBundle bundle) {
    _entries
      ..removeWhere(
        (_, existing) => existing.manifest.gameId == bundle.manifest.gameId,
      )
      ..[bundle.manifest.cacheKey] = bundle;
  }

  void invalidateGame(String gameId) {
    _entries.removeWhere((_, bundle) => bundle.manifest.gameId == gameId);
  }

  void clear() => _entries.clear();
}
