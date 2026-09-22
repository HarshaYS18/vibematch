import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibematch_app/features/auth/models/current_user.dart';
import 'package:vibematch_app/features/auth/presentation/auth_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backend-incomplete profile overrides stale local completion flag', () async {
    final user = CurrentUser.mockNormalUser();
    final key = 'vm_profile_setup_done_${user.publicUserId}';
    SharedPreferences.setMockInitialValues(<String, Object>{key: true});
    final prefs = await SharedPreferences.getInstance();

    final needsSetup = await resolveProfileSetupRequirement(user: user, prefs: prefs);

    expect(needsSetup, isTrue);
    expect(prefs.getBool(key), isNull);
  });

  test('backend-complete profile self-heals local completion flag', () async {
    final base = CurrentUser.mockNormalUser();
    final user = CurrentUser.fromJson(<String, dynamic>{
      ...base.toJson(),
      'avatar_url': 'https://cdn.example/avatar.jpg',
    });
    final key = 'vm_profile_setup_done_${user.publicUserId}';
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    final needsSetup = await resolveProfileSetupRequirement(user: user, prefs: prefs);

    expect(needsSetup, isFalse);
    expect(prefs.getBool(key), isTrue);
  });
}
