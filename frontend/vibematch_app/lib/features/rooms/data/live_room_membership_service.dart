import 'package:flutter/foundation.dart';

enum LiveRoomMembershipStatus {
  guest,
  pending,
  roomMember,
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

  String get key =>
      LiveRoomMembershipService.keyFor(roomId: roomId, userId: userId);

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

/// In-memory projection of backend room-membership truth.
///
/// Permanent membership must never be approved by Flutter. [markPending] is
/// allowed for temporary request UI, while [applyBackendMembershipSnapshot]
/// is the only path that confirms or removes room-member state.
class LiveRoomMembershipService {
  const LiveRoomMembershipService._();

  static final ValueNotifier<Map<String, LiveRoomMembershipSnapshot>> snapshots =
      ValueNotifier(<String, LiveRoomMembershipSnapshot>{});

  static String normalizeUserId(String userId) {
    final clean = userId.trim();
    if (clean.isEmpty) return '';
    final match = RegExp(
      r'^user_(\d+)$',
      caseSensitive: false,
    ).firstMatch(clean);
    return match?.group(1) ?? clean.toLowerCase();
  }

  static String keyFor({required String roomId, required String userId}) =>
      '${roomId.trim()}::${normalizeUserId(userId)}';

  static LiveRoomMembershipStatus statusFor({
    required String roomId,
    required String userId,
  }) {
    return snapshots.value[keyFor(roomId: roomId, userId: userId)]?.status ??
        LiveRoomMembershipStatus.guest;
  }

  static bool isRoomMember({required String roomId, required String userId}) {
    return statusFor(roomId: roomId, userId: userId) ==
        LiveRoomMembershipStatus.roomMember;
  }

  static bool isPending({required String roomId, required String userId}) {
    return statusFor(roomId: roomId, userId: userId) ==
        LiveRoomMembershipStatus.pending;
  }

  static List<LiveRoomMembershipSnapshot> roomMemberSnapshotsForRoom(
    String roomId,
  ) {
    final cleanRoomId = roomId.trim();
    return snapshots.value.values
        .where((item) => item.roomId.trim() == cleanRoomId)
        .where((item) => item.status == LiveRoomMembershipStatus.roomMember)
        .toList(growable: false);
  }

  static List<LiveRoomMembershipSnapshot> memberRoomsForUserIds(
    Set<String> userIds,
  ) {
    final normalizedIds = userIds
        .map(normalizeUserId)
        .where((item) => item.isNotEmpty)
        .toSet();

    return snapshots.value.values
        .where((item) => normalizedIds.contains(normalizeUserId(item.userId)))
        .where((item) => item.status == LiveRoomMembershipStatus.roomMember)
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

  /// Applies membership flags returned by a backend room snapshot or roster
  /// mutation. Users not present in [roomMemberByUserId] are left untouched;
  /// this avoids treating an online-participant list as a complete room roster.
  static void applyBackendMembershipSnapshot({
    required String roomId,
    required Map<String, bool> roomMemberByUserId,
    bool completeRoster = false,
    String? roomName,
    String? language,
    String? modeTitle,
    int? onlineCount,
  }) {
    final cleanRoomId = roomId.trim();
    if (cleanRoomId.isEmpty) return;

    final next = Map<String, LiveRoomMembershipSnapshot>.from(snapshots.value);
    final seenKeys = <String>{};
    for (final entry in roomMemberByUserId.entries) {
      final normalizedUserId = normalizeUserId(entry.key);
      if (normalizedUserId.isEmpty) continue;

      final key = keyFor(roomId: cleanRoomId, userId: normalizedUserId);
      seenKeys.add(key);
      final previous = next[key];
      final backendStatus = entry.value
          ? LiveRoomMembershipStatus.roomMember
          : LiveRoomMembershipStatus.guest;

      // Pending is temporary UI state until the backend explicitly approves
      // membership. A generic participant snapshot with is_member=false does
      // not prove that a separate pending request was rejected.
      final nextStatus =
          !entry.value && previous?.status == LiveRoomMembershipStatus.pending
          ? LiveRoomMembershipStatus.pending
          : backendStatus;

      next[key] = LiveRoomMembershipSnapshot(
        roomId: cleanRoomId,
        userId: normalizedUserId,
        status: nextStatus,
        roomName: roomName ?? previous?.roomName,
        language: language ?? previous?.language,
        modeTitle: modeTitle ?? previous?.modeTitle,
        onlineCount: onlineCount ?? previous?.onlineCount,
      );
    }

    if (completeRoster) {
      for (final entry in next.entries.toList(growable: false)) {
        final previous = entry.value;
        if (previous.roomId.trim() != cleanRoomId ||
            seenKeys.contains(entry.key) ||
            previous.status == LiveRoomMembershipStatus.pending) {
          continue;
        }

        next[entry.key] = previous.copyWith(
          status: LiveRoomMembershipStatus.guest,
          roomName: roomName,
          language: language,
          modeTitle: modeTitle,
          onlineCount: onlineCount,
        );
      }
    }

    snapshots.value = Map<String, LiveRoomMembershipSnapshot>.unmodifiable(next);
  }

  /// Backward-compatible entry point for older callers. New code must confirm
  /// membership via [applyBackendMembershipSnapshot] from a backend response.
  @Deprecated('Use applyBackendMembershipSnapshot with backend response data.')
  static void markRoomMember({
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
      status: LiveRoomMembershipStatus.roomMember,
      roomName: roomName,
      language: language,
      modeTitle: modeTitle,
      onlineCount: onlineCount,
    );
  }

  @Deprecated('Use applyBackendMembershipSnapshot with backend response data.')
  static void markMember({
    required String roomId,
    required String userId,
    String? roomName,
    String? language,
    String? modeTitle,
    int? onlineCount,
  }) {
    markRoomMember(
      roomId: roomId,
      userId: userId,
      roomName: roomName,
      language: language,
      modeTitle: modeTitle,
      onlineCount: onlineCount,
    );
  }

  static void markGuest({required String roomId, required String userId}) {
    _setStatus(
      roomId: roomId,
      userId: userId,
      status: LiveRoomMembershipStatus.guest,
    );
  }

  static void clearAll() {
    if (snapshots.value.isEmpty) return;
    snapshots.value = <String, LiveRoomMembershipSnapshot>{};
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
    final cleanUserId = normalizeUserId(userId);
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

    snapshots.value = Map<String, LiveRoomMembershipSnapshot>.unmodifiable(next);
  }
}
