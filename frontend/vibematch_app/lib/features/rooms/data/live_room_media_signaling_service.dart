import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/vm_media_config.dart';
import '../../auth/models/current_user.dart';
import '../presentation/live_room_models.dart';
import 'live_room_foreground_service.dart';

class LiveRoomMediaSignalingService with WidgetsBindingObserver {
  LiveRoomMediaSignalingService._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final LiveRoomMediaSignalingService instance = LiveRoomMediaSignalingService._();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  String? _roomId;
  String? _roomName;
  String? _peerId;
  SeatUser? _currentUser;
  SeatUser? _activeLoggedInSeatUser;
  bool _connecting = false;
  bool _joined = false;
  bool _shouldStayConnected = false;
  bool _appInForeground = true;
  bool _foregroundServiceStarted = false;

  final ValueNotifier<LiveMediaRoomSnapshot?> roomSnapshot = ValueNotifier<LiveMediaRoomSnapshot?>(null);

  bool get isConnected => _channel != null;
  bool get isJoined => _joined;
  String? get roomId => _roomId;
  String? get peerId => _peerId;
  SeatUser? get activeLoggedInSeatUser => _activeLoggedInSeatUser;

  SeatUser effectiveCurrentUser(SeatUser fallback) => _activeLoggedInSeatUser ?? fallback;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    _debug('app lifecycle changed: $state');
    if (_appInForeground) {
      _scheduleReconnect(reason: 'app resumed');
    }
  }

  void configureRoom({required String roomId, required String roomName}) {
    final nextRoomId = roomId.trim().isEmpty ? 'VM257808' : roomId.trim();
    _roomId = nextRoomId;
    _roomName = roomName.trim().isEmpty ? 'Live Room' : roomName.trim();
    if (roomSnapshot.value?.roomId != nextRoomId) {
      roomSnapshot.value = null;
    }
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
    _shouldStayConnected = true;
    await _startForegroundServiceIfNeeded();
    await _joinRoomInternal(reason: 'join requested');
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

  void setAdminMute({required String targetUserId, required bool muted}) {
    if (targetUserId.trim().isEmpty) return;
    _send('admin_mute/set', {'target_user_id': targetUserId, 'muted': muted});
  }

  void sendRoomChat(String text) {
    final safeText = text.trim();
    if (safeText.isEmpty) return;
    _send('room/chat', {'text': safeText});
  }

  Future<void> leaveRoom() async {
    _shouldStayConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_channel != null && _joined) {
      _send('room/leave', <String, Object?>{});
    }
    _joined = false;
    _peerId = null;
    roomSnapshot.value = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _connecting = false;
    await _stopForegroundServiceIfNeeded();
  }

  Future<void> _startForegroundServiceIfNeeded() async {
    if (_foregroundServiceStarted) return;
    _foregroundServiceStarted = true;
    await LiveRoomForegroundService.start(
      roomName: _roomName ?? 'Live Room',
      roomId: _roomId ?? 'Vibe Match',
    );
    _debug('live room foreground service started');
  }

  Future<void> _stopForegroundServiceIfNeeded() async {
    if (!_foregroundServiceStarted) return;
    _foregroundServiceStarted = false;
    await LiveRoomForegroundService.stop();
    _debug('live room foreground service stopped');
  }

  Future<void> _joinRoomInternal({required String reason}) async {
    final effectiveUser = _currentUser;
    final safeRoomId = _roomId ?? 'VM257808';
    if (effectiveUser == null) return;

    if (_joined && _channel != null) return;

    _debug('joining media room: $reason');
    await _connect();
    if (_channel == null) {
      _scheduleReconnect(reason: 'join failed without channel');
      return;
    }
    _send('room/join', _joinPayload(effectiveUser, safeRoomId));
    _joined = true;
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
          _scheduleReconnect(reason: 'socket error');
        },
        onDone: () {
          _debug('media websocket closed');
          _resetConnectionState();
          _scheduleReconnect(reason: 'socket closed');
        },
      );
      _debug('media websocket connecting: ${VmMediaConfig.wsUrl}');
    } catch (error) {
      _debug('media websocket connect failed: $error');
      _resetConnectionState();
      _scheduleReconnect(reason: 'connect exception');
    } finally {
      _connecting = false;
    }
  }

  void _scheduleReconnect({required String reason}) {
    if (!_shouldStayConnected || !_appInForeground || _currentUser == null || _roomId == null) return;
    if (_channel != null || _connecting) return;
    _reconnectTimer?.cancel();
    _debug('media reconnect scheduled: $reason');
    _reconnectTimer = Timer(const Duration(milliseconds: 900), () {
      _reconnectTimer = null;
      if (!_shouldStayConnected || !_appInForeground) return;
      unawaited(_joinRoomInternal(reason: 'reconnect: $reason'));
    });
  }

  Map<String, Object?> _joinPayload(SeatUser user, String safeRoomId) {
    final stablePeerId = '${safeRoomId}_${user.id}'.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    _peerId = stablePeerId;
    return {'room_id': safeRoomId, 'peer_id': stablePeerId, 'user_id': user.id, 'display_name': user.name, 'seat_index': null};
  }

  void _send(String type, Map<String, Object?> payload) {
    final channel = _channel;
    if (channel == null) {
      _debug('media send skipped, socket not connected: $type');
      _scheduleReconnect(reason: 'send skipped for $type');
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
      if (payload is Map<String, dynamic>) {
        final roomData = payload['room'];
        if (roomData is Map<String, dynamic>) {
          roomSnapshot.value = LiveMediaRoomSnapshot.fromJson(roomData);
        }
      }
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

class LiveMediaRoomSnapshot {
  const LiveMediaRoomSnapshot({required this.roomId, required this.peers});

  final String roomId;
  final List<LiveMediaPeerSnapshot> peers;

  factory LiveMediaRoomSnapshot.fromJson(Map<String, dynamic> json) {
    final rawPeers = json['peers'];
    final peers = rawPeers is List ? rawPeers.whereType<Map<String, dynamic>>().map(LiveMediaPeerSnapshot.fromJson).toList() : <LiveMediaPeerSnapshot>[];
    return LiveMediaRoomSnapshot(roomId: json['room_id']?.toString() ?? '', peers: peers);
  }
}

class LiveMediaPeerSnapshot {
  const LiveMediaPeerSnapshot({required this.peerId, required this.userId, required this.displayName, required this.seatIndex, required this.micEnabled, required this.adminMuted});

  final String peerId;
  final String userId;
  final String displayName;
  final int? seatIndex;
  final bool micEnabled;
  final bool adminMuted;

  factory LiveMediaPeerSnapshot.fromJson(Map<String, dynamic> json) {
    final adminMutedValue = json['admin_muted'] ?? json['adminMuted'];
    return LiveMediaPeerSnapshot(
      peerId: json['peer_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'Vibe User',
      seatIndex: json['seat_index'] is int ? json['seat_index'] as int : int.tryParse(json['seat_index']?.toString() ?? ''),
      micEnabled: json['mic_enabled'] == true,
      adminMuted: adminMutedValue == true,
    );
  }
}
