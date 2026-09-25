import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/vm_motion.dart';
import '../../../foundation/realtime/realtime_event_envelope.dart';
import '../../../foundation/runtime/media_resource_lifecycle.dart';
import '../../../realtime/app_realtime_hub.dart';
import '../../../main.dart';
import '../../auth/models/current_user.dart';
import '../presentation/live_room_models.dart';
import '../presentation/modules/cricket_room_mode_signal.dart';
import '../presentation/widgets/cricket_room_backgrounds.dart';
import '../presentation/widgets/room_theme.dart';
import '../../../room_media/domain/room_media_engine.dart';
import '../../../room_media/runtime/room_media_resource_participant.dart';
import '../../../room_media/room_media_engine_factory.dart';
import 'live_room_log.dart';
import 'live_room_foreground_service.dart';
import 'seat_authority_gate.dart';

/// Compatibility facade for room media and transient realtime effects.
///
/// Durable room/chat/settings state is owned by RoomSessionRepository and
/// backend REST commands. This singleton may coordinate the media engine,
/// application-realtime subscription, seat/audio enforcement, invitations and
/// transient system effects, but it must not originate durable chat/settings
/// mutations or act as a second canonical room-state authority.
class LiveRoomMediaSignalingService with WidgetsBindingObserver {
  LiveRoomMediaSignalingService._({
    RoomMediaEngine? mediaEngine,
  }) : _mediaEngine = mediaEngine ?? createRoomMediaEngine() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final LiveRoomMediaSignalingService instance =
      LiveRoomMediaSignalingService._();

  final RoomMediaEngine _mediaEngine;
  final AppRealtimeHub _appRealtimeHub = AppRealtimeHub.shared;

  // Chunk 34-M9: lifecycle registration follows the actual room-media
  // connection, not the room widget lifetime. This is required because a room
  // may stay connected while minimized after its route widget is disposed.
  MediaResourceRegistry? _mediaResourceRegistry;
  RoomMediaResourceParticipant? _mediaResourceParticipant;

  StreamSubscription<RealtimeEventEnvelope>? _realtimeSubscription;

  String? _roomId;
  String? _roomName;
  String? _peerId;
  String? _roomScopedRoleRoomId;

  SeatUser? _currentUser;
  SeatUser? _activeLoggedInSeatUser;

  bool _connecting = false;
  bool _joined = false;
  bool _shouldStayConnected = false;
  bool _appInForeground = true;
  bool _foregroundServiceStarted = false;
  bool _showingRoomBlockDialog = false;
  int _commandSequence = 0;
  final SeatAuthorityGate _seatAuthorityGate = SeatAuthorityGate();

  final ValueNotifier<LiveMediaRoomSnapshot?> roomSnapshot =
      _VersionedRoomSnapshotNotifier();

  final ValueNotifier<LiveMediaRoomBlock?> roomBlock =
      ValueNotifier<LiveMediaRoomBlock?>(null);

  final ValueNotifier<LiveMediaSeatInvite?> seatInvite =
      ValueNotifier<LiveMediaSeatInvite?>(null);

  final StreamController<Map<String, dynamic>> _canonicalRoomSnapshotController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Canonical room snapshots projected from RoomSessionRepository.
  ///
  /// The Go application socket is delta-first. RoomSessionRepository reconciles
  /// those deltas, then this compatibility stream updates remaining legacy UI
  /// consumers while the adapters are retired.
  Stream<Map<String, dynamic>> get canonicalRoomSnapshotEvents =>
      _canonicalRoomSnapshotController.stream;

  bool get isConnected => _appRealtimeHub.isConnected;
  bool get isJoined => _joined;
  String? get roomId => _roomId;
  String? get roomName => _roomName;
  String? get peerId => _peerId;
  SeatUser? get activeLoggedInSeatUser => _activeLoggedInSeatUser;
  RoomMediaEngine get mediaEngine => _mediaEngine;

