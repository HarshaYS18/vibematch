import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/vm_media_config.dart';
import '../presentation/live_room_models.dart';

class LiveRoomMediaSignalingService {
  LiveRoomMediaSignalingService._();

  static final LiveRoomMediaSignalingService instance = LiveRoomMediaSignalingService._();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  String? _roomId;
  String? _roomName;
  String? _peerId;
  SeatUser? _currentUser;
  bool _connecting = false;
  bool _joined = false;

  bool get isConnected => _channel != null;
  bool get isJoined => _joined;
  String? get roomId => _roomId;
  String? get peerId => _peerId;

  void configureRoom({
    required String roomId,
    required String roomName,
  }) {
    _roomId = roomId.trim().isEmpty ? 'VM257808' : roomId.trim();
    _roomName = roomName.trim().isEmpty ? 'Live Room' : roomName.trim();
  }

  Future<void> joinRoom({required SeatUser currentUser}) async {
    _currentUser = currentUser;
    final safeRoomId = _roomId ?? 'VM257808';

    if (_joined && _channel != null) {
      _send('room/join', _joinPayload(currentUser, safeRoomId));
      return;
    }

    await _connect();
    _send('room/join', _joinPayload(currentUser, safeRoomId));
    _joined = true;
  }

  void takeSeat(int seatIndex) {
    if (seatIndex < 0) return;
    _send('seat/take', {'seat_index': seatIndex});
  }

  void leaveSeat() {
    _send('seat/leave', <String, Object?>{});
  }

  void setMicEnabled(bool enabled) {
    _send('mic/set_enabled', {'enabled': enabled});
  }

  void sendRoomChat(String text) {
    final safeText = text.trim();
    if (safeText.isEmpty) return;
    _send('room/chat', {'text': safeText});
  }

  Future<void> leaveRoom() async {
    if (_channel != null && _joined) {
      _send('room/leave', <String, Object?>{});
    }
    _joined = false;
    _peerId = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _connecting = false;
  }

  Future<void> _connect() async {
    if (_channel != null || _connecting) return;
    _connecting = true;
    try {
      final wsUrl = Uri.parse(VmMediaConfig.wsUrl);
      final channel = WebSocketChannel.connect(wsUrl);
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (Object error) {
          _debug('media websocket error: $error');
          _resetConnectionState();
        },
        onDone: () {
          _debug('media websocket closed');
          _resetConnectionState();
        },
      );
      _debug('media websocket connecting: ${VmMediaConfig.wsUrl}');
    } catch (error) {
      _debug('media websocket connect failed: $error');
      _resetConnectionState();
    } finally {
      _connecting = false;
    }
  }

  Map<String, Object?> _joinPayload(SeatUser user, String safeRoomId) {
    final stablePeerId = '${safeRoomId}_${user.id}'.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    _peerId = stablePeerId;
    return {
      'room_id': safeRoomId,
      'peer_id': stablePeerId,
      'user_id': user.id,
      'display_name': user.name,
      'seat_index': _currentSeatIndexFor(user),
    };
  }

  int? _currentSeatIndexFor(SeatUser user) {
    return null;
  }

  void _send(String type, Map<String, Object?> payload) {
    final channel = _channel;
    if (channel == null) {
      _debug('media send skipped, socket not connected: $type');
      return;
    }

    final message = jsonEncode({'type': type, 'payload': payload});
    channel.sink.add(message);
    _debug('media sent: $type $payload');
  }

  void _handleMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type = decoded['type']?.toString() ?? 'unknown';
      final payload = decoded['payload'];
      _debug('media received: $type $payload');
    } catch (error) {
      _debug('media received unreadable message: $raw');
    }
  }

  void _resetConnectionState() {
    _channel = null;
    _subscription = null;
    _joined = false;
    _connecting = false;
  }

  void _debug(String message) {
    // ignore: avoid_print
    print('[VibeMatchMedia] $message');
  }
}
