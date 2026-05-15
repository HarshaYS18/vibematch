import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_local_storage.dart';

class GlobalRankingsApiService {
  const GlobalRankingsApiService();

  Future<GlobalRankingResponse> fetchSentRankings({
    GlobalRankingPeriod period = GlobalRankingPeriod.daily,
    int limit = 100,
  }) {
    return _fetchRanking(
      path: '/rankings/sent',
      type: GlobalRankingType.sent,
      period: period,
      limit: limit,
    );
  }

  Future<GlobalRankingResponse> fetchReceivedRankings({
    GlobalRankingPeriod period = GlobalRankingPeriod.daily,
    int limit = 100,
  }) {
    return _fetchRanking(
      path: '/rankings/received',
      type: GlobalRankingType.received,
      period: period,
      limit: limit,
    );
  }

  Future<GlobalRankingResponse> fetchRechargeRankings({
    GlobalRankingPeriod period = GlobalRankingPeriod.daily,
    int limit = 100,
  }) {
    return _fetchRanking(
      path: '/rankings/recharge',
      type: GlobalRankingType.recharge,
      period: period,
      limit: limit,
    );
  }

  Future<GlobalRankingResponse> fetchRanking({
    required GlobalRankingType type,
    GlobalRankingPeriod period = GlobalRankingPeriod.daily,
    int limit = 100,
  }) {
    switch (type) {
      case GlobalRankingType.sent:
        return fetchSentRankings(period: period, limit: limit);
      case GlobalRankingType.received:
        return fetchReceivedRankings(period: period, limit: limit);
      case GlobalRankingType.recharge:
        return fetchRechargeRankings(period: period, limit: limit);
    }
  }

  Future<GlobalRankingResponse> _fetchRanking({
    required String path,
    required GlobalRankingType type,
    required GlobalRankingPeriod period,
    required int limit,
  }) async {
    final token = await AuthLocalStorage().getAccessToken();
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final safeLimit = limit.clamp(1, 100);
    final response = await http.get(
      Uri.parse(
        VmApiConfig.endpoint(
          '$path?period=${period.backendValue}&limit=$safeLimit',
        ),
      ),
      headers: headers,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to load ${type.label} rankings (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return GlobalRankingResponse.empty(type: type, period: period);
    }
    return GlobalRankingResponse.fromJson(decoded, fallbackType: type, fallbackPeriod: period);
  }
}

enum GlobalRankingType {
  sent,
  received,
  recharge;

  String get label {
    switch (this) {
      case GlobalRankingType.sent:
        return 'Sent';
      case GlobalRankingType.received:
        return 'Received';
      case GlobalRankingType.recharge:
        return 'Recharge';
    }
  }

  String get backendValue {
    switch (this) {
      case GlobalRankingType.sent:
        return 'sent';
      case GlobalRankingType.received:
        return 'received';
      case GlobalRankingType.recharge:
        return 'recharge';
    }
  }
}

enum GlobalRankingPeriod {
  daily,
  weekly,
  monthly;

  String get label {
    switch (this) {
      case GlobalRankingPeriod.daily:
        return 'Today';
      case GlobalRankingPeriod.weekly:
        return 'This week';
      case GlobalRankingPeriod.monthly:
        return 'This month';
    }
  }

  String get backendValue {
    switch (this) {
      case GlobalRankingPeriod.daily:
        return 'daily';
      case GlobalRankingPeriod.weekly:
        return 'weekly';
      case GlobalRankingPeriod.monthly:
        return 'monthly';
    }
  }
}

class GlobalRankingResponse {
  const GlobalRankingResponse({
    required this.type,
    required this.period,
    required this.generatedAt,
    required this.periodStartAt,
    required this.entries,
  });

  final GlobalRankingType type;
  final GlobalRankingPeriod period;
  final DateTime? generatedAt;
  final DateTime? periodStartAt;
  final List<GlobalRankingEntry> entries;

  factory GlobalRankingResponse.empty({
    required GlobalRankingType type,
    required GlobalRankingPeriod period,
  }) {
    return GlobalRankingResponse(
      type: type,
      period: period,
      generatedAt: null,
      periodStartAt: null,
      entries: const <GlobalRankingEntry>[],
    );
  }

  factory GlobalRankingResponse.fromJson(
    Map<String, dynamic> json, {
    required GlobalRankingType fallbackType,
    required GlobalRankingPeriod fallbackPeriod,
  }) {
    final entries = json['entries'];
    return GlobalRankingResponse(
      type: _typeFromWire(json['ranking_type'], fallbackType),
      period: _periodFromWire(json['period'], fallbackPeriod),
      generatedAt: _date(json['generated_at']),
      periodStartAt: _date(json['period_start_at']),
      entries: entries is List
          ? entries
                .whereType<Map>()
                .map((entry) => GlobalRankingEntry.fromJson(entry.cast<String, dynamic>()))
                .toList(growable: false)
          : const <GlobalRankingEntry>[],
    );
  }
}

class GlobalRankingEntry {
  const GlobalRankingEntry({
    required this.rank,
    required this.score,
    required this.scoreDisplay,
    required this.user,
  });

  final int rank;
  final int score;
  final String scoreDisplay;
  final GlobalRankingUser user;

  factory GlobalRankingEntry.fromJson(Map<String, dynamic> json) {
    final user = _map(json['user']);
    return GlobalRankingEntry(
      rank: _int(json['rank']),
      score: _int(json['score']),
      scoreDisplay: _string(json['score_display'], fallback: _compact(_int(json['score']))),
      user: GlobalRankingUser.fromJson(user),
    );
  }
}

class GlobalRankingUser {
  const GlobalRankingUser({
    required this.id,
    required this.publicUserId,
    required this.displayName,
    required this.username,
    required this.vipLevel,
    required this.svipLevel,
    required this.sendLevel,
    required this.receiveLevel,
    this.avatarUrl,
  });

  final int id;
  final int publicUserId;
  final String displayName;
  final String username;
  final int vipLevel;
  final int svipLevel;
  final int sendLevel;
  final int receiveLevel;
  final String? avatarUrl;

  factory GlobalRankingUser.fromJson(Map<String, dynamic> json) {
    return GlobalRankingUser(
      id: _int(json['id']),
      publicUserId: _int(json['public_user_id']),
      displayName: _string(json['display_name'], fallback: _string(json['username'], fallback: 'Vibe User')),
      username: _string(json['username'], fallback: ''),
      vipLevel: _int(json['vip_level']),
      svipLevel: _int(json['svip_level']),
      sendLevel: _int(json['send_level']),
      receiveLevel: _int(json['receive_level']),
      avatarUrl: _nullableString(json['avatar_url']),
    );
  }
}

GlobalRankingType _typeFromWire(Object? value, GlobalRankingType fallback) {
  final text = value?.toString().trim().toLowerCase();
  if (text == 'sent') return GlobalRankingType.sent;
  if (text == 'received') return GlobalRankingType.received;
  if (text == 'recharge') return GlobalRankingType.recharge;
  return fallback;
}

GlobalRankingPeriod _periodFromWire(Object? value, GlobalRankingPeriod fallback) {
  final text = value?.toString().trim().toLowerCase();
  if (text == 'daily' || text == 'today') return GlobalRankingPeriod.daily;
  if (text == 'weekly' || text == 'week') return GlobalRankingPeriod.weekly;
  if (text == 'monthly' || text == 'month') return GlobalRankingPeriod.monthly;
  return fallback;
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

DateTime? _date(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}

String _compact(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}
