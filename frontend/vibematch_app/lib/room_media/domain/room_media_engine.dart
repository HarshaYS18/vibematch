import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum RoomMediaEnginePlatform { native, web }

enum RoomMediaEnginePhase {
  idle,
  joining,
  joined,
  reconnecting,
  leaving,
  disposed,
}

@immutable
class RoomMediaJoinRequest {
  const RoomMediaJoinRequest({
    required this.roomId,
    required this.userId,
  });

  final String roomId;
  final String userId;

  String get sessionKey => '${roomId.trim()}::${userId.trim()}';
}

@immutable
class RoomMediaRemoteProducer {
  const RoomMediaRemoteProducer({
    required this.producerId,
    required this.peerId,
    this.kind = 'audio',
    this.publicUserId,
    this.seatNo,
  });

  final String producerId;
  final String peerId;
  final String kind;
  final String? publicUserId;
  final int? seatNo;
}

/// Platform-neutral room media transport contract.
///
/// Room presence, durable membership, permissions, and seat authority remain
/// owned by RoomSessionRepository. This engine only owns WebRTC/mediasoup
/// transport state and local media intent after room-domain authorization.
abstract interface class RoomMediaEngine {
  RoomMediaEnginePlatform get platform;
  RoomMediaEnginePhase get phase;

  String? get roomId;
  String? get userId;
  bool get isDisposed;

  ValueListenable<List<RTCVideoRenderer>> get remoteAudioRenderers;
  ValueListenable<Set<String>> get activeSpeakerPeerIds;
  ValueListenable<String?> get lastError;

  Future<void> join(RoomMediaJoinRequest request);
  Future<void> leave();

  Future<void> publishMic({
    required int seatIndex,
    bool muted = false,
  });
  Future<void> stopPublishingMic();
  Future<void> mute();
  Future<void> unmute();

  Future<void> consume(RoomMediaRemoteProducer producer);
  Future<void> reconnect();

  Future<bool> startRoomMusic({
    required String url,
    required String title,
    int seekMs = 0,
  });
  Future<bool> stopRoomMusic();

  /// Applies the platform-appropriate output route policy.
  Future<void> preferSystemAudioRoute();

  /// Terminal and idempotent. Room transitions should use [leave] instead.
  Future<void> dispose();
}
