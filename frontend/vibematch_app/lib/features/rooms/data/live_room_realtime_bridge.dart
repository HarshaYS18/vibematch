abstract class LiveRoomRealtimeSeatApplier {
  void applyRemoteSeatOccupy({
    required int seatIndex,
    required String userId,
    required String displayName,
  });

  void applyRemoteSeatLeave({required int seatIndex});

  void applyRemoteSeatSwitch({
    required int fromSeatIndex,
    required int toSeatIndex,
    required String userId,
    required String displayName,
  });

  void applyRemoteSeatLock({required int seatIndex});

  void applyRemoteSeatUnlock({required int seatIndex});

  void applyRemoteSelfMute({
    required String userId,
    required bool muted,
  });

  void applyRemoteAdminMute({
    required String userId,
    required bool muted,
  });

  void applyRemoteRoomStateSnapshot(Map<String, dynamic> payload);
}

class LiveRoomRealtimeBridge {
  const LiveRoomRealtimeBridge._();

  static String? _roomId;
  static String? _userId;
  static void Function({
    required String type,
    String? roomId,
    String? userId,
    String? requestId,
    Map<String, dynamic> payload,
  })? _sendEvent;

  static LiveRoomRealtimeSeatApplier? _seatApplier;

  static void attachSocket({
    required String roomId,
    required String userId,
    required void Function({
      required String type,
      String? roomId,
      String? userId,
      String? requestId,
      Map<String, dynamic> payload,
    }) sendEvent,
  }) {
    _roomId = roomId;
    _userId = userId;
    _sendEvent = sendEvent;
  }

  static void detachSocket() {
    _roomId = null;
    _userId = null;
    _sendEvent = null;
  }

  static void registerSeatApplier(LiveRoomRealtimeSeatApplier applier) {
    _seatApplier = applier;
  }

  static void unregisterSeatApplier(LiveRoomRealtimeSeatApplier applier) {
    if (identical(_seatApplier, applier)) {
      _seatApplier = null;
    }
  }

  static void sendSeatOccupy(int seatIndex) {
    _sendRoomStateEvent('room.seat.occupy', {'seat_index': seatIndex});
  }

  static void sendSeatLeave(int seatIndex) {
    _sendRoomStateEvent('room.seat.leave', {'seat_index': seatIndex});
  }

  static void sendSeatSwitch({
    required int fromSeatIndex,
    required int toSeatIndex,
  }) {
    _sendRoomStateEvent('room.seat.switch', {
      'from_seat_index': fromSeatIndex,
      'to_seat_index': toSeatIndex,
    });
  }

  static void sendSeatLock(int seatIndex) {
    _sendRoomStateEvent('room.seat.lock', {'seat_index': seatIndex});
  }

  static void sendSeatUnlock(int seatIndex) {
    _sendRoomStateEvent('room.seat.unlock', {'seat_index': seatIndex});
  }

  static void sendSelfMute(bool muted) {
    final userId = _userId;
    if (userId == null) return;
    _sendRoomStateEvent(
      muted ? 'room.mic.self_mute' : 'room.mic.self_unmute',
      {'target_user_id': userId, 'muted': muted},
    );
  }

  static void sendAdminMute({
    required String targetUserId,
    required bool muted,
  }) {
    _sendRoomStateEvent(
      muted ? 'room.mic.admin_mute' : 'room.mic.admin_unmute',
      {'target_user_id': targetUserId, 'muted': muted},
    );
  }

  static void applyIncomingEvent({
    required String type,
    required Map<String, dynamic> payload,
  }) {
    final applier = _seatApplier;
    if (applier == null) return;

    switch (type) {
      case 'room.state.snapshot':
      case 'room.state.updated':
        applier.applyRemoteRoomStateSnapshot(payload);
        return;
      case 'room.seat.occupied':
        applier.applyRemoteSeatOccupy(
          seatIndex: _intPayload(payload, 'seat_index'),
          userId: _stringPayload(payload, 'actor_user_id'),
          displayName: _stringPayload(payload, 'actor_name'),
        );
        return;
      case 'room.seat.left':
        applier.applyRemoteSeatLeave(
          seatIndex: _intPayload(payload, 'seat_index'),
        );
        return;
      case 'room.seat.switched':
        applier.applyRemoteSeatSwitch(
          fromSeatIndex: _intPayload(payload, 'from_seat_index'),
          toSeatIndex: _intPayload(payload, 'to_seat_index'),
          userId: _stringPayload(payload, 'actor_user_id'),
          displayName: _stringPayload(payload, 'actor_name'),
        );
        return;
      case 'room.seat.locked':
        applier.applyRemoteSeatLock(
          seatIndex: _intPayload(payload, 'seat_index'),
        );
        return;
      case 'room.seat.unlocked':
        applier.applyRemoteSeatUnlock(
          seatIndex: _intPayload(payload, 'seat_index'),
        );
        return;
      case 'room.mic.self_muted':
      case 'room.mic.self_unmuted':
        applier.applyRemoteSelfMute(
          userId: _stringPayload(payload, 'target_user_id'),
          muted: _boolPayload(payload, 'muted'),
        );
        return;
      case 'room.mic.admin_muted':
      case 'room.mic.admin_unmuted':
        applier.applyRemoteAdminMute(
          userId: _stringPayload(payload, 'target_user_id'),
          muted: _boolPayload(payload, 'muted'),
        );
        return;
      default:
        return;
    }
  }

  static void _sendRoomStateEvent(String type, Map<String, dynamic> payload) {
    final roomId = _roomId;
    final userId = _userId;
    final sendEvent = _sendEvent;
    if (roomId == null || userId == null || sendEvent == null) return;

    sendEvent(
      type: type,
      roomId: roomId,
      userId: userId,
      requestId: '$type-${DateTime.now().millisecondsSinceEpoch}',
      payload: payload,
    );
  }

  static int _intPayload(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? -1;
  }

  static String _stringPayload(Map<String, dynamic> payload, String key) {
    return payload[key]?.toString() ?? '';
  }

  static bool _boolPayload(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }
}
