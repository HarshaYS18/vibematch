import 'dart:async';

import '../../../presence/data/presence_api_service.dart';
import '../../data/live_room_presence_repository.dart';

class LiveRoomPresenceController {
  LiveRoomPresenceController({
    PresenceApiService presenceApi = const PresenceApiService(),
    LiveRoomPresenceRepository? roomPresenceRepository,
  }) : _presenceApi = presenceApi,
       _roomPresenceRepository =
           roomPresenceRepository ?? LiveRoomPresenceRepository();

  final PresenceApiService _presenceApi;
  final LiveRoomPresenceRepository _roomPresenceRepository;
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
    _roomPresenceRepository.close();
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

    await _sendRoomParticipantHeartbeat();
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

    await _sendRoomParticipantHeartbeat();
  }

  Future<void> _sendRoomParticipantHeartbeat() async {
    if (_left) return;
    final roomId = _roomPublicId.trim();
    if (roomId.isEmpty) return;

    try {
      await _roomPresenceRepository.heartbeat(roomId);
    } catch (_) {
      // The websocket room state is still authoritative for visible room UI.
      // If this heartbeat fails, backend stale cleanup will eventually remove
      // the participant after the timeout.
    }
  }
}
