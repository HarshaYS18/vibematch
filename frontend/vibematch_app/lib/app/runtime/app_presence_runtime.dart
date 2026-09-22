import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/presence/data/presence_api_service.dart';
import '../../session/data/session_repository.dart';

class AppPresenceRuntime {
  AppPresenceRuntime({
    required PresenceApiService presenceApiService,
    required SessionRepository sessionRepository,
  })  : _presenceApiService = presenceApiService,
        _sessionRepository = sessionRepository;

  final PresenceApiService _presenceApiService;
  final SessionRepository _sessionRepository;

  Timer? _heartbeatTimer;
  Future<void> Function()? _onSessionInvalid;
  bool _heartbeatInFlight = false;
  bool _invalidSessionReported = false;

  void start({
    Future<void> Function()? onSessionInvalid,
  }) {
    _onSessionInvalid = onSessionInvalid ?? _onSessionInvalid;
    _invalidSessionReported = false;
    if (_heartbeatTimer != null) return;

    unawaited(_heartbeat());
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_heartbeat()),
    );
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _heartbeat() async {
    if (_heartbeatInFlight) return;
    _heartbeatInFlight = true;
    try {
      await _presenceApiService.heartbeat();
    } catch (error) {
      if (!_sessionRepository.isAuthoritativeFailure(error) ||
          _invalidSessionReported) {
        return;
      }
      _invalidSessionReported = true;
      stop();
      await _onSessionInvalid?.call();
    } finally {
      _heartbeatInFlight = false;
    }
  }

  void dispose() => stop();
}

final appPresenceRuntimeProvider = Provider.autoDispose<AppPresenceRuntime>(
  (ref) {
    final runtime = AppPresenceRuntime(
      presenceApiService: const PresenceApiService(),
      sessionRepository: ref.read(sessionRepositoryProvider.notifier),
    );
    ref.onDispose(runtime.dispose);
    return runtime;
  },
);
