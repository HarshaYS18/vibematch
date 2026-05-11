import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api_service.dart';
import '../presentation/live_room_models.dart';

class LiveRoomPresenceRepository {
  LiveRoomPresenceRepository({ApiClient? apiClient, AuthApiService? authApiService})
      : _apiClient = apiClient ?? ApiClient(),
        _authApiService = authApiService ?? const AuthApiService();

  final ApiClient _apiClient;
  final AuthApiService _authApiService;

  static final ValueNotifier<List<SeatUser>> activeParticipants = ValueNotifier<List<SeatUser>>(const <SeatUser>[]);

  static List<SeatUser> get currentParticipants => activeParticipants.value;

  static SeatUser? userByRoomUserId(String userId) {
    for (final user in activeParticipants.value) {
      if (user.id == userId) return user;
    }
    return null;
  }

  static void publishParticipants(List<SeatUser> participants) {
    final deduped = <SeatUser>[];
    final ids = <String>{};
    for (final user in participants) {
      if (ids.add(user.id)) deduped.add(user);
    }
    activeParticipants.value = List<SeatUser>.unmodifiable(deduped);
  }

  static void publishParticipant(SeatUser participant) {
    final next = <SeatUser>[];
    var replaced = false;
    for (final user in activeParticipants.value) {
      if (user.id == participant.id) {
        next.add(participant);
        replaced = true;
      } else {
        next.add(user);
      }
    }
    if (!replaced) next.add(participant);
    activeParticipants.value = List<SeatUser>.unmodifiable(next);
  }

  Future<LiveRoomPresenceSnapshot> joinRoom(String roomId) => _postSnapshot('/rooms/$roomId/join');

  Future<LiveRoomPresenceSnapshot> heartbeat(String roomId) => _postSnapshot('/rooms/$roomId/heartbeat');

  Future<LiveRoomPresenceSnapshot> fetchParticipants(String roomId) async {
    final response = await _apiClient.getMap('/rooms/$roomId/participants', headers: _headers());
    final snapshot = LiveRoomPresenceSnapshot.fromJson(response);
    publishParticipants(snapshot.participants);
    return snapshot;
  }

  Future<int> leaveRoom(String roomId) async {
    final response = await _apiClient.postMap('/rooms/$roomId/leave', headers: _headers());
    return _int(response['online_count']);
  }

  Future<SeatUser> addRoomMember({required String roomId, required int publicUserId}) async {
    final response = await _apiClient.postMap(
      '/rooms/$roomId/members',
      headers: _jsonHeaders(),
      body: {'public_user_id': publicUserId},
    );
    final user = LiveRoomPresenceSnapshot.participantToSeatUser(response);
    publishParticipant(user);
    return user;
  }

  Future<SeatUser> removeRoomMember({required String roomId, required int publicUserId}) async {
    final response = await _apiClient.deleteMap('/rooms/$roomId/members/$publicUserId', headers: _headers());
    final user = LiveRoomPresenceSnapshot.participantToSeatUser(response);
    publishParticipant(user);
    return user;
  }

  Future<SeatUser> addRoomAdmin({required String roomId, required int publicUserId}) async {
    final response = await _apiClient.postMap(
      '/rooms/$roomId/admins',
      headers: _jsonHeaders(),
      body: {'public_user_id': publicUserId},
    );
    final user = LiveRoomPresenceSnapshot.participantToSeatUser(response);
    publishParticipant(user);
    return user;
  }

  Future<SeatUser> removeRoomAdmin({required String roomId, required int publicUserId}) async {
    final response = await _apiClient.deleteMap('/rooms/$roomId/admins/$publicUserId', headers: _headers());
    final user = LiveRoomPresenceSnapshot.participantToSeatUser(response);
    publishParticipant(user);
    return user;
  }

  Future<LiveRoomPresenceSnapshot> _postSnapshot(String path) async {
    final response = await _apiClient.postMap(path, headers: _headers());
    final snapshot = LiveRoomPresenceSnapshot.fromJoinJson(response);
    publishParticipants(snapshot.participants);
    return snapshot;
  }

