import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/games/application/game_discovery_ranker.dart';
import 'package:vibematch_app/features/games/data/game_api_service.dart';

GameDefinition game(String key, String name) {
  return GameDefinition(
    gameKey: key,
    displayName: name,
    category: 'party',
    isEnabled: true,
    isCoinGame: false,
    minAppVersion: '1.0.0',
    configVersion: 1,
    cdnBaseUrl: 'https://cdn.example.com/$key/',
    configUrl: null,
    assetManifestUrl: 'https://cdn.example.com/$key/manifest.json',
    uiConfig: const <String, dynamic>{},
    rules: const <String, dynamic>{},
    risk: const <String, dynamic>{},
  );
}

void main() {
  test('recent games rank before recommendations without changing catalog data', () {
    final ranked = rankGameCatalog(
      <GameDefinition>[
        game('alpha', 'Alpha'),
        game('beta', 'Beta'),
        game('gamma', 'Gamma'),
      ],
      recentGameIds: const <String>['gamma'],
      recommendedGameIds: const <String>['beta'],
    );

    expect(
      ranked.map((item) => item.gameKey).toList(),
      const <String>['gamma', 'beta', 'alpha'],
    );
  });

  test('recommendations fall back to stable display-name order', () {
    final ranked = rankGameCatalog(
      <GameDefinition>[
        game('zeta', 'Zeta'),
        game('alpha', 'Alpha'),
        game('beta', 'Beta'),
      ],
      recentGameIds: const <String>[],
      recommendedGameIds: const <String>['beta'],
    );

    expect(
      ranked.map((item) => item.gameKey).toList(),
      const <String>['beta', 'alpha', 'zeta'],
    );
  });
}
