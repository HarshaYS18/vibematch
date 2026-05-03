import 'dart:async';

import 'live_room_realtime_event.dart';
import 'live_room_realtime_service.dart';

class LiveRoomRealtimeHub {
  LiveRoomRealtimeHub._();

  static final LiveRoomRealtimeService _service = LiveRoomRealtimeService();
  static StreamSubscription<LiveRoomRealtimeEvent>? _eventSubscription;
  static StreamSubscription<String>? _logSubscription;
  static String? _roomId;
  static bool _connecting = false;
  static bool _connected = false;
  static int _onlineCount = 0;

  static bool get connected => _connected;
  static int get onlineCount => _onlineCount;

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

  static void sendSeatTake(int seatIndex) {
    _service.send('room/seat/take', <String, dynamic>{
      'seat_index': seatIndex,
      'seat_no': seatIndex + 1,
    });
  }

  static void sendSeatLeave(int seatIndex) {
    _service.send('room/seat/leave', <String, dynamic>{
      'seat_index': seatIndex,
      'seat_no': seatIndex + 1,
    });
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
    _service.send('room/seat/mute_state', <String, dynamic>{
      'seat_index': seatIndex,
      'seat_no': seatIndex + 1,
      'muted': muted,
      'admin_muted': adminMuted,
    });
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
  }
}
