import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_api_service.dart';
import '../../features/auth/models/current_user.dart';
import '../domain/session_state.dart';

class SessionRepository extends StateNotifier<SessionState> {
  SessionRepository({
    AuthApiService authApiService = const AuthApiService(),
  })  : _authApiService = authApiService,
        super(const SessionState.unknown());

  final AuthApiService _authApiService;

  Future<CurrentUser> restore() async {
    state = const SessionState(status: SessionStatus.restoring);
    try {
      final user = await _authApiService.restoreCurrentUser();
      await _publishAuthenticated(user);
      return user;
    } catch (error) {
      state = SessionState(
        status: SessionStatus.signedOut,
        failureMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<CurrentUser> devLogin({
    required String email,
    String? username,
    String? displayName,
  }) async {
    final result = await _authApiService.devLogin(
      email: email,
      username: username,
      displayName: displayName,
    );
    await _publishAuthenticated(result.user);
    return result.user;
  }

  Future<CurrentUser> googleLogin({required String idToken}) async {
    final result = await _authApiService.googleLogin(idToken: idToken);
    await _publishAuthenticated(result.user);
    return result.user;
  }

  Future<CurrentUser> refresh() async {
    final user = await _authApiService.getCurrentUser(forceRefresh: true);
    await _publishAuthenticated(user);
    return user;
  }

  Future<void> logout() async {
    await _authApiService.logout();
    state = const SessionState(status: SessionStatus.signedOut);
  }

  void handleExternalSignOut() {
    state = const SessionState(status: SessionStatus.signedOut);
  }

  bool isAuthoritativeFailure(Object error) {
    return _authApiService.isAuthoritativeSessionFailure(error);
  }

  Future<void> _publishAuthenticated(CurrentUser user) async {
    state = SessionState(
      status: SessionStatus.authenticated,
      accessToken: _authApiService.cachedAccessToken,
      deviceSessionId: await _authApiService.getCurrentDeviceId(),
      signedInUserId: user.id,
    );
  }
}

final sessionRepositoryProvider =
    StateNotifierProvider<SessionRepository, SessionState>(
  (ref) => SessionRepository(),
);
