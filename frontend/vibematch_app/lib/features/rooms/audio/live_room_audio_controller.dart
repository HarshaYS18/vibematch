import 'package:flutter/foundation.dart';

import '../realtime/live_room_realtime_hub.dart';
import 'audio_session_api_service.dart';
import 'mediasoup_room_audio_engine.dart';
import 'room_audio_engine.dart';
import 'room_audio_state.dart';

class LiveRoomAudioController extends ChangeNotifier {
  LiveRoomAudioController({
    AudioSessionApiService? sessionApi,
    RoomAudioEngine? engine,
  })  : _sessionApi = sessionApi ?? AudioSessionApiService(),
        _engine = engine ?? MediasoupRoomAudioEngine() {
    _engine.addListener(_onEngineChanged);
  }

  final AudioSessionApiService _sessionApi;
  final RoomAudioEngine _engine;

  String? _lastRoomId;
  int? _lastSeatIndex;
  bool _wantedPublishing = false;
  bool _operationInFlight = false;

  RoomAudioState get state => _engine.state;
  bool get connected => state.connected;
  bool get connecting => state.connecting;
  bool get publishing => state.publishing;
  bool get selfMuted => state.selfMuted;
  bool get canRetry => _lastRoomId != null && !_operationInFlight;

  Future<void> joinRoomAudio(String roomId) async {
    if (_operationInFlight) return;
    _operationInFlight = true;
    try {
      _lastRoomId = roomId;
      await LiveRoomRealtimeHub.connect(roomId);
      final session = await _sessionApi.createRoomAudioSession(roomId);
      await _engine.joinAsAudience(
        roomId: session.roomId,
        peerId: session.peerId,
        audioToken: session.audioToken,
      );
    } finally {
      _operationInFlight = false;
    }
  }

  Future<void> retryLastRoomAudio() async {
    final roomId = _lastRoomId;
    if (roomId == null) return;
    await joinRoomAudio(roomId);
    if (_wantedPublishing && _lastSeatIndex != null) {
      await takeSeatAndPublish(_lastSeatIndex!);
    }
  }

  Future<void> takeSeatAndPublish(int seatIndex) async {
    _lastSeatIndex = seatIndex;
    _wantedPublishing = true;
    final seatNo = seatIndex + 1;
    await _engine.takeSpeakerSeat(seatNo);
    await _engine.publishMic();
    LiveRoomRealtimeHub.sendSeatTake(seatIndex);
  }

  Future<void> leaveSeat() async {
    final seatIndex = _lastSeatIndex;
    _lastSeatIndex = null;
    _wantedPublishing = false;
    await _engine.leaveSpeakerSeat();
    if (seatIndex != null) {
      LiveRoomRealtimeHub.sendSeatLeave(seatIndex);
    }
  }

  Future<void> toggleSelfMute() async {
    await _engine.setSelfMuted(!state.selfMuted);
    final seatIndex = _lastSeatIndex;
    if (seatIndex != null) {
      LiveRoomRealtimeHub.sendMuteState(
        seatIndex: seatIndex,
        muted: state.selfMuted,
        adminMuted: false,
      );
    }
  }

  Future<void> stopPublishing() async {
    _wantedPublishing = false;
    await _engine.stopPublishing();
  }

  Future<void> leaveRoomAudio() async {
    _lastRoomId = null;
    _lastSeatIndex = null;
    _wantedPublishing = false;
    await _engine.leaveRoomAudio();
    await LiveRoomRealtimeHub.disconnect();
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    super.dispose();
  }

  void _onEngineChanged() => notifyListeners();
}
