import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/inbox_call_models.dart';

class InboxCallApiService {
  const InboxCallApiService({AuthApiService authApiService = const AuthApiService()}) : _authApiService = authApiService;

  final AuthApiService _authApiService;

  Future<Map<String, String>> _headers() async {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('No auth token available for Inbox call API. Login first.');
    }
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<InboxCallSession> startCall({
    required String conversationId,
    required InboxCallType callType,
    required String peerName,
    required String peerAvatarText,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/calls/conversations/$conversationId/start')),
      headers: await _headers(),
      body: jsonEncode(<String, dynamic>{'call_type': callType.name}),
    );
    _throwIfFailed(response, 'start inbox call');
    return _callFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
      peerName: peerName,
      peerAvatarText: peerAvatarText,
      direction: InboxCallDirection.outgoing,
    );
  }

  Future<InboxCallSession> acceptCall({
    required InboxCallSession session,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/calls/conversations/${session.conversationId}/${session.id}/accept')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'accept inbox call');
    return _callFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
      peerName: session.peerName,
      peerAvatarText: session.peerAvatarText,
      direction: session.direction,
    );
  }

  Future<InboxCallSession> declineCall({
    required InboxCallSession session,
    String? reason,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/calls/conversations/${session.conversationId}/${session.id}/decline')),
      headers: await _headers(),
      body: jsonEncode(<String, dynamic>{'reason': reason}),
    );
    _throwIfFailed(response, 'decline inbox call');
    return _callFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
      peerName: session.peerName,
      peerAvatarText: session.peerAvatarText,
      direction: session.direction,
    );
  }

  Future<InboxCallSession> endCall({
    required InboxCallSession session,
    String? reason,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/calls/conversations/${session.conversationId}/${session.id}/end')),
      headers: await _headers(),
      body: jsonEncode(<String, dynamic>{'reason': reason}),
    );
    _throwIfFailed(response, 'end inbox call');
    return _callFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
      peerName: session.peerName,
      peerAvatarText: session.peerAvatarText,
      direction: session.direction,
    );
  }

  Future<InboxCallSession> timeoutRingingCall({
    required InboxCallSession session,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/calls/conversations/${session.conversationId}/${session.id}/missed')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'timeout inbox call');
    return session.copyWith(status: InboxCallStatus.missed, endedAt: DateTime.now());
  }

  InboxCallSession callFromRealtimeJson(
    Map<String, dynamic> json, {
    required String peerName,
    required String peerAvatarText,
    required InboxCallDirection direction,
  }) {
    return _callFromJson(json, peerName: peerName, peerAvatarText: peerAvatarText, direction: direction);
  }

  InboxCallSession _callFromJson(
    Map<String, dynamic> json, {
    required String peerName,
    required String peerAvatarText,
    required InboxCallDirection direction,
  }) {
    final callType = json['call_type']?.toString() == 'video' ? InboxCallType.video : InboxCallType.audio;
    final status = _statusFromString(json['status']?.toString());
    final startedAt = DateTime.tryParse(json['started_at']?.toString() ?? '') ?? DateTime.now();
    final endedAt = DateTime.tryParse(json['ended_at']?.toString() ?? '');
    final durationSeconds = int.tryParse(json['duration_seconds']?.toString() ?? '');
    return InboxCallSession(
      id: json['id']?.toString() ?? 'call_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: json['conversation_id']?.toString() ?? '',
      peerName: peerName,
      peerAvatarText: peerAvatarText,
      type: callType,
      direction: direction,
      status: status,
      startedAt: startedAt,
      endedAt: endedAt,
      duration: durationSeconds == null ? null : Duration(seconds: durationSeconds),
      roomId: json['mediasoup_room_id']?.toString(),
    );
  }

  InboxCallStatus _statusFromString(String? value) {
    return switch (value) {
      'accepted' => InboxCallStatus.accepted,
      'declined' => InboxCallStatus.declined,
      'missed' => InboxCallStatus.missed,
      'ended' => InboxCallStatus.ended,
      'failed' => InboxCallStatus.failed,
      _ => InboxCallStatus.ringing,
    };
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String detail = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        detail = decoded['detail']?.toString() ?? response.body;
      }
    } catch (_) {}
    throw Exception('Could not $action: $detail');
  }
}
