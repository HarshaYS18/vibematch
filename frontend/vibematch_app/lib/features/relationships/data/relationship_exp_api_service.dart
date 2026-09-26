import 'dart:convert';

import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_local_storage.dart';

class RelationshipExpApiService {
  const RelationshipExpApiService();

  Future<RelationshipExpMaster> getMaster() async {
    final json = await _getMap('/relationships/master');
    return RelationshipExpMaster.fromJson(json);
  }

  Future<RelationshipExpSummary> getMySummary() async {
    final json = await _getMap('/relationships/me/summary');
    return RelationshipExpSummary.fromJson(json);
  }

  Future<RelationshipExpSummary> getUserSummary({required int publicUserId}) async {
    final json = await _getMap('/relationships/users/$publicUserId/summary');
    return RelationshipExpSummary.fromJson(json);
  }

  Future<RelationshipPairSummary> getPairSummary({
    required int otherPublicUserId,
  }) async {
    final json = await _getMap('/relationships/pairs/$otherPublicUserId/summary');
    return RelationshipPairSummary.fromJson(json);
  }

  Future<List<RelationshipRankingEntry>> getRankings({
    RelationshipRankingPeriod period = RelationshipRankingPeriod.weekly,
    int limit = 100,
  }) async {
    final json = await _getMap(
      '/relationships/rankings?period=${period.backendValue}&limit=${limit.clamp(1, 100)}',
    );
    final entries = json['entries'] ?? json['rankings'] ?? json['items'];
    if (entries is! List) return const <RelationshipRankingEntry>[];
    return entries
        .whereType<Map>()
        .map((item) => RelationshipRankingEntry.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<List<RelationshipExpHistoryEntry>> getHistory({
    int limit = 50,
    int? otherPublicUserId,
  }) async {
    final suffix = otherPublicUserId == null ? '' : '&other_public_user_id=$otherPublicUserId';
    final json = await _getMap('/relationships/me/history?limit=${limit.clamp(1, 100)}$suffix');
    final entries = json['entries'] ?? json['history'] ?? json['items'];
    if (entries is! List) return const <RelationshipExpHistoryEntry>[];
    return entries
        .whereType<Map>()
        .map((item) => RelationshipExpHistoryEntry.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<RelationshipExpGainResult> recordExpEvent({
    required String eventType,
    required int otherPublicUserId,
    int exp = 0,
    int coinValue = 0,
    String? roomPublicId,
  }) async {
    final body = <String, dynamic>{
      'event_type': eventType,
      'other_public_user_id': otherPublicUserId,
      'exp': exp,
      'coin_value': coinValue,
    };
    final cleanRoomId = roomPublicId?.trim();
    if (cleanRoomId != null && cleanRoomId.isNotEmpty) {
      body['room_public_id'] = cleanRoomId;
    }
    final json = await _postMap('/relationships/exp/events', body: body);
    return RelationshipExpGainResult.fromJson(json);
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint(path)),
      headers: await _headers(),
    );
    return _decodeMap(response, 'GET $path');
  }

  Future<Map<String, dynamic>> _postMap(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint(path)),
      headers: <String, String>{
        ...await _headers(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    return _decodeMap(response, 'POST $path');
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

enum RelationshipRankingPeriod {
  daily,
  weekly,
  monthly;

  String get label {
    switch (this) {
      case RelationshipRankingPeriod.daily:
        return 'Today';
      case RelationshipRankingPeriod.weekly:
        return 'This week';
      case RelationshipRankingPeriod.monthly:
        return 'This month';
    }
  }

  String get backendValue {
    switch (this) {
      case RelationshipRankingPeriod.daily:
        return 'daily';
      case RelationshipRankingPeriod.weekly:
        return 'weekly';
      case RelationshipRankingPeriod.monthly:
        return 'monthly';
    }
  }
}

class RelationshipExpMaster {
  const RelationshipExpMaster({
    required this.enabled,
    required this.maxLevel,
    required this.rules,
  });

  final bool enabled;
  final int maxLevel;
  final Map<String, dynamic> rules;

  factory RelationshipExpMaster.fromJson(Map<String, dynamic> json) {
    return RelationshipExpMaster(
      enabled: _bool(json['enabled'], fallback: true),
      maxLevel: _int(json['max_level']) <= 0 ? 100 : _int(json['max_level']),
      rules: _map(json['rules']),
    );
  }
}

class RelationshipExpSummary {
  const RelationshipExpSummary({
    required this.publicUserId,
    required this.totalExp,
    required this.level,
    required this.nextLevelExp,
    required this.progress,
    required this.bestPair,
  });

  final int publicUserId;
  final int totalExp;
  final int level;
  final int nextLevelExp;
  final double progress;
  final RelationshipPairUser? bestPair;

  factory RelationshipExpSummary.fromJson(Map<String, dynamic> json) {
    final summary = _map(json['summary']).isEmpty ? json : _map(json['summary']);
    final bestPair = summary['best_pair'] ?? json['best_pair'];
    return RelationshipExpSummary(
      publicUserId: _int(summary['public_user_id']),
      totalExp: _int(summary['total_exp'] ?? summary['exp']),
      level: _int(summary['level']) <= 0 ? 1 : _int(summary['level']),
      nextLevelExp: _int(summary['next_level_exp']),
      progress: _progress(summary['progress'] ?? summary['progress_ratio']),
      bestPair: bestPair == null ? null : RelationshipPairUser.fromJson(_map(bestPair)),
    );
  }
}

class RelationshipPairSummary {
  const RelationshipPairSummary({
    required this.pairId,
    required this.totalExp,
    required this.level,
    required this.progress,
    required this.currentUser,
    required this.otherUser,
  });

  final String pairId;
  final int totalExp;
  final int level;
  final double progress;
  final RelationshipPairUser? currentUser;
  final RelationshipPairUser? otherUser;

  factory RelationshipPairSummary.fromJson(Map<String, dynamic> json) {
    final pair = _map(json['pair']).isEmpty ? json : _map(json['pair']);
    final current = pair['current_user'] ?? json['current_user'];
    final other = pair['other_user'] ?? json['other_user'];
    return RelationshipPairSummary(
      pairId: _string(pair['id'] ?? pair['pair_id'], fallback: ''),
      totalExp: _int(pair['total_exp'] ?? pair['exp']),
      level: _int(pair['level']) <= 0 ? 1 : _int(pair['level']),
      progress: _progress(pair['progress'] ?? pair['progress_ratio']),
      currentUser: current == null ? null : RelationshipPairUser.fromJson(_map(current)),
      otherUser: other == null ? null : RelationshipPairUser.fromJson(_map(other)),
    );
  }
}

class RelationshipPairUser {
  const RelationshipPairUser({
    required this.publicUserId,
    required this.displayName,
    required this.avatarUrl,
  });

  final int publicUserId;
  final String displayName;
  final String? avatarUrl;

  factory RelationshipPairUser.fromJson(Map<String, dynamic> json) {
    return RelationshipPairUser(
      publicUserId: _int(json['public_user_id'] ?? json['id']),
      displayName: _string(json['display_name'] ?? json['username'] ?? json['name'], fallback: 'Vibe User'),
      avatarUrl: _nullableString(json['avatar_url']),
    );
  }
}

class RelationshipRankingEntry {
  const RelationshipRankingEntry({
    required this.rank,
    required this.score,
    required this.pair,
  });

  final int rank;
  final int score;
  final RelationshipPairSummary pair;

  factory RelationshipRankingEntry.fromJson(Map<String, dynamic> json) {
    return RelationshipRankingEntry(
      rank: _int(json['rank']),
      score: _int(json['score'] ?? json['total_exp']),
      pair: RelationshipPairSummary.fromJson(_map(json['pair']).isEmpty ? json : _map(json['pair'])),
    );
  }
}

class RelationshipExpHistoryEntry {
  const RelationshipExpHistoryEntry({
    required this.id,
    required this.eventType,
    required this.expDelta,
    required this.description,
    required this.createdAt,
  });

  final int id;
  final String eventType;
  final int expDelta;
  final String description;
  final DateTime? createdAt;

  factory RelationshipExpHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RelationshipExpHistoryEntry(
      id: _int(json['id']),
      eventType: _string(json['event_type'] ?? json['type'], fallback: 'relationship'),
      expDelta: _int(json['exp_delta'] ?? json['exp'] ?? json['score']),
      description: _string(json['description'] ?? json['title'], fallback: 'Relationship activity'),
      createdAt: _date(json['created_at'] ?? json['createdAt']),
    );
  }
}

class RelationshipExpGainResult {
  const RelationshipExpGainResult({
    required this.status,
    required this.summary,
    required this.pair,
  });

  final String status;
  final RelationshipExpSummary? summary;
  final RelationshipPairSummary? pair;

  factory RelationshipExpGainResult.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];
    final pair = json['pair'];
    return RelationshipExpGainResult(
      status: _string(json['status'], fallback: 'ok'),
      summary: summary == null ? null : RelationshipExpSummary.fromJson(_map(summary)),
      pair: pair == null ? null : RelationshipPairSummary.fromJson(_map(pair)),
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

double _progress(Object? value) {
  double parsed = 0;
  if (value is num) parsed = value.toDouble();
  if (value is String) parsed = double.tryParse(value) ?? 0;
  if (parsed > 1) parsed = parsed / 100;
  return parsed.clamp(0, 1).toDouble();
}

DateTime? _date(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}
