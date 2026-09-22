import '../domain/watch_party_state.dart';
import '../domain/watch_provider_adapter.dart';
import 'watch_party_clock.dart';

class WatchPartyCoordinator {
  WatchPartyCoordinator({
    required WatchProviderAdapter adapter,
    WatchPartyClock? clock,
    this.ignoreDriftMs = 250,
    this.largeDriftMs = 1500,
  }) : _adapter = adapter,
       _clock = clock ?? WatchPartyClock();

  final WatchProviderAdapter _adapter;
  final WatchPartyClock _clock;
  final int ignoreDriftMs;
  final int largeDriftMs;

  Future<void> _tail = Future<void>.value();
  String? _loadedFingerprint;
  bool _disposed = false;

  WatchPartyClock get clock => _clock;

  Future<void> reconcile(WatchPartyState state) {
    if (_disposed) return Future<void>.value();
    final operation = _tail.then((_) => _apply(state));
    _tail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<void> _apply(WatchPartyState state) async {
    if (state.serverTimeMs > 0) {
      _clock.observeServerTime(state.serverTimeMs);
    }

    final session = state.session;
    if (session == null || !session.active) {
      if (_loadedFingerprint != null &&
          _adapter.capabilities.programmaticPause) {
        await _adapter.pause();
      }
      return;
    }

    if (_adapter.providerId.trim().toLowerCase() !=
        session.provider.trim().toLowerCase()) {
      throw StateError(
        'Watch provider adapter ${_adapter.providerId} cannot render '
        '${session.provider}.',
      );
    }

    final fingerprint =
        '${session.sessionId}|${session.contentId ?? ''}|${session.contentUrl ?? ''}';
    if (_loadedFingerprint != fingerprint) {
      await _adapter.load(session);
      _loadedFingerprint = fingerprint;
    }

    final capabilities = _adapter.capabilities;
    final targetMs = session.targetPositionMsAt(_clock.serverNowMs);

    if (capabilities.programmaticPosition) {
      final localMs = await _adapter.currentPositionMs();
      final driftMs = targetMs - localMs;
      final driftAbs = driftMs.abs();

      if (session.playbackState == WatchPlaybackState.paused) {
        if (driftAbs > ignoreDriftMs && capabilities.programmaticSeek) {
          await _adapter.seekTo(targetMs);
        }
        if (capabilities.playbackRateControl) {
          await _adapter.setPlaybackRate(session.playbackRate);
        }
      } else if (driftAbs >= largeDriftMs ||
          !capabilities.playbackRateControl) {
        if (driftAbs > ignoreDriftMs && capabilities.programmaticSeek) {
          await _adapter.seekTo(targetMs);
        }
        if (capabilities.playbackRateControl) {
          await _adapter.setPlaybackRate(session.playbackRate);
        }
      } else if (driftAbs > ignoreDriftMs) {
        final correction = driftMs > 0 ? 1.05 : 0.95;
        await _adapter.setPlaybackRate(
          (session.playbackRate * correction).clamp(0.25, 4.0).toDouble(),
        );
      } else if (capabilities.playbackRateControl) {
        await _adapter.setPlaybackRate(session.playbackRate);
      }
    }

    if (session.playbackState == WatchPlaybackState.playing) {
      if (capabilities.programmaticPlay) {
        await _adapter.play();
      }
    } else if (capabilities.programmaticPause) {
      await _adapter.pause();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _tail;
    await _adapter.dispose();
  }
}
