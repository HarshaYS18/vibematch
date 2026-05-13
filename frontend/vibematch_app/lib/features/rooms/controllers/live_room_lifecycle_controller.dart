import 'dart:async';

import '../data/room_api_service.dart';

class LiveRoomLifecycleController {
  LiveRoomLifecycleController({RoomApiService? roomApiService})
      : _roomApiService = roomApiService ?? const RoomApiService();

  final RoomApiService _roomApiService;
  Timer? _heartbeatTimer;
  String? _roomId;
  RoomJoinSnapshot? lastSnapshot;
  Object? lastError;

  Future<RoomJoinSnapshot?> join(String roomId) async {
    final safeRoomId = roomId.trim();
    if (safeRoomId.isEmpty) return null;
    _roomId = safeRoomId;
    try {
      final snapshot = await _roomApiService.joinRoom(safeRoomId);
      lastSnapshot = snapshot;
      lastError = null;
      _startHeartbeat();
      return snapshot;
    } catch (error) {
      lastError = error;
      return null;
    }
  }

  Future<RoomJoinSnapshot?> heartbeat() async {
    final safeRoomId = _roomId;
    if (safeRoomId == null || safeRoomId.isEmpty) return null;
    try {
      final snapshot = await _roomApiService.heartbeatRoom(safeRoomId);
      lastSnapshot = snapshot;
      lastError = null;
      return snapshot;
    } catch (error) {
      lastError = error;
      return null;
    }
  }

  Future<List<RoomParticipantDto>> participants() async {
    final safeRoomId = _roomId;
    if (safeRoomId == null || safeRoomId.isEmpty) return const [];
    try {
      final result = await _roomApiService.listParticipants(safeRoomId);
      lastError = null;
      return result;
    } catch (error) {
      lastError = error;
      return const [];
    }
  }

  Future<void> leave() async {
    final safeRoomId = _roomId;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _roomId = null;
    if (safeRoomId == null || safeRoomId.isEmpty) return;
    try {
      await _roomApiService.leaveRoom(safeRoomId);
      lastError = null;
    } catch (error) {
      lastError = error;
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      unawaited(heartbeat());
    });
  }
}
