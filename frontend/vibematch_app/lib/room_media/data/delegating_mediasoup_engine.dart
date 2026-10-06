import 'dart:async';

import '../domain/room_media_engine.dart';
import '../runtime/room_media_resource_registry_binding.dart';
import 'mediasoup_audio_delegate.dart';

/// Deterministic lifecycle wrapper shared by native and web mediasoup engines.
///
/// All mutating operations are serialized so reconnects, room switches, and
/// teardown cannot create overlapping producer/consumer lifecycles.
abstract class DelegatingMediasoupEngine implements RoomMediaEngine, RoomMediaResourceRegistryBinding {
  DelegatingMediasoupEngine({
    required MediasoupAudioDelegate delegate,
  }) : _delegate = delegate;

  final MediasoupAudioDelegate _delegate;

  Future<void> _tail = Future<void>.value();
  RoomMediaJoinRequest? _session;
  RoomMediaEnginePhase _phase = RoomMediaEnginePhase.idle;
  final Set<String> _consumedProducerIds = <String>{};

  bool _disposeRequested = false;
  Future<void>? _disposeFuture;

  MediasoupAudioDelegate get delegate => _delegate;

  @override
  void bindMediaResourceRegistry(registry) {
    _delegate.bindMediaResourceRegistry(registry);
  }

  @override
  RoomMediaEnginePhase get phase => _phase;

  @override
  String? get roomId => _session?.roomId;

  @override
  String? get userId => _session?.userId;

  @override
  bool get isDisposed => _phase == RoomMediaEnginePhase.disposed;

  @override
  get remoteAudioRenderers => _delegate.remoteAudioRenderers;

  @override
  get activeSpeakerPeerIds => _delegate.activeSpeakerPeerIds;

  @override
  get lastError => _delegate.lastError;

  @override
  Future<void> join(RoomMediaJoinRequest request) {
    final normalized = RoomMediaJoinRequest(
      roomId: request.roomId.trim(),
      userId: request.userId.trim(),
    );

    if (normalized.roomId.isEmpty || normalized.userId.isEmpty) {
      return Future<void>.error(
        ArgumentError('Room media join requires roomId and userId.'),
      );
    }

    return _enqueue<void>(() async {
      _ensureUsable();

      final current = _session;
      if (current?.sessionKey == normalized.sessionKey &&
          _delegate.isJoined) {
        _phase = RoomMediaEnginePhase.joined;
        return;
      }

      if (current != null &&
          current.sessionKey != normalized.sessionKey) {
        await _leaveUnlocked();
      }

      _phase = RoomMediaEnginePhase.joining;
      _session = normalized;

      try {
        await _delegate.join(
          roomId: normalized.roomId,
          userId: normalized.userId,
        );
        _phase = RoomMediaEnginePhase.joined;
      } catch (_) {
        _session = null;
        _phase = RoomMediaEnginePhase.idle;
        rethrow;
      }
    });
  }

  @override
  Future<void> leave() {
    if (_disposeRequested) {
      return _disposeFuture ?? Future<void>.value();
    }

    return _enqueue<void>(() async {
      if (_disposeRequested) return;
      await _leaveUnlocked();
    });
  }

  @override
  Future<void> publishMic({
    required int seatIndex,
    bool muted = false,
  }) {
    if (seatIndex < 0) {
      return Future<void>.error(
        ArgumentError.value(seatIndex, 'seatIndex', 'must be non-negative'),
      );
    }

    return _enqueue<void>(() async {
      _ensureUsable();
      _requireSession();
      await _delegate.syncSeat(
        seatIndex: seatIndex,
        micEnabled: !muted,
      );
    });
  }

  @override
  Future<void> stopPublishingMic() {
    return _enqueue<void>(() async {
      _ensureUsable();
      if (_session == null) return;
      await _delegate.stopPublishingMic();
    });
  }

  @override
  Future<void> mute() {
    return _enqueue<void>(() async {
      _ensureUsable();
      if (_session == null) return;
      await _delegate.setMuted(true);
    });
  }

  @override
  Future<void> unmute() {
    return _enqueue<void>(() async {
      _ensureUsable();
      _requireSession();
      await _delegate.setMuted(false);
    });
  }

  @override
  Future<void> consume(RoomMediaRemoteProducer producer) {
    final producerId = producer.producerId.trim();
    if (producerId.isEmpty) return Future<void>.value();

    return _enqueue<void>(() async {
      _ensureUsable();
      _requireSession();

      if (_consumedProducerIds.contains(producerId)) return;
      _consumedProducerIds.add(producerId);

      try {
        await _delegate.consume(producer);
      } catch (_) {
        _consumedProducerIds.remove(producerId);
        rethrow;
      }
    });
  }

  @override
  Future<void> reconnect() {
    return _enqueue<void>(() async {
      _ensureUsable();
      if (_session == null) return;

      _phase = RoomMediaEnginePhase.reconnecting;
      try {
        await _delegate.reconnect();
        _phase = RoomMediaEnginePhase.joined;
      } catch (_) {
        _phase = _delegate.isJoined
            ? RoomMediaEnginePhase.joined
            : RoomMediaEnginePhase.joining;
        rethrow;
      }
    });
  }

  @override
  Future<bool> startRoomMusic({
    required String url,
    required String title,
    int seekMs = 0,
  }) {
    return _enqueue<bool>(() async {
      _ensureUsable();
      _requireSession();
      return _delegate.startRoomMusic(
        url: url,
        title: title,
        seekMs: seekMs,
      );
    });
  }

  @override
  Future<bool> stopRoomMusic() {
    return _enqueue<bool>(() async {
      _ensureUsable();
      if (_session == null) return false;
      return _delegate.stopRoomMusic();
    });
  }

  @override
  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) return existing;

    _disposeRequested = true;
    final future = _enqueue<void>(() async {
      if (isDisposed) return;
      await _leaveUnlocked();
      _phase = RoomMediaEnginePhase.disposed;
    });
    _disposeFuture = future;
    return future;
  }

  Future<void> _leaveUnlocked() async {
    if (_session == null && !_delegate.isJoined) {
      _phase = RoomMediaEnginePhase.idle;
      _consumedProducerIds.clear();
      return;
    }

    _phase = RoomMediaEnginePhase.leaving;
    try {
      await _delegate.leave();
    } finally {
      _session = null;
      _consumedProducerIds.clear();
      if (!_disposeRequested) {
        _phase = RoomMediaEnginePhase.idle;
      }
    }
  }

  RoomMediaJoinRequest _requireSession() {
    final session = _session;
    if (session == null) {
      throw StateError('Room media is not joined.');
    }
    return session;
  }

  void _ensureUsable() {
    if (_disposeRequested || isDisposed) {
      throw StateError('RoomMediaEngine has been disposed.');
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final completer = Completer<T>();

    _tail = _tail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }
}
