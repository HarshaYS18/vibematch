import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api_service.dart';
import '../../auth/models/user_identity_snapshot.dart';
import 'live_room_membership_service.dart';
import '../presentation/live_room_models.dart';

class LiveRoomPresenceRepository {
  LiveRoomPresenceRepository({
    ApiClient? apiClient,
    AuthApiService? authApiService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _authApiService = authApiService ?? const AuthApiService();

  final ApiClient _apiClient;
  final AuthApiService _authApiService;

  static final ValueNotifier<List<SeatUser>> activeParticipants =
      ValueNotifier<List<SeatUser>>(const <SeatUser>[]);
  static String? _activeRoomId;

  static String? get currentRoomId => _activeRoomId;
  static List<SeatUser> get currentParticipants => activeParticipants.value;

  static void clearCachedPresence() {
    _activeRoomId = null;
    activeParticipants.value = const <SeatUser>[];
  }

  static List<SeatUser> currentParticipantsForRoom(String? roomId) {
    final cleanRoomId = roomId?.trim();
    if (cleanRoomId == null || cleanRoomId.isEmpty) return const <SeatUser>[];
    if (_activeRoomId != cleanRoomId) return const <SeatUser>[];
    return activeParticipants.value;
  }

  static SeatUser? userByRoomUserId(String userId) {
    for (final user in activeParticipants.value) {
      if (user.id == userId) return user;
    }
    return null;
  }

  static void clearIfRoomChanged(String roomId) {
    final cleanRoomId = roomId.trim();
    if (cleanRoomId.isEmpty) return;
    if (_activeRoomId == cleanRoomId) return;
    _activeRoomId = cleanRoomId;
    activeParticipants.value = const <SeatUser>[];
  }

  static void publishParticipants(
    List<SeatUser> participants, {
    String? roomId,
  }) {
    final cleanRoomId = roomId?.trim();
    if (cleanRoomId != null && cleanRoomId.isNotEmpty) {
      _activeRoomId = cleanRoomId;
    }

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

  static void _removeParticipant(String userId) {
    final next = activeParticipants.value
        .where((user) => user.id != userId)
        .toList(growable: false);
    if (next.length == activeParticipants.value.length) return;
    activeParticipants.value = List<SeatUser>.unmodifiable(next);
  }

  static void updateParticipantRoomAdmin({
    required String roomId,
    required String userId,
    required String displayName,
    required bool isRoomAdmin,
  }) {
    final cleanRoomId = roomId.trim();
    if (cleanRoomId.isNotEmpty) _activeRoomId = cleanRoomId;

    final existing = userByRoomUserId(userId);
    final nextUser =
        (existing ??
                SeatUser(
                  id: userId,
                  name: displayName.trim().isEmpty
                      ? 'Vibe User'
                      : displayName.trim(),
                  roleLabel: 'Member',
                  familyName: '',
                  relationshipText: '',
                  vipLevel: 0,
                  sendingLevel: 0,
                  receivingLevel: 0,
                  sentExp: 0,
                  receivedExp: 0,
                  medals: const [],
                  avatarColors: _avatarColors(userId),
                ))
            .copyWith(
              isRoomAdmin: isRoomAdmin,
              roleLabel: isRoomAdmin ? 'Admin' : 'Member',
            );

    publishParticipant(nextUser);
  }

  Future<LiveRoomPresenceSnapshot> joinRoom(
    String roomId, {
    String? lockPassword,
  }) => _postSnapshot(
    '/rooms/$roomId/join',
    body: {
      if (lockPassword != null && lockPassword.trim().isNotEmpty)
        'lock_password': lockPassword.trim(),
    },
  );

  Future<LiveRoomPresenceSnapshot> heartbeat(String roomId) =>
      _postSnapshot('/rooms/$roomId/heartbeat');

  Future<LiveRoomPresenceSnapshot> fetchParticipants(String roomId) async {
    final response = await _apiClient.getMap(
      '/rooms/$roomId/participants',
      headers: _headers(),
    );
    final snapshot = LiveRoomPresenceSnapshot.fromJson(response);
    final resolvedRoomId = snapshot.roomId.isEmpty ? roomId : snapshot.roomId;
    publishParticipants(
      LiveRoomPresenceSnapshot.onlineParticipants(response['participants']),
      roomId: resolvedRoomId,
    );
    LiveRoomMembershipService.applyBackendMembershipSnapshot(
      roomId: resolvedRoomId,
      roomMemberByUserId: snapshot.roomMemberByUserId,
      onlineCount: snapshot.onlineCount,
    );
    return snapshot;
  }

  Future<int> leaveRoom(String roomId) async {
    final response = await _apiClient.postMap(
      '/rooms/$roomId/leave',
      headers: _headers(),
    );
    return _int(response['online_count']);
  }

  Future<SeatUser> addRoomMember({
    required String roomId,
    required int publicUserId,
  }) async {
    final response = await _apiClient.postMap(
      '/rooms/$roomId/members',
      headers: _jsonHeaders(),
      body: {'public_user_id': publicUserId},
    );
    return _applyRosterMutation(roomId, response);
  }

  Future<SeatUser> removeRoomMember({
    required String roomId,
    required int publicUserId,
  }) async {
    final response = await _apiClient.deleteMap(
      '/rooms/$roomId/members/$publicUserId',
      headers: _headers(),
    );
    return _applyRosterMutation(roomId, response);
  }

  Future<SeatUser> addRoomAdmin({
    required String roomId,
    required int publicUserId,
  }) async {
    final response = await _apiClient.postMap(
      '/rooms/$roomId/admins',
      headers: _jsonHeaders(),
      body: {'public_user_id': publicUserId},
    );
    return _applyRosterMutation(roomId, response);
  }

  Future<SeatUser> removeRoomAdmin({
    required String roomId,
    required int publicUserId,
  }) async {
    final response = await _apiClient.deleteMap(
      '/rooms/$roomId/admins/$publicUserId',
      headers: _headers(),
    );
    return _applyRosterMutation(roomId, response);
  }

  SeatUser _applyRosterMutation(
    String roomId,
    Map<String, dynamic> response,
  ) {
    final user = LiveRoomPresenceSnapshot.participantToSeatUser(response);
    _activeRoomId = roomId;
    if (response['is_online'] == true) {
      publishParticipant(user);
    } else {
      _removeParticipant(user.id);
    }
    LiveRoomMembershipService.applyBackendMembershipSnapshot(
      roomId: roomId,
      roomMemberByUserId: {
        user.id: LiveRoomPresenceSnapshot.isRoomMemberParticipant(response),
      },
    );
    return user;
  }

  Future<LiveRoomPresenceSnapshot> _postSnapshot(
    String path, {
    Object? body,
  }) async {
    late final Map<String, dynamic> response;
    try {
      response = await _apiClient.postMap(
        path,
        headers: _headers(),
        body: body,
      );
    } on ApiException catch (error) {
      final body = error.body;
      if (body is Map<String, dynamic>) {
        final detail = body['detail'];
        if (detail != null && detail.toString().trim().isNotEmpty) {
          throw Exception(detail.toString().trim());
        }
      }
      rethrow;
    }
    final snapshot = LiveRoomPresenceSnapshot.fromJoinJson(response);
    publishParticipants(snapshot.participants, roomId: snapshot.roomId);
    LiveRoomMembershipService.applyBackendMembershipSnapshot(
      roomId: snapshot.roomId,
      roomMemberByUserId: snapshot.roomMemberByUserId,
      onlineCount: snapshot.onlineCount,
    );
    return snapshot;
  }

  Map<String, String> _headers() {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before entering rooms.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Map<String, String> _jsonHeaders() => {
    ..._headers(),
    'Content-Type': 'application/json',
  };

  void close() => _apiClient.close();
}

class LiveRoomPresenceSnapshot {
  const LiveRoomPresenceSnapshot({
    required this.roomId,
    required this.onlineCount,
    required this.participants,
    this.roomMemberByUserId = const <String, bool>{},
    this.joinedUser,
    this.shouldShowEnteredMessage = false,
  });

  final String roomId;
  final int onlineCount;
  final List<SeatUser> participants;
  final Map<String, bool> roomMemberByUserId;
  final SeatUser? joinedUser;
  final bool shouldShowEnteredMessage;

  factory LiveRoomPresenceSnapshot.fromJoinJson(Map<String, dynamic> json) {
    final room = json['room'] is Map<String, dynamic>
        ? json['room'] as Map<String, dynamic>
        : <String, dynamic>{};
    final joinedRaw = json['joined_user'];
    return LiveRoomPresenceSnapshot(
      roomId: room['id']?.toString() ?? '',
      onlineCount: _int(room['online_count']),
      participants: onlineParticipants(json['participants']),
      roomMemberByUserId: roomMembershipByUserId(json['participants']),
      joinedUser: joinedRaw is Map<String, dynamic>
          ? participantToSeatUser(joinedRaw)
          : null,
      shouldShowEnteredMessage: json['should_show_entered_message'] == true,
    );
  }

  factory LiveRoomPresenceSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveRoomPresenceSnapshot(
      roomId: json['room_id']?.toString() ?? '',
      onlineCount: _int(json['online_count']),
      participants: _participants(json['participants']),
      roomMemberByUserId: roomMembershipByUserId(json['participants']),
    );
  }

  static Map<String, bool> roomMembershipByUserId(dynamic raw) {
    if (raw is! List) return const <String, bool>{};
    final result = <String, bool>{};
    for (final participant in raw.whereType<Map<String, dynamic>>()) {
      final identity = UserIdentitySnapshot.fromJson(participant);
      if (identity.backendUserId <= 0 && identity.publicUserId <= 0) continue;
      result[identity.roomUserId] = isRoomMemberParticipant(participant);
    }
    return Map<String, bool>.unmodifiable(result);
  }

  static bool isRoomMemberParticipant(Map<String, dynamic> json) {
    return json['is_member'] == true ||
        json['is_room_member'] == true ||
        json['is_room_admin'] == true ||
        json['is_owner'] == true;
  }

  static List<SeatUser> onlineParticipants(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .where((participant) => participant['is_online'] == true)
        .map(participantToSeatUser)
        .toList(growable: false);
  }

  static List<SeatUser> _participants(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(participantToSeatUser)
        .toList(growable: false);
  }

  static SeatUser participantToSeatUser(Map<String, dynamic> json) {
    final identity = UserIdentitySnapshot.fromJson(json);
    final isOwner = json['is_owner'] == true;
    final isRoomAdmin = json['is_room_admin'] == true;
    final isMember = json['is_member'] == true;
    final roleLabel = isOwner
        ? 'Channel Host'
        : isRoomAdmin
        ? 'Admin'
        : isMember
        ? 'Member'
        : identity.roleDisplayLabel;

    final avatarFrame = identity.equippedItems.avatarFrame;
    final chatBubble = identity.equippedItems.chatBubble;

    return SeatUser(
      id: identity.roomUserId,
      name: identity.visibleName,
      roleLabel: roleLabel,
      familyName: '',
      familyLevel: 'bronze',
      relationshipText: '',
      vipLevel: identity.vip.vipLevel,
      svipLevel: identity.vip.svipLevel,
      sendingLevel: identity.sendLevel,
      receivingLevel: identity.receiveLevel,
      sentExp: identity.sentExp,
      receivedExp: identity.receivedExp,
      medals: const [],
      avatarColors: _avatarColors(
        identity.publicUserId > 0
            ? identity.publicUserId.toString()
            : identity.roomUserId,
      ),
      nameGradientColors: identity.vip.nameGradientColors,
      avatarUrl: identity.avatarUrl,
      equippedAvatarFrameAssetPath: avatarFrame?.assetPath,
      equippedAvatarFrameImageUrl: avatarFrame?.bestImageUrl,
      equippedChatBubbleAssetPath: chatBubble?.assetPath,
      equippedChatBubbleImageUrl: chatBubble?.bestImageUrl,
      isHost: isOwner,
      isRoomAdmin: isRoomAdmin || isOwner,
    );
  }
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

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
