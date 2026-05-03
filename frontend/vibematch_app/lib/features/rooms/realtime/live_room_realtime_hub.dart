import 'dart:async';

import 'live_room_realtime_event.dart';
import 'live_room_realtime_service.dart';

class LiveRoomRealtimeActionResult {
  const LiveRoomRealtimeActionResult({
    required this.ok,
    required this.action,
    required this.payload,
    this.message,
  });

  final bool ok;
  final String action;
  final Map<String, dynamic> payload;
  final String? message;
}

class LiveRoomRealtimeHub {
  LiveRoomRealtimeHub._();

  static final LiveRoomRealtimeService _service = LiveRoomRealtimeService();
  static StreamSubscription<LiveRoomRealtimeEvent>? _eventSubscription;
  static StreamSubscription<String>? _logSubscription;
  static String? _roomId;
  static bool _connecting = false;
  static bool _connected = false;
  static int _onlineCount = 0;
  static int _requestCounter = 0;
  static final Map<String, Completer<LiveRoomRealtimeActionResult>> _pendingActions =
      <String, Completer<LiveRoomRealtimeActionResult>>{};

  static bool get connected => _connected;
  static int get onlineCount => _onlineCount;
  static Stream<LiveRoomRealtimeEvent> get events => _service.events;

  static Future<void> connect(String roomId) async {
    if (_connected && _roomId == roomId) return;
    if (_connecting) return;

    _connecting = true;
    try {
      await disconnect();
      _roomId = roomId;
      _eventSubscription = _service.events.listen(_handleEvent);
      _logSubscription = _service.logs.listen((_) {});
      await _service.connect(roomId);
      _connected = true;
      sendPing(force: true);
    } finally {
      _connecting = false;
    }
  }

  static Future<void> disconnect() async {
    for (final completer in _pendingActions.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Live room realtime disconnected'));
      }
    }
    _pendingActions.clear();
    await _eventSubscription?.cancel();
    await _logSubscription?.cancel();
    _eventSubscription = null;
    _logSubscription = null;
    _connected = false;
    _onlineCount = 0;
    _roomId = null;
    await _service.disconnect();
  }

  static void sendChatMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    _service.send('room/chat/message', <String, dynamic>{'message': trimmed});
  }

  static Future<LiveRoomRealtimeActionResult> requestSeatTake(int seatIndex) {
    return _sendAction('room/seat/take', <String, dynamic>{
      'seat_index': seatIndex,
      'seat_no': seatIndex + 1,
    });
  }

  static Future<LiveRoomRealtimeActionResult> requestSeatLeave(int seatIndex) {
    return _sendAction('room/seat/leave', <String, dynamic>{
      'seat_index': seatIndex,
      'seat_no': seatIndex + 1,
    });
  }

  static Future<LiveRoomRealtimeActionResult> requestMuteState({
    required int seatIndex,
    required bool muted,
    required bool adminMuted,
  }) {
    return _sendAction('room/seat/mute_state', <String, dynamic>{
      'seat_index': seatIndex,
      'seat_no': seatIndex + 1,
      'muted': muted,
      'admin_muted': adminMuted,
    });
  }

  static void sendSeatTake(int seatIndex) {
    requestSeatTake(seatIndex);
  }

  static void sendSeatLeave(int seatIndex) {
    requestSeatLeave(seatIndex);
  }

  static void sendSeatApplication(int seatIndex) {
    _service.send('room/seat/request', <String, dynamic>{
      'seat_index': seatIndex,
      'seat_no': seatIndex + 1,
    });
  }

  static void sendMuteState({
    required int seatIndex,
    required bool muted,
    required bool adminMuted,
  }) {
    requestMuteState(seatIndex: seatIndex, muted: muted, adminMuted: adminMuted);
  }

  static void sendJoinRequest() {
    _service.send('room/join_request');
  }

  static void sendJoinRequestResolution({
    required String targetUserId,
    required bool approved,
  }) {
    _service.send('room/join_request/resolve', <String, dynamic>{
      'target_user_id': targetUserId,
      'approved': approved,
    });
  }

  static void sendGiftSent({
    required String giftId,
    required List<String> receiverIds,
    required int combo,
  }) {
    _service.send('room/gift/sent', <String, dynamic>{
      'gift_id': giftId,
      'receiver_ids': receiverIds,
      'combo': combo,
    });
  }

  static void sendReaction(String reaction) {
    _service.send('room/reaction/sent', <String, dynamic>{'reaction': reaction});
  }

  static void sendTyping() {
    _service.send('room/typing');
  }

  static void sendSettingsUpdate(Map<String, dynamic> data) {
    _service.send('room/settings/update', data);
  }

  static void sendPing({bool force = false}) {
    _service.send('room/ping');
  }

  static Future<LiveRoomRealtimeActionResult> _sendAction(
    String action,
    Map<String, dynamic> payload,
  ) async {
    if (!_connected) {
      final roomId = _roomId;
      if (roomId == null) throw StateError('Live room realtime is not connected');
      await connect(roomId);
    }

    final requestId = '${DateTime.now().microsecondsSinceEpoch}-${_requestCounter++}';
    final completer = Completer<LiveRoomRealtimeActionResult>();
    _pendingActions[requestId] = completer;

    _service.send(action, <String, dynamic>{
      ...payload,
      'request_id': requestId,
    });

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _pendingActions.remove(requestId);
        throw TimeoutException('Timed out waiting for $action confirmation');
      },
    );
  }

  static void _handleEvent(LiveRoomRealtimeEvent event) {
    if (event.type == 'room/snapshot' || event.type == 'room/presence') {
      final value = event.payload['online_count'];
      if (value is int) {
        _onlineCount = value;
      } else if (value is num) {
        _onlineCount = value.toInt();
      } else {
        _onlineCount = int.tryParse(value?.toString() ?? '') ?? _onlineCount;
      }
    }

    if (event.type == 'room/action_result') {
      final requestId = event.payload['request_id']?.toString();
      if (requestId == null) return;
      final completer = _pendingActions.remove(requestId);
      if (completer == null || completer.isCompleted) return;

      final rawPayload = event.payload['payload'];
      final payload = rawPayload is Map<String, dynamic>
          ? rawPayload
          : rawPayload is Map
              ? rawPayload.cast<String, dynamic>()
              : <String, dynamic>{};

      final result = LiveRoomRealtimeActionResult(
        ok: event.payload['ok'] == true,
        action: event.payload['action']?.toString() ?? '',
        payload: payload,
        message: event.payload['message']?.toString(),
      );

      if (result.ok) {
        completer.complete(result);
      } else {
        completer.completeError(StateError(result.message ?? 'Live room action rejected'));
      }
    }
  }
}
