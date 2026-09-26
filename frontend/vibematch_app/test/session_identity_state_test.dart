import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/auth/models/current_user.dart';
import 'package:vibematch_app/identity/domain/identity_state.dart';
import 'package:vibematch_app/session/domain/session_state.dart';

void main() {
  test('identity state exposes one versioned canonical avatar', () {
    final base = CurrentUser.mockNormalUser();
    final user = CurrentUser.fromJson(<String, dynamic>{
      ...base.toJson(),
      'display_name': 'FunKey User',
      'avatar_url': 'https://cdn.example/avatar.jpg',
      'profile_setup_completed': true,
      'updated_at': '2026-09-22T12:00:00Z',
    });

    final state = IdentityState.fromUser(user);

    expect(state.profileSetupCompleted, isTrue);
    expect(state.avatar.url, 'https://cdn.example/avatar.jpg');
    expect(state.avatar.thumbnailUrl, state.avatar.url);
    expect(state.profileVersion, greaterThan(0));
  });

  test('session authentication requires token and canonical user id', () {
    const state = SessionState(
      status: SessionStatus.authenticated,
      accessToken: 'token',
      deviceSessionId: 'device',
      signedInUserId: 42,
    );

    expect(state.isAuthenticated, isTrue);
  });
}
