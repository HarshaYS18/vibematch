import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/features/auth/models/current_user.dart';
import 'package:vibematch_app/features/auth/presentation/auth_gate.dart';

void main() {
  test('backend-incomplete profile requires onboarding', () async {
    final user = CurrentUser.mockNormalUser();

    final needsSetup = await resolveProfileSetupRequirement(user: user);

    expect(needsSetup, isTrue);
  });

  test('backend-complete profile skips onboarding', () async {
    final base = CurrentUser.mockNormalUser();
    final user = CurrentUser.fromJson(<String, dynamic>{
      ...base.toJson(),
      'display_name': 'Canonical User',
      'avatar_url': 'https://cdn.example/avatar.jpg',
      'profile_setup_completed': true,
    });

    final needsSetup = await resolveProfileSetupRequirement(user: user);

    expect(needsSetup, isFalse);
  });

  test('explicit backend incomplete state wins over populated local fields', () async {
    final base = CurrentUser.mockNormalUser();
    final user = CurrentUser.fromJson(<String, dynamic>{
      ...base.toJson(),
      'display_name': 'Canonical User',
      'avatar_url': 'https://cdn.example/avatar.jpg',
      'profile_setup_completed': false,
    });

    expect(
      await resolveProfileSetupRequirement(user: user),
      isTrue,
    );
  });
}
