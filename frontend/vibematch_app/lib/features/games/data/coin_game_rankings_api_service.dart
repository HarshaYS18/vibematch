import 'dart:convert';

import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_local_storage.dart';

class CoinGameRankingsApiService {
  const CoinGameRankingsApiService();

  Future<CoinGameMaster> getMaster() async {
    final json = await _getMap('/games/master');
    return CoinGameMaster.fromJson(json);
  }

  Future<List<CoinGameInfo>> getGames() async {
    final json = await _getMap('/games');
    final items = json['games'] ?? json['items'] ?? json['entries'];
    if (items is! List) return const <CoinGameInfo>[];
    return items
        .whereType<Map>()
        .map((item) => CoinGameInfo.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<List<CoinGameRankingEntry>> getRankings({
    required String gameId,
    CoinGameRankingType type = CoinGameRankingType.winnings,
    CoinGameRankingPeriod period = CoinGameRankingPeriod.daily,
    int limit = 100,
  }) async {
    final cleanGameId = gameId.trim();
    final json = await _getMap(
      '/games/$cleanGameId/rankings/${type.backendValue}?period=${period.backendValue}&limit=${limit.clamp(1, 100)}',
    );
    final entries = json['entries'] ?? json['rankings'] ?? json['items'];
    if (entries is! List) return const <CoinGameRankingEntry>[];
    return entries
        .whereType<Map>()
        .map((item) => CoinGameRankingEntry.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint(path)),
      headers: await _headers(),
    );
    return _decodeMap(response, 'GET $path');
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthLocalStorage().getAccessToken();
    return <String, String>{
      'Accept': 'application/json',
      if (token != null && token.trim().isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeMap(http.Response response, String label) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$label failed (${response.statusCode}): ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return const <String, dynamic>{};
  }
}

enum CoinGameRankingPeriod {
  daily,
  weekly,
  monthly;

  String get label {
    switch (this) {
      case CoinGameRankingPeriod.daily:
        return 'Today';
      case CoinGameRankingPeriod.weekly:
        return 'This week';
      case CoinGameRankingPeriod.monthly:
        return 'This month';
    }
  }

  String get backendValue {
    switch (this) {
      case CoinGameRankingPeriod.daily:
        return 'daily';
      case CoinGameRankingPeriod.weekly:
        return 'weekly';
      case CoinGameRankingPeriod.monthly:
        return 'monthly';
    }
  }
}

enum CoinGameRankingType {
  winnings,
  bidding,
  losses;

  String get label {
    switch (this) {
      case CoinGameRankingType.winnings:
        return 'Winnings';
      case CoinGameRankingType.bidding:
        return 'Bidding';
      case CoinGameRankingType.losses:
        return 'Losses';
    }
  }

  String get backendValue {
    switch (this) {
      case CoinGameRankingType.winnings:
        return 'winnings';
      case CoinGameRankingType.bidding:
        return 'bidding';
      case CoinGameRankingType.losses:
        return 'losses';
    }
  }
}

class CoinGameMaster {
  const CoinGameMaster({required this.enabled, required this.games, required this.raw});

  final bool enabled;
  final List<CoinGameInfo> games;
  final Map<String, dynamic> raw;

  factory CoinGameMaster.fromJson(Map<String, dynamic> json) {
    final items = json['games'];
    return CoinGameMaster(
      enabled: _bool(json['enabled'], fallback: true),
      games: items is List
          ? items
              .whereType<Map>()
              .map((item) => CoinGameInfo.fromJson(item.cast<String, dynamic>()))
              .toList(growable: false)
          : const <CoinGameInfo>[],
      raw: json,
    );
  }
}

class CoinGameInfo {
  const CoinGameInfo({
    required this.id,
    required this.name,
    required this.enabled,
  });

  final String id;
  final String name;
  final bool enabled;

  factory CoinGameInfo.fromJson(Map<String, dynamic> json) {
    return CoinGameInfo(
      id: _string(json['id'] ?? json['game_id'] ?? json['key'], fallback: ''),
      name: _string(json['name'] ?? json['title'], fallback: 'Coin Game'),
      enabled: _bool(json['enabled'], fallback: true),
    );
  }
}

class CoinGameRankingEntry {
  const CoinGameRankingEntry({
    required this.rank,
    required this.publicUserId,
    required this.displayName,
    required this.avatarUrl,
    required this.score,
    required this.rounds,
  });

  final int rank;
  final int publicUserId;
  final String displayName;
  final String? avatarUrl;
  final int score;
  final int rounds;

  factory CoinGameRankingEntry.fromJson(Map<String, dynamic> json) {
    final user = _map(json['user']).isEmpty ? json : _map(json['user']);
    return CoinGameRankingEntry(
      rank: _int(json['rank']),
      publicUserId: _int(user['public_user_id'] ?? user['id']),
      displayName: _string(user['display_name'] ?? user['username'] ?? json['display_name'], fallback: 'Vibe User'),
      avatarUrl: _nullableString(user['avatar_url'] ?? json['avatar_url']),
      score: _int(json['score'] ?? json['amount'] ?? json['coins']),
      rounds: _int(json['rounds'] ?? json['count']),
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _string(Object? value, {required String fallback}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool _bool(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
  }
  return fallback;
}
