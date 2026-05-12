import 'live_room_system_event_bus.dart';
import 'live_room_settings_event_bus.dart';
import 'live_room_seat_application_event_bus.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/vm_media_config.dart';
import '../../../main.dart';
import '../../auth/models/current_user.dart';
import '../presentation/live_room_models.dart';
import 'live_room_audio_service.dart';
import 'live_room_foreground_service.dart';
import 'live_room_presence_repository.dart';

class LiveRoomMediaSignalingService with WidgetsBindingObserver {
  LiveRoomMediaSignalingService._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final LiveRoomMediaSignalingService instance =
      LiveRoomMediaSignalingService._();

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
  bool _showingRoomBlockDialog = false;

  final ValueNotifier<LiveMediaRoomSnapshot?> roomSnapshot =
      ValueNotifier<LiveMediaRoomSnapshot?>(null);

  final ValueNotifier<LiveMediaRoomBlock?> roomBlock =
      ValueNotifier<LiveMediaRoomBlock?>(null);

  final ValueNotifier<LiveMediaSeatInvite?> seatInvite =
      ValueNotifier<LiveMediaSeatInvite?>(null);

  bool get isConnected => _channel != null;
  bool get isJoined => _joined;
  String? get roomId => _roomId;
  String? get peerId => _peerId;
  SeatUser? get activeLoggedInSeatUser => _activeLoggedInSeatUser;

  SeatUser effectiveCurrentUser(SeatUser fallback) {
    return _activeLoggedInSeatUser ?? fallback;
  }

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
    final roleLabel =
        user.primaryRoleBadge?.badgeLabel ?? user.roleDisplayLabel;

    _activeLoggedInSeatUser = SeatUser(
      id: 'user_${user.publicUserId}',
      name: user.displayName ?? user.username ?? 'Vibe User',
      roleLabel: isOfficial ? roleLabel : 'Member',
      familyName: '',
      familyLevel: 'bronze',
      relationshipText: '',
      vipLevel: isOfficial ? 32 : user.vip.vipLevel,
      svipLevel: isOfficial ? 3 : user.vip.svipLevel,
      sendingLevel: isOfficial ? 52 : 1,
      receivingLevel: isOfficial ? 44 : 1,
      sentExp: 0,
      receivedExp: 0,
      medals: const <String>[],
      avatarColors: isOfficial
          ? const <Color>[Color(0xFFFFC857), Color(0xFFE84C72)]
          : const <Color>[Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      isCurrentUser: true,
      isHost: isOfficial,
      isRoomAdmin: isOfficial,
    );

    _debug(
      'active logged-in room identity set: '
      '${_activeLoggedInSeatUser!.id} ${_activeLoggedInSeatUser!.name}',
    );
  }

  void seedActiveRoomSeatUser(SeatUser user) {
    _activeLoggedInSeatUser = SeatUser(
      id: user.id,
      name: user.name,
      roleLabel: user.roleLabel,
      familyName: user.familyName,
      familyLevel: user.familyLevel,
      relationshipText: user.relationshipText,
      vipLevel: user.vipLevel,
      svipLevel: user.svipLevel,
      sendingLevel: user.sendingLevel,
      receivingLevel: user.receivingLevel,
      sentExp: user.sentExp,
      receivedExp: user.receivedExp,
      medals: user.medals,
      avatarColors: user.avatarColors,
      age: user.age,
      locationLabel: user.locationLabel,
      locationVisible: user.locationVisible,
      gender: user.gender,
      isCurrentUser: true,
      isHost: user.isHost,
      isRoomAdmin: user.isRoomAdmin,
      selfMuted: user.selfMuted,
      adminMuted: user.adminMuted,
    );

    _currentUser = _activeLoggedInSeatUser;

    _debug(
      'active room identity seeded from presence: '
      '${user.id} ${user.name} host=${user.isHost} admin=${user.isRoomAdmin}',
    );
  }

  bool isSeatVacant(int seatIndex) {
    if (seatIndex < 0) return false;

    final snapshot = roomSnapshot.value;
    if (snapshot == null) return true;

    return !snapshot.peers.any((peer) => peer.seatIndex == seatIndex);
  }

