import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api_service.dart';
import '../../profile/presentation/control_center/vip_svip_admin_page.dart';
import '../presentation/live_room_models.dart';

class LiveRoomPresenceRepository {
  LiveRoomPresenceRepository({ApiClient? apiClient, AuthApiService? authApiService})
      : _apiClient = apiClient ?? ApiClient(),
        _authApiService = authApiService ?? const AuthApiService();

  final ApiClient _apiClient;
  final AuthApiService _authApiService;

  Future<LiveRoomPresenceSnapshot> joinRoom(String roomId) => _postSnapshot('/rooms/$roomId/join');

  Future<LiveRoomPresenceSnapshot> heartbeat(String roomId) => _postSnapshot('/rooms/$roomId/heartbeat');

  Future<LiveRoomPresenceSnapshot> fetchParticipants(String roomId) async {
    final response = await _apiClient.getMap('/rooms/$roomId/participants', headers: _headers());
    return LiveRoomPresenceSnapshot.fromJson(response);
  }

  Future<int> leaveRoom(String roomId) async {
    final response = await _apiClient.postMap('/rooms/$roomId/leave', headers: _headers());
    return _int(response['online_count']);
  }

  Future<LiveRoomPresenceSnapshot> _postSnapshot(String path) async {
    final response = await _apiClient.postMap(path, headers: _headers());
    return LiveRoomPresenceSnapshot.fromJoinJson(response);
  }

  Map<String, String> _headers() {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) throw Exception('Please login again before entering rooms.');
    return {'Authorization': 'Bearer $token'};
  }

  void close() => _apiClient.close();
}

class LiveRoomPresenceSnapshot {
  const LiveRoomPresenceSnapshot({required this.roomId, required this.onlineCount, required this.participants});

  final String roomId;
  final int onlineCount;
  final List<SeatUser> participants;

  factory LiveRoomPresenceSnapshot.fromJoinJson(Map<String, dynamic> json) {
    final room = json['room'] is Map<String, dynamic> ? json['room'] as Map<String, dynamic> : <String, dynamic>{};
    return LiveRoomPresenceSnapshot(
      roomId: room['id']?.toString() ?? '',
      onlineCount: _int(room['online_count']),
      participants: _participants(json['participants']),
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
    return raw.whereType<Map<String, dynamic>>().map(_participantToSeatUser).toList(growable: false);
  }

  static SeatUser _participantToSeatUser(Map<String, dynamic> json) {
    final publicUserId = json['public_user_id']?.toString() ?? '';
    final displayName = _text(json['display_name']) ?? _text(json['username']) ?? (publicUserId.isEmpty ? 'Vibe User' : 'User $publicUserId');
    final vip = json['vip'] is Map<String, dynamic> ? json['vip'] as Map<String, dynamic> : <String, dynamic>{};
    final svipLevel = _int(vip['svip_level']);
    final vipLevel = _int(vip['vip_level']);
    final isOwner = json['is_owner'] == true;
    final role = _text(json['primary_role']) ?? 'user';
    return SeatUser(
      id: 'user_$publicUserId',
      name: displayName,
      roleLabel: isOwner ? 'Channel Host' : _roleLabel(role),
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
      isRoomAdmin: isOwner,
    );
  }
}

String _roleLabel(String role) {
  final normalized = role.toLowerCase();
  if (normalized.contains('founder') || normalized.contains('owner')) return 'Official';
  if (normalized.contains('admin')) return 'Administrator';
  if (normalized.contains('monitor')) return 'Monitor';
  if (normalized.contains('cs')) return 'CS';
  return 'Member';
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
