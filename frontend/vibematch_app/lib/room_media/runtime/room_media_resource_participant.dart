import '../../foundation/runtime/media_resource_lifecycle.dart';
import '../domain/room_media_engine.dart';

/// Chunk 34-M9 lifecycle adapter for the canonical room WebRTC/mediasoup engine.
///
/// The engine remains transport-only authority. Room membership, permissions,
/// seats and durable room state stay in RoomSessionRepository/backend.
class RoomMediaResourceParticipant implements MediaResourceParticipant {
  RoomMediaResourceParticipant({
    required this.resourceId,
    required RoomMediaEngine engine,
  }) : _engine = engine;

  @override
  final String resourceId;

  final RoomMediaEngine _engine;
  bool _released = false;

  @override
  MediaResourceKind get kind => MediaResourceKind.roomWebRtc;

  /// Foreground recovery reconnects an existing media session. Backgrounding is
  /// deliberately non-destructive so seat/mic intent and foreground-service
  /// behavior are preserved.
  @override
  Future<void> onForegroundChanged(bool isForeground) async {
    if (_released || !isForeground || _engine.isDisposed) return;
    final phase = _engine.phase;
    if (_engine.roomId == null ||
        (phase != RoomMediaEnginePhase.joining &&
            phase != RoomMediaEnginePhase.joined &&
            phase != RoomMediaEnginePhase.reconnecting)) {
      return;
    }
    await _engine.reconnect();
  }

  /// Active WebRTC transports are not reconstructable warm cache. Memory
  /// pressure must not silently leave or rebuild the room media session.
  @override
  Future<void> onMemoryPressure() async {}

  /// Session teardown leaves the active room media session but does not
  /// terminally dispose the singleton-owned engine, which may be reused after
  /// a future authenticated session.
  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    if (_engine.isDisposed) return;
    await _engine.leave();
  }
}
