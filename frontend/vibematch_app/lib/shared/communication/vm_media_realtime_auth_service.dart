import 'dart:convert';

import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../core/network/vm_api_config.dart';
import '../../features/auth/data/auth_api_service.dart';

class VmMediaRealtimeAuthService {
  const VmMediaRealtimeAuthService({
    AuthApiService authApiService = const AuthApiService(),
  }) : _authApiService = authApiService;

  final AuthApiService _authApiService;

  Future<VmMediaRealtimeVerifyResult> verify({
    required String requestedAction,
    String? roomPublicId,
    String? deviceId,
  }) async {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw StateError('No auth token available for media realtime verification. Login first.');
    }

    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/media-realtime/verify')),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, Object?>{
        'room_public_id': roomPublicId,
        'device_id': deviceId,
        'requested_action': requestedAction,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Media realtime verification failed (${response.statusCode}): ${response.body}');
    }

    return VmMediaRealtimeVerifyResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

class VmMediaRealtimeVerifyResult {
  const VmMediaRealtimeVerifyResult({
    required this.allowed,
    required this.requestedAction,
    required this.permissions,
    required this.user,
    required this.mediasoupContext,
    this.reason,
    this.roomPublicId,
  });

  final bool allowed;
  final String? reason;
  final String requestedAction;
  final String? roomPublicId;
  final List<String> permissions;
  final VmMediaRealtimeUserRef user;
  final Map<String, Object?> mediasoupContext;

  factory VmMediaRealtimeVerifyResult.fromJson(Map<String, dynamic> json) {
    return VmMediaRealtimeVerifyResult(
      allowed: json['allowed'] == true,
      reason: _nullableString(json['reason']),
      requestedAction: json['requested_action']?.toString() ?? 'join_room',
      roomPublicId: _nullableString(json['room_public_id']),
      permissions: (json['permissions'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      user: VmMediaRealtimeUserRef.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      mediasoupContext: Map<String, Object?>.from(
        (json['mediasoup_context'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
    );
  }
}

class VmMediaRealtimeUserRef {
  const VmMediaRealtimeUserRef({
    required this.userId,
    required this.publicUserId,
    required this.roles,
    required this.primaryRole,
    required this.isActive,
    required this.isBanned,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  final int userId;
  final int publicUserId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final List<String> roles;
  final String primaryRole;
  final bool isActive;
  final bool isBanned;

  factory VmMediaRealtimeUserRef.fromJson(Map<String, dynamic> json) {
    return VmMediaRealtimeUserRef(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      publicUserId: (json['public_user_id'] as num?)?.toInt() ?? 0,
      username: _nullableString(json['username']),
      displayName: _nullableString(json['display_name']),
      avatarUrl: _nullableString(json['avatar_url']),
      roles: (json['roles'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      primaryRole: json['primary_role']?.toString() ?? 'user',
      isActive: json['is_active'] == true,
      isBanned: json['is_banned'] == true,
    );
  }
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}
