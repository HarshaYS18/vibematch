enum RoomSessionConnection {
  idle,
  joining,
  connected,
  reconnecting,
  leaving,
  left,
  failed,
}

class RoomSessionParticipant {
  const RoomSessionParticipant({
    required this.backendUserId,
    required this.publicUserId,
    required this.roomUserKey,
    required this.displayName,
    required this.avatarUrl,
    required this.isPresent,
    required this.isMember,
    required this.isAdmin,
    required this.isHost,
    required this.seatIndex,
    required this.micEnabled,
    required this.adminMuted,
    required this.raw,
  });

  final int backendUserId;
  final int publicUserId;
  final String roomUserKey;
  final String displayName;
  final String? avatarUrl;

  /// Active room presence. Presence does not imply durable membership.
  final bool isPresent;

  /// Durable membership. Membership does not imply presence or a stage seat.
  final bool isMember;
  final bool isAdmin;
  final bool isHost;

  /// Stage occupancy. Null means this present user is in the audience.
  final int? seatIndex;
  final bool micEnabled;
  final bool adminMuted;
  final Map<String, dynamic> raw;

  bool get isSeated => seatIndex != null;

  factory RoomSessionParticipant.fromJson(Map<String, dynamic> json) {
    final backendUserId =
        _nullableInt(json['backend_user_id']) ??
        _nullableInt(json['user_id']) ??
        0;
    final publicUserId =
        _nullableInt(json['public_user_id']) ?? backendUserId;
    return RoomSessionParticipant(
      backendUserId: backendUserId,
      publicUserId: publicUserId,
      roomUserKey:
          _text(json['room_user_key']) ?? 'user_$publicUserId',
      displayName:
          _text(json['display_name']) ??
          _text(json['username']) ??
          publicUserId.toString(),
      avatarUrl: _text(json['avatar_url']),
      isPresent: _bool(json['is_active'], fallback: true),
      isMember: _bool(
        json['is_room_member'] ?? json['is_member'],
        fallback: false,
      ),
      isAdmin: _bool(json['is_room_admin'], fallback: false),
      isHost: _bool(
        json['is_host'] ?? json['is_room_owner'] ?? json['is_owner'],
        fallback: false,
      ),
      seatIndex: _nullableInt(json['seat_index']),
      micEnabled: _bool(json['mic_enabled'], fallback: false),
      adminMuted: _bool(json['admin_muted'], fallback: false),
      raw: Map<String, dynamic>.unmodifiable(json),
    );
  }
}

class RoomMembershipEntry {
  const RoomMembershipEntry({
    required this.backendUserId,
    required this.publicUserId,
    required this.isMember,
    required this.isAdmin,
    required this.isHost,
    required this.raw,
  });

  final int backendUserId;
  final int publicUserId;
  final bool isMember;
  final bool isAdmin;
  final bool isHost;
  final Map<String, dynamic> raw;

  factory RoomMembershipEntry.fromJson(Map<String, dynamic> json) {
    final backendUserId =
        _nullableInt(json['backend_user_id']) ??
        _nullableInt(json['user_id']) ??
        0;
    return RoomMembershipEntry(
      backendUserId: backendUserId,
      publicUserId:
          _nullableInt(json['public_user_id']) ?? backendUserId,
      isMember: _bool(
        json['is_room_member'] ?? json['is_member'],
        fallback: false,
      ),
      isAdmin: _bool(json['is_room_admin'], fallback: false),
      isHost: _bool(
        json['is_host'] ?? json['is_room_owner'] ?? json['is_owner'],
        fallback: false,
      ),
      raw: Map<String, dynamic>.unmodifiable(json),
    );
  }
}

class RoomSessionSeat {
  const RoomSessionSeat({
    required this.index,
    required this.occupantBackendUserId,
    required this.occupantPublicUserId,
    required this.locked,
    required this.micEnabled,
    required this.adminMuted,
    required this.raw,
  });

  final int index;
  final int? occupantBackendUserId;
  final int? occupantPublicUserId;
  final bool locked;
  final bool micEnabled;
  final bool adminMuted;
  final Map<String, dynamic> raw;

  bool get occupied => occupantBackendUserId != null;

  factory RoomSessionSeat.fromJson(Map<String, dynamic> json) {
    return RoomSessionSeat(
      index: _nullableInt(json['seat_index']) ?? -1,
      occupantBackendUserId:
          _nullableInt(json['occupant_backend_user_id']) ??
          _nullableInt(json['occupant_user_id']),
      occupantPublicUserId: _nullableInt(json['occupant_public_user_id']),
      locked: _bool(json['is_locked'], fallback: false),
      micEnabled: _bool(json['mic_enabled'], fallback: false),
      adminMuted: _bool(json['admin_muted'], fallback: false),
      raw: Map<String, dynamic>.unmodifiable(json),
    );
  }
}

