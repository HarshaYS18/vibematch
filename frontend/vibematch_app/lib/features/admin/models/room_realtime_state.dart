class RoomRealtimeState {
  const RoomRealtimeState({
    required this.roomId,
    required this.seats,
    required this.updatedAt,
  });

  factory RoomRealtimeState.fromJson(Map<String, dynamic> json) {
    final rawSeats = json['seats'];
    return RoomRealtimeState(
      roomId: json['room_id']?.toString() ?? '',
      seats: rawSeats is List
          ? rawSeats
              .whereType<Map<String, dynamic>>()
              .map(RoomRealtimeSeatState.fromJson)
              .toList(growable: false)
          : const [],
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String roomId;
  final List<RoomRealtimeSeatState> seats;
  final DateTime updatedAt;

  int get occupiedCount => seats.where((seat) => seat.user != null).length;
  int get lockedCount => seats.where((seat) => seat.locked).length;
  int get selfMutedCount => seats.where((seat) => seat.user?.selfMuted == true).length;
  int get adminMutedCount => seats.where((seat) => seat.user?.adminMuted == true).length;
}

class RoomRealtimeSeatState {
  const RoomRealtimeSeatState({
    required this.seatIndex,
    required this.locked,
    this.user,
  });

  factory RoomRealtimeSeatState.fromJson(Map<String, dynamic> json) {
    final userPayload = json['user'];
    return RoomRealtimeSeatState(
      seatIndex: _intValue(json['seat_index']),
      locked: _boolValue(json['locked']),
      user: userPayload is Map<String, dynamic>
          ? RoomRealtimeSeatUser.fromJson(userPayload)
          : null,
    );
  }

  final int seatIndex;
  final bool locked;
  final RoomRealtimeSeatUser? user;

  bool get occupied => user != null;

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _boolValue(Object? value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }
}

class RoomRealtimeSeatUser {
  const RoomRealtimeSeatUser({
    required this.userId,
    required this.displayName,
    required this.selfMuted,
    required this.adminMuted,
  });

  factory RoomRealtimeSeatUser.fromJson(Map<String, dynamic> json) {
    return RoomRealtimeSeatUser(
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'Guest',
      selfMuted: _boolValue(json['self_muted']),
      adminMuted: _boolValue(json['admin_muted']),
    );
  }

  final String userId;
  final String displayName;
  final bool selfMuted;
  final bool adminMuted;

  static bool _boolValue(Object? value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }
}
