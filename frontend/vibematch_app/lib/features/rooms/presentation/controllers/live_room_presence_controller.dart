import 'dart:async';

import '../../../presence/data/presence_api_service.dart';

class LiveRoomPresenceController {
  LiveRoomPresenceController({
    PresenceApiService presenceApi = const PresenceApiService(),
  }) : _presenceApi = presenceApi;

  final PresenceApiService _presenceApi;
  Timer? _heartbeatTimer;
  bool _left = true;
  String _roomPublicId = '';
  String _roomName = '';
  String _roomMode = '';
  bool _isSecret = false;

  void start({
    required String roomPublicId,
    required String roomName,
    required String roomMode,
    required bool isSecret,
  }) {
    updateRoom(
      roomPublicId: roomPublicId,
      roomName: roomName,
      roomMode: roomMode,
      isSecret: isSecret,
    );
    _left = false;
    _heartbeatTimer?.cancel();
    unawaited(_enterRoomPresence());
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => unawaited(_sendHeartbeat()),
    );
  }

  void updateRoom({
    required String roomPublicId,
    required String roomName,
    required String roomMode,
    required bool isSecret,
  }) {
    _roomPublicId = roomPublicId;
    _roomName = roomName;
    _roomMode = roomMode;
    _isSecret = isSecret;
  }

  Future<void> leave() async {
    if (_left) return;
    _left = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    try {
      await _presenceApi.leaveRoom();
    } catch (_) {
      // Best effort. Backend also expires stale room presence by heartbeat.
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _enterRoomPresence() async {
    try {
      await _presenceApi.enterRoom(
        roomPublicId: _roomPublicId,
        roomName: _roomName,
        roomMode: _roomMode,
        isSecret: _isSecret,
      );
    } catch (_) {
      // Room presence must never block live room loading.
    }
  }

  Future<void> _sendHeartbeat() async {
    if (_left) return;

    try {
      await _presenceApi.heartbeat(
        roomPublicId: _roomPublicId,
        roomName: _roomName,
        roomMode: _roomMode,
        isSecret: _isSecret,
      );
    } catch (_) {
      // Keep room stable even if heartbeat fails temporarily.
    }
  }
}
