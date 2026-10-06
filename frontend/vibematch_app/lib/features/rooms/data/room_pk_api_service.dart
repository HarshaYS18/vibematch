import 'dart:convert';

import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class RoomPkRoomSummary {
  const RoomPkRoomSummary({
    required this.roomId,
    required this.roomName,
    required this.onlineCount,
    this.coverPhotoUrl,
  });

  final String roomId;
  final String roomName;
  final String? coverPhotoUrl;
  final int onlineCount;

  factory RoomPkRoomSummary.fromJson(Map<String, dynamic> json) {
    return RoomPkRoomSummary(
      roomId: json['room_id']?.toString() ?? '',
      roomName: json['room_name']?.toString() ?? 'Live Room',
      coverPhotoUrl: _nullableText(json['cover_photo_url']),
      onlineCount: _int(json['online_count']),
    );
  }
}

class RoomPkMatchSnapshot {
  const RoomPkMatchSnapshot({
    required this.matchId,
    required this.status,
    required this.challenger,
    required this.opponent,
    required this.durationSeconds,
    required this.challengerScore,
    required this.opponentScore,
    required this.challengeExpiresAt,
    this.winnerRoomId,
    this.startedAt,
    this.endsAt,
    this.finishedAt,
    this.finishedReason,
  });

  final String matchId;
  final String status;
  final RoomPkRoomSummary challenger;
  final RoomPkRoomSummary opponent;
  final int durationSeconds;
  final int challengerScore;
  final int opponentScore;
  final String? winnerRoomId;
  final DateTime challengeExpiresAt;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final DateTime? finishedAt;
  final String? finishedReason;

  bool get isPending => status == 'challenged';
  bool get isActive => status == 'active';
  bool get isFinished =>
      status == 'finished' || status == 'declined' || status == 'cancelled';

  bool involvesRoom(String roomId) =>
      challenger.roomId == roomId || opponent.roomId == roomId;

  RoomPkRoomSummary roomFor(String roomId) =>
      challenger.roomId == roomId ? challenger : opponent;

  RoomPkRoomSummary opponentFor(String roomId) =>
      challenger.roomId == roomId ? opponent : challenger;

  int scoreFor(String roomId) =>
      challenger.roomId == roomId ? challengerScore : opponentScore;

  int opponentScoreFor(String roomId) =>
      challenger.roomId == roomId ? opponentScore : challengerScore;

  factory RoomPkMatchSnapshot.fromJson(Map<String, dynamic> json) {
    return RoomPkMatchSnapshot(
      matchId: json['match_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'cancelled',
      challenger: RoomPkRoomSummary.fromJson(_map(json['challenger'])),
      opponent: RoomPkRoomSummary.fromJson(_map(json['opponent'])),
      durationSeconds: _int(json['duration_seconds']),
      challengerScore: _int(json['challenger_score']),
      opponentScore: _int(json['opponent_score']),
      winnerRoomId: _nullableText(json['winner_room_id']),
      challengeExpiresAt:
          _date(json['challenge_expires_at']) ?? DateTime.now().toUtc(),
      startedAt: _date(json['started_at']),
      endsAt: _date(json['ends_at']),
      finishedAt: _date(json['finished_at']),
      finishedReason: _nullableText(json['finished_reason']),
    );
  }
}

class RoomPkApiService {
  const RoomPkApiService({
    this.authApiService = const AuthApiService(),
  });

  final AuthApiService authApiService;

  Future<List<RoomPkRoomSummary>> listCandidates(
    String roomId, {
    int limit = 30,
  }) async {
    final response = await http.get(
      Uri.parse(
        VmApiConfig.endpoint('/rooms/$roomId/pk/candidates?limit=$limit'),
      ),
      headers: _authHeaders(),
    );
    _ensureSuccess(response, 'Failed to load PK rooms');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const <RoomPkRoomSummary>[];
    return decoded
        .whereType<Map>()
        .map((item) => RoomPkRoomSummary.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<RoomPkMatchSnapshot?> current(String roomId) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/rooms/$roomId/pk/current')),
      headers: _authHeaders(),
    );
    _ensureSuccess(response, 'Failed to load PK state');
    final body = response.body.trim();
    if (body.isEmpty || body == 'null') return null;
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    return RoomPkMatchSnapshot.fromJson(decoded.cast<String, dynamic>());
  }

  Future<RoomPkMatchSnapshot> challenge({
    required String roomId,
    required String opponentRoomId,
    int durationSeconds = 180,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/rooms/$roomId/pk/challenge')),
      headers: _authHeaders(),
      body: jsonEncode({
        'opponent_room_id': opponentRoomId,
        'duration_seconds': durationSeconds,
      }),
    );
    _ensureSuccess(response, 'Failed to send PK challenge');
    return RoomPkMatchSnapshot.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }

  Future<RoomPkMatchSnapshot> decide({
    required String roomId,
    required String matchId,
    required bool accept,
  }) async {
    final response = await http.post(
      Uri.parse(
        VmApiConfig.endpoint('/rooms/$roomId/pk/$matchId/decision'),
      ),
      headers: _authHeaders(),
      body: jsonEncode({'accept': accept}),
    );
    _ensureSuccess(response, 'Failed to answer PK challenge');
    return RoomPkMatchSnapshot.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }

  Future<RoomPkMatchSnapshot> cancel({
    required String roomId,
    required String matchId,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/rooms/$roomId/pk/$matchId/cancel')),
      headers: _authHeaders(),
    );
    _ensureSuccess(response, 'Failed to end PK');
    return RoomPkMatchSnapshot.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }

  Future<RoomPkMatchSnapshot> finish({
    required String roomId,
    required String matchId,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/rooms/$roomId/pk/$matchId/finish')),
      headers: _authHeaders(),
    );
    _ensureSuccess(response, 'Failed to finalize PK');
    return RoomPkMatchSnapshot.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }

  Map<String, String> _authHeaders() {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _ensureSuccess(http.Response response, String fallback) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final body = response.body.trim();
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['detail'] != null) {
          throw Exception(decoded['detail'].toString());
        }
      } catch (error) {
        if (error is Exception) rethrow;
      }
    }
    throw Exception('$fallback (${response.statusCode})');
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text)?.toUtc();
}