  Map<String, String> _headers() {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) throw Exception('Please login again before entering rooms.');
    return {'Authorization': 'Bearer $token'};
  }

  Map<String, String> _jsonHeaders() {
    return {..._headers(), 'Content-Type': 'application/json'};
  }

  void close() => _apiClient.close();
}

class LiveRoomPresenceSnapshot {
  const LiveRoomPresenceSnapshot({
    required this.roomId,
    required this.onlineCount,
    required this.participants,
    this.joinedUser,
    this.shouldShowEnteredMessage = false,
  });

  final String roomId;
  final int onlineCount;
  final List<SeatUser> participants;
  final SeatUser? joinedUser;
  final bool shouldShowEnteredMessage;

  factory LiveRoomPresenceSnapshot.fromJoinJson(Map<String, dynamic> json) {
    final room = json['room'] is Map<String, dynamic> ? json['room'] as Map<String, dynamic> : <String, dynamic>{};
    final joinedRaw = json['joined_user'];
    return LiveRoomPresenceSnapshot(
      roomId: room['id']?.toString() ?? '',
      onlineCount: _int(room['online_count']),
      participants: _participants(json['participants']),
      joinedUser: joinedRaw is Map<String, dynamic> ? participantToSeatUser(joinedRaw) : null,
      shouldShowEnteredMessage: json['should_show_entered_message'] == true,
    );
  }

  factory LiveRoomPresenceSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveRoomPresenceSnapshot(
      roomId: json['room_id']?.toString() ?? '',
      onlineCount: _int(json['online_count']),
      participants: _participants(json['participants']),
    );
  }

  static List<SeatUser> _participants(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(participantToSeatUser).toList(growable: false);
  }

  static SeatUser participantToSeatUser(Map<String, dynamic> json) {
    final publicUserId = json['public_user_id']?.toString() ?? '';
    final displayName = _text(json['display_name']) ?? _text(json['username']) ?? (publicUserId.isEmpty ? 'Vibe User' : 'User $publicUserId');
    final vip = json['vip'] is Map<String, dynamic> ? json['vip'] as Map<String, dynamic> : <String, dynamic>{};
    final svipLevel = _int(vip['svip_level']);
    final vipLevel = _int(vip['vip_level']);
    final isOwner = json['is_owner'] == true;
    final isRoomAdmin = json['is_room_admin'] == true;
    final isMember = json['is_member'] == true;
    final role = _text(json['primary_role']) ?? 'user';
    return SeatUser(
      id: 'user_$publicUserId',
      name: displayName,
      roleLabel: isOwner
          ? 'Channel Host'
          : isRoomAdmin
              ? 'Administrator'
              : isMember
                  ? 'Member'
                  : _roleLabel(role),
      familyName: '',
      familyLevel: 'bronze',
      relationshipText: '',
      vipLevel: vipLevel,
      svipLevel: svipLevel,
      sendingLevel: 1,
      receivingLevel: 1,
      sentExp: 0,
      receivedExp: 0,
      medals: const [],
      avatarColors: _avatarColors(publicUserId),
      isHost: isOwner,
      isRoomAdmin: isRoomAdmin || isOwner,
    );
  }
}

String _roleLabel(String role) {
  final normalized = role.toLowerCase();
  if (normalized.contains('founder') || normalized.contains('owner')) return 'Official';
  if (normalized.contains('admin')) return 'Administrator';
  if (normalized.contains('monitor')) return 'Monitor';
  if (normalized.contains('cs')) return 'CS';
  return 'Guest';
}

List<Color> _avatarColors(String seed) {
  final hash = seed.hashCode.abs();
  final palettes = <List<Color>>[
    const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
    const [Color(0xFFE84C72), Color(0xFF8C5CF6)],
    const [Color(0xFFFFC857), Color(0xFFE84C72)],
    const [Color(0xFF4A9BFF), Color(0xFF12C7B7)],
  ];
  return palettes[hash % palettes.length];
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
