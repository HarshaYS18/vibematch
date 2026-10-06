import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_api_service.dart';

class RecentGamesStore {
  RecentGamesStore({AuthApiService? authApiService})
      : _authApiService = authApiService ?? const AuthApiService();

  static const int _maxItems = 12;
  static const String _keyPrefix = 'funkey_recent_games_v1';

  final AuthApiService _authApiService;

  String get _key {
    final publicUserId = _authApiService.cachedUser?.publicUserId.toString();
    return '$_keyPrefix:${publicUserId ?? 'anonymous'}';
  }

  Future<List<String>> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getStringList(_key) ?? const <String>[];
      return raw
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .take(_maxItems)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> record(String gameId) async {
    final clean = gameId.trim();
    if (clean.isEmpty) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      final current = preferences.getStringList(_key) ?? const <String>[];
      final next = <String>[
        clean,
        ...current.where((item) => item.trim() != clean),
      ].take(_maxItems).toList(growable: false);
      await preferences.setStringList(_key, next);
    } catch (_) {
      // Recent-game ranking is convenience state, never gameplay authority.
    }
  }
}
