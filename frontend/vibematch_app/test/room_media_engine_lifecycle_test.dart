import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vibematch_app/room_media/data/delegating_mediasoup_engine.dart';
import 'package:vibematch_app/room_media/data/mediasoup_audio_delegate.dart';
import 'package:vibematch_app/room_media/domain/room_media_engine.dart';

void main() {
  group('RoomMediaEngine lifecycle', () {
    test('deduplicates same-session join and leaves before room switch', () async {
      final delegate = _FakeMediasoupAudioDelegate();
      final engine = _TestMediasoupEngine(delegate);

      await engine.join(
        const RoomMediaJoinRequest(roomId: 'room-a', userId: 'user-1'),
      );
      await engine.join(
        const RoomMediaJoinRequest(roomId: 'room-a', userId: 'user-1'),
      );
      await engine.join(
        const RoomMediaJoinRequest(roomId: 'room-b', userId: 'user-1'),
      );

      expect(
        delegate.calls,
        <String>[
          'join:room-a:user-1',
          'leave',
          'join:room-b:user-1',
        ],
      );
      expect(engine.roomId, 'room-b');
      expect(engine.phase, RoomMediaEnginePhase.joined);
    });

    test('serializes mic intent and room music through the engine', () async {
      final delegate = _FakeMediasoupAudioDelegate();
      final engine = _TestMediasoupEngine(delegate);

      await engine.join(
        const RoomMediaJoinRequest(roomId: 'room-a', userId: 'user-1'),
      );
      await engine.publishMic(seatIndex: 2);
      await engine.mute();
      await engine.unmute();
      await engine.stopPublishingMic();
      final started = await engine.startRoomMusic(
        url: 'https://cdn.example.test/music.mp3',
        title: 'Track',
      );
      final stopped = await engine.stopRoomMusic();

      expect(started, isTrue);
      expect(stopped, isTrue);
      expect(
        delegate.calls,
        containsAllInOrder(<String>[
          'seat:2:true',
          'muted:true',
          'muted:false',
          'stop-mic',
          'music-start',
          'music-stop',
        ]),
      );
    });

    test('deduplicates consumers and reconnects the active session', () async {
      final delegate = _FakeMediasoupAudioDelegate();
      final engine = _TestMediasoupEngine(delegate);

      await engine.join(
        const RoomMediaJoinRequest(roomId: 'room-a', userId: 'user-1'),
      );

      const producer = RoomMediaRemoteProducer(
        producerId: 'producer-1',
        peerId: 'peer-2',
      );

      await engine.consume(producer);
      await engine.consume(producer);
      await engine.reconnect();

      expect(
        delegate.calls.where((call) => call == 'consume:producer-1').length,
        1,
      );
      expect(
        delegate.calls.where((call) => call == 'reconnect').length,
        1,
      );
      expect(engine.phase, RoomMediaEnginePhase.joined);
    });

    test('dispose is terminal and idempotent', () async {
      final delegate = _FakeMediasoupAudioDelegate();
      final engine = _TestMediasoupEngine(delegate);

      await engine.join(
        const RoomMediaJoinRequest(roomId: 'room-a', userId: 'user-1'),
      );

      await engine.dispose();
      await engine.dispose();

      expect(
        delegate.calls.where((call) => call == 'leave').length,
        1,
      );
      expect(engine.phase, RoomMediaEnginePhase.disposed);
      expect(engine.isDisposed, isTrue);

      await expectLater(
        engine.join(
          const RoomMediaJoinRequest(roomId: 'room-b', userId: 'user-1'),
        ),
        throwsStateError,
      );
    });
  });
}

class _TestMediasoupEngine extends DelegatingMediasoupEngine {
  _TestMediasoupEngine(MediasoupAudioDelegate delegate)
      : super(delegate: delegate);

  @override
  RoomMediaEnginePlatform get platform => RoomMediaEnginePlatform.native;

  @override
  Future<void> preferSystemAudioRoute() async {}
}

class _FakeMediasoupAudioDelegate implements MediasoupAudioDelegate {
  final List<String> calls = <String>[];
  final ValueNotifier<List<RTCVideoRenderer>> _remoteAudioRenderers =
      ValueNotifier<List<RTCVideoRenderer>>(<RTCVideoRenderer>[]);
  final ValueNotifier<Set<String>> _activeSpeakerPeerIds =
      ValueNotifier<Set<String>>(<String>{});
  final ValueNotifier<String?> _lastError = ValueNotifier<String?>(null);

  bool _joined = false;
  String? _roomId;

  @override
  bool get isJoined => _joined;

  @override
  String? get roomId => _roomId;

  @override
  ValueListenable<List<RTCVideoRenderer>> get remoteAudioRenderers =>
      _remoteAudioRenderers;

  @override
  ValueListenable<Set<String>> get activeSpeakerPeerIds =>
      _activeSpeakerPeerIds;

  @override
  ValueListenable<String?> get lastError => _lastError;

  @override
  Future<void> join({
    required String roomId,
    required String userId,
  }) async {
    calls.add('join:$roomId:$userId');
    _roomId = roomId;
    _joined = true;
  }

  @override
  Future<void> leave() async {
    calls.add('leave');
    _joined = false;
    _roomId = null;
  }

  @override
  Future<void> syncSeat({
    required int seatIndex,
    required bool micEnabled,
  }) async {
    calls.add('seat:$seatIndex:$micEnabled');
  }

  @override
  Future<void> stopPublishingMic() async {
    calls.add('stop-mic');
  }

  @override
  Future<void> setMuted(bool muted) async {
    calls.add('muted:$muted');
  }

  @override
  Future<void> consume(RoomMediaRemoteProducer producer) async {
    calls.add('consume:${producer.producerId}');
  }

  @override
  Future<void> reconnect() async {
    calls.add('reconnect');
    _joined = true;
  }

  @override
  Future<bool> startRoomMusic({
    required String url,
    required String title,
    int seekMs = 0,
  }) async {
    calls.add('music-start');
    return true;
  }

  @override
  Future<bool> stopRoomMusic() async {
    calls.add('music-stop');
    return true;
  }
}
