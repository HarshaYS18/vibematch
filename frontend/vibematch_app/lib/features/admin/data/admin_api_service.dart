import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/room_realtime_audit_log.dart';

class AdminApiService {
  AdminApiService({
    AuthApiService? authApiService,
  }) : _authApiService = authApiService ?? const AuthApiService();

  final AuthApiService _authApiService;

  Future<List<RoomRealtimeAuditLog>> getRoomRealtimeAuditLogs({
    int limit = 100,
  }) {
    return _getAuditLogs('/admin/room-realtime-audit-logs?limit=$limit');
  }

  Future<List<RoomRealtimeAuditLog>> getRoomRealtimeAuditLogsForRoom({
    required String roomId,
    String? eventType,
    int limit = 100,
  }) {
    final query = <String, String>{'limit': '$limit'};
    if (eventType != null && eventType.trim().isNotEmpty) {
      query['event_type'] = eventType.trim();
    }

    final uri = Uri(
      path: '/admin/room-realtime-audit-logs/room/${Uri.encodeComponent(roomId.trim())}',
      queryParameters: query,
    );

    return _getAuditLogs(uri.toString());
  }

  Future<List<RoomRealtimeAuditLog>> getRoomRealtimeAuditLogsForActor({
    required String actorUserId,
    int limit = 100,
  }) {
    return _getAuditLogs(
      '/admin/room-realtime-audit-logs/actor/${Uri.encodeComponent(actorUserId.trim())}?limit=$limit',
    );
  }

  Future<List<RoomRealtimeAuditLog>> _getAuditLogs(String path) async {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Founder token missing. Please login again.');
    }

    final uri = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to load room audit logs (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Room audit log response was invalid.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(RoomRealtimeAuditLog.fromJson)
        .toList(growable: false);
  }
}
