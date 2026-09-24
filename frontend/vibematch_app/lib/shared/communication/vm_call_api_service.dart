import 'dart:convert';

import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../core/network/vm_api_config.dart';
import '../../features/auth/data/auth_api_service.dart';
import 'vm_communication_models.dart';

class VmCallApiService {
  const VmCallApiService({
    AuthApiService authApiService = const AuthApiService(),
  }) : _authApiService = authApiService;

  final AuthApiService _authApiService;

  Future<List<VmCallSessionRef>> listMyCalls({int limit = 30}) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/calls?limit=$limit')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'list calls');
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(VmCallSessionWireMapper.fromJson)
        .toList();
  }

  Future<VmCallSessionRef> createCall({
    required VmCallType callType,
    required List<int> participantUserIds,
    int? conversationId,
    String? roomPublicId,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/calls')),
      headers: await _headers(),
      body: jsonEncode(<String, Object?>{
        'participant_user_ids': participantUserIds,
        'conversation_id': conversationId,
        'room_public_id': roomPublicId,
        'call_type': _callTypeToApi(callType),
      }),
    );
    _throwIfFailed(response, 'create call');
    return VmCallSessionWireMapper.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<VmCallSessionRef> getCall(String callPublicId) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/calls/$callPublicId')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'get call');
    return VmCallSessionWireMapper.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<VmCallSessionRef> updateMyParticipant({
    required String callPublicId,
    VmCallStatus? status,
    bool? isMuted,
    bool? isCameraEnabled,
  }) async {
    final response = await http.patch(
      Uri.parse(VmApiConfig.endpoint('/calls/$callPublicId/participant')),
      headers: await _headers(),
      body: jsonEncode(<String, Object?>{
        'status': status == null ? null : _participantStatusToApi(status),
        'is_muted': isMuted,
        'is_camera_enabled': isCameraEnabled,
      }),
    );
    _throwIfFailed(response, 'update call participant');
    return VmCallSessionWireMapper.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<VmCallSessionRef> endCall({
    required String callPublicId,
    String endReason = 'ended',
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/calls/$callPublicId/end')),
      headers: await _headers(),
      body: jsonEncode(<String, Object?>{'end_reason': endReason}),
    );
    _throwIfFailed(response, 'end call');
    return VmCallSessionWireMapper.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Map<String, String>> _headers() async {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw StateError('No auth token available for call API. Login first.');
    }
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw StateError('Call API failed to $action (${response.statusCode}): ${response.body}');
  }

  String _callTypeToApi(VmCallType type) {
    return switch (type) {
      VmCallType.audio => 'direct_audio',
      VmCallType.video => 'direct_video',
      VmCallType.groupAudio => 'group_audio',
      VmCallType.groupVideo => 'group_video',
    };
  }

  String _participantStatusToApi(VmCallStatus status) {
    return switch (status) {
      VmCallStatus.ringing => 'ringing',
      VmCallStatus.connecting => 'ringing',
      VmCallStatus.active => 'joined',
      VmCallStatus.declined => 'declined',
      VmCallStatus.missed => 'missed',
      VmCallStatus.ended => 'left',
      VmCallStatus.failed => 'failed',
      VmCallStatus.cancelled => 'left',
      VmCallStatus.idle => 'invited',
    };
  }
}

class VmCallSessionWireMapper {
  const VmCallSessionWireMapper._();

  static VmCallSessionRef fromJson(Map<String, dynamic> json) {
    return VmCallSessionRef(
      callId: json['call_public_id']?.toString() ?? json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString(),
      type: _typeFromApi(json['call_type']?.toString()),
      status: _statusFromApi(json['status']?.toString()),
      startedByPublicUserId: (json['started_by_public_user_id'] as num?)?.toInt() ??
          (json['started_by_user_id'] as num?)?.toInt() ??
          0,
      participants: (json['participants'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_participantFromJson)
          .toList(),
      startedAt: _date(json['started_at']),
      endedAt: _date(json['ended_at']),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
    );
  }

  static VmCallParticipantRef _participantFromJson(Map<String, dynamic> json) {
    return VmCallParticipantRef(
      publicUserId: (json['public_user_id'] as num?)?.toInt() ?? 0,
      displayName: json['display_name']?.toString() ?? 'User',
      avatarUrl: _nullableString(json['avatar_url']),
      isMuted: json['is_muted'] == true,
      isCameraEnabled: json['is_camera_enabled'] != false,
    );
  }

  static VmCallType _typeFromApi(String? value) {
    return switch (value) {
      'direct_video' => VmCallType.video,
      'group_audio' => VmCallType.groupAudio,
      'group_video' => VmCallType.groupVideo,
      _ => VmCallType.audio,
    };
  }

  static VmCallStatus _statusFromApi(String? value) {
    return switch (value) {
      'ringing' => VmCallStatus.ringing,
      'connecting' => VmCallStatus.connecting,
      'active' => VmCallStatus.active,
      'declined' => VmCallStatus.declined,
      'missed' => VmCallStatus.missed,
      'ended' => VmCallStatus.ended,
      'failed' => VmCallStatus.failed,
      'cancelled' => VmCallStatus.cancelled,
      _ => VmCallStatus.idle,
    };
  }

  static DateTime? _date(Object? value) {
    final text = value?.toString();
    if (text == null || text.trim().isEmpty || text == 'null') return null;
    return DateTime.tryParse(text);
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }
}
