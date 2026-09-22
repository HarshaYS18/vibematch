import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_api_service.dart';
import '../../features/auth/models/current_user.dart';
import '../../identity/data/identity_repository.dart';

class AppIdentityRuntime {
  AppIdentityRuntime({
    required IdentityRepository identityRepository,
  }) : _identityRepository = identityRepository;

  final IdentityRepository _identityRepository;
  StreamSubscription<CurrentUser>? _subscription;

  void start({required CurrentUser initialUser}) {
    _identityRepository.accept(initialUser);
    _subscription ??= AuthUserRealtimeService.instance.users.listen(
      _identityRepository.accept,
    );
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}

final appIdentityRuntimeProvider = Provider.autoDispose<AppIdentityRuntime>(
  (ref) {
    final runtime = AppIdentityRuntime(
      identityRepository: ref.read(identityRepositoryProvider.notifier),
    );
    ref.onDispose(runtime.dispose);
    return runtime;
  },
);
