import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vibematch_app/foundation/runtime/media_resource_lifecycle.dart';
import 'package:vibematch_app/room_media/domain/room_media_engine.dart';
import 'package:vibematch_app/room_media/runtime/room_media_resource_participant.dart';

/// Chunk 34-M9 behavior coverage for the canonical room WebRTC lifecycle.
void main() {
  test('exposes stable room WebRTC resource kind', () {
    final engine = _FakeRoomMediaEngine();
    final participant = RoomMediaResourceParticipant(
      resourceId: 'room-webrtc:room-1',
      engine: engine,
    );

    expect(participant.resourceId, 'room-webrtc:room-1');
    expect(participant.kind, MediaResourceKind.roomWebRtc);
  });

  test('foreground reconnects an active joined media session only', () async {
    final engine = _FakeRoomMediaEngine()
      ..room = 'room-1'
      ..currentPhase = RoomMediaEnginePhase.joined;
    final participant = RoomMediaResourceParticipant(
      resourceId: 'room-webrtc:room-1',
      engine: engine,
    );

    await participant.onForegroundChanged(false);
    await participant.onForegroundChanged(true);

    expect(engine.reconnectCount, 1);
  });

  test('foreground does not reconnect an idle engine', () async {
    final engine = _FakeRoomMediaEngine();
    final participant = RoomMediaResourceParticipant(
      resourceId: 'room-webrtc:room-1',
      engine: engine,
    );

    await participant.onForegroundChanged(true);

    expect(engine.reconnectCount, 0);
  });

  test('memory pressure does not tear down active WebRTC', () async {
    final engine = _FakeRoomMediaEngine()
      ..room = 'room-1'
      ..currentPhase = RoomMediaEnginePhase.joined;
    final participant = RoomMediaResourceParticipant(
      resourceId: 'room-webrtc:room-1',
      engine: engine,
    );

    await participant.onMemoryPressure();

    expect(engine.leaveCount, 0);
    expect(engine.disposeCount, 0);
  });

  test('session release leaves once without terminal engine disposal', () async {
    final engine = _FakeRoomMediaEngine()
      ..room = 'room-1'
      ..currentPhase = RoomMediaEnginePhase.joined;
    final participant = RoomMediaResourceParticipant(
      resourceId: 'room-webrtc:room-1',
      engine: engine,
    );

    await participant.release();
    await participant.release();
    await participant.onForegroundChanged(true);

    expect(engine.leaveCount, 1);
    expect(engine.disposeCount, 0);
    expect(engine.reconnectCount, 0);
  });
}

class _FakeRoomMediaEngine implements RoomMediaEngine {
  final ValueNotifier<List<RTCVideoRenderer>> _renderers =
      ValueNotifier<List<RTCVideoRenderer>>(<RTCVideoRenderer>[]);
  final ValueNotifier<Set<String>> _speakers =
      ValueNotifier<Set<String>>(<String>{});
  final ValueNotifier<String?> _error = ValueNotifier<String?>(null);

  String? room;
  String? user;
  RoomMediaEnginePhase currentPhase = RoomMediaEnginePhase.idle;
  bool disposed = false;
  int reconnectCount = 0;
  int leaveCount = 0;
  int disposeCount = 0;

  @override
  RoomMediaEnginePlatform get platform => RoomMediaEnginePlatform.native;

  @override
  RoomMediaEnginePhase get phase => currentPhase;

  @override
  String? get roomId => room;

  @override
  String? get userId => user;

  @override
  bool get isDisposed => disposed;

  @override
  ValueListenable<List<RTCVideoRenderer>> get remoteAudioRenderers => _renderers;

  @override
  ValueListenable<Set<String>> get activeSpeakerPeerIds => _speakers;

  @override
  ValueListenable<String?> get lastError => _error;

  @override
  Future<void> join(RoomMediaJoinRequest request) async {
    room = request.roomId;
    user = request.userId;
    currentPhase = RoomMediaEnginePhase.joined;
  }

  @override
  Future<void> leave() async {
    leaveCount += 1;
    room = null;
    user = null;
    currentPhase = RoomMediaEnginePhase.idle;
  }

  @override
  Future<void> publishMic({required int seatIndex, bool muted = false}) async {}

  @override
  Future<void> stopPublishingMic() async {}

  @override
  Future<void> mute() async {}

  @override
  Future<void> unmute() async {}

  @override
  Future<void> consume(RoomMediaRemoteProducer producer) async {}

  @override
  Future<void> reconnect() async {
    reconnectCount += 1;
    currentPhase = RoomMediaEnginePhase.joined;
  }

  @override
  Future<bool> startRoomMusic({
    required String url,
    required String title,
    int seekMs = 0,
  }) async => true;

  @override
  Future<bool> stopRoomMusic() async => true;

  @override
  Future<void> preferSystemAudioRoute() async {}

  @override
  Future<void> dispose() async {
    disposeCount += 1;
    disposed = true;
    currentPhase = RoomMediaEnginePhase.disposed;
  }
}
