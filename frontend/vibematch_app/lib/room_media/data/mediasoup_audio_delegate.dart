import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../domain/room_media_engine.dart';

/// Narrow adapter over the existing production mediasoup implementation.
///
/// Keeping this interface separate lets RoomMediaEngine lifecycle tests run
/// without opening sockets or microphone devices.
abstract interface class MediasoupAudioDelegate {
  bool get isJoined;
  String? get roomId;

  ValueListenable<List<RTCVideoRenderer>> get remoteAudioRenderers;
  ValueListenable<Set<String>> get activeSpeakerPeerIds;
  ValueListenable<String?> get lastError;

  Future<void> join({
    required String roomId,
    required String userId,
  });
  Future<void> leave();

  Future<void> syncSeat({
    required int seatIndex,
    required bool micEnabled,
  });
  Future<void> stopPublishingMic();
  Future<void> setMuted(bool muted);

  Future<void> consume(RoomMediaRemoteProducer producer);
  Future<void> reconnect();

  Future<bool> startRoomMusic({
    required String url,
    required String title,
    int seekMs = 0,
  });
  Future<bool> stopRoomMusic();
}
