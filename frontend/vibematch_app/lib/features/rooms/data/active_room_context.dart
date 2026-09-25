import 'live_room_media_signaling_service.dart';

/// Read-only compatibility view of the currently scoped media room.
///
/// Chunk 33 removed the process-global mutable room-id/name cache. Canonical
/// room state lives in RoomSessionRepository; media transport exposes its
/// currently attached room only for legacy command routing.
class ActiveRoomContext {
  const ActiveRoomContext._();

  static String? get roomPublicId {
    final value =
        LiveRoomMediaSignalingService.instance.roomId?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String? get roomName {
    final value =
        LiveRoomMediaSignalingService.instance.roomName?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @Deprecated(
    'Room identity is scoped by RoomSessionRepository. '
    'Configure media transport at room entry only.',
  )
  static void setActiveRoom({
    required String roomPublicId,
    required String roomName,
  }) {
    LiveRoomMediaSignalingService.instance.configureRoom(
      roomId: roomPublicId,
      roomName: roomName,
    );
  }

  @Deprecated('Room lifecycle owns transport detach; no global cache remains.')
  static void clear() {}

  @Deprecated('Room lifecycle owns transport detach; no global cache remains.')
  static void clearIfMatches(String roomPublicId) {}
}
