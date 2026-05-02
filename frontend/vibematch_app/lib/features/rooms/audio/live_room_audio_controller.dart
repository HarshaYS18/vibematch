import 'package:flutter/foundation.dart';

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

  RoomAudioState get state => _engine.state;
  bool get connected => state.connected;
  bool get publishing => state.publishing;
  bool get selfMuted => state.selfMuted;

  Future<void> joinRoomAudio(String roomId) async {
    final session = await _sessionApi.createRoomAudioSession(roomId);
    await _engine.joinAsAudience(
      roomId: session.roomId,
      peerId: session.peerId,
      audioToken: session.audioToken,
    );
  }

  Future<void> takeSeatAndPublish(int seatIndex) async {
    final seatNo = seatIndex + 1;
    await _engine.takeSpeakerSeat(seatNo);
    await _engine.publishMic();
  }

  Future<void> leaveSeat() async {
    await _engine.leaveSpeakerSeat();
  }

  Future<void> toggleSelfMute() async {
    await _engine.setSelfMuted(!state.selfMuted);
  }

  Future<void> stopPublishing() async {
    await _engine.stopPublishing();
  }

  Future<void> leaveRoomAudio() async {
    await _engine.leaveRoomAudio();
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    super.dispose();
  }

  void _onEngineChanged() => notifyListeners();
}
