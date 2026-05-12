import 'package:flutter/foundation.dart';

enum LiveRoomMembershipStatus {
  guest,
  pending,
  member,
}

class LiveRoomMembershipSnapshot {
  const LiveRoomMembershipSnapshot({required this.roomId, required this.userId, required this.status});

  final String roomId;
  final String userId;
  final LiveRoomMembershipStatus status;

  String get key => LiveRoomMembershipService.keyFor(roomId: roomId, userId: userId);
}

class LiveRoomMembershipService {
  const LiveRoomMembershipService._();

  static final ValueNotifier<Map<String, LiveRoomMembershipSnapshot>> snapshots = ValueNotifier(<String, LiveRoomMembershipSnapshot>{});

  static String keyFor({required String roomId, required String userId}) => '${roomId.trim()}::${userId.trim()}';

  static LiveRoomMembershipStatus statusFor({required String roomId, required String userId}) {
    return snapshots.value[keyFor(roomId: roomId, userId: userId)]?.status ?? LiveRoomMembershipStatus.guest;
  }

  static void markPending({required String roomId, required String userId}) {
    _setStatus(roomId: roomId, userId: userId, status: LiveRoomMembershipStatus.pending);
  }

  static void markMember({required String roomId, required String userId}) {
    _setStatus(roomId: roomId, userId: userId, status: LiveRoomMembershipStatus.member);
  }

  static void markGuest({required String roomId, required String userId}) {
    _setStatus(roomId: roomId, userId: userId, status: LiveRoomMembershipStatus.guest);
  }

  static void _setStatus({required String roomId, required String userId, required LiveRoomMembershipStatus status}) {
    final cleanRoomId = roomId.trim();
    final cleanUserId = userId.trim();
    if (cleanRoomId.isEmpty || cleanUserId.isEmpty) return;
    final next = Map<String, LiveRoomMembershipSnapshot>.from(snapshots.value);
    next[keyFor(roomId: cleanRoomId, userId: cleanUserId)] = LiveRoomMembershipSnapshot(roomId: cleanRoomId, userId: cleanUserId, status: status);
    snapshots.value = next;
  }
}