  void takeSeatIfVacant(int seatIndex) {
    if (!isSeatVacant(seatIndex)) {
      _debug('auto seat skipped because seat $seatIndex is already occupied');
      return;
    }

    takeSeat(seatIndex);
  }

  Future<void> joinRoom({required SeatUser currentUser}) async {
    final effectiveUser = effectiveCurrentUser(currentUser);

    _currentUser = effectiveUser;
    _shouldStayConnected = true;
    roomBlock.value = null;
    _showingRoomBlockDialog = false;

    await _startForegroundServiceIfNeeded();
    await _joinRoomInternal(reason: 'join requested');
  }

  void takeSeat(int seatIndex) {
    if (seatIndex < 0) return;

    seatInvite.value = null;
    LiveRoomAudioService.instance.takeSeat(seatIndex);

    _send('seat/take', <String, Object?>{'seat_index': seatIndex});
  }

  void sendSeatInvite({required int seatIndex, required String targetUserId}) {
    if (seatIndex < 0 || targetUserId.trim().isEmpty) return;

    final currentUserId = _activeLoggedInSeatUser?.id ?? _currentUser?.id;
    if (currentUserId != null && targetUserId == currentUserId) return;

    _send('seat_invite/send', <String, Object?>{
      'seat_index': seatIndex,
      'target_user_id': targetUserId,
    });
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

    _send('admin/seat_leave', <String, Object?>{
      'seat_index': seatIndex,
      'target_user_id': targetUserId,
    });
  }

  void lockSeat({required int seatIndex}) {
    if (seatIndex < 0) return;

    _send('admin/seat_lock', <String, Object?>{'seat_index': seatIndex});
  }

  void unlockSeat({required int seatIndex}) {
    if (seatIndex < 0) return;

    _send('admin/seat_unlock', <String, Object?>{'seat_index': seatIndex});
  }

  void leaveAndLockSeat({
    required int seatIndex,
    required String targetUserId,
  }) {
    if (seatIndex < 0 || targetUserId.trim().isEmpty) return;

    _send('admin/seat_leave_lock', <String, Object?>{
      'seat_index': seatIndex,
      'target_user_id': targetUserId,
    });
  }

  void kickUser({
    required String targetUserId,
    String reason = 'Removed by room admin',
    String duration = '1h',
  }) {
    if (targetUserId.trim().isEmpty) return;

    _send('admin/kick', <String, Object?>{
      'target_user_id': targetUserId,
      'reason': reason,
      'duration': duration,
    });
  }

  void removeKickBlock({required String targetUserId}) {
    if (targetUserId.trim().isEmpty) return;

    _send('admin/kick_remove', <String, Object?>{
      'target_user_id': targetUserId,
    });
  }

  void setMicEnabled(bool enabled) {
    if (enabled && _currentUserIsAdminMuted()) {
      _debug('mic enable blocked because current user is admin-muted');
      LiveRoomAudioService.instance.setSelfMuted(true);

      _send('mic/set_enabled', <String, Object?>{'enabled': false});
      return;
    }

    LiveRoomAudioService.instance.setSelfMuted(!enabled);

    _send('mic/set_enabled', <String, Object?>{'enabled': enabled});
  }

  void setAdminMute({required String targetUserId, required bool muted}) {
    if (targetUserId.trim().isEmpty) return;

    _applyAdminMuteToCurrentSnapshot(targetUserId: targetUserId, muted: muted);

    _enforceAdminMuteIfCurrentUser(targetUserId: targetUserId, muted: muted);

    _send('admin_mute/set', <String, Object?>{
      'target_user_id': targetUserId,
      'muted': muted,
    });
  }

  void setRoomAdminStatus({
    required String targetUserId,
    required bool isRoomAdmin,
  }) {
    if (targetUserId.trim().isEmpty) return;

    _send('room_admin/set', <String, Object?>{
      'target_user_id': targetUserId,
      'is_room_admin': isRoomAdmin,
    });
  }

  void setRoomApplyOnlyMode(bool enabled) {
    _send('room_settings/apply_mode', <String, Object?>{
      'apply_only_mode_enabled': enabled,
    });
  }

  void sendSeatApplicationRequest({required int seatIndex}) {
    if (seatIndex < 0) return;
    _send('seat_application/request', <String, Object?>{
      'seat_index': seatIndex,
    });
  }

