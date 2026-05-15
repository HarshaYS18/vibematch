import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_local_storage.dart';

class RoomLevelSummary {
  const RoomLevelSummary({
    required this.level,
    required this.totalExp,
    required this.maxLevel,
    required this.progress,
    required this.nextLevelExp,
    required this.periodExp,
    required this.rank,
  });

  final int level;
  final int totalExp;
  final int maxLevel;
  final double progress;
  final int nextLevelExp;
  final int periodExp;
  final int? rank;

  factory RoomLevelSummary.fromJson(Map<String, dynamic> json) {
    final room = _map(json['room']);
    final level = _firstPositive([room['level'], json['level']]);
    final totalExp = _firstPositive([
      room['total_exp'],
      room['totalExp'],
      json['total_exp'],
      json['totalExp'],
      json['exp'],
    ]);
    final maxLevel = _firstPositive([room['max_level'], json['max_level'], 100]);
    final nextLevelExp = _firstPositive([
      room['next_level_exp'],
      json['next_level_exp'],
      json['nextLevelExp'],
    ]);
    final rawProgress = _firstProgress([
      room['progress'],
      room['progress_ratio'],
      json['progress'],
      json['progress_ratio'],
    ]);

    return RoomLevelSummary(
      level: level <= 0 ? 1 : level,
      totalExp: totalExp,
      maxLevel: maxLevel <= 0 ? 100 : maxLevel,
      progress: rawProgress.clamp(0, 1),
      nextLevelExp: nextLevelExp,
      periodExp: _firstPositive([room['period_exp'], json['period_exp']]),
      rank: _nullableInt(room['rank'] ?? json['rank']),
    );
  }

  const RoomLevelSummary.fallback(int fallbackLevel)
      : level = fallbackLevel,
        totalExp = 0,
        maxLevel = 100,
        progress = 0,
        nextLevelExp = 0,
        periodExp = 0,
        rank = null;
}

class RoomLevelHistoryEntry {
  const RoomLevelHistoryEntry({
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

  factory RoomLevelHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RoomLevelHistoryEntry(
      id: _int(json['id']),
      eventType: _string(json['event_type'] ?? json['type'], fallback: 'activity'),
      expDelta: _int(json['exp_delta'] ?? json['exp'] ?? json['score']),
      description: _string(json['description'] ?? json['title'], fallback: 'Room activity'),
      createdAt: _date(json['created_at'] ?? json['createdAt']),
    );
  }
}

class RoomLevelService {
  RoomLevelService._();

  static final RoomLevelService instance = RoomLevelService._();
  final AuthLocalStorage _storage = AuthLocalStorage();

  Future<RoomLevelSummary> fetchRoomLevel({
    required String roomPublicId,
    required int fallbackLevel,
  }) async {
    final cleanRoomPublicId = roomPublicId.trim();
    if (cleanRoomPublicId.isEmpty || cleanRoomPublicId == 'unknown_room') {
      return RoomLevelSummary.fallback(fallbackLevel);
    }

    try {
      final decoded = await _getMap('/rooms/$cleanRoomPublicId/level');
      return RoomLevelSummary.fromJson(decoded);
    } catch (_) {
      return RoomLevelSummary.fallback(fallbackLevel);
    }
  }

  Future<List<RoomLevelHistoryEntry>> fetchRoomLevelHistory({
    required String roomPublicId,
    int limit = 30,
  }) async {
    final cleanRoomPublicId = roomPublicId.trim();
    if (cleanRoomPublicId.isEmpty || cleanRoomPublicId == 'unknown_room') {
      return const <RoomLevelHistoryEntry>[];
    }

    try {
      final decoded = await _getMap(
        '/rooms/$cleanRoomPublicId/level/history?limit=${limit.clamp(1, 100)}',
      );
      final entries = decoded['entries'] ?? decoded['history'] ?? decoded['items'];
      if (entries is! List) return const <RoomLevelHistoryEntry>[];
      return entries
          .whereType<Map>()
          .map((item) => RoomLevelHistoryEntry.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false);
    } catch (_) {
      return const <RoomLevelHistoryEntry>[];
    }
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    final token = await _storage.getAccessToken();
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint(path)),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Room level request failed (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return const <String, dynamic>{};
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  return _int(value);
}

int _firstPositive(List<dynamic> values) {
  for (final value in values) {
    final parsed = _int(value);
    if (parsed > 0) return parsed;
  }
  return 0;
}

double _double(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

double _firstProgress(List<dynamic> values) {
  for (final value in values) {
    final parsed = _double(value);
    if (parsed > 0) return parsed > 1 ? parsed / 100 : parsed;
  }
  return 0;
}

String _string(dynamic value, {required String fallback}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

DateTime? _date(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}
