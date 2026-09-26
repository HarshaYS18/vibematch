import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/wallet/data/wallet_realtime_sync_service.dart';
import '../../identity/data/identity_repository.dart';
import '../../realtime/app_realtime_hub.dart';

class AppWalletRuntime {
  AppWalletRuntime({
    required AppRealtimeHub realtimeHub,
    required IdentityRepository identityRepository,
  })  : _realtimeHub = realtimeHub,
        _identityRepository = identityRepository;

  final AppRealtimeHub _realtimeHub;
  final IdentityRepository _identityRepository;

  StreamSubscription<dynamic>? _eventSubscription;
  StreamSubscription<RealtimeResyncRequest>? _resyncSubscription;
  bool _started = false;
  bool _resyncInFlight = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    await _realtimeHub.start();
    _eventSubscription = _realtimeHub.events.listen((event) {
      WalletRealtimeSyncService.instance.applyRealtimeEvent(
        event.toLegacyEvent(),
      );
    });
    _resyncSubscription = _realtimeHub.resyncRequests.listen(
      (request) => unawaited(_handleResync(request)),
    );
  }

  Future<void> _handleResync(RealtimeResyncRequest request) async {
    if (_resyncInFlight) return;
    if (request.stream != '*' && !request.stream.startsWith('app:')) return;
    _resyncInFlight = true;
    try {
      await _identityRepository.refresh();
      final observed = request.observedSequence;
      if (observed != null && observed > 0 && request.stream != '*') {
        _realtimeHub.markResynced(request.stream, observed);
      }
    } catch (_) {
      // The next reconnect/event gap will retry canonical master-state sync.
    } finally {
      _resyncInFlight = false;
    }
  }

  Future<void> stop() async {
    _started = false;
    final eventSubscription = _eventSubscription;
    final resyncSubscription = _resyncSubscription;
    _eventSubscription = null;
    _resyncSubscription = null;
    await eventSubscription?.cancel();
    await resyncSubscription?.cancel();
  }
}

final appWalletRuntimeProvider = Provider.autoDispose<AppWalletRuntime>((ref) {
  final runtime = AppWalletRuntime(
    realtimeHub: ref.read(appRealtimeHubProvider),
    identityRepository: ref.read(identityRepositoryProvider.notifier),
  );
  ref.onDispose(() => unawaited(runtime.stop()));
  return runtime;
});
