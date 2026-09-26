import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_api_service.dart';
import '../../features/auth/models/current_user.dart';
import '../domain/identity_state.dart';

class IdentityRepository extends Notifier<IdentityState> {
  final AuthApiService _authApiService = const AuthApiService();

  @override
  IdentityState build() => const IdentityState.empty();

  void accept(CurrentUser user) {
    state = IdentityState.fromUser(user);
  }

  Future<CurrentUser> refresh() async {
    final user = await _authApiService.getCurrentUser(forceRefresh: true);
    accept(user);
    return user;
  }

  Future<CurrentUser> updateProfile({
    required String displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    final user = await _authApiService.updateProfile(
      displayName: displayName,
      bio: bio,
      avatarUrl: avatarUrl,
    );
    accept(user);
    return user;
  }

  Future<void> persist(CurrentUser user) async {
    await _authApiService.persistCurrentUser(user);
    accept(user);
  }

  void clear() {
    state = const IdentityState.empty();
  }
}

final identityRepositoryProvider =
    NotifierProvider<IdentityRepository, IdentityState>(
      IdentityRepository.new,
    );