  SeatUser effectiveCurrentUser(SeatUser fallback) {
    return _activeLoggedInSeatUser ?? fallback;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    _debug('app lifecycle changed: $state');

    if (_appInForeground) {
      _scheduleReconnect(reason: 'app resumed');
      // Production AppShell lifecycle recovery flows through the registered
      // resource participant. Keep a direct fallback only for isolated/test
      // contexts where no resource registry is available.
      if (_mediaResourceRegistry == null) {
        _runMediaAction(
          _mediaEngine.reconnect(),
          label: 'resume room audio fallback',
        );
      }
    }
  }

  void configureRoom({
    required String roomId,
    required String roomName,
    MediaResourceRegistry? resourceRegistry,
  }) {
    final nextRoomId = roomId.trim().isEmpty ? 'VM257808' : roomId.trim();

    _roomId = nextRoomId;
    _roomName = roomName.trim().isEmpty ? 'Live Room' : roomName.trim();
    _configureMediaResourceLifecycle(nextRoomId, resourceRegistry);

    if (roomSnapshot.value?.roomId != nextRoomId) {
      roomSnapshot.value = null;
      roomBlock.value = null;
      seatInvite.value = null;
      _seatAuthorityGate.cancelPendingSeat();
    }
  }

  void _configureMediaResourceLifecycle(
    String roomId,
    MediaResourceRegistry? resourceRegistry,
  ) {
    final nextResourceId = 'room-webrtc:$roomId';
    final currentParticipant = _mediaResourceParticipant;
    if (identical(_mediaResourceRegistry, resourceRegistry) &&
        currentParticipant?.resourceId == nextResourceId) {
      return;
    }

    _detachMediaResourceLifecycle();
    if (resourceRegistry == null) return;

    final participant = RoomMediaResourceParticipant(
      resourceId: nextResourceId,
      engine: _mediaEngine,
    );
    try {
      resourceRegistry.register(participant);
      _mediaResourceRegistry = resourceRegistry;
      _mediaResourceParticipant = participant;
      unawaited(
        participant
            .onForegroundChanged(resourceRegistry.isForeground)
            .catchError((Object error) {
              _warn('room media lifecycle sync failed: $error');
            }),
      );
    } catch (error) {
      _warn('room media lifecycle registration failed: $error');
    }
  }

  void _detachMediaResourceLifecycle() {
    final registry = _mediaResourceRegistry;
    final participant = _mediaResourceParticipant;
    _mediaResourceRegistry = null;
    _mediaResourceParticipant = null;
    if (registry == null || participant == null) return;
    registry.unregister(
      participant.resourceId,
      expectedParticipant: participant,
    );
  }

