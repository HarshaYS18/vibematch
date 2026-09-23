import 'dart:async';

import '../../../presence/data/presence_api_service.dart';

class LiveRoomPresenceController {
  LiveRoomPresenceController({
    PresenceApiService presenceApi = const PresenceApiService(),
  }) : _presenceApi = presenceApi;

  final PresenceApiService _presenceApi;
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
    // The room realtime socket owns live presence through its Redis lease.
    // PostgreSQL presence is checkpointed on lifecycle edges, not every 25s.
    unawaited(_enterRoomPresence());
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

    try {
      await _presenceApi.leaveRoom();
    } catch (_) {
      // Best effort. Socket lease expiry also removes live presence.
    }
  }

  void dispose() {}

  Future<void> _enterRoomPresence() async {
    try {
      await _presenceApi.enterRoom(
        roomPublicId: _roomPublicId,
        roomName: _roomName,
        roomMode: _roomMode,
        isSecret: _isSecret,
      );
    } catch (_) {
      // Presence visibility must never block live room loading.
    }
  }

}
