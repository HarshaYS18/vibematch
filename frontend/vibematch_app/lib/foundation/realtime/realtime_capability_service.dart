import '../networking/app_network_client.dart';

class RealtimeCapabilityGrant {
  const RealtimeCapabilityGrant({
    required this.token,
    required this.expiresAt,
    required this.sessionId,
    required this.scopes,
    this.roomPublicId,
    this.permissions = const <String>[],
    this.membershipVersion,
  });

  final String token;
  final DateTime expiresAt;
  final String sessionId;
  final List<String> scopes;
  final String? roomPublicId;
  final List<String> permissions;
  final int? membershipVersion;

  bool get isFresh =>
      expiresAt.isAfter(DateTime.now().toUtc().add(const Duration(seconds: 30)));

  factory RealtimeCapabilityGrant.fromJson(Map<String, dynamic> json) {
    final token = json['token']?.toString().trim() ?? '';
    if (token.isEmpty) {
      throw StateError('Realtime capability response did not include a token.');
    }
    final epochSeconds = _int(json['expires_at']);
    if (epochSeconds <= 0) {
      throw StateError('Realtime capability response has invalid expiry.');
    }
    return RealtimeCapabilityGrant(
      token: token,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        epochSeconds * 1000,
        isUtc: true,
      ),
      sessionId: json['session_id']?.toString() ?? '',
      scopes: _strings(json['scopes']),
      roomPublicId: json['room_public_id']?.toString(),
      permissions: _strings(json['permissions']),
      membershipVersion: json['membership_version'] == null
          ? null
          : _int(json['membership_version']),
    );
  }
}

class RealtimeCapabilityService {
  RealtimeCapabilityService({
    required AppNetworkClient networkClient,
    required String? Function() accessTokenProvider,
  })  : _networkClient = networkClient,
        _accessTokenProvider = accessTokenProvider;

  final AppNetworkClient _networkClient;
  final String? Function() _accessTokenProvider;

  Future<RealtimeCapabilityGrant> issue({String? roomId}) async {
    final accessToken = _accessTokenProvider()?.trim();
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('No authenticated session for realtime capability.');
    }
    final normalizedRoomId = roomId?.trim();
    final response = await _networkClient.postMap(
      '/realtime/capability',
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      body: <String, dynamic>{
        if (normalizedRoomId != null && normalizedRoomId.isNotEmpty)
          'room_public_id': normalizedRoomId,
      },
    );
    return RealtimeCapabilityGrant.fromJson(response);
  }
}

List<String> _strings(dynamic value) {
  if (value is! List) return const <String>[];
  return List<String>.unmodifiable(
    value.map((item) => item.toString()).where((item) => item.isNotEmpty),
  );
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
