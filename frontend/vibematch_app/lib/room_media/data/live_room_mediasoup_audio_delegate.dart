import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../foundation/runtime/media_resource_lifecycle.dart';

import '../../features/rooms/data/live_room_audio_service.dart';
import '../domain/room_media_engine.dart';
import 'mediasoup_audio_delegate.dart';

/// Compatibility adapter around the production room mediasoup client.
///
/// The legacy service remains the low-level implementation during Chunk 6,
/// but room features no longer depend on it directly.
class LiveRoomMediasoupAudioDelegate implements MediasoupAudioDelegate {
  LiveRoomMediasoupAudioDelegate({
    LiveRoomAudioService? service,
  }) : _service = service ?? LiveRoomAudioService.instance;

  final LiveRoomAudioService _service;

  @override
  void bindMediaResourceRegistry(MediaResourceRegistry? registry) {
    _service.bindMediaResourceRegistry(registry);
  }

  @override
  bool get isJoined => _service.isJoined;

  @override
  String? get roomId => _service.roomId;

  @override
  ValueListenable<List<RTCVideoRenderer>> get remoteAudioRenderers =>
      _service.remoteAudioRenderers;

  @override
  ValueListenable<Set<String>> get activeSpeakerPeerIds =>
      _service.activeSpeakerPeerIds;

  @override
  ValueListenable<String?> get lastError => _service.lastError;

  @override
  Future<void> join({
    required String roomId,
    required String userId,
  }) async {
    if (_service.isJoined && _service.roomId == roomId) return;

    await _service.joinRoomForUser(
      roomId: roomId,
      userId: userId,
    );

    await _waitForBool(
      _service.joined,
      expected: true,
      operation: 'join room media',
      timeout: const Duration(seconds: 30),
    );
  }

  @override
  Future<void> leave() {
    return _service.leaveRoom();
  }

  @override
  Future<void> syncSeat({
    required int seatIndex,
    required bool micEnabled,
  }) async {
    _service.takeSeat(seatIndex, micEnabled: micEnabled);
  }

  @override
  Future<void> stopPublishingMic() async {
    _service.leaveSeat();
  }

  @override
  Future<void> setMuted(bool muted) async {
    _service.setSelfMuted(muted);
  }

  @override
  Future<void> consume(RoomMediaRemoteProducer producer) {
    return _service.consumeRemoteProducer(
      producerId: producer.producerId,
      peerId: producer.peerId,
      kind: producer.kind,
      publicUserId: producer.publicUserId,
      seatNo: producer.seatNo,
    );
  }

  @override
  Future<void> reconnect() async {
    if (_service.roomId == null) return;

    await _service.recoverAfterForeground();

    await _waitForBool(
      _service.joined,
      expected: true,
      operation: 'reconnect room media',
      timeout: const Duration(seconds: 30),
    );
  }

  @override
  Future<bool> startRoomMusic({
    required String url,
    required String title,
    int seekMs = 0,
  }) {
    return _service.startRoomMusic(
      url: url,
      title: title,
      seekMs: seekMs,
    );
  }

  @override
  Future<bool> stopRoomMusic() {
    return _service.stopRoomMusic();
  }

  Future<void> _waitForBool(
    ValueListenable<bool> listenable, {
    required bool expected,
    required String operation,
    required Duration timeout,
  }) async {
    if (listenable.value == expected) return;

    final completer = Completer<void>();

    void listener() {
      if (listenable.value == expected && !completer.isCompleted) {
        completer.complete();
      }
    }

    listenable.addListener(listener);
    try {
      await completer.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Timed out while waiting to $operation.',
          timeout,
        ),
      );
    } finally {
      listenable.removeListener(listener);
    }
  }
}
