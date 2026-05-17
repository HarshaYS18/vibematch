import 'package:flutter/foundation.dart';

enum LiveRoomMembershipStatus {
  guest,
  pending,
  member,
}

class LiveRoomMembershipSnapshot {
  const LiveRoomMembershipSnapshot({
    required this.roomId,
    required this.userId,
    required this.status,
    this.roomName,
    this.language,
    this.modeTitle,
    this.onlineCount,
  });

  final String roomId;
  final String userId;
  final LiveRoomMembershipStatus status;
  final String? roomName;
  final String? language;
  final String? modeTitle;
  final int? onlineCount;

  String get key => LiveRoomMembershipService.keyFor(roomId: roomId, userId: userId);

  LiveRoomMembershipSnapshot copyWith({
    LiveRoomMembershipStatus? status,
    String? roomName,
    String? language,
    String? modeTitle,
    int? onlineCount,
  }) {
    return LiveRoomMembershipSnapshot(
      roomId: roomId,
      userId: userId,
      status: status ?? this.status,
      roomName: roomName ?? this.roomName,
      language: language ?? this.language,
      modeTitle: modeTitle ?? this.modeTitle,
      onlineCount: onlineCount ?? this.onlineCount,
    );
  }
}

class LiveRoomMembershipService {
  const LiveRoomMembershipService._();

  static final ValueNotifier<Map<String, LiveRoomMembershipSnapshot>> snapshots =
      ValueNotifier(<String, LiveRoomMembershipSnapshot>{});

  static String keyFor({required String roomId, required String userId}) => '${roomId.trim()}::${userId.trim()}';

  static LiveRoomMembershipStatus statusFor({required String roomId, required String userId}) {
    final status = snapshots.value[keyFor(roomId: roomId, userId: userId)]?.status;

    // Production rule:
    // Local cache may only represent a pending request. Approved room_member
    // status must come from the backend room snapshot (`Room Member` /
    // is_room_member), otherwise stale local cache can show the member shield
    // for normal visitors.
    if (status == LiveRoomMembershipStatus.pending) {
      return LiveRoomMembershipStatus.pending;
    }
    return LiveRoomMembershipStatus.guest;
  }

  static List<LiveRoomMembershipSnapshot> memberRoomsForUserIds(Set<String> userIds) {
    final normalizedIds = userIds.map((item) => item.trim()).where((item) => item.isNotEmpty).toSet();

    return snapshots.value.values
        .where((item) => normalizedIds.contains(item.userId.trim()))
        .where((item) => item.status == LiveRoomMembershipStatus.member)
        .toList(growable: false);
  }

  static void markPending({
    required String roomId,
    required String userId,
    String? roomName,
    String? language,
    String? modeTitle,
    int? onlineCount,
  }) {
    _setStatus(
      roomId: roomId,
      userId: userId,
      status: LiveRoomMembershipStatus.pending,
      roomName: roomName,
      language: language,
      modeTitle: modeTitle,
      onlineCount: onlineCount,
    );
  }

  static void markMember({
    required String roomId,
    required String userId,
    String? roomName,
    String? language,
    String? modeTitle,
    int? onlineCount,
  }) {
    _setStatus(
      roomId: roomId,
      userId: userId,
      status: LiveRoomMembershipStatus.member,
      roomName: roomName,
      language: language,
      modeTitle: modeTitle,
      onlineCount: onlineCount,
    );
  }

  static void markGuest({required String roomId, required String userId}) {
    _setStatus(roomId: roomId, userId: userId, status: LiveRoomMembershipStatus.guest);
  }

  static void _setStatus({
    required String roomId,
    required String userId,
    required LiveRoomMembershipStatus status,
    String? roomName,
    String? language,
    String? modeTitle,
    int? onlineCount,
  }) {
    final cleanRoomId = roomId.trim();
    final cleanUserId = userId.trim();
    if (cleanRoomId.isEmpty || cleanUserId.isEmpty) return;

    final key = keyFor(roomId: cleanRoomId, userId: cleanUserId);
    final previous = snapshots.value[key];
    final next = Map<String, LiveRoomMembershipSnapshot>.from(snapshots.value);

    next[key] = (previous ??
            LiveRoomMembershipSnapshot(
              roomId: cleanRoomId,
              userId: cleanUserId,
              status: status,
            ))
        .copyWith(
      status: status,
      roomName: roomName,
      language: language,
      modeTitle: modeTitle,
      onlineCount: onlineCount,
    );

    snapshots.value = next;
  }
}
