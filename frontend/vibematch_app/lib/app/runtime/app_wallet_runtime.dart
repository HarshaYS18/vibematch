import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/wallet/data/wallet_realtime_sync_service.dart';

class AppWalletRuntime {
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await WalletRealtimeSyncService.instance.start();
    } catch (_) {
      _started = false;
      rethrow;
    }
  }

  Future<void> stop() async {
    _started = false;
    await WalletRealtimeSyncService.instance.stop();
  }
}

final appWalletRuntimeProvider = Provider.autoDispose<AppWalletRuntime>((ref) {
  final runtime = AppWalletRuntime();
  ref.onDispose(() => unawaited(runtime.stop()));
  return runtime;
});
