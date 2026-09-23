import '../../../realtime/app_realtime_hub.dart';
import 'live_room_media_signaling_service.dart';

class LiveRoomMusicSignalingService {
  LiveRoomMusicSignalingService._();

  static final LiveRoomMusicSignalingService instance =
      LiveRoomMusicSignalingService._();

  final AppRealtimeHub _hub = AppRealtimeHub.shared;

  bool get isConnected => _hub.isConnected;

  Future<void> sendControl({
    required String roomId,
    required String action,
    required String trackId,
    required String trackTitle,
    required int positionMs,
    required int durationMs,
  }) async {
    await _hub.start();
    final event = action == 'stop'
        ? 'room_music/stop_external'
        : 'room_music/control_external';
    _send(event, _basePayload(roomId)..addAll(<String, Object?>{
      'action': action,
      'track_id': trackId,
      'track_title': trackTitle,
      'position_ms': positionMs < 0 ? 0 : positionMs,
      'duration_ms': durationMs < 0 ? 0 : durationMs,
      'producer_id': _producerIdFor(roomId),
      'media_tag': 'room-music-audio',
    }));
  }

  Future<void> sendProducerStarted({
    required String roomId,
    required String trackId,
    required String trackTitle,
    required int positionMs,
    required int durationMs,
  }) async {
    await _hub.start();
    _send(
      'room_music/producer_started_external',
      _basePayload(roomId)..addAll(<String, Object?>{
        'track_id': trackId,
        'track_title': trackTitle,
        'position_ms': positionMs < 0 ? 0 : positionMs,
        'duration_ms': durationMs < 0 ? 0 : durationMs,
        'producer_id': _producerIdFor(roomId),
        'media_tag': 'room-music-audio',
      }),
    );
  }

  Future<void> close() async {
    // AppRealtimeHub is application-scoped and must not be stopped by a
    // feature compatibility service.
  }

  Map<String, Object?> _basePayload(String roomId) {
    final activeUser =
        LiveRoomMediaSignalingService.instance.activeLoggedInSeatUser;
    final peerId = LiveRoomMediaSignalingService.instance.peerId ??
        (activeUser == null
            ? 'room_music_controller'
            : '${roomId}_${activeUser.id}');
    return <String, Object?>{
      'room_id': roomId,
      'controller_peer_id': peerId,
      'controller_user_id': activeUser?.id ?? 'room_music_user',
      'controller_name': activeUser?.name ?? 'Room music',
      'is_host': activeUser?.isHost == true,
      'is_room_admin':
          activeUser?.isRoomAdmin == true || activeUser?.isHost == true,
    };
  }

  String _producerIdFor(String roomId) {
    final peerId =
        LiveRoomMediaSignalingService.instance.peerId ?? 'room_music';
    return '${roomId}_${peerId}_music_audio'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  void _send(String type, Map<String, Object?> payload) {
    final safeRoomId = payload['room_id']?.toString().trim() ?? '';
    if (safeRoomId.isEmpty) return;
    _hub.sendRaw(<String, dynamic>{
      'type': type,
      'room_public_id': safeRoomId,
      'command_id':
          'music-${DateTime.now().microsecondsSinceEpoch}',
      'payload': payload,
    });
  }
}
