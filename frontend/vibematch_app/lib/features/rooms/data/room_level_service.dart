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
  });

  final int level;
  final int totalExp;
  final int maxLevel;
  final double progress;

  factory RoomLevelSummary.fromJson(Map<String, dynamic> json) {
    final room = _map(json['room']);
    return RoomLevelSummary(
      level: _int(room['level']) == 0 ? _int(json['level']) : _int(room['level']),
      totalExp: _int(room['total_exp']) == 0 ? _int(json['total_exp']) : _int(room['total_exp']),
      maxLevel: _int(room['max_level']) == 0 ? 100 : _int(room['max_level']),
      progress: _double(room['progress']),
    );
  }

  const RoomLevelSummary.fallback(int fallbackLevel)
      : level = fallbackLevel,
        totalExp = 0,
        maxLevel = 100,
        progress = 0;
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
      final token = await _storage.getAccessToken();
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null && token.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await http.get(
        Uri.parse(VmApiConfig.endpoint('/experience/rooms/public/$cleanRoomPublicId')),
        headers: headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return RoomLevelSummary.fallback(fallbackLevel);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return RoomLevelSummary.fallback(fallbackLevel);
      }
      return RoomLevelSummary.fromJson(decoded);
    } catch (_) {
      return RoomLevelSummary.fallback(fallbackLevel);
    }
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

double _double(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