class RoomSessionState {
  const RoomSessionState({
    required this.roomId,
    required this.connection,
    required this.room,
    required this.presence,
    required this.audience,
    required this.membershipRoster,
    required this.members,
    required this.admins,
    required this.seats,
    required this.stage,
    required this.permissions,
    required this.restrictions,
    required this.chat,
    required this.gifts,
    required this.activities,
    required this.media,
    required this.watchParty,
    required this.onlineCount,
    required this.stateVersion,
    required this.eventSequence,
    required this.errorMessage,
  });

  factory RoomSessionState.initial(String roomId) {
    return RoomSessionState(
      roomId: roomId,
      connection: RoomSessionConnection.idle,
      room: const <String, dynamic>{},
      presence: const <int, RoomSessionParticipant>{},
      audience: const <int, RoomSessionParticipant>{},
      membershipRoster: const <int, RoomMembershipEntry>{},
      members: const <int>{},
      admins: const <int>{},
      seats: const <int, RoomSessionSeat>{},
      stage: const <String, dynamic>{},
      permissions: const <String, bool>{},
      restrictions: const <String, dynamic>{},
      chat: const <Map<String, dynamic>>[],
      gifts: const <String, dynamic>{},
      activities: const <String, dynamic>{},
      media: const <String, dynamic>{},
      watchParty: const <String, dynamic>{},
      onlineCount: 0,
      stateVersion: 0,
      eventSequence: 0,
      errorMessage: null,
    );
  }

  final String roomId;
  final RoomSessionConnection connection;
  final Map<String, dynamic> room;

  /// All active participants, including users currently on stage.
  final Map<int, RoomSessionParticipant> presence;

  /// Active participants who are not occupying a seat.
  final Map<int, RoomSessionParticipant> audience;

  /// Durable membership independently of current presence.
  final Map<int, RoomMembershipEntry> membershipRoster;
  final Set<int> members;
  final Set<int> admins;

  /// Stage/seat occupancy independently of presence and membership.
  final Map<int, RoomSessionSeat> seats;
  final Map<String, dynamic> stage;

  /// Explicit backend-projected user capabilities only. Empty means the
  /// backend did not project per-user permissions; no capability is inferred.
  final Map<String, bool> permissions;
  final Map<String, dynamic> restrictions;
  final List<Map<String, dynamic>> chat;
  final Map<String, dynamic> gifts;
  final Map<String, dynamic> activities;
  final Map<String, dynamic> media;
  final Map<String, dynamic> watchParty;

  final int onlineCount;
  final int stateVersion;
  final int eventSequence;
  final String? errorMessage;

  bool get isJoined =>
      connection == RoomSessionConnection.connected ||
      connection == RoomSessionConnection.reconnecting;

  RoomSessionParticipant? participantByPublicUserId(int publicUserId) {
    for (final participant in presence.values) {
      if (participant.publicUserId == publicUserId) return participant;
    }
    return null;
  }

