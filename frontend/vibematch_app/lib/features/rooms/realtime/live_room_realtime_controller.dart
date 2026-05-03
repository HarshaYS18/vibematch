import 'dart:async';

import 'package:flutter/foundation.dart';

import 'live_room_realtime_event.dart';
import 'live_room_realtime_service.dart';

class LiveRoomRealtimeController extends ChangeNotifier {
  LiveRoomRealtimeController({
    LiveRoomRealtimeService? service,
  }) : _service = service ?? LiveRoomRealtimeService() {
    _subscriptions.add(_service.events.listen(_handleEvent));
    _subscriptions.add(_service.logs.listen(_setStatus));
  }

  final LiveRoomRealtimeService _service;
  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];
  final List<LiveRoomRealtimeEvent> _recentEvents = <LiveRoomRealtimeEvent>[];

  bool _connected = false;
  bool _connecting = false;
  String _status = 'Realtime idle';
  int _onlineCount = 0;
  DateTime? _lastTypingSentAt;
  DateTime? _lastPingSentAt;

  bool get connected => _connected;
  bool get connecting => _connecting;
  String get status => _status;
  int get onlineCount => _onlineCount;
  List<LiveRoomRealtimeEvent> get recentEvents => List<LiveRoomRealtimeEvent>.unmodifiable(_recentEvents);

  Future<void> connect(String roomId) async {
    if (_connecting || _connected) return;
    _connecting = true;
    _status = 'Connecting realtime';
    notifyListeners();

    try {
      await _service.connect(roomId);
      _connected = true;
      _connecting = false;
      _status = 'Realtime connected';
      notifyListeners();
      sendPing(force: true);
    } catch (error) {
      _connected = false;
      _connecting = false;
      _status = 'Realtime failed: $error';
      notifyListeners();
      rethrow;
    }
  }

  void sendChatMessage(String message) {
    if (message.trim().isEmpty) return;
    _service.send('room/chat/message', <String, dynamic>{
      'message': message.trim(),
    });
  }

  void sendSeatTake({required int seatIndex}) {
    _service.send('room/seat/take', <String, dynamic>{
      'seat_index': seatIndex,
      'seat_no': seatIndex + 1,
    });
  }

  void sendSeatLeave({required int seatIndex}) {
    _service.send('room/seat/leave', <String, dynamic>{
      'seat_index': seatIndex,
      'seat_no': seatIndex + 1,
    });
  }

  void sendMuteState({required int seatIndex, required bool muted, required bool adminMuted}) {
    _service.send('room/seat/mute_state', <String, dynamic>{
      'seat_index': seatIndex,
      'seat_no': seatIndex + 1,
      'muted': muted,
      'admin_muted': adminMuted,
    });
  }

  void sendJoinRequest() {
    _service.send('room/join_request');
  }

  void sendJoinRequestResolution({required String targetUserId, required bool approved}) {
    _service.send('room/join_request/resolve', <String, dynamic>{
      'target_user_id': targetUserId,
      'approved': approved,
    });
  }

  void sendGiftSent({required String giftId, required List<String> receiverIds, required int combo}) {
    _service.send('room/gift/sent', <String, dynamic>{
      'gift_id': giftId,
      'receiver_ids': receiverIds,
      'combo': combo,
    });
  }

  void sendReaction(String reaction) {
    _service.send('room/reaction/sent', <String, dynamic>{
      'reaction': reaction,
    });
  }

  void sendTyping() {
    final now = DateTime.now();
    final last = _lastTypingSentAt;
    if (last != null && now.difference(last).inMilliseconds < 2500) return;
    _lastTypingSentAt = now;
    _service.send('room/typing');
  }

  void sendPing({bool force = false}) {
    final now = DateTime.now();
    final last = _lastPingSentAt;
    if (!force && last != null && now.difference(last).inSeconds < 20) return;
    _lastPingSentAt = now;
    _service.send('room/ping');
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    _connected = false;
    _connecting = false;
    _status = 'Realtime disconnected';
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _service.dispose();
    super.dispose();
  }

  void _handleEvent(LiveRoomRealtimeEvent event) {
    if (event.type == 'room/snapshot' || event.type == 'room/presence') {
      _onlineCount = _asInt(event.payload['online_count'], fallback: _onlineCount);
    }

    _recentEvents.insert(0, event);
    if (_recentEvents.length > 80) {
      _recentEvents.removeRange(80, _recentEvents.length);
    }

    _status = 'Realtime event: ${event.type}';
    notifyListeners();
  }

  void _setStatus(String status) {
    _status = status;
    notifyListeners();
  }

  int _asInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
