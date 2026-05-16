import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

const Duration _istOffset = Duration(hours: 5, minutes: 30);
final RegExp _timestampHasOffsetPattern = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

DateTime _toIst(DateTime value) => value.toUtc().add(_istOffset);
DateTime _nowIst() => DateTime.now().toUtc().add(_istOffset);

class PresenceApiService {
  const PresenceApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<PresenceDto> heartbeat({
    String? roomPublicId,
    String? roomName,
    String? roomMode,
    bool isSecret = false,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/presence/heartbeat')),
      headers: _authHeaders(),
      body: jsonEncode({
        if (roomPublicId != null && roomPublicId.trim().isNotEmpty)
          'room_public_id': roomPublicId.trim(),
        if (roomName != null && roomName.trim().isNotEmpty)
          'room_name': roomName.trim(),
        if (roomMode != null && roomMode.trim().isNotEmpty)
          'room_mode': roomMode.trim(),
        'is_secret': isSecret,
      }),
    );
    _throwIfFailed(response, 'send presence heartbeat');
    return PresenceDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<PresenceDto> enterRoom({
    required String roomPublicId,
    required String roomName,
    String? roomMode,
    bool isSecret = false,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/presence/room/enter')),
      headers: _authHeaders(),
      body: jsonEncode({
        'room_public_id': roomPublicId.trim(),
        'room_name': roomName.trim(),
        if (roomMode != null && roomMode.trim().isNotEmpty)
          'room_mode': roomMode.trim(),
        'is_secret': isSecret,
      }),
    );
    _throwIfFailed(response, 'enter room presence');
    return PresenceDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<PresenceDto> leaveRoom() async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/presence/room/leave')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'leave room presence');
    return PresenceDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<PresenceDto> getPublicPresence(int publicUserId) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/presence/public/$publicUserId')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'load public presence');
    return PresenceDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<PresenceDto>> getBatchPresence(List<int> publicUserIds) async {
    final uniqueIds = publicUserIds
        .where((id) => id > 0)
        .toSet()
        .take(100)
        .toList(growable: false);
    if (uniqueIds.isEmpty) return const <PresenceDto>[];

    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/presence/batch')),
      headers: _authHeaders(),
      body: jsonEncode({'public_user_ids': uniqueIds}),
    );
    _throwIfFailed(response, 'load batch presence');

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(PresenceDto.fromJson)
        .toList(growable: false);
  }

  Map<String, String> _authHeaders() {
    final access = authApiService.cachedAccessToken;
    if (access == null || access.trim().isEmpty)
      throw Exception('Please login again.');
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $access',
    };
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final body = response.body.trim();
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail']?.toString().trim();
          if (detail != null && detail.isNotEmpty) throw Exception(detail);
        }
      } catch (_) {
        throw Exception(body);
      }
    }

    throw Exception('Failed to $action (${response.statusCode})');
  }
}

class PresenceDto {
  const PresenceDto({
    required this.publicUserId,
    required this.isOnline,
    required this.inRoom,
    this.lastSeenAt,
    this.roomPublicId,
    this.roomName,
    this.roomMode,
    this.roomEnteredAt,
  });

  final int publicUserId;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final bool inRoom;
  final String? roomPublicId;
  final String? roomName;
  final String? roomMode;
  final DateTime? roomEnteredAt;

  bool get hasVisibleRoom =>
      inRoom && roomName != null && roomName!.trim().isNotEmpty;

  String get onlineLabel {
    if (isOnline) return 'Online';
    final seen = lastSeenAt;
    if (seen == null) return 'Offline';

    final diff = _nowIst().difference(_toIst(seen));
    if (diff.inMinutes < 1) return 'last seen just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      return 'last seen ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 30) {
      return 'last seen ${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    return 'last seen a month ago';
  }

  factory PresenceDto.fromJson(Map<String, dynamic> json) {
    return PresenceDto(
      publicUserId: _int(json['public_user_id'], fallback: 0),
      isOnline: json['is_online'] == true,
      lastSeenAt: _date(json['last_seen_at']),
      inRoom: json['in_room'] == true,
      roomPublicId: _nullableText(json['room_public_id']),
      roomName: _nullableText(json['room_name']),
      roomMode: _nullableText(json['room_mode']),
      roomEnteredAt: _date(json['room_entered_at']),
    );
  }
}

int _int(dynamic value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String? _nullableText(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value.toUtc();
  if (value is! String || value.trim().isEmpty) return null;

  final text = value.trim();
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;

  if (_timestampHasOffsetPattern.hasMatch(text)) return parsed.toUtc();

  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}
