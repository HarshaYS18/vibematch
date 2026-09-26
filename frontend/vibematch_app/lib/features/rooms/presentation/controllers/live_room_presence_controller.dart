/// Compatibility lifecycle shim retained for legacy widgets.
///
/// Room entry/exit is owned by RoomSessionRepository and online liveness is
/// owned by the authenticated realtime socket lease. This controller must never
/// perform presence network writes.
class LiveRoomPresenceController {
  bool _left = true;

  void start({
    required String roomPublicId,
    required String roomName,
    required String roomMode,
    required bool isSecret,
  }) {
    _left = false;
  }

  void updateRoom({
    required String roomPublicId,
    required String roomName,
    required String roomMode,
    required bool isSecret,
  }) {}

  Future<void> leave() async {
    if (_left) return;
    _left = true;
  }

  void dispose() {}
}