  void forceAssignSeat({required String targetUserId, required int seatIndex}) {
    if (targetUserId.trim().isEmpty || seatIndex < 0) return;
    _send('admin/seat_assign', <String, Object?>{
      'target_user_id': targetUserId,
      'seat_index': seatIndex,
    });
  }

  void broadcastRoomSystemMessage(String message) {
    final safeMessage = message.trim();
    if (safeMessage.isEmpty) return;

    _send('room/system_message', <String, Object?>{'message': safeMessage});
  }

  void broadcastChatCleared() {
    _send('room/chat_clear', <String, Object?>{});
  }

  void sendRoomChat(String text) {
    final safeText = text.trim();
    if (safeText.isEmpty) return;

    _send('room/chat', <String, Object?>{'text': safeText});
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

  Future<void> _disconnectAfterServerRemoval({
    required LiveMediaRoomBlock block,
  }) async {
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
    _exitRoomAndShowBlockDialog(block);
  }

  void _exitRoomAndShowBlockDialog(LiveMediaRoomBlock block) {
    if (_showingRoomBlockDialog) return;

    _showingRoomBlockDialog = true;

    Future<void>.delayed(const Duration(milliseconds: 80), () async {
      final navigator = rootNavigatorKey.currentState;
      final navContext = rootNavigatorKey.currentContext;

      if (navigator == null || navContext == null) {
        _showingRoomBlockDialog = false;
        return;
      }

      while (navigator.canPop()) {
        navigator.pop();
        break;
      }

      await Future<void>.delayed(const Duration(milliseconds: 220));

      final dialogContext = rootNavigatorKey.currentContext;
      if (dialogContext == null) {
        _showingRoomBlockDialog = false;
        return;
      }

      await showDialog<void>(
        context: dialogContext,
        useRootNavigator: true,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('Room access blocked'),
          content: Text(block.displayMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      _showingRoomBlockDialog = false;
    });
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
      _debug(
        'media room already joined; preserving active session for $reason',
      );
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
        cancelOnError: true,
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
    if (!_shouldStayConnected ||
        !_appInForeground ||
        _currentUser == null ||
        _roomId == null) {
      return;
    }

    if (_channel != null || _connecting) return;

    _reconnectTimer?.cancel();

    _debug('media reconnect scheduled: $reason');

    _reconnectTimer = Timer(const Duration(milliseconds: 2500), () {
      _reconnectTimer = null;

      if (!_shouldStayConnected || !_appInForeground) return;

      unawaited(
        _joinRoomInternal(reason: 'reconnect: $reason').catchError((
          Object error,
        ) {
          _debug('media reconnect ignored after failure: $error');
        }),
      );
    });
  }

  Map<String, Object?> _joinPayload(SeatUser user, String safeRoomId) {
    final stablePeerId = '${safeRoomId}_${user.id}'.replaceAll(
      RegExp(r'[^a-zA-Z0-9_\-]'),
      '_',
    );

    _peerId = stablePeerId;

    return <String, Object?>{
      'room_id': safeRoomId,
      'peer_id': stablePeerId,
      'user_id': user.id,
      'display_name': user.name,
      'is_host': user.isHost,
      'is_room_admin': user.isRoomAdmin || user.isHost,
      'role_label': user.isHost
          ? 'Channel Host'
          : user.isRoomAdmin
          ? 'Admin'
          : user.roleLabel,
      'seat_index': null,
    };
  }

  void _send(String type, Map<String, Object?> payload) {
    final channel = _channel;

    if (channel == null) {
      _debug('media send skipped, socket not connected: $type');
      _scheduleReconnect(reason: 'send skipped for $type');
      return;
    }

    try {
      final message = jsonEncode(<String, Object?>{
        'type': type,
        'payload': payload,
      });

      channel.sink.add(message);

      _debug('media sent: $type $payload');
    } catch (error) {
      _debug('media send failed for $type: $error');
      _resetConnectionState();
      _scheduleReconnect(reason: 'send failed for $type');
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type = decoded['type']?.toString() ?? 'unknown';
      final payload = decoded['payload'];

      _debug('media received: $type $payload');

      if (payload is! Map<String, dynamic>) return;

      if (type == 'room/system_event') {
        LiveRoomSystemEventBus.publish(LiveRoomSystemEvent.fromJson(payload));

        return;
      }
      if (type == 'room_admin/updated') {
        final targetUserId = payload['target_user_id']?.toString() ?? '';
        final targetName = payload['target_name']?.toString() ?? '';
        final roomId = payload['room_id']?.toString() ?? _roomId ?? '';
        final isRoomAdmin = payload['is_room_admin'] == true;

        if (targetUserId.isNotEmpty) {
          LiveRoomPresenceRepository.updateParticipantRoomAdmin(
            roomId: roomId,
            userId: targetUserId,
            displayName: targetName,
            isRoomAdmin: isRoomAdmin,
          );
        }

        final roomData = payload['room'];
        if (roomData is Map<String, dynamic>) {
          roomSnapshot.value = LiveMediaRoomSnapshot.fromJson(roomData);
          _enforceCurrentUserAudioStateFromSnapshot(roomSnapshot.value);
        }

        return;
      }
      if (type == 'seat_application/received') {
        LiveRoomSeatApplicationEventBus.publish(
          LiveRoomSeatApplicationEvent.fromJson(payload),
        );
        return;
      }

      if (type == 'room_settings/updated') {
        LiveRoomSettingsEventBus.publish(
          LiveRoomSettingsEvent.fromJson(payload),
        );

        final roomData = payload['room'];
        if (roomData is Map<String, dynamic>) {
          roomSnapshot.value = LiveMediaRoomSnapshot.fromJson(roomData);
          _enforceCurrentUserAudioStateFromSnapshot(roomSnapshot.value);
        }

        return;
      }

      if (type == 'kick_block/removed' || type == 'kick_block/remove_result') {
        final removed = payload['removed'] == true;
        final targetUserId = payload['target_user_id']?.toString();
        final currentUserId = _currentUser?.id ?? _activeLoggedInSeatUser?.id;

        if (removed &&
            (targetUserId == null || targetUserId == currentUserId)) {
          roomBlock.value = null;
          _showingRoomBlockDialog = false;
          _debug('cleared local room block after kick block removal');
        }

        final roomData = payload['room'];
        if (roomData is Map<String, dynamic>) {
          roomSnapshot.value = LiveMediaRoomSnapshot.fromJson(roomData);
        }

        return;
      }

      if (type == 'room/kicked' || type == 'room/join_blocked') {
        unawaited(
          _disconnectAfterServerRemoval(
            block: LiveMediaRoomBlock.fromJson(payload, type: type),
          ),
        );
        return;
      }

      if (type == 'room/joined') {
        roomBlock.value = null;
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

        _enforceCurrentUserAudioStateFromSnapshot(roomSnapshot.value);
      } else if (type == 'admin_mute/updated') {
        roomSnapshot.value = _overlayAdminMute(roomSnapshot.value, payload);
        _enforceAdminMutePayloadIfCurrentUser(payload);
      }
    } catch (error) {
      _debug('media received unreadable message: $raw');
    }
  }

  void _joinAudioAfterMediaJoin() {
    final roomId = _roomId;
    final user = _currentUser ?? _activeLoggedInSeatUser;

    if (roomId == null || user == null) return;

    unawaited(
      LiveRoomAudioService.instance.joinRoom(roomId: roomId, currentUser: user),
    );
  }

  void _applyAdminMuteToCurrentSnapshot({
    required String targetUserId,
    required bool muted,
  }) {
    final snapshot = roomSnapshot.value;
    if (snapshot == null) return;

    roomSnapshot.value = LiveMediaRoomSnapshot(
      roomId: snapshot.roomId,
      peerCount: snapshot.peerCount,
      lockedSeatIndexes: snapshot.lockedSeatIndexes,
      peers: snapshot.peers.map((peer) {
        final matchesUser =
            peer.userId == targetUserId || peer.peerId == targetUserId;
        if (!matchesUser) return peer;

        return peer.copyWith(
          adminMuted: muted,
          micEnabled: muted ? false : peer.micEnabled,
        );
      }).toList(),
    );
  }

  LiveMediaRoomSnapshot? _overlayAdminMute(
    LiveMediaRoomSnapshot? snapshot,
    Map<String, dynamic> payload,
  ) {
    if (snapshot == null) return null;

    final targetPeerId = payload['peer_id']?.toString();
    final targetUserId = payload['user_id']?.toString();
    final muted =
        payload['admin_muted'] == true || payload['adminMuted'] == true;
    final micEnabled = payload.containsKey('mic_enabled')
        ? payload['mic_enabled'] == true
        : null;

    return LiveMediaRoomSnapshot(
      roomId: snapshot.roomId,
      peerCount: snapshot.peerCount,
      lockedSeatIndexes: snapshot.lockedSeatIndexes,
      peers: snapshot.peers.map((peer) {
        final matchesPeer =
            targetPeerId != null &&
            targetPeerId.isNotEmpty &&
            peer.peerId == targetPeerId;
        final matchesUser =
            targetUserId != null &&
            targetUserId.isNotEmpty &&
            peer.userId == targetUserId;

        if (!matchesPeer && !matchesUser) return peer;

        return peer.copyWith(
          adminMuted: muted,
          micEnabled: micEnabled ?? (muted ? false : peer.micEnabled),
        );
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

  void _enforceCurrentUserAudioStateFromSnapshot(
    LiveMediaRoomSnapshot? snapshot,
  ) {
    if (snapshot == null) return;

    final currentUserId = _currentUser?.id ?? _activeLoggedInSeatUser?.id;
    final currentPeerId = _peerId;

    if (currentUserId == null && currentPeerId == null) return;

    LiveMediaPeerSnapshot? currentPeer;

    for (final peer in snapshot.peers) {
      final matchesUser = currentUserId != null && peer.userId == currentUserId;
      final matchesPeer = currentPeerId != null && peer.peerId == currentPeerId;

      if (matchesUser || matchesPeer) {
        currentPeer = peer;
        break;
      }
    }

    if (currentPeer == null || currentPeer.seatIndex == null) {
      _debug('current user is no longer seated; forcing local audio leaveSeat');
      LiveRoomAudioService.instance.leaveSeat();
      return;
    }

    if (currentPeer.adminMuted) {
      _debug('admin mute enforced from room snapshot for current user');
      LiveRoomAudioService.instance.setSelfMuted(true);
    }
  }

  void _enforceAdminMutePayloadIfCurrentUser(Map<String, dynamic> payload) {
    final targetPeerId = payload['peer_id']?.toString();
    final targetUserId = payload['user_id']?.toString();
    final muted =
        payload['admin_muted'] == true || payload['adminMuted'] == true;

    if (!muted) return;

    _enforceAdminMuteIfCurrentUser(
      targetUserId: targetUserId,
      targetPeerId: targetPeerId,
      muted: muted,
    );
  }

  void _enforceAdminMuteIfCurrentUser({
    String? targetUserId,
    String? targetPeerId,
    required bool muted,
  }) {
    if (!muted) return;

    final currentUserId = _currentUser?.id ?? _activeLoggedInSeatUser?.id;
    final currentPeerId = _peerId;

    final matchesUser =
        targetUserId != null &&
        targetUserId.isNotEmpty &&
        currentUserId == targetUserId;
    final matchesPeer =
        targetPeerId != null &&
        targetPeerId.isNotEmpty &&
        currentPeerId == targetPeerId;

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
  const LiveMediaSeatInvite({
    required this.inviteId,
    required this.roomId,
    required this.seatIndex,
    required this.inviterUserId,
    required this.inviterName,
  });

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
  const LiveMediaRoomBlock({
    required this.type,
    required this.reason,
    this.kickedUntil,
    this.remainingMs,
  });

  final String type;
  final String reason;
  final DateTime? kickedUntil;
  final int? remainingMs;

  bool get isKick => type == 'room/kicked' || type == 'room/join_blocked';

  String get durationLabel {
    final ms =
        remainingMs ??
        (kickedUntil == null
            ? null
            : kickedUntil!.difference(DateTime.now()).inMilliseconds);

    if (ms == null) return 'a permanent duration';

    final safeMs = ms < 0 ? 0 : ms;
    final totalMinutes = (safeMs / 60000).ceil();

    if (totalMinutes <= 1) return 'less than 1 minute';
    if (totalMinutes < 60) return '$totalMinutes minutes';

    final hours = (totalMinutes / 60).ceil();
    if (hours < 24) return '$hours hour${hours == 1 ? '' : 's'}';

    final days = (hours / 24).ceil();
    return '$days day${days == 1 ? '' : 's'}';
  }

  String get displayMessage {
    if (isKick) {
      return 'You were kicked out of this room for $durationLabel. You can enter again after the kick duration ends or when a room owner removes the block.';
    }

    return reason;
  }

  factory LiveMediaRoomBlock.fromJson(
    Map<String, dynamic> json, {
    required String type,
  }) {
    return LiveMediaRoomBlock(
      type: type,
      reason:
          json['reason']?.toString() ?? 'You cannot enter this room right now.',
      kickedUntil: DateTime.tryParse(json['kicked_until']?.toString() ?? ''),
      remainingMs:
          int.tryParse(json['remaining_ms']?.toString() ?? '') ??
          int.tryParse(json['duration_ms']?.toString() ?? ''),
    );
  }
}

class LiveMediaRoomSnapshot {
  const LiveMediaRoomSnapshot({
    required this.roomId,
    required this.peers,
    int? peerCount,
    this.lockedSeatIndexes = const <int>{},
  }) : peerCount = peerCount ?? peers.length;

  final String roomId;
  final int peerCount;
  final List<LiveMediaPeerSnapshot> peers;
  final Set<int> lockedSeatIndexes;

  factory LiveMediaRoomSnapshot.fromJson(Map<String, dynamic> json) {
    final rawPeers = json['peers'];

    final peers = rawPeers is List
        ? rawPeers
              .whereType<Map<String, dynamic>>()
              .map(LiveMediaPeerSnapshot.fromJson)
              .toList()
        : <LiveMediaPeerSnapshot>[];

    final rawLockedSeats =
        json['locked_seat_indexes'] ?? json['lockedSeatIndexes'];

    final lockedSeatIndexes = rawLockedSeats is List
        ? rawLockedSeats
              .map((item) => int.tryParse(item.toString()))
              .whereType<int>()
              .toSet()
        : <int>{};

    final parsedPeerCount = int.tryParse(json['peer_count']?.toString() ?? '');

    return LiveMediaRoomSnapshot(
      roomId: json['room_id']?.toString() ?? '',
      peerCount: parsedPeerCount ?? peers.length,
      peers: peers,
      lockedSeatIndexes: lockedSeatIndexes,
    );
  }
}

class LiveMediaPeerSnapshot {
  const LiveMediaPeerSnapshot({
    required this.peerId,
    required this.userId,
    required this.displayName,
    this.isHost = false,
    this.isRoomAdmin = false,
    this.roleLabel = '',
    this.seatIndex,
    this.micEnabled = false,
    this.adminMuted = false,
  });

  final String peerId;
  final String userId;
  final String displayName;
  final bool isHost;
  final bool isRoomAdmin;
  final String roleLabel;
  final int? seatIndex;
  final bool micEnabled;
  final bool adminMuted;

  factory LiveMediaPeerSnapshot.fromJson(Map<String, dynamic> json) {
    return LiveMediaPeerSnapshot(
      peerId: json['peer_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? 'Vibe User',
      isHost: json['is_host'] == true || json['isHost'] == true,
      isRoomAdmin: json['is_room_admin'] == true || json['isRoomAdmin'] == true,
      roleLabel: json['role_label']?.toString() ?? '',
      seatIndex: int.tryParse(json['seat_index']?.toString() ?? ''),
      micEnabled: json['mic_enabled'] == true || json['micEnabled'] == true,
      adminMuted: json['admin_muted'] == true || json['adminMuted'] == true,
    );
  }

  LiveMediaPeerSnapshot copyWith({
    String? peerId,
    String? userId,
    String? displayName,
    bool? isHost,
    bool? isRoomAdmin,
    String? roleLabel,
    int? seatIndex,
    bool clearSeatIndex = false,
    bool? micEnabled,
    bool? adminMuted,
  }) {
    return LiveMediaPeerSnapshot(
      peerId: peerId ?? this.peerId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      isHost: isHost ?? this.isHost,
      isRoomAdmin: isRoomAdmin ?? this.isRoomAdmin,
      roleLabel: roleLabel ?? this.roleLabel,
      seatIndex: clearSeatIndex ? null : seatIndex ?? this.seatIndex,
      micEnabled: micEnabled ?? this.micEnabled,
      adminMuted: adminMuted ?? this.adminMuted,
    );
  }
}
