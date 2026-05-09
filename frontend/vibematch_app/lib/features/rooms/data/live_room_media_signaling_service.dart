import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/vm_media_config.dart';
import '../../auth/models/current_user.dart';
import '../presentation/live_room_models.dart';
import 'live_room_audio_service.dart';
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
  final ValueNotifier<LiveMediaRoomBlock?> roomBlock = ValueNotifier<LiveMediaRoomBlock?>(null);
  final ValueNotifier<LiveMediaSeatInvite?> seatInvite = ValueNotifier<LiveMediaSeatInvite?>(null);

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
      roomBlock.value = null;
      seatInvite.value = null;
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
    seatInvite.value = null;
    LiveRoomAudioService.instance.takeSeat(seatIndex);
    _send('seat/take', {'seat_index': seatIndex});
  }

  void sendSeatInvite({required int seatIndex, required String targetUserId}) {
    if (seatIndex < 0 || targetUserId.trim().isEmpty) return;
    final currentUserId = _activeLoggedInSeatUser?.id ?? _currentUser?.id;
    if (currentUserId != null && targetUserId == currentUserId) return;
    _send('seat_invite/send', {'seat_index': seatIndex, 'target_user_id': targetUserId});
  }

  void clearSeatInvite() {
    seatInvite.value = null;
  }

  void leaveSeat() {
    LiveRoomAudioService.instance.leaveSeat();
    _send('seat/leave', <String, Object?>{});
  }

  void forceLeaveSeat({required int seatIndex, required String targetUserId}) {
    if (seatIndex < 0 || targetUserId.trim().isEmpty) return;
    _send('admin/seat_leave', {'seat_index': seatIndex, 'target_user_id': targetUserId});
  }

  void lockSeat({required int seatIndex}) {
    if (seatIndex < 0) return;
    _send('admin/seat_lock', {'seat_index': seatIndex});
  }

  void unlockSeat({required int seatIndex}) {
    if (seatIndex < 0) return;
    _send('admin/seat_unlock', {'seat_index': seatIndex});
  }

  void leaveAndLockSeat({required int seatIndex, required String targetUserId}) {
    if (seatIndex < 0 || targetUserId.trim().isEmpty) return;
    _send('admin/seat_leave_lock', {'seat_index': seatIndex, 'target_user_id': targetUserId});
  }

  void kickUser({required String targetUserId, String reason = 'Removed by room admin', String duration = '1h'}) {
    if (targetUserId.trim().isEmpty) return;
    _send('admin/kick', {'target_user_id': targetUserId, 'reason': reason, 'duration': duration});
  }

  void setMicEnabled(bool enabled) {
    if (enabled && _currentUserIsAdminMuted()) {
      _debug('mic enable blocked because current user is admin-muted');
      LiveRoomAudioService.instance.setSelfMuted(true);
      _send('mic/set_enabled', {'enabled': false});
      return;
    }
    LiveRoomAudioService.instance.setSelfMuted(!enabled);
    _send('mic/set_enabled', {'enabled': enabled});
  }

  void setAdminMute({required String targetUserId, required bool muted}) {
    if (targetUserId.trim().isEmpty) return;
    _applyAdminMuteToCurrentSnapshot(targetUserId: targetUserId, muted: muted);
    _enforceAdminMuteIfCurrentUser(targetUserId: targetUserId, muted: muted);
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
    roomBlock.value = null;
    seatInvite.value = null;
    await LiveRoomAudioService.instance.leaveRoom();
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _connecting = false;
    await _stopForegroundServiceIfNeeded();
  }

  Future<void> _disconnectAfterServerRemoval({required LiveMediaRoomBlock block}) async {
    roomBlock.value = block;
    _shouldStayConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _joined = false;
    _peerId = null;
    roomSnapshot.value = null;
    seatInvite.value = null;
    await LiveRoomAudioService.instance.leaveRoom();
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

    if (_joined && _channel != null) {
      _debug('media room already joined; preserving active session for $reason');
      return;
    }

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
    final stablePeerId = '${safeRoomId}_${user.id}'.replaceAll(RegExp(r'[^a-zA-Z0-9_\\-]'), '_');
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
        if (type == 'room/kicked' || type == 'room/join_blocked') {
          unawaited(_disconnectAfterServerRemoval(block: LiveMediaRoomBlock.fromJson(payload, type: type)));
          return;
        }
        if (type == 'room/joined') {
          _joinAudioAfterMediaJoin();
        }
        if (type == 'seat_invite/received') {
          seatInvite.value = LiveMediaSeatInvite.fromJson(payload);
          return;
        }
        final roomData = payload['room'];
        if (roomData is Map<String, dynamic>) {
          final nextSnapshot = LiveMediaRoomSnapshot.fromJson(roomData);
          if (type == 'admin_mute/updated') {
            roomSnapshot.value = _overlayAdminMute(nextSnapshot, payload);
          } else {
            roomSnapshot.value = nextSnapshot;
          }
          _enforceCurrentUserAdminMuteFromSnapshot(roomSnapshot.value);
        } else if (type == 'admin_mute/updated') {
          roomSnapshot.value = _overlayAdminMute(roomSnapshot.value, payload);
          _enforceAdminMutePayloadIfCurrentUser(payload);
        }
      }
    } catch (error) {
      _debug('media received unreadable message: $raw');
    }
  }

  void _joinAudioAfterMediaJoin() {
    final roomId = _roomId;
    final user = _currentUser ?? _activeLoggedInSeatUser;
    if (roomId == null || user == null) return;
    unawaited(LiveRoomAudioService.instance.joinRoom(roomId: roomId, currentUser: user));
  }

  void _applyAdminMuteToCurrentSnapshot({required String targetUserId, required bool muted}) {
    final snapshot = roomSnapshot.value;
    if (snapshot == null) return;
    roomSnapshot.value = LiveMediaRoomSnapshot(
      roomId: snapshot.roomId,
      peerCount: snapshot.peerCount,
      lockedSeatIndexes: snapshot.lockedSeatIndexes,
      peers: snapshot.peers.map((peer) {
        final matchesUser = peer.userId == targetUserId || peer.peerId == targetUserId;
        if (!matchesUser) return peer;
        return peer.copyWith(adminMuted: muted, micEnabled: muted ? false : peer.micEnabled);
      }).toList(),
    );
  }

  LiveMediaRoomSnapshot? _overlayAdminMute(LiveMediaRoomSnapshot? snapshot, Map<String, dynamic> payload) {
    if (snapshot == null) return null;
    final targetPeerId = payload['peer_id']?.toString();
    final targetUserId = payload['user_id']?.toString();
    final muted = payload['admin_muted'] == true || payload['adminMuted'] == true;
    final micEnabled = payload.containsKey('mic_enabled') ? payload['mic_enabled'] == true : null;

    return LiveMediaRoomSnapshot(
      roomId: snapshot.roomId,
      peerCount: snapshot.peerCount,
      lockedSeatIndexes: snapshot.lockedSeatIndexes,
      peers: snapshot.peers.map((peer) {
        final matchesPeer = targetPeerId != null && targetPeerId.isNotEmpty && peer.peerId == targetPeerId;
        final matchesUser = targetUserId != null && targetUserId.isNotEmpty && peer.userId == targetUserId;
        if (!matchesPeer && !matchesUser) return peer;
        return peer.copyWith(adminMuted: muted, micEnabled: micEnabled ?? (muted ? false : peer.micEnabled));
      }).toList(),
    );
  }

  bool _currentUserIsAdminMuted() {
    final snapshot = roomSnapshot.value;
    if (snapshot == null) return false;
    final currentUserId = _currentUser?.id ?? _activeLoggedInSeatUser?.id;
    final currentPeerId = _peerId;
    for (final peer in snapshot.peers) {
      final matchesUser = currentUserId != null && peer.userId == currentUserId;
      final matchesPeer = currentPeerId != null && peer.peerId == currentPeerId;
      if ((matchesUser || matchesPeer) && peer.adminMuted) return true;
    }
    return false;
  }

  void _enforceCurrentUserAdminMuteFromSnapshot(LiveMediaRoomSnapshot? snapshot) {
    if (snapshot == null) return;
    final currentUserId = _currentUser?.id ?? _activeLoggedInSeatUser?.id;
    final currentPeerId = _peerId;
    for (final peer in snapshot.peers) {
      final matchesUser = currentUserId != null && peer.userId == currentUserId;
      final matchesPeer = currentPeerId != null && peer.peerId == currentPeerId;
      if ((matchesUser || matchesPeer) && peer.adminMuted) {
        _debug('admin mute enforced from room snapshot for current user');
        LiveRoomAudioService.instance.setSelfMuted(true);
        return;
      }
    }
  }

  void _enforceAdminMutePayloadIfCurrentUser(Map<String, dynamic> payload) {
    final targetPeerId = payload['peer_id']?.toString();
    final targetUserId = payload['user_id']?.toString();
    final muted = payload['admin_muted'] == true || payload['adminMuted'] == true;
    if (!muted) return;
    _enforceAdminMuteIfCurrentUser(targetUserId: targetUserId, targetPeerId: targetPeerId, muted: muted);
  }

  void _enforceAdminMuteIfCurrentUser({String? targetUserId, String? targetPeerId, required bool muted}) {
    if (!muted) return;
    final currentUserId = _currentUser?.id ?? _activeLoggedInSeatUser?.id;
    final currentPeerId = _peerId;
    final matchesUser = targetUserId != null && targetUserId.isNotEmpty && currentUserId == targetUserId;
    final matchesPeer = targetPeerId != null && targetPeerId.isNotEmpty && currentPeerId == targetPeerId;
    if (!matchesUser && !matchesPeer) return;
    _debug('admin mute enforced on current user audio producer');
    LiveRoomAudioService.instance.setSelfMuted(true);
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

class LiveMediaSeatInvite {
  const LiveMediaSeatInvite({required this.inviteId, required this.roomId, required this.seatIndex, required this.inviterUserId, required this.inviterName});

  final String inviteId;
  final String roomId;
  final int seatIndex;
  final String inviterUserId;
  final String inviterName;

  factory LiveMediaSeatInvite.fromJson(Map<String, dynamic> json) {
    return LiveMediaSeatInvite(
      inviteId: json['invite_id']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? '',
      seatIndex: int.tryParse(json['seat_index']?.toString() ?? '') ?? -1,
      inviterUserId: json['inviter_user_id']?.toString() ?? '',
      inviterName: json['inviter_name']?.toString() ?? 'Room admin',
    );
  }
}

class LiveMediaRoomBlock {
  const LiveMediaRoomBlock({required this.type, required this.reason, this.kickedUntil, this.remainingMs});

  final String type;
  final String reason;
  final DateTime? kickedUntil;
  final int? remainingMs;

  factory LiveMediaRoomBlock.fromJson(Map<String, dynamic> json, {required String type}) {
    return LiveMediaRoomBlock(
      type: type,
      reason: json['reason']?.toString() ?? 'You cannot enter this room right now.',
      kickedUntil: DateTime.tryParse(json['kicked_until']?.toString() ?? ''),
      remainingMs: int.tryParse(json['remaining_ms']?.toString() ?? '') ?? int.tryParse(json['duration_ms']?.toString() ?? ''),
    );
  }
}

class LiveMediaRoomSnapshot {
  const LiveMediaRoomSnapshot({required this.roomId, required this.peers, int? peerCount, this.lockedSeatIndexes = const <int>{}}) : peerCount = peerCount ?? peers.length;

  final String roomId;
  final int peerCount;
  final List<LiveMediaPeerSnapshot> peers;
  final Set<int> lockedSeatIndexes;

  factory LiveMediaRoomSnapshot.fromJson(Map<String, dynamic> json) {
    final rawPeers = json['peers'];
    final peers = rawPeers is List ? rawPeers.whereType<Map<String, dynamic>>().map(LiveMediaPeerSnapshot.fromJson).toList() : <LiveMediaPeerSnapshot>[];
    final rawLockedSeats = json['locked_seat_indexes'] ?? json['lockedSeatIndexes'];
    final lockedSeatIndexes = rawLockedSeats is List ? rawLockedSeats.map((item) => int.tryParse(item.toString())).whereType<int>().toSet() : <int>{};
    final parsedPeerCount = int.tryParse(json['peer_count']?.toString() ?? '');
    return LiveMediaRoomSnapshot(roomId: json['room_id']?.toString() ?? '', peerCount: parsedPeerCount ?? peers.length, peers: peers, lockedSeatIndexes: lockedSeatIndexes);
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

  LiveMediaPeerSnapshot copyWith({bool? micEnabled, bool? adminMuted}) {
    return LiveMediaPeerSnapshot(
      peerId: peerId,
      userId: userId,
      displayName: displayName,
      seatIndex: seatIndex,
      micEnabled: micEnabled ?? this.micEnabled,
      adminMuted: adminMuted ?? this.adminMuted,
    );
  }

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
