import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/vm_media_config.dart';
import '../../auth/models/current_user.dart';
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
  SeatUser? _activeLoggedInSeatUser;
  bool _connecting = false;
  bool _joined = false;
  bool _internalSmokeTestSent = false;

  bool get isConnected => _channel != null;
  bool get isJoined => _joined;
  String? get roomId => _roomId;
  String? get peerId => _peerId;
  SeatUser? get activeLoggedInSeatUser => _activeLoggedInSeatUser;

  SeatUser effectiveCurrentUser(SeatUser fallback) => _activeLoggedInSeatUser ?? fallback;

  void configureRoom({required String roomId, required String roomName}) {
    _roomId = roomId.trim().isEmpty ? 'VM257808' : roomId.trim();
    _roomName = roomName.trim().isEmpty ? 'Live Room' : roomName.trim();
    _internalSmokeTestSent = false;
  }

  void setActiveLoggedInUser(CurrentUser user) {
    final isOfficial = user.canSeeOwnerControls;
    final roleLabel = user.primaryRoleBadge?.badgeLabel ?? user.roleDisplayLabel;
    _activeLoggedInSeatUser = SeatUser(
      id: 'user_${user.publicUserId}',
      name: user.displayName ?? user.username ?? 'Vibe User',
      roleLabel: isOfficial ? roleLabel : 'Member',
      familyName: '',
      familyLevel: 'bronze',
      relationshipText: '',
      vipLevel: isOfficial ? 32 : 1,
      svipLevel: isOfficial ? 3 : 0,
      sendingLevel: isOfficial ? 52 : 1,
      receivingLevel: isOfficial ? 44 : 1,
      sentExp: 0,
      receivedExp: 0,
      medals: const [],
      avatarColors: isOfficial ? const [Color(0xFFFFC857), Color(0xFFE84C72)] : const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      isCurrentUser: true,
      isHost: isOfficial,
      isRoomAdmin: isOfficial,
    );
    _debug('active logged-in room identity set: ${_activeLoggedInSeatUser!.id} ${_activeLoggedInSeatUser!.name}');
  }

  Future<void> joinRoom({required SeatUser currentUser}) async {
    final effectiveUser = effectiveCurrentUser(currentUser);
    _currentUser = effectiveUser;
    final safeRoomId = _roomId ?? 'VM257808';

    if (_joined && _channel != null) {
      _send('room/join', _joinPayload(effectiveUser, safeRoomId));
      return;
    }

    await _connect();
    _send('room/join', _joinPayload(effectiveUser, safeRoomId));
    _joined = true;
    _runInternalSmokeTestOnce();
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
    _internalSmokeTestSent = false;
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
    return {'room_id': safeRoomId, 'peer_id': stablePeerId, 'user_id': user.id, 'display_name': user.name, 'seat_index': null};
  }

  void _runInternalSmokeTestOnce() {
    if (_internalSmokeTestSent) return;
    _internalSmokeTestSent = true;
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!_joined || _channel == null) return;
      _debug('internal smoke test: seat/take 0');
      takeSeat(0);
    });
    Future<void>.delayed(const Duration(milliseconds: 1000), () {
      if (!_joined || _channel == null) return;
      _debug('internal smoke test: mic/set_enabled true');
      setMicEnabled(true);
    });
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (!_joined || _channel == null) return;
      _debug('internal smoke test: mic/set_enabled false');
      setMicEnabled(false);
    });
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (!_joined || _channel == null) return;
      _debug('internal smoke test: seat/leave');
      leaveSeat();
    });
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