  factory RoomSessionState.fromSnapshot(
    Map<String, dynamic> snapshot, {
    required RoomSessionConnection connection,
  }) {
    final roomId =
        _text(snapshot['room_id']) ??
        _text(snapshot['room_public_id']) ??
        '';

    final presence = <int, RoomSessionParticipant>{};
    final audience = <int, RoomSessionParticipant>{};
    for (final item in _mapList(snapshot['participants'])) {
      final participant = RoomSessionParticipant.fromJson(item);
      if (participant.backendUserId <= 0) continue;
      presence[participant.backendUserId] = participant;
      if (!participant.isSeated) {
        audience[participant.backendUserId] = participant;
      }
    }

    final membershipRoster = <int, RoomMembershipEntry>{};
    final members = <int>{};
    final admins = <int>{};
    for (final item in _mapList(snapshot['membership_roster'])) {
      final entry = RoomMembershipEntry.fromJson(item);
      if (entry.backendUserId <= 0) continue;
      membershipRoster[entry.backendUserId] = entry;
      if (entry.isMember || entry.isAdmin || entry.isHost) {
        members.add(entry.backendUserId);
      }
      if (entry.isAdmin || entry.isHost) {
        admins.add(entry.backendUserId);
      }
    }

    final seats = <int, RoomSessionSeat>{};
    for (final item in _mapList(snapshot['seats'])) {
      final seat = RoomSessionSeat.fromJson(item);
      if (seat.index >= 0) seats[seat.index] = seat;
    }

    final pendingMemberRequests = _mapList(
      snapshot['pending_room_member_requests'],
    );
    final pendingSeatApplications = _mapList(
      snapshot['pending_seat_applications'],
    );

    return RoomSessionState(
      roomId: roomId,
      connection: connection,
      room: Map<String, dynamic>.unmodifiable(snapshot),
      presence: Map<int, RoomSessionParticipant>.unmodifiable(presence),
      audience: Map<int, RoomSessionParticipant>.unmodifiable(audience),
      membershipRoster:
          Map<int, RoomMembershipEntry>.unmodifiable(membershipRoster),
      members: Set<int>.unmodifiable(members),
      admins: Set<int>.unmodifiable(admins),
      seats: Map<int, RoomSessionSeat>.unmodifiable(seats),
      stage: Map<String, dynamic>.unmodifiable(<String, dynamic>{
        'seat_layout_id': snapshot['seat_layout_id'],
        'seat_count': _nullableInt(snapshot['seat_count']) ?? seats.length,
        'active_seated_count':
            _nullableInt(snapshot['active_seated_count']) ??
            seats.values.where((seat) => seat.occupied).length,
      }),
      permissions: Map<String, bool>.unmodifiable(
        _boolMap(snapshot['permissions']),
      ),
      restrictions: Map<String, dynamic>.unmodifiable(<String, dynamic>{
        'is_secret': _bool(snapshot['is_secret'], fallback: false),
        'is_locked': _bool(snapshot['is_locked'], fallback: false),
        'is_members_only': _bool(
          snapshot['is_members_only'],
          fallback: false,
        ),
      }),
      chat: List<Map<String, dynamic>>.unmodifiable(
        _mapList(snapshot['recent_messages']),
      ),
      gifts: Map<String, dynamic>.unmodifiable(_map(snapshot['gifts'])),
      activities: Map<String, dynamic>.unmodifiable(<String, dynamic>{
        ..._map(snapshot['activity']),
        'pending_room_member_requests': pendingMemberRequests,
        'pending_seat_applications': pendingSeatApplications,
      }),
      media: Map<String, dynamic>.unmodifiable(<String, dynamic>{
        ..._map(snapshot['media']),
        'background_theme_id': snapshot['background_theme_id'],
        'seat_layout_id': snapshot['seat_layout_id'],
      }),
      watchParty:
          Map<String, dynamic>.unmodifiable(_map(snapshot['watch_party'])),
      onlineCount:
          _nullableInt(snapshot['public_online_count']) ??
          _nullableInt(snapshot['online_count']) ??
          presence.length,
      stateVersion:
          _nullableInt(snapshot['state_version']) ??
          _nullableInt(snapshot['room_version']) ??
          0,
      eventSequence: _nullableInt(snapshot['event_sequence']) ?? 0,
      errorMessage: null,
    );
  }

  RoomSessionState copyWith({
    RoomSessionConnection? connection,
    Map<String, dynamic>? room,
    Map<int, RoomSessionParticipant>? presence,
    Map<int, RoomSessionParticipant>? audience,
    Map<int, RoomMembershipEntry>? membershipRoster,
    Set<int>? members,
    Set<int>? admins,
    Map<int, RoomSessionSeat>? seats,
    Map<String, dynamic>? stage,
    Map<String, bool>? permissions,
    Map<String, dynamic>? restrictions,
    List<Map<String, dynamic>>? chat,
    Map<String, dynamic>? gifts,
    Map<String, dynamic>? activities,
    Map<String, dynamic>? media,
    Map<String, dynamic>? watchParty,
    int? onlineCount,
    int? stateVersion,
    int? eventSequence,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RoomSessionState(
      roomId: roomId,
      connection: connection ?? this.connection,
      room: room ?? this.room,
      presence: presence ?? this.presence,
      audience: audience ?? this.audience,
      membershipRoster: membershipRoster ?? this.membershipRoster,
      members: members ?? this.members,
      admins: admins ?? this.admins,
      seats: seats ?? this.seats,
      stage: stage ?? this.stage,
      permissions: permissions ?? this.permissions,
      restrictions: restrictions ?? this.restrictions,
      chat: chat ?? this.chat,
      gifts: gifts ?? this.gifts,
      activities: activities ?? this.activities,
      media: media ?? this.media,
      watchParty: watchParty ?? this.watchParty,
      onlineCount: onlineCount ?? this.onlineCount,
      stateVersion: stateVersion ?? this.stateVersion,
      eventSequence: eventSequence ?? this.eventSequence,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

Map<String, bool> _boolMap(dynamic value) {
  if (value is! Map) return const <String, bool>{};
  final result = <String, bool>{};
  for (final entry in value.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty || entry.value is! bool) continue;
    result[key] = entry.value as bool;
  }
  return result;
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList(growable: false);
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _nullableInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

bool _bool(dynamic value, {required bool fallback}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' ||
      normalized == '0' ||
      normalized == 'no') {
    return false;
  }
  return fallback;
}