  void setActiveLoggedInUser(CurrentUser user) {
    final isOfficial = user.canSeeOwnerControls;
    final roleLabel =
        user.primaryRoleBadge?.badgeLabel ?? user.roleDisplayLabel;
    final roomUserId = 'user_${user.publicUserId}';
    final existingRoomUser =
        _activeLoggedInSeatUser?.id == roomUserId &&
            _roomScopedRoleRoomId == _roomId
        ? _activeLoggedInSeatUser
        : null;
    final isRoomHost = isOfficial || (existingRoomUser?.isHost ?? false);
    final isRoomAdmin =
        isOfficial || isRoomHost || (existingRoomUser?.isRoomAdmin ?? false);
    final roomRoleLabel = isRoomHost
        ? 'Channel Host'
        : isRoomAdmin
        ? 'Admin'
        : roleLabel;

    _activeLoggedInSeatUser = SeatUser(
      id: roomUserId,
      name: user.displayName ?? user.username ?? 'Vibe User',
      roleLabel: roomRoleLabel,
      familyName: existingRoomUser?.familyName ?? '',
      familyLevel: existingRoomUser?.familyLevel ?? 'bronze',
      relationshipText: existingRoomUser?.relationshipText ?? '',
      vipLevel: user.vip.vipLevel,
      svipLevel: user.vip.svipLevel,
      sendingLevel: existingRoomUser?.sendingLevel ?? 0,
      receivingLevel: existingRoomUser?.receivingLevel ?? 0,
      sentExp: existingRoomUser?.sentExp ?? 0,
      receivedExp: existingRoomUser?.receivedExp ?? 0,
      medals: existingRoomUser?.medals ?? const <String>[],
      avatarColors: isOfficial
          ? const <Color>[Color(0xFFFFC857), Color(0xFFE84C72)]
          : existingRoomUser?.avatarColors ??
                const <Color>[Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      avatarUrl: user.avatarUrl,
      age: existingRoomUser?.age,
      locationLabel: existingRoomUser?.locationLabel,
      locationVisible: existingRoomUser?.locationVisible ?? true,
      gender: existingRoomUser?.gender ?? RoomUserGender.undisclosed,
      isCurrentUser: true,
      isHost: isRoomHost,
      isRoomAdmin: isRoomAdmin,
      selfMuted: existingRoomUser?.selfMuted ?? true,
      adminMuted: existingRoomUser?.adminMuted ?? false,
    );
    if (_currentUser?.id == roomUserId) {
      _currentUser = _activeLoggedInSeatUser;
    }

    final roomId = _roomId;
    final shouldSyncActiveRoom =
        roomId != null &&
        (roomSnapshot.value?.roomId == roomId || _joined);
    if (shouldSyncActiveRoom) {
      _overlayCurrentUserProfileInSnapshot(_activeLoggedInSeatUser!);
    }

    if (_joined && _appRealtimeHub.isConnected) {
      _send('profile/update', _profileUpdatePayload(_activeLoggedInSeatUser!));
    }

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
      avatarUrl: user.avatarUrl,
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
    _roomScopedRoleRoomId = _roomId;

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

  void takeSeat(int seatIndex, {bool? micEnabled}) {
    if (seatIndex < 0) return;

    seatInvite.value = null;
    _seatAuthorityGate.requestSeat(seatIndex, micEnabled: micEnabled);

    final payload = <String, Object?>{'seat_index': seatIndex};
    if (micEnabled != null) payload['mic_enabled'] = micEnabled;
    _send('seat/take', payload);
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

  void acceptSeatInvite({required int seatIndex}) {
    if (seatIndex < 0) return;
    seatInvite.value = null;
    _seatAuthorityGate.requestSeat(seatIndex);
    _send('seat_invite/accept', <String, Object?>{'seat_index': seatIndex});
  }

  void rejectSeatInvite({required int seatIndex}) {
    if (seatIndex < 0) return;
    _send('seat_invite/reject', <String, Object?>{'seat_index': seatIndex});
    seatInvite.value = null;
  }

  void clearSeatInvite() {
    seatInvite.value = null;
  }

  void rejectSeatApplication({
    required int seatIndex,
    required String targetUserId,
  }) {
    if (seatIndex < 0 || targetUserId.trim().isEmpty) return;
    _send('seat_application/reject', <String, Object?>{
      'seat_index': seatIndex,
      'target_user_id': targetUserId,
    });
  }

  void leaveSeat() {
    _seatAuthorityGate.cancelPendingSeat();
    _runMediaAction(
      _mediaEngine.stopPublishingMic(),
      label: 'stop mic publishing',
    );

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
      _runMediaAction(
        _mediaEngine.mute(),
        label: 'mute microphone',
      );

      _send('mic/set_enabled', <String, Object?>{'enabled': false});
      return;
    }

    // FastAPI's following room snapshot confirms both seat ownership and the
    // mic state.  Do not start a producer merely because this command was sent.
    _seatAuthorityGate.requestMicEnabled(enabled);
    if (!enabled) _runMediaAction(
        _mediaEngine.mute(),
        label: 'mute microphone',
      );

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

  void requestRoomMembership() {
    _send('room_member/request', const <String, Object?>{});
  }

  void approveRoomMembership(String targetUserId) {
    final target = targetUserId.trim();
    if (target.isEmpty) return;
    _send('room_member/approve', <String, Object?>{
      'target_user_id': target,
    });
  }

  void rejectRoomMembership(String targetUserId) {
    final target = targetUserId.trim();
    if (target.isEmpty) return;
    _send('room_member/reject', <String, Object?>{
      'target_user_id': target,
    });
  }

  void removeRoomMembership(String targetUserId) {
    final target = targetUserId.trim();
    if (target.isEmpty) return;
    _send('room_member/remove', <String, Object?>{
      'target_user_id': target,
    });
  }

  void startCricketMode(CricketQuickMatchSetup setup) {
    _send('room_cricket/start', <String, Object?>{
      'room_id': setup.roomId,
      'setup': setup.toJson(),
      'background_theme_id': cricketFloodlightArenaBackgroundTheme.id,
    });
  }

  void endCricketMode(String roomId) {
    final safeRoomId = roomId.trim();
    if (safeRoomId.isEmpty) return;

    _send('room_cricket/end', <String, Object?>{
      'room_id': safeRoomId,
      'background_theme_id': defaultRoomBackgroundTheme.id,
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

  Future<void> leaveRoom() async {
    _shouldStayConnected = false;
    _detachMediaResourceLifecycle();
    _seatAuthorityGate.cancelPendingSeat();
    // RoomSessionRepository owns the durable room/leave mutation. This facade
    // only tears down the shared room subscription and media plane.
    final leavingRoomId = _roomId;
    if (leavingRoomId != null && leavingRoomId.trim().isNotEmpty) {
      _appRealtimeHub.unsubscribeRoom(leavingRoomId);
    }

    _joined = false;
    _peerId = null;
    roomSnapshot.value = null;
    roomBlock.value = null;
    seatInvite.value = null;

    await _mediaEngine.leave();
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _connecting = false;

    await _stopForegroundServiceIfNeeded();
  }

  Future<void> _disconnectAfterServerRemoval({
    required LiveMediaRoomBlock block,
  }) async {
    roomBlock.value = block;
    _shouldStayConnected = false;
    _seatAuthorityGate.cancelPendingSeat();
    final removedRoomId = _roomId;
    if (removedRoomId != null && removedRoomId.trim().isNotEmpty) {
      _appRealtimeHub.unsubscribeRoom(removedRoomId);
    }

    _joined = false;
    _peerId = null;
    roomSnapshot.value = null;
    seatInvite.value = null;
    _detachMediaResourceLifecycle();

    await _mediaEngine.leave();
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
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
        animationStyle: VmMotion.sheetAnimationStyle,
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

    if (_joined && _appRealtimeHub.isConnected) {
      _debug(
        'application room transport already joined; preserving session for $reason',
      );
      return;
    }

    _debug('joining application room transport: $reason');
    await _connect();

    if (!_appRealtimeHub.isConnected) {
      _scheduleReconnect(reason: 'shared realtime hub unavailable');
      return;
    }

    // Authoritative room presence was already established by
    // RoomSessionRepository before this facade is entered. The Go socket only
    // subscribes to room events; it must not perform a duplicate room/join.
    _appRealtimeHub.subscribeRoom(safeRoomId);
    _peerId ??= '${safeRoomId}_${effectiveUser.id}'.replaceAll(
      RegExp(r'[^a-zA-Z0-9_\-]'),
      '_',
    );
    _joined = true;
    roomBlock.value = null;
    _joinAudioAfterMediaJoin();
  }

  Future<void> _connect() async {
    if (_connecting) return;
    _connecting = true;
    try {
      _realtimeSubscription ??= _appRealtimeHub.events.listen(_handleMessage);
      await _appRealtimeHub.start();
      _debug('application realtime delegated to AppRealtimeHub');
    } catch (error) {
      _warn('shared application realtime start failed: $error');
      _scheduleReconnect(reason: 'shared realtime start failed');
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

    _debug('application realtime reconnect delegated to AppRealtimeHub: $reason');
    unawaited(
      _appRealtimeHub.start().catchError((Object error) {
        _warn('shared application realtime reconnect failed: $error');
      }),
    );
  }

  Map<String, Object?> _profileUpdatePayload(SeatUser user) {
    return <String, Object?>{
      'room_id': _roomId,
      'peer_id': _peerId,
      'user_id': user.id,
      'display_name': user.name,
      'avatar_url': user.avatarUrl,
      'vip_level': user.vipLevel,
      'svip_level': user.svipLevel,
      'sending_level': user.sendingLevel,
      'receiving_level': user.receivingLevel,
      'is_host': user.isHost,
      'is_room_admin': user.isRoomAdmin || user.isHost,
      'role_label': _roomRoleLabelFor(user),
    };
  }

  String _roomRoleLabelFor(SeatUser user) {
    if (user.isHost) return 'Channel Host';
    if (user.isRoomAdmin) return 'Admin';
    return user.roleLabel;
  }

  void _send(String type, Map<String, Object?> payload) {
    final roomId = _roomId?.trim();
    if (!_appRealtimeHub.isConnected ||
        roomId == null ||
        roomId.isEmpty) {
      _debug('application realtime send skipped: $type');
      _scheduleReconnect(reason: 'send skipped for $type');
      return;
    }

    try {
      final commandId =
          '${DateTime.now().microsecondsSinceEpoch}_${_commandSequence++}';
      _appRealtimeHub.sendRaw(<String, dynamic>{
        'type': type,
        'room_public_id': roomId,
        'command_id': commandId,
        'payload': Map<String, Object?>.from(payload),
      });
      _debug('application realtime sent: $type command=$commandId');
    } catch (error) {
      _warn('application realtime send failed for $type: $error');
      _scheduleReconnect(reason: 'send failed for $type');
    }
  }

  void _handleMessage(RealtimeEventEnvelope event) {
    try {
      final decoded = event.toLegacyEvent();
      final type = decoded['type']?.toString() ?? 'unknown';
      final rawPayload = decoded['payload'];
      final payload = rawPayload is Map
          ? rawPayload.cast<String, dynamic>()
          : Map<String, dynamic>.from(decoded);

      final eventRoomId =
          payload['room_id']?.toString() ??
          payload['room_public_id']?.toString() ??
          decoded['room_id']?.toString() ??
          decoded['room_public_id']?.toString();
      final activeRoomId = _roomId?.trim();
      if (eventRoomId != null &&
          eventRoomId.trim().isNotEmpty &&
          activeRoomId != null &&
          eventRoomId.trim() != activeRoomId) {
        return;
      }
      if (type.startsWith('inbox.') ||
          type.startsWith('inbox_') ||
          type.startsWith('wallet.') ||
          type.startsWith('notification.')) {
        return;
      }

      _debug('application realtime received: $type $payload');

      final rawCanonicalRoom = payload['room'];
      if (rawCanonicalRoom is Map) {
        final canonicalRoom = rawCanonicalRoom.cast<String, dynamic>();
        final snapshotRoomId =
            canonicalRoom['room_id']?.toString() ??
            canonicalRoom['room_public_id']?.toString() ??
            payload['room_id']?.toString();
        if (_roomId == null ||
            snapshotRoomId == null ||
            snapshotRoomId.trim().isEmpty ||
            snapshotRoomId.trim() == _roomId) {
          _canonicalRoomSnapshotController.add(
            Map<String, dynamic>.unmodifiable(canonicalRoom),
          );
        }
      }

      if (type == 'command/ack') {
        return;
      }

      if (type == 'command/error') {
        _debug(
          'room command rejected: '
          '${payload['command_type']} ${payload['message']}',
        );
        if (payload['command_type']?.toString() == 'seat/take') {
          _seatAuthorityGate.rejectSeatRequest();
          _runMediaAction(
      _mediaEngine.stopPublishingMic(),
      label: 'stop mic publishing',
    );
        }
        return;
      }

      if (type == 'room/system_event') {
        return;
      }
      if (type == 'room_admin/updated') {
        final roomData = payload['room'];
        if (roomData is Map<String, dynamic>) {
          roomSnapshot.value = LiveMediaRoomSnapshot.fromJson(roomData);
          _enforceCurrentUserAudioStateFromSnapshot(roomSnapshot.value);
        }

        return;
      }
      if (type == 'seat_application/received') {
        return;
      }

      if (type == 'room_settings/updated') {
        final roomData = payload['room'];
        if (roomData is Map<String, dynamic>) {
          roomSnapshot.value = LiveMediaRoomSnapshot.fromJson(roomData);
          _enforceCurrentUserAudioStateFromSnapshot(roomSnapshot.value);
        }

        return;
      }

      if (type == 'room_cricket/state') {
        // Cricket presentation state is owned by the mounted
        // LiveRoomControllerBundle. The shared media transport must not write
        // process-global UI state; scoped realtime subscribers project this
        // event into their own room controller.
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
        if (type == 'room/kicked' && !_payloadTargetsCurrentUser(payload)) {
          final roomData = payload['room'];
          if (roomData is Map<String, dynamic>) {
            roomSnapshot.value = LiveMediaRoomSnapshot.fromJson(roomData);
          }
          return;
        }
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

      if (type == 'profile/updated') {
        _publishProfileUpdateFromPayload(payload);
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
      _warn('received unreadable websocket message');
    }
  }

  void _joinAudioAfterMediaJoin() {
    final roomId = _roomId;
    final user = _currentUser ?? _activeLoggedInSeatUser;

    if (roomId == null || user == null) return;

    _runMediaAction(
      _mediaEngine.join(
        RoomMediaJoinRequest(
          roomId: roomId,
          userId: user.id,
        ),
      ),
      label: 'join room audio',
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
      stateVersion: snapshot.stateVersion,
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

  void _overlayCurrentUserProfileInSnapshot(SeatUser user) {
    final snapshot = roomSnapshot.value;
    if (snapshot == null) return;

    final currentPeerId = _peerId;
    final roleLabel = _roomRoleLabelFor(user);

    roomSnapshot.value = LiveMediaRoomSnapshot(
      roomId: snapshot.roomId,
      stateVersion: snapshot.stateVersion,
      peerCount: snapshot.peerCount,
      lockedSeatIndexes: snapshot.lockedSeatIndexes,
      peers: snapshot.peers.map((peer) {
        final matchesUser = peer.userId == user.id;
        final matchesPeer =
            currentPeerId != null &&
            currentPeerId.isNotEmpty &&
            peer.peerId == currentPeerId;
        if (!matchesUser && !matchesPeer) return peer;

        return peer.copyWith(
          displayName: user.name,
          isHost: user.isHost,
          isRoomAdmin: user.isRoomAdmin || user.isHost,
          roleLabel: roleLabel,
          avatarUrl: user.avatarUrl,
          clearAvatarUrl: user.avatarUrl == null,
          vipLevel: user.vipLevel,
          svipLevel: user.svipLevel,
          sendingLevel: user.sendingLevel,
          receivingLevel: user.receivingLevel,
        );
      }).toList(),
    );
  }

  void _publishProfileUpdateFromPayload(
    Map<String, dynamic> payload,
  ) {
    final userId = payload['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    final snapshot = roomSnapshot.value;
    if (snapshot == null) return;

    final isHost =
        payload['is_host'] == true || payload['isHost'] == true;
    final isRoomAdmin =
        payload['is_room_admin'] == true ||
        payload['isRoomAdmin'] == true;
    final displayName =
        _text(payload['display_name'] ?? payload['displayName']);
    final roleLabel =
        _text(payload['role_label'] ?? payload['roleLabel']);
    final avatarUrl =
        _text(payload['avatar_url'] ?? payload['avatarUrl']);

    roomSnapshot.value = LiveMediaRoomSnapshot(
      roomId: snapshot.roomId,
      stateVersion: snapshot.stateVersion,
      peerCount: snapshot.peerCount,
      lockedSeatIndexes: snapshot.lockedSeatIndexes,
      peers: snapshot.peers.map((peer) {
        if (peer.userId != userId) return peer;
        return peer.copyWith(
          displayName: displayName,
          isHost: isHost,
          isRoomAdmin: isRoomAdmin || isHost,
          roleLabel: isHost
              ? 'Channel Host'
              : isRoomAdmin
              ? 'Admin'
              : roleLabel,
          avatarUrl: avatarUrl,
          clearAvatarUrl: avatarUrl == null,
          vipLevel: _int(
            payload['vip_level'] ?? payload['vipLevel'],
          ),
          svipLevel: _int(
            payload['svip_level'] ?? payload['svipLevel'],
          ),
          sendingLevel: _int(
            payload['sending_level'] ?? payload['sendingLevel'],
          ),
          receivingLevel: _int(
            payload['receiving_level'] ??
                payload['receivingLevel'],
          ),
        );
      }).toList(growable: false),
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
      stateVersion: snapshot.stateVersion,
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

    final decision = _seatAuthorityGate.observe(
      authoritativeSeatIndex: currentPeer?.seatIndex,
      authoritativeMicEnabled: currentPeer?.micEnabled ?? false,
      adminMuted: currentPeer?.adminMuted ?? false,
    );

    if (decision.awaitSeatConfirmation) {
      _debug(
        'awaiting authoritative seat confirmation before changing local audio',
      );
      return;
    }

    if (decision.shouldLeaveSeat) {
      _debug('current user is no longer seated; forcing local audio leaveSeat');
      _runMediaAction(
      _mediaEngine.stopPublishingMic(),
      label: 'stop mic publishing',
    );
      return;
    }

    final confirmedSeatIndex = decision.confirmedSeatIndex;
    if (confirmedSeatIndex != null) {
      _runMediaAction(
        _mediaEngine.publishMic(
          seatIndex: confirmedSeatIndex,
          muted: decision.micEnabled != true,
        ),
        label: 'apply authoritative microphone state',
      );
    }

    if (currentPeer?.adminMuted == true) {
      _debug('admin mute enforced from room snapshot for current user');
      _runMediaAction(
        _mediaEngine.mute(),
        label: 'mute microphone',
      );
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

  bool _payloadTargetsCurrentUser(Map<String, dynamic> payload) {
    final currentUserId = _currentUser?.id ?? _activeLoggedInSeatUser?.id;
    final currentPeerId = _peerId;
    final targetValues = <String>[
      payload['target_user_id']?.toString() ?? '',
      payload['target_backend_user_id']?.toString() ?? '',
      payload['target_public_user_id']?.toString() ?? '',
      payload['target_peer_id']?.toString() ?? '',
    ].where((value) => value.trim().isNotEmpty).toList();
    if (targetValues.isEmpty) return true;
    for (final value in targetValues) {
      if (currentUserId != null &&
          _identityAliases(value).contains(currentUserId)) {
        return true;
      }
      if (currentPeerId != null && value == currentPeerId) return true;
    }
    return false;
  }

  Set<String> _identityAliases(String rawId) {
    final value = rawId.trim();
    if (value.isEmpty) return <String>{};
    final aliases = <String>{value, value.toLowerCase()};
    final match = RegExp(r'(?:^|_)user_(\d+)$').firstMatch(value);
    if (match != null) {
      aliases.add(match.group(1)!);
      aliases.add('user_${match.group(1)!}');
    }
    final direct = int.tryParse(value);
    if (direct != null) aliases.add('user_$direct');
    return aliases;
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
    _runMediaAction(
        _mediaEngine.mute(),
        label: 'mute microphone',
      );
  }

  void applyCanonicalRoomState(Map<String, dynamic> room) {
    final projectedRoomId =
        room['room_id']?.toString() ??
        room['room_public_id']?.toString() ??
        _roomId;
    if (projectedRoomId != null &&
        _roomId != null &&
        projectedRoomId.trim().isNotEmpty &&
        projectedRoomId.trim() != _roomId!.trim()) {
      return;
    }

    final canonical = Map<String, dynamic>.unmodifiable(
      Map<String, dynamic>.from(room),
    );
    _canonicalRoomSnapshotController.add(canonical);

    try {
      final nextSnapshot = LiveMediaRoomSnapshot.fromJson(canonical);
      roomSnapshot.value = nextSnapshot;
      _enforceCurrentUserAudioStateFromSnapshot(nextSnapshot);
    } catch (error) {
      _warn('canonical room projection ignored: $error');
    }
  }

  void _runMediaAction(
    Future<void> action, {
    required String label,
  }) {
    unawaited(
      action.catchError((Object error) {
        _warn('$label failed: $error');
      }),
    );
  }


  void _debug(String message) {
    LiveRoomLog.trace('Media', message);
  }

  void _warn(String message) {
    LiveRoomLog.warning('Media', message);
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
    this.stateVersion = 0,
    this.lockedSeatIndexes = const <int>{},
  }) : peerCount = peerCount ?? peers.length;

  final String roomId;
  final int peerCount;
  final int stateVersion;
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
    final stateVersion =
        int.tryParse(json['state_version']?.toString() ?? '') ?? 0;

    return LiveMediaRoomSnapshot(
      roomId: json['room_id']?.toString() ?? '',
      peerCount: parsedPeerCount ?? peers.length,
      stateVersion: stateVersion,
      peers: peers,
      lockedSeatIndexes: lockedSeatIndexes,
    );
  }
}

class _VersionedRoomSnapshotNotifier
    extends ValueNotifier<LiveMediaRoomSnapshot?> {
  _VersionedRoomSnapshotNotifier() : super(null);

  @override
  set value(LiveMediaRoomSnapshot? next) {
    final current = super.value;
    if (next != null &&
        current != null &&
        next.roomId == current.roomId &&
        next.stateVersion < current.stateVersion) {
      return;
    }
    super.value = next;
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
    this.avatarUrl,
    this.vipLevel = 0,
    this.svipLevel = 0,
    this.sendingLevel = 0,
    this.receivingLevel = 0,
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
  final String? avatarUrl;
  final int vipLevel;
  final int svipLevel;
  final int sendingLevel;
  final int receivingLevel;
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
      avatarUrl: _text(json['avatar_url'] ?? json['avatarUrl']),
      vipLevel: _int(json['vip_level'] ?? json['vipLevel']),
      svipLevel: _int(json['svip_level'] ?? json['svipLevel']),
      sendingLevel: _int(json['sending_level'] ?? json['sendingLevel']),
      receivingLevel: _int(json['receiving_level'] ?? json['receivingLevel']),
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
    String? avatarUrl,
    bool clearAvatarUrl = false,
    int? vipLevel,
    int? svipLevel,
    int? sendingLevel,
    int? receivingLevel,
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
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      vipLevel: vipLevel ?? this.vipLevel,
      svipLevel: svipLevel ?? this.svipLevel,
      sendingLevel: sendingLevel ?? this.sendingLevel,
      receivingLevel: receivingLevel ?? this.receivingLevel,
      seatIndex: clearSeatIndex ? null : seatIndex ?? this.seatIndex,
      micEnabled: micEnabled ?? this.micEnabled,
      adminMuted: adminMuted ?? this.adminMuted,
    );
  }
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty || text == 'null' ? null : text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
